import 'dart:async';
import 'package:customer/utils/zone_selection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../models/banner_model.dart';
import '../service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DineInController extends GetxController {
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

  RxBool isLoading = true.obs;
  RxBool isPopular = true.obs;

  @override
  void onInit() {
    getCategory();
    getData();
    // TODO: implement onInit
    super.onInit();
  }

  RxList<VendorCategoryModel> vendorCategoryModel = <VendorCategoryModel>[].obs;

  RxList<VendorModel> allNearestRestaurant = <VendorModel>[].obs;
  RxList<VendorModel> newArrivalRestaurantList = <VendorModel>[].obs;
  RxList<VendorModel> popularRestaurantList = <VendorModel>[].obs;

  RxList<BannerModel> bannerBottomModel = <BannerModel>[].obs;
  Rx<PageController> pageBottomController = PageController(viewportFraction: 0.877).obs;
  RxInt currentBottomPage = 0.obs;

  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;

  Future<void> getData() async {
    isLoading.value = true;
    await getZone();

    _subscriptions.add(FireStoreUtils.getAllNearestRestaurant(isDining: true).listen((event) async {
      newArrivalRestaurantList.clear();
      allNearestRestaurant.clear();
      popularRestaurantList.clear();

      allNearestRestaurant.addAll(event);
      newArrivalRestaurantList.addAll(event);
      popularRestaurantList.addAll(event);

      popularRestaurantList.sort(
        (a, b) => Constant.calculateReview(
          reviewCount: b.reviewsCount.toString(),
          reviewSum: b.reviewsSum.toString(),
        ).compareTo(Constant.calculateReview(reviewCount: a.reviewsCount.toString(), reviewSum: a.reviewsSum.toString())),
      );

      newArrivalRestaurantList.sort((a, b) => (b.createdAt ?? Timestamp.now()).toDate().compareTo((a.createdAt ?? Timestamp.now()).toDate()));
    }));

    update();
    // Was a flat three-second sleep, whatever the connection did. The spinner
    // now lifts on the first delivery from the listener above, and only falls
    // back to a timeout when the list really is empty - see the same change in
    // `FoodHomeController.setLoading()`.
    unawaited(_clearLoadingWhenRestaurantsArrive());
  }

  Future<void> _clearLoadingWhenRestaurantsArrive() async {
    if (allNearestRestaurant.isNotEmpty) {
      isLoading.value = false;
      return;
    }

    final Completer<void> firstDelivery = Completer<void>();
    final Worker listener = ever<List<VendorModel>>(allNearestRestaurant, (List<VendorModel> value) {
      if (value.isNotEmpty && !firstDelivery.isCompleted) firstDelivery.complete();
    });

    try {
      await firstDelivery.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Timed out: nothing nearby, as far as this screen can tell.
    } finally {
      listener.dispose();
      isLoading.value = false;
    }
  }

  /// Three independent reads, previously queued behind one another.
  Future<void> getCategory() async {
    await Future.wait(<Future<void>>[
      FireStoreUtils.getHomeVendorCategory().then((value) {
        vendorCategoryModel.value = value;
      }),
      FireStoreUtils.getHomeBottomBanner().then((value) {
        bannerBottomModel.value = value;
      }),
      if (Constant.userModel != null)
        FireStoreUtils.getFavouriteRestaurant().then((value) {
          favouriteList.value = value;
        }),
    ]);
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
