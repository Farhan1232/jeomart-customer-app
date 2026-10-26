import 'package:customer/themes/show_toast_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/constant.dart';
import '../screen_ui/auth_screens/otp_verification_screen.dart';

class MobileLoginController extends GetxController {
  final Rx<TextEditingController> mobileController = TextEditingController().obs;
  final Rx<TextEditingController> countryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  final Rx<TextEditingController> countryISOCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP to the entered phone number
  Future<void> sendOtp() async {
    final mobile = mobileController.value.text.trim();
    final countryCode = countryCodeController.value.text.trim();
    final countryISOCode = countryISOCodeController.value.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      ShowToastDialog.showToast("Please enter a valid 10-digit mobile number".tr);
      return;
    }

    try {
      ShowToastDialog.showLoader("Sending OTP...".tr);

      await _auth.verifyPhoneNumber(
        phoneNumber: '$countryCode$mobile',
        verificationCompleted: (PhoneAuthCredential credential) {
          // Optionally handle auto-verification
        },
        verificationFailed: (FirebaseAuthException e) {
          ShowToastDialog.closeLoader();
          if (e.code == 'invalid-phone-number') {
            ShowToastDialog.showToast("Invalid phone number".tr);
          } else {
            ShowToastDialog.showToast(e.message ?? "OTP verification failed".tr);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          ShowToastDialog.closeLoader();
          Get.to(() => const OtpVerificationScreen(), arguments: {'countryCode': countryCode, 'countryISOCode': countryISOCode, 'phoneNumber': mobile, 'verificationId': verificationId});
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("OTP timed out. Please try again.".tr);
          // Optional: Handle timeout
        },
      );
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
    }
  }

  @override
  void onClose() {
    mobileController.value.dispose();
    countryCodeController.value.dispose();
    countryISOCodeController.value.dispose();
    super.onClose();
  }
}
