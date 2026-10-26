import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../service/fire_store_utils.dart';
import '../utils/firestore_paginator.dart';
import '../utils/parallel.dart';
import 'package:get/get.dart';

/// The Favourites screen.
///
/// ## What changed here, and why
///
/// This was the last screen in the app still reading a whole collection into an
/// `RxList` - the "known gap C-2" the pagination coverage test carried as an
/// accepted exemption. Two things were wrong with it, and they compounded:
///
/// 1. **Both favourite sets were read whole**, with no page and no cursor.
/// 2. **Each row then cost two more reads, in series.** For every favourited
///    product it read the product, waited, read that product's vendor, waited,
///    and only then moved to the next row. A customer with 20 favourited items
///    paid 40 round trips laid end to end before the tab drew anything.
///
/// Now each list is paged 20 at a time by the same [FirestorePaginator] the
/// order, booking, wallet and review screens use, and the enrichment for a page
/// happens in two concurrent waves rather than 2N serial steps - with each
/// distinct vendor asked for once even when several favourites share it.
///
/// The rows themselves, their order, and every subscription-expiry rule that
/// decides whether a favourite is still shown are unchanged.
class FavouriteController extends GetxController {
  RxBool favouriteRestaurant = true.obs;
  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;
  RxList<VendorModel> favouriteVendorList = <VendorModel>[].obs;

  RxList<FavouriteItemModel> favouriteItemList = <FavouriteItemModel>[].obs;
  RxList<ProductModel> favouriteFoodList = <ProductModel>[].obs;

  RxBool isLoading = true.obs;

  /// Pages `favorite_vendor` for this customer and section.
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, FavouriteModel>? vendorsPaginator;

  /// Pages `favorite_item` for this customer and section.
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, FavouriteItemModel>? itemsPaginator;

  Worker? _vendorsWorker;
  Worker? _itemsWorker;

  /// Vendors already fetched this session, so paging forward never re-reads a
  /// vendor an earlier page already resolved.
  final Map<String, VendorModel> _vendorsById = <String, VendorModel>{};

  bool get hasMoreFavouriteVendors => vendorsPaginator?.hasMore.value ?? false;

  bool get hasMoreFavouriteItems => itemsPaginator?.hasMore.value ?? false;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  @override
  void onClose() {
    _vendorsWorker?.dispose();
    _itemsWorker?.dispose();
    vendorsPaginator?.dispose();
    itemsPaginator?.dispose();
    super.onClose();
  }

  Future<void> getData() async {
    reset();
    if (Constant.userModel != null) {
      _startVendorsPaginator();
      _startItemsPaginator();
      // Both first pages are asked for together.
      await Future.wait(<Future<void>>[vendorsPaginator!.refresh(), itemsPaginator!.refresh()]);
    }
    isLoading.value = false;
  }

  void _startVendorsPaginator() {
    _vendorsWorker?.dispose();
    vendorsPaginator?.dispose();

    final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, FavouriteModel>(
      source: FirestorePageSource(FireStoreUtils.favouriteVendorQuery()),
      mapper: (doc) {
        final data = doc.data();
        if (data == null) return null;
        try {
          return FavouriteModel.fromJson(data);
        } catch (_) {
          return null;
        }
      },
      pageSize: 20,
    );
    vendorsPaginator = paginator;

    _vendorsWorker = ever<List<FavouriteModel>>(paginator.items, (List<FavouriteModel> items) {
      favouriteList.value = items;
      unawaited(_resolveFavouriteVendors(items));
    });
  }

  void _startItemsPaginator() {
    _itemsWorker?.dispose();
    itemsPaginator?.dispose();

    final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, FavouriteItemModel>(
      source: FirestorePageSource(FireStoreUtils.favouriteItemQuery()),
      mapper: (doc) {
        final data = doc.data();
        if (data == null) return null;
        try {
          return FavouriteItemModel.fromJson(data);
        } catch (_) {
          return null;
        }
      },
      pageSize: 20,
    );
    itemsPaginator = paginator;

    _itemsWorker = ever<List<FavouriteItemModel>>(paginator.items, (List<FavouriteItemModel> items) {
      favouriteItemList.value = items;
      unawaited(_resolveFavouriteFoods(items));
    });
  }

  /// Turns the current page of favourited vendors into the vendor cards shown.
  ///
  /// Every filtering rule below is the one that was here before; only the
  /// fetching changed, from one awaited read per row to one concurrent wave.
  Future<void> _resolveFavouriteVendors(List<FavouriteModel> favourites) async {
    final List<VendorModel?> vendors = await Parallel.map<FavouriteModel, VendorModel>(
      favourites,
      (FavouriteModel element) => FireStoreUtils.getVendorById(element.restaurantId.toString()),
    );

    final List<VendorModel> favouriteVendorData = <VendorModel>[];
    for (final VendorModel? value in vendors) {
      if (value == null) continue;
      if ((Constant.isSubscriptionModelApplied == true || value.adminCommission?.isEnabled == true) && value.subscriptionPlan != null) {
        if (value.subscriptionTotalOrders == "-1") {
          favouriteVendorData.add(value);
        } else {
          if ((value.subscriptionExpiryDate != null && value.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || value.subscriptionPlan?.expiryDay == '-1') {
            if (value.subscriptionTotalOrders != '0') {
              favouriteVendorData.add(value);
            }
          }
        }
      } else {
        favouriteVendorData.add(value);
      }
    }

    favouriteVendorData.sort((a, b) {
      final aOpen = Constant.statusCheckOpenORClose(vendorModel: a);
      final bOpen = Constant.statusCheckOpenORClose(vendorModel: b);
      if (aOpen == bOpen) return 0;
      return aOpen ? -1 : 1;
    });

    favouriteVendorList.value = removeDuplicateVendor(favouriteVendorData);
  }

  /// Turns the current page of favourited products into the product cards.
  ///
  /// Two waves - every product, then every vendor those products name - in
  /// place of the read-wait-read-wait chain this used to be. Vendors already
  /// resolved on an earlier page are not asked for again.
  Future<void> _resolveFavouriteFoods(List<FavouriteItemModel> favourites) async {
    final List<ProductModel?> products = await Parallel.map<FavouriteItemModel, ProductModel>(
      favourites,
      (FavouriteItemModel element) => FireStoreUtils.getProductById(element.productId.toString()),
    );

    final List<String> vendorIdsNeeded =
        products
            .where((ProductModel? p) => p != null && p.publish == true)
            .map((ProductModel? p) => p!.vendorID.toString())
            .toSet()
            .where((String id) => !_vendorsById.containsKey(id))
            .toList();

    await Parallel.map<String, void>(vendorIdsNeeded, (String vendorId) async {
      final doc = await FireStoreUtils.fireStore.collection(CollectionName.vendors).doc(vendorId).get();
      if (doc.exists) _vendorsById[vendorId] = VendorModel.fromJson(doc.data()!);
      return null;
    });

    final List<ProductModel> favouriteFoodData = <ProductModel>[];
    for (final ProductModel? value in products) {
      if (value == null || value.publish != true) continue;
      final VendorModel? vendorModel = _vendorsById[value.vendorID.toString()];
      if (vendorModel == null) continue;

      if (Constant.isSubscriptionModelApplied == true || vendorModel.adminCommission?.isEnabled == true) {
        if (vendorModel.subscriptionPlan != null) {
          if (vendorModel.subscriptionTotalOrders == "-1") {
            favouriteFoodData.add(value);
          } else {
            if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) ||
                vendorModel.subscriptionPlan?.expiryDay == "-1") {
              if (vendorModel.subscriptionTotalOrders != '0') {
                favouriteFoodData.add(value);
              }
            }
          }
        }
      } else {
        favouriteFoodData.add(value);
      }
    }

    favouriteFoodList.value = removeDuplicateFoods(favouriteFoodData);
  }

  Future<void> loadMoreFavouriteVendors() async {
    await vendorsPaginator?.loadMore();
  }

  Future<void> loadMoreFavouriteItems() async {
    await itemsPaginator?.loadMore();
  }

  Future<void> refreshFavouriteVendors() async {
    await vendorsPaginator?.refresh();
  }

  Future<void> refreshFavouriteItems() async {
    await itemsPaginator?.refresh();
  }

  void reset() {
    favouriteRestaurant.value = true;
    favouriteList.value = [];
    favouriteVendorList.value = [];
    favouriteItemList.value = [];
    favouriteFoodList.value = [];
    _vendorsById.clear();
    isLoading.value = true;
  }

  List<ProductModel> removeDuplicateFoods(List<ProductModel> favouriteFoodList) {
    final seenIds = <String>{};
    return favouriteFoodList.where((food) {
      return seenIds.add(food.id!);
    }).toList();
  }

  List<VendorModel> removeDuplicateVendor(List<VendorModel> favouriteFoodVendor) {
    final seenIds = <String>{};
    return favouriteFoodVendor.where((food) {
      return seenIds.add(food.id!);
    }).toList();
  }
}
