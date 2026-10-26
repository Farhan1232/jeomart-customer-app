import 'package:customer/models/dine_in_booking_model.dart';
import 'package:get/get.dart';

class DineInBookingDetailsController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<DineInBookingModel> bookingModel = DineInBookingModel().obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      bookingModel.value = argumentData['bookingModel'];
    }
    isLoading.value = false;
    update();
  }
}
