import 'dart:async';
import 'package:customer/utils/zone_selection.dart';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/banner_model.dart';
import '../models/story_model.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';

class FoodHomeController extends GetxController {
  /// Firestore listeners opened by this controller.
  ///
  /// They used to run for the rest of the session because nothing cancelled
  /// them when the screen closed, and re-entering the screen opened another
  /// set on top.
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.onClose();
  }

  DashBoardController dashBoardController = Get.find<DashBoardController>();
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
  RxString selectedOrderTypeValue = "Delivery".tr.obs;

  Rx<PageController> pageController = PageController(viewportFraction: 0.877).obs;
  Rx<PageController> pageBottomController = PageController(viewportFraction: 0.877).obs;
  RxInt currentPage = 0.obs;
  RxInt currentBottomPage = 0.obs;

  late TabController tabController;

  @override
  void onInit() async {
    await getData();
    super.onInit();
  }

  RxList<VendorCategoryModel> vendorCategoryModel = <VendorCategoryModel>[].obs;

  RxList<VendorModel> allNearestRestaurant = <VendorModel>[].obs;
  RxList<VendorModel> newArrivalRestaurantList = <VendorModel>[].obs;
  RxList<AdvertisementModel> advertisementList = <AdvertisementModel>[].obs;
  RxList<VendorModel> popularRestaurantList = <VendorModel>[].obs;
  RxList<VendorModel> couponRestaurantList = <VendorModel>[].obs;
  RxList<CouponModel> couponList = <CouponModel>[].obs;

  RxList<StoryModel> storyList = <StoryModel>[].obs;
  RxList<BannerModel> bannerModel = <BannerModel>[].obs;
  RxList<BannerModel> bannerBottomModel = <BannerModel>[].obs;

  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;

  Future<void> getData() async {
    isLoading.value = true;
    getCartData();
    selectedOrderTypeValue.value = Preferences.getString(Preferences.foodDeliveryType, defaultValue: "Delivery");
    await getZone();
    _subscriptions.add(
      FireStoreUtils.getAllNearestRestaurant().listen((event) async {
        popularRestaurantList.clear();
        newArrivalRestaurantList.clear();
        allNearestRestaurant.clear();
        advertisementList.clear();

        allNearestRestaurant.addAll(event);
        newArrivalRestaurantList.addAll(event);
        popularRestaurantList.addAll(event);
        Constant.restaurantList = allNearestRestaurant;
        popularRestaurantList.sort(
          (a, b) => Constant.calculateReview(
            reviewCount: b.reviewsCount.toString(),
            reviewSum: b.reviewsSum.toString(),
          ).compareTo(Constant.calculateReview(reviewCount: a.reviewsCount.toString(), reviewSum: a.reviewsSum.toString())),
        );

        newArrivalRestaurantList.sort((a, b) => (b.createdAt ?? Timestamp.now()).toDate().compareTo((a.createdAt ?? Timestamp.now()).toDate()));
        // Categories, coupons, stories and adverts are four independent reads
        // that were queued behind one another inside this callback - and this
        // callback runs again on **every** change to any nearby vendor
        // document, so the chain was paid repeatedly, not just once. They all
        // read `allNearestRestaurant`, which is already filled above, and none
        // of them reads what another writes. Issued together.
        await Future.wait(<Future<void>>[
          getVendorCategory(),
          FireStoreUtils.getHomeCoupon().then((value) {
            couponRestaurantList.clear();
            couponList.clear();
            for (var element1 in value) {
              for (var element in allNearestRestaurant) {
                if (element1.vendorID == element.id && element1.expiresAt!.toDate().isAfter(DateTime.now())) {
                  couponList.add(element1);
                  couponRestaurantList.add(element);
                }
              }
            }
          }),
          FireStoreUtils.getStory().then((stories) {
            storyList.clear();

            // Create a fast lookup Set of all nearest vendor IDs
            final nearestIds = allNearestRestaurant.map((e) => e.id).toSet();

            // Filter stories whose vendorID exists in nearestIds
            storyList.addAll(stories.where((story) => nearestIds.contains(story.vendorID)));
          }),
          if (Constant.isEnableAdsFeature == true)
            FireStoreUtils.getAllAdvertisement().then((value) {
              advertisementList.clear();
              for (var element1 in value) {
                for (var element in allNearestRestaurant) {
                  if (element1.vendorId == element.id) {
                    advertisementList.add(element1);
                  }
                }
              }
            }),
        ]);
      }),
    );
    setLoading();
  }

  /// Takes the spinner down when the restaurants have actually arrived.
  ///
  /// This used to be a flat `Future.delayed(1s)`, and three seconds when the
  /// list came back empty. It was wrong in both directions, in the same way the
  /// splash screen's three-second timer was before Session 8 removed it:
  ///
  ///  * on a good connection the vendors were on screen in a fraction of a
  ///    second and the customer watched a spinner sit on top of them for the
  ///    rest of the second;
  ///  * on a slow one the timer expired first, so the screen said there was
  ///    nothing nearby and then popped the restaurants in underneath the
  ///    message.
  ///
  /// Now the first delivery from the vendor listener takes the spinner down,
  /// and the timeout is only a floor under a genuinely empty result - a
  /// customer standing outside every delivery zone still has to be told so.
  Future<void> setLoading() async {
    if (allNearestRestaurant.isNotEmpty) {
      isLoading.value = false;
      update();
      return;
    }

    // Nothing yet: wait for the first delivery, but never for ever.
    final Completer<void> firstDelivery = Completer<void>();
    final Worker listener = ever<List<VendorModel>>(allNearestRestaurant, (List<VendorModel> value) {
      if (value.isNotEmpty && !firstDelivery.isCompleted) firstDelivery.complete();
    });

    try {
      await firstDelivery.future.timeout(_emptyResultGrace);
    } catch (_) {
      // Timed out. The list really does look empty, so say so.
    } finally {
      listener.dispose();
      isLoading.value = false;
      update();
    }
  }

  /// How long an empty list is given to fill before the screen commits to
  /// saying it is empty. Matches the old worst case, so a slow connection is no
  /// worse off than it was.
  static const Duration _emptyResultGrace = Duration(seconds: 3);

  /// Four reads that fill four unrelated parts of the home screen, and used to
  /// run one after another. Issued together now - see the same change in
  /// `HomeECommerceController.getVendorCategory()`.
  Future<void> getVendorCategory() async {
    await Future.wait(<Future<void>>[
      FireStoreUtils.getHomeVendorCategory().then((value) {
        vendorCategoryModel.value = value;
        if (Constant.restaurantList != null) {
          List<String> usedCategoryIds = Constant.restaurantList!.expand((vendor) => vendor.categoryID ?? []).whereType<String>().toSet().toList();
          vendorCategoryModel.value = vendorCategoryModel.where((category) => usedCategoryIds.contains(category.id)).toList();
        }
      }),
      FireStoreUtils.getHomeTopBanner().then((value) {
        bannerModel.value = value;
      }),
      FireStoreUtils.getHomeBottomBanner().then((value) {
        bannerBottomModel.value = value;
      }),
      getFavouriteRestaurant(),
    ]);
  }

  Future<void> getFavouriteRestaurant() async {
    if (Constant.userModel?.id != null) {
      await FireStoreUtils.getFavouriteRestaurant().then((value) {
        favouriteList.value = value;
      });
    }
    log("Constant.userModel?.id :: ${favouriteList.length}");
  }

  Future<void> getZone() async {
    await FireStoreUtils.getZone().then((value) {
      // One shared rule - see [ZoneSelection]. A point that is inside no zone
      // used to leave the customer holding whichever zone came last in the list.
      ZoneSelection.apply(
        value,
        latitude: Constant.selectedLocation.location?.latitude,
        longitude: Constant.selectedLocation.location?.longitude,
      );
    });
  }
}
