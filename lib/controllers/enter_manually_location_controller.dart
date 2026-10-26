import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';

class EnterManuallyLocationController extends GetxController {
  Rx<UserModel> userModel = UserModel().obs;

  RxList<ShippingAddress> shippingAddressList = <ShippingAddress>[].obs;

  List saveAsList = ['Home', 'Work', 'Hotel', 'other'].obs;
  RxString selectedSaveAs = "Home".obs;

  Rx<TextEditingController> houseBuildingTextEditingController = TextEditingController().obs;
  Rx<TextEditingController> localityEditingController = TextEditingController().obs;
  Rx<TextEditingController> landmarkEditingController = TextEditingController().obs;
  Rx<UserLocation> location = UserLocation().obs;
  Rx<ShippingAddress> shippingModel = ShippingAddress().obs;
  RxBool isLoading = false.obs;
  RxBool isDefault = false.obs;

  RxString mode = "Add".obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      //check mode
      mode.value = argumentData['mode'] ?? "Add";

      //check address
      if (argumentData['address'] != null && argumentData['address'] is ShippingAddress) {
        shippingModel.value = argumentData['address'];
        setData(shippingModel.value);
      }
    }

    await getUser();
    isLoading.value = false;
    update();
  }

  void setData(ShippingAddress shippingAddress) {
    shippingModel.value = shippingAddress;
    houseBuildingTextEditingController.value.text = shippingAddress.address.toString();
    localityEditingController.value.text = shippingAddress.locality.toString();
    landmarkEditingController.value.text = shippingAddress.landmark.toString();
    selectedSaveAs.value = shippingAddress.addressAs.toString();
    location.value = shippingAddress.location!;
  }

  Future<void> getUser() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        if (userModel.value.shippingAddress != null) {
          shippingAddressList.value = userModel.value.shippingAddress!;
        }
      }
    });
  }

  String getLocalizedSaveAs(String key) {
    switch (key) {
      case 'Home':
        return 'Home'.tr;
      case 'Work':
        return 'Work'.tr;
      case 'Hotel':
        return 'Hotel'.tr;
      case 'Other':
        return 'Other'.tr;
      default:
        return key;
    }
  }
}
