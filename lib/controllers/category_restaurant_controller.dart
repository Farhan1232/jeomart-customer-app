import 'dart:async';
import 'package:customer/utils/zone_selection.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_model.dart';
import '../models/vendor_category_model.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class CategoryRestaurantController extends GetxController {
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
  RxBool dineIn = true.obs;
  RxBool ecommarce = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<VendorCategoryModel> vendorCategoryModel = VendorCategoryModel().obs;
  RxList<VendorModel> allNearestRestaurant = <VendorModel>[].obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      vendorCategoryModel.value = argumentData['vendorCategoryModel'];
      dineIn.value = argumentData['dineIn'];
      ecommarce.value = argumentData['ecommerce'] ?? false;
      await getZone();
      await getRestaurant();
    }
    // Was a flat one-second sleep. The spinner now lifts when the first page of
    // restaurants lands, and falls back to the same one second only when the
    // category genuinely has nothing in it.
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
      await firstDelivery.future.timeout(const Duration(seconds: 1));
    } catch (_) {
      // Timed out: this category has nothing nearby.
    } finally {
      listener.dispose();
      isLoading.value = false;
    }
  }

  Future getRestaurant() async {
    _subscriptions.add(FireStoreUtils.getAllNearestRestaurantByCategoryId(categoryId: vendorCategoryModel.value.id.toString(), isDining: dineIn.value).listen((event) async {
      allNearestRestaurant.clear();
      allNearestRestaurant.addAll(event);
    }));
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
