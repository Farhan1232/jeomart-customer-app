import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/show_toast_dialog.dart';

class ForgotPasswordController extends GetxController {
  Rx<TextEditingController> emailEditingController =
      TextEditingController().obs;

  Future<void> forgotPassword() async {
    final email = emailEditingController.value.text.trim();

    if (email.isEmpty) {
      ShowToastDialog.showToast("Please enter your email address.".tr);
      return;
    }

    if (!GetUtils.isEmail(email)) {
      ShowToastDialog.showToast("Please enter a valid email address.".tr);
      return;
    }

    try {
      ShowToastDialog.showLoader("Please wait...".tr);
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
        'reset_password_link_sent'.trParams({'email': email}),
      );
      Get.back();
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast('No user found for that email.'.tr);
      } else {
        ShowToastDialog.showToast(e.message?.tr ?? "something_went_wrong".tr);
      }
    }
  }
}
