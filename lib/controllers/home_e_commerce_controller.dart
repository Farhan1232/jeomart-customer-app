import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/service/cart_provider.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/constant.dart';

class HomeECommerceController extends GetxController {
  /// Firestore and cart listeners opened by this controller.
  ///
  /// They used to run for the rest of the session because nothing cancelled
  /// them when the screen closed - and because a GetX controller is rebuilt
  /// every time its route is pushed, re-entering the screen opened another set
  /// on top. Five visits meant five live vendor streams all rewriting the same
  /// list, which is Firestore traffic and list rebuilds multiplied by however
  /// many times the customer had been in and out.
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.onClose();
  }

  final CartProvider cartProvider = CartProvider();

  Future<void> getCartData() async {
    _subscriptions.add(cartProvider.cartStream.listen((event) async {
      cartItem.clear();
      cartItem.addAll(event);
    }));
    update();
  }

  RxBool isLoading = true.obs;
  RxBool isListView = true.obs;
  RxBool isPopular = true.obs;

  Rx<PageController> pageController = PageController(viewportFraction: 0.877).obs;
  Rx<PageController> pageBottomController = PageController(viewportFraction: 0.877).obs;
  RxInt currentPage = 0.obs;
  RxInt currentBottomPage = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getVendorCategory();
    getData();
    super.onInit();
  }

  RxList<VendorCategoryModel> vendorCategoryModel = <VendorCategoryModel>[].obs;
  RxList<VendorCategoryModel> categoryWiseProductList = <VendorCategoryModel>[].obs;

  RxList<VendorModel> allNearestRestaurant = <VendorModel>[].obs;
  RxList<VendorModel> newArrivalRestaurantList = <VendorModel>[].obs;
  RxList<AdvertisementModel> advertisementList = <AdvertisementModel>[].obs;

  RxList<BannerModel> bannerModel = <BannerModel>[].obs;
  RxList<BannerModel> bannerBottomModel = <BannerModel>[].obs;
  RxList<BrandsModel> brandList = <BrandsModel>[].obs;

  Future<void> getData() async {
    isLoading.value = true;
    getCartData();
    _subscriptions.add(FireStoreUtils.getAllNearestRestaurant(ecommarce: true).listen((event) async {
      print("=====>${event.length}");

      newArrivalRestaurantList.clear();
      allNearestRestaurant.clear();
      advertisementList.clear();

      allNearestRestaurant.addAll(event);
      newArrivalRestaurantList.addAll(event);
      Constant.restaurantList = allNearestRestaurant;
      List<String> usedCategoryIds = allNearestRestaurant.expand((vendor) => vendor.categoryID ?? []).whereType<String>().toSet().toList();
      vendorCategoryModel.value = vendorCategoryModel.where((category) => usedCategoryIds.contains(category.id)).toList();

      newArrivalRestaurantList.sort((a, b) => (b.createdAt ?? Timestamp.now()).toDate().compareTo((a.createdAt ?? Timestamp.now()).toDate()));

      if (Constant.isEnableAdsFeature == true) {
        await FireStoreUtils.getAllAdvertisement().then((value) {
          advertisementList.clear();
          for (var element1 in value) {
            for (var element in allNearestRestaurant) {
              if (element1.vendorId == element.id) {
                advertisementList.add(element1);
              }
            }
          }
        });
      }
    }));
    setLoading();
  }

  /// Takes the spinner down when the stores have actually arrived, rather than
  /// one second later regardless. Same change, and for the same reasons, as
  /// `FoodHomeController.setLoading()` - see the note there.
  Future<void> setLoading() async {
    if (allNearestRestaurant.isNotEmpty) {
      isLoading.value = false;
      update();
      return;
    }

    final Completer<void> firstDelivery = Completer<void>();
    final Worker listener = ever<List<VendorModel>>(allNearestRestaurant, (List<VendorModel> value) {
      if (value.isNotEmpty && !firstDelivery.isCompleted) firstDelivery.complete();
    });

    try {
      await firstDelivery.future.timeout(_emptyResultGrace);
    } catch (_) {
      // Timed out: the list really is empty as far as this screen can tell.
    } finally {
      listener.dispose();
      isLoading.value = false;
      update();
    }
  }

  /// Matches the old worst case, so a slow connection is no worse off.
  static const Duration _emptyResultGrace = Duration(seconds: 3);

  /// Six reads that fill six unrelated parts of the home screen.
  ///
  /// They used to run one after another, so the last strip on the page waited
  /// for the five above it - six round trips to draw one screen. Nothing here
  /// consumes anything another one produces, so they are issued together and
  /// the screen waits for the slowest, not the sum.
  Future<void> getVendorCategory() async {
    await Future.wait(<Future<void>>[
      FireStoreUtils.getHomeVendorCategory().then((value) {
        vendorCategoryModel.value = value;
      }),
      FireStoreUtils.getHomePageShowCategory().then((value) {
        categoryWiseProductList.value = value;
      }),
      FireStoreUtils.getHomeTopBanner().then((value) {
        bannerModel.value = value;
      }),
      FireStoreUtils.getHomeBottomBanner().then((value) {
        bannerBottomModel.value = value;
      }),
      FireStoreUtils.getBrandList().then((value) {
        brandList.value = value;
      }),
      getFavouriteRestaurant(),
    ]);
  }

  /// The product strip of each category card, read once per visit.
  ///
  /// The screen used to create this future inside `build`, so every rebuild of
  /// the home screen - each vendor delivery, the spinner coming down, each of
  /// the six home reads landing - started every card's reads again, and each
  /// of those re-read the nearby stores and then every store's products. The
  /// store products do not depend on the category, so all cards share one read
  /// of them. A read that fails is forgotten, so the next rebuild tries again
  /// exactly as it used to.
  final Map<String, Future<List<ProductModel>>> _categoryProducts = <String, Future<List<ProductModel>>>{};
  Future<List<ProductModel>>? _storeProducts;

  Future<List<ProductModel>> productsForCategory(String categoryId) {
    final Future<List<ProductModel>>? known = _categoryProducts[categoryId];
    if (known != null) return known;

    Future<List<ProductModel>>? storeProducts = _storeProducts;
    if (storeProducts == null) {
      final Future<List<ProductModel>> started = FireStoreUtils.getStoreProducts();
      _storeProducts = storeProducts = started;
      started.then<void>((_) {}, onError: (Object _) {
        if (identical(_storeProducts, started)) _storeProducts = null;
      });
    }

    final Future<List<ProductModel>> products = FireStoreUtils.getProductListByCategoryId(categoryId, storeProducts: storeProducts);
    _categoryProducts[categoryId] = products;
    products.then<void>((_) {}, onError: (Object _) {
      if (identical(_categoryProducts[categoryId], products)) _categoryProducts.remove(categoryId);
    });
    return products;
  }

  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;

  Future<void> getFavouriteRestaurant() async {
    if (Constant.userModel?.id != null) {
      await FireStoreUtils.getFavouriteRestaurant().then((value) {
        favouriteList.value = value;
      });
    }
  }
}
