import 'dart:async';
import '../models/dine_in_booking_model.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class DineInBookingController extends GetxController {
  RxBool isLoading = true.obs;

  RxBool isFeature = true.obs;

  RxList<DineInBookingModel> featureList = <DineInBookingModel>[].obs;
  RxList<DineInBookingModel> historyList = <DineInBookingModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getDineInBooking();
    super.onInit();
  }

  Future<void> getDineInBooking() async {
    // Upcoming and past bookings are two independent queries that were awaited
    // one after the other. Both are started together and still applied in the
    // same order.
    final featureReq = FireStoreUtils.getDineInBooking(true);
    final historyReq = FireStoreUtils.getDineInBooking(false);
    unawaited(historyReq.then<void>((_) {}, onError: (Object _) {}));

    await featureReq.then(
      (value) {
        featureList.value = value;
      },
    );
    await historyReq.then(
      (value) {
        historyList.value = value;
      },
    );

    isLoading.value = false;
  }
}
