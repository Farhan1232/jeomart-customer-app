import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../constant/constant.dart';
import '../models/referral_model.dart';
import '../utils/registration_field_visibility.dart';
import '../screen_ui/service_home_screen/service_list_screen.dart';
import '../service/fire_store_utils.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/notification_service.dart';

class SignUpController extends GetxController {
  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryISOCodeEditingController = TextEditingController().obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;
  Rx<TextEditingController> referralCodeEditingController = TextEditingController().obs;

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  // State
  final RxBool isLoading = false.obs;
  final auth.FirebaseAuth firebaseAuth = auth.FirebaseAuth.instance;

  RxString type = "email".obs;
  Rx<UserModel> userModel = UserModel().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;
  RxBool agreedToTerms = false.obs;

  @override
  void onInit() {
    super.onInit();
    getArgument();
  }

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      if (type.value == "mobileNumber") {
        phoneNUmberEditingController.value.text = userModel.value.phoneNumber.toString();
        countryCodeEditingController.value.text = userModel.value.countryCode.toString();
        countryISOCodeEditingController.value.text = userModel.value.countryISOCode.toString();
      } else if (type.value == "google" || type.value == "apple") {
        emailEditingController.value.text = userModel.value.email ?? "";
        firstNameEditingController.value.text = userModel.value.firstName ?? "";
        lastNameEditingController.value.text = userModel.value.lastName ?? "";
      }
    }
  }

  /// The referral code the customer typed, or `""` when the field is hidden.
  ///
  /// Session 4 hides the field ("Hide Referral Code from registration page"),
  /// so this is the single place that decides whether a code exists at all.
  /// Reading it defensively means the sign-up path behaves identically whether
  /// the field is absent or simply left blank - which was already a supported
  /// case before this change.
  String get enteredReferralCode =>
      RegistrationFieldVisibility.referralCodeFrom(referralCodeEditingController.value.text);

  Future<void> signUpWithEmailAndPassword() async {
    final String referralCode = enteredReferralCode;
    if (referralCode.isEmpty) {
      // Nothing to validate. Registration proceeds exactly as it did for a
      // customer who left the field empty.
      signUp();
      return;
    }
    await FireStoreUtils.checkReferralCodeValidOrNot(referralCode).then((value) async {
      if (value == true) {
        signUp();
      } else {
        ShowToastDialog.showToast("Referral code is Invalid".tr);
      }
    });
  }

  /// Create this account's own `referral/{uid}` document.
  ///
  /// Every customer gets one - it is what the Refer a Friend screen displays -
  /// so this runs whether or not a code was entered, and accounts created after
  /// Session 4 are indistinguishable from earlier ones there.
  ///
  /// The `referralBy` lookup only runs when a code was actually typed. The
  /// previous code always queried `referralCode == <text>`, so with the field
  /// hidden it would query for the empty string on every signup: a wasted read
  /// that could also match a malformed legacy document and mis-attribute the
  /// referral. The answer for an empty code is "no referrer" by definition.
  Future<void> addReferralRecord() async {
    final String referralCode = enteredReferralCode;
    String referredBy = "";
    if (referralCode.isNotEmpty) {
      final ReferralModel? referrer = await FireStoreUtils.getReferralUserByCode(referralCode);
      referredBy = referrer?.id ?? "";
    }
    await FireStoreUtils.referralAdd(
      ReferralModel(id: FireStoreUtils.getCurrentUid(), referralBy: referredBy, referralCode: Constant.getReferralCode()),
    );
  }

  Future<void> signUp() async {
    ShowToastDialog.showLoader("Please wait".tr);
    if (type.value == "google" || type.value == "apple" || type.value == "mobileNumber") {
      userModel.value.firstName = firstNameEditingController.value.text.toString();
      userModel.value.lastName = lastNameEditingController.value.text.toString();
      userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
      userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
      userModel.value.role = Constant.userRoleCustomer;
      userModel.value.fcmToken = await NotificationService.getToken();
      userModel.value.active = true;
      userModel.value.countryCode = countryCodeEditingController.value.text;
      userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
      userModel.value.createdAt = Timestamp.now();
      userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';

      await addReferralRecord();

      await FireStoreUtils.updateUser(userModel.value).then((value) {
        if (userModel.value.shippingAddress != null && userModel.value.shippingAddress!.isNotEmpty) {
          if (userModel.value.shippingAddress!.where((element) => element.isDefault == true).isNotEmpty) {
            Constant.selectedLocation = userModel.value.shippingAddress!.where((element) => element.isDefault == true).single;
          } else {
            Constant.selectedLocation = userModel.value.shippingAddress!.first;
          }
          Get.offAll(const ServiceListScreen());
        } else {
          Get.offAll(const LocationPermissionScreen());
        }
        ShowToastDialog.showToast("Account create successfully".tr);
      });
    } else {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailEditingController.value.text.trim(), password: passwordEditingController.value.text.trim());
        if (credential.user != null) {
          userModel.value.id = credential.user!.uid;
          userModel.value.firstName = firstNameEditingController.value.text.toString();
          userModel.value.lastName = lastNameEditingController.value.text.toString();
          userModel.value.email = emailEditingController.value.text.toString().toLowerCase();
          userModel.value.phoneNumber = phoneNUmberEditingController.value.text.toString();
          userModel.value.role = Constant.userRoleCustomer;
          userModel.value.fcmToken = await NotificationService.getToken();
          userModel.value.active = true;
          userModel.value.countryCode = countryCodeEditingController.value.text;
          userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
          userModel.value.createdAt = Timestamp.now();
          userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
          userModel.value.provider = 'email';

          await addReferralRecord();

          await FireStoreUtils.updateUser(userModel.value).then((value) async {
            if (userModel.value.shippingAddress != null && userModel.value.shippingAddress!.isNotEmpty) {
              if (userModel.value.shippingAddress!.where((element) => element.isDefault == true).isNotEmpty) {
                Constant.selectedLocation = userModel.value.shippingAddress!.where((element) => element.isDefault == true).single;
              } else {
                Constant.selectedLocation = userModel.value.shippingAddress!.first;
              }
              Get.offAll(const ServiceListScreen());
            } else {
              Get.offAll(const LocationPermissionScreen());
            }
          });
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.".tr);
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast("The account already exists for that email.".tr);
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid".tr);
        }
      } catch (e) {
        ShowToastDialog.showToast(e.toString());
      }
    }

    ShowToastDialog.closeLoader();
  }
}
