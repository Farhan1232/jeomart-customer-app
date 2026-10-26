import 'dart:async';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class AdvertisementListController extends GetxController {
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

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    getAdvertisementList();
    getFavouriteRestaurant();
    super.onInit();
  }

  RxList<AdvertisementModel> advertisementList = <AdvertisementModel>[].obs;

  Future<void> getAdvertisementList() async {
    advertisementList.clear();
    List<VendorModel> allNearestRestaurant = <VendorModel>[];
    _subscriptions.add(
      FireStoreUtils.getAllNearestRestaurant().listen((event) async {
        allNearestRestaurant.addAll(event);
        await FireStoreUtils.getAllAdvertisement().then((value) {
          List<AdvertisementModel> adsList = value;
          advertisementList.addAll(adsList.where((ads) => allNearestRestaurant.any((restaurant) => restaurant.id == ads.vendorId)));
        });
        isLoading.value = false;
      }),
    );
  }

  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;

  Future<void> getFavouriteRestaurant() async {
    if (Constant.userModel != null) {
      await FireStoreUtils.getFavouriteRestaurant().then((value) {
        favouriteList.value = value;
      });
    }
  }
}
