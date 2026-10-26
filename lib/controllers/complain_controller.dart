import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/cab_order_model.dart';
import '../service/fire_store_utils.dart';
import '../themes/show_toast_dialog.dart';

class ComplainController extends GetxController {
  Rx<CabOrderModel> order = CabOrderModel().obs;

  final Rx<TextEditingController> title = TextEditingController().obs;
  final Rx<TextEditingController> comment = TextEditingController().obs;
  RxString status = ''.obs;

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments;
    if (args != null && args is Map && args['order'] is CabOrderModel) {
      order.value = args['order'] as CabOrderModel;
      getComplain();
    } else {
      ShowToastDialog.showToast("Order data not found".tr);
      Get.back();
    }
  }

  Future<void> getComplain() async {
    isLoading.value = true;
    try {
      final data = await FireStoreUtils.getRideComplainData(order.value.id ?? '');
      if (data != null) {
        title.value.text = data['title'] ?? '';
        comment.value.text = data['description'] ?? '';
        status.value = data['status'] ?? '';
      }
    } catch (e) {
      ShowToastDialog.showToast("Failed to load complaint".tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitComplain() async {
    // Validation
    if (title.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter complaint title".tr);
      return;
    }

    if (comment.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter complaint description".tr);
      return;
    }

    isLoading.value = true;
    ShowToastDialog.showLoader("Please wait...".tr);

    try {
      // Check if complaint already exists
      bool exists = await FireStoreUtils.isRideComplainAdded(order.value.id ?? '');

      if (!exists) {
        await FireStoreUtils.setRideComplain(
          orderId: order.value.id ?? '',
          title: title.value.text.trim(),
          description: comment.value.text.trim(),
          customerID: order.value.authorID ?? '',
          customerName: "${order.value.author?.firstName ?? ''} ${order.value.author?.lastName ?? ''}".trim(),
          driverID: order.value.driverId ?? '',
          driverName: "${order.value.driver?.firstName ?? ''} ${order.value.driver?.lastName ?? ''}".trim(),
        );

        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Your complaint has been submitted to admin".tr);
        Get.back();
      } else {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Your complaint is already submitted".tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong, please try again".tr);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    title.value.dispose();
    comment.value.dispose();
    super.onClose();
  }
}
