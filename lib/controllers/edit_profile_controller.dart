import 'dart:io';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import '../service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../themes/show_toast_dialog.dart';

class EditProfileController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<UserModel> userModel = UserModel().obs;

  Rx<TextEditingController> firstNameController = TextEditingController().obs;
  Rx<TextEditingController> lastNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        userModel.value = value;
        firstNameController.value.text = userModel.value.firstName.toString();
        lastNameController.value.text = userModel.value.lastName.toString();
        emailController.value.text = userModel.value.email.toString();
        phoneNumberController.value.text = userModel.value.phoneNumber.toString();
        countryCodeController.value.text = userModel.value.countryCode.toString();
        countryISOCodeController.value.text = userModel.value.countryISOCode.toString();
        profileImage.value = userModel.value.profilePictureURL ?? "";
      }
    });

    isLoading.value = false;
  }

  Future<void> saveData() async {
    ShowToastDialog.showLoader("Please wait...".tr);
    if (Constant().hasValidUrl(profileImage.value) == false && profileImage.value.isNotEmpty) {
      profileImage.value = await Constant.uploadUserImageToFireStorage(File(profileImage.value), "profileImage/${FireStoreUtils.getCurrentUid()}", File(profileImage.value).path.split('/').last);
    }

    userModel.value.firstName = firstNameController.value.text;
    userModel.value.lastName = lastNameController.value.text;
    userModel.value.profilePictureURL = profileImage.value;

    await FireStoreUtils.updateUser(userModel.value).then((value) {
      ShowToastDialog.closeLoader();
      //Get.back(result: true);
    });
  }

  final ImagePicker _imagePicker = ImagePicker();
  RxString profileImage = "".obs;

  Future pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      Get.back();
      profileImage.value = image.path;
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"failed_to_pick".tr} : \n $e");
    }
  }
}
