import 'dart:convert';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../constant/constant.dart';
import '../models/user_model.dart';
import '../screen_ui/auth_screens/login_screen.dart';
import '../screen_ui/auth_screens/sign_up_screen.dart';
import '../screen_ui/service_home_screen/service_list_screen.dart';
import '../service/fire_store_utils.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/notification_service.dart';
import 'package:crypto/crypto.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;

  /// Focus nodes
  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  /// Loading indicator
  final RxBool isLoading = false.obs;

  RxBool passwordVisible = true.obs;

  Future<void> loginWithEmail() async {
    final email = emailController.value.text.trim();
    final password = passwordController.value.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ShowToastDialog.showToast("Please enter a valid email address".tr);
      return;
    }

    if (password.isEmpty) {
      ShowToastDialog.showToast("Please enter your password".tr);
      return;
    }

    try {
      isLoading.value = true;
      ShowToastDialog.showLoader("Logging in...".tr);

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

      final userModel = await FireStoreUtils.getUserProfile(credential.user!.uid);

      if (userModel != null && userModel.role == Constant.userRoleCustomer) {
        if (userModel.active == true) {
          userModel.fcmToken = await NotificationService.getToken();
          await FireStoreUtils.updateUser(userModel);

          if (userModel.shippingAddress != null && userModel.shippingAddress!.isNotEmpty) {
            final defaultAddress = userModel.shippingAddress!.firstWhere((e) => e.isDefault == true, orElse: () => userModel.shippingAddress!.first);

            Constant.selectedLocation = defaultAddress;

            Get.offAll(() => const ServiceListScreen());
          } else {
            Get.offAll(() => const LocationPermissionScreen());
          }
        } else {
          await FirebaseAuth.instance.signOut();
          ShowToastDialog.showToast("This user is disabled. Please contact admin.".tr);
          Get.offAll(() => const LoginScreen());
        }
      } else {
        await FirebaseAuth.instance.signOut();
        ShowToastDialog.showToast("This user does not exist in the customer app.".tr);
        Get.offAll(() => const LoginScreen());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast("No user found for that email.".tr);
      } else if (e.code == 'wrong-password') {
        ShowToastDialog.showToast("Wrong password provided.".tr);
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Invalid email.".tr);
      } else {
        ShowToastDialog.showToast(e.message?.tr ?? "Login failed. Please try again.".tr);
      }
    } finally {
      isLoading.value = false;
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> loginWithGoogle() async {
    ShowToastDialog.showLoader("please wait...".tr);
    await signInWithGoogle().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        if (value.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = value.user!.uid;
          userModel.email = value.user!.email;
          userModel.firstName = value.user!.displayName?.split(' ').first;
          userModel.lastName = value.user!.displayName?.split(' ').last;
          userModel.provider = 'google';

          ShowToastDialog.closeLoader();
          Get.off(const SignUpScreen(), arguments: {"userModel": userModel, "type": "google"});
        } else {
          await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
              if (userModel != null && userModel.role == Constant.userRoleCustomer) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);

                  if (userModel.shippingAddress != null && userModel.shippingAddress!.isNotEmpty) {
                    final defaultAddress = userModel.shippingAddress!.firstWhere((e) => e.isDefault == true, orElse: () => userModel.shippingAddress!.first);

                    Constant.selectedLocation = defaultAddress;

                    Get.offAll(() => const ServiceListScreen());
                  } else {
                    Get.offAll(() => const LocationPermissionScreen());
                  }
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disabled. Please contact admin.".tr);
                  Get.offAll(() => const LoginScreen());
                }
              } else {
                await FirebaseAuth.instance.signOut();
                ShowToastDialog.showToast("This user does not exist in the customer app.".tr);
                Get.offAll(() => const LoginScreen());
              }
            } else {
              UserModel userModel = UserModel();
              userModel.id = value.user!.uid;
              userModel.email = value.user!.email;
              userModel.firstName = value.user!.displayName?.split(' ').first;
              userModel.lastName = value.user!.displayName?.split(' ').last;
              userModel.provider = 'google';

              Get.off(const SignUpScreen(), arguments: {"userModel": userModel, "type": "google"});
            }
          });
        }
      }
    });
  }

  Future<void> loginWithApple() async {
    ShowToastDialog.showLoader("please wait...".tr);
    await signInWithApple().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        Map<String, dynamic> map = value;
        AuthorizationCredentialAppleID appleCredential = map['appleCredential'];
        UserCredential userCredential = map['userCredential'];

        print("isNewUser: ${userCredential.additionalUserInfo!.isNewUser}");
        print("apple email: ${appleCredential.email}");
        if (userCredential.additionalUserInfo!.isNewUser) {
          // New user → go to sign-up
          UserModel userModel = UserModel();
          userModel.id = userCredential.user!.uid;
          userModel.email = appleCredential.email ?? userCredential.user!.email;
          userModel.firstName = appleCredential.givenName ?? "";
          userModel.lastName = appleCredential.familyName ?? "";
          userModel.provider = 'apple';

          Get.off(const SignUpScreen(), arguments: {"userModel": userModel, "type": "apple"});
        } else {
          // Existing user
          await FireStoreUtils.userExistOrNot(userCredential.user!.uid).then((userExit) async {
            if (userExit == true) {
              UserModel? userModel = await FireStoreUtils.getUserProfile(userCredential.user!.uid);
              if (userModel != null && userModel.role == Constant.userRoleCustomer) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);

                  if (userModel.shippingAddress != null && userModel.shippingAddress!.isNotEmpty) {
                    final defaultAddress = userModel.shippingAddress!.firstWhere((e) => e.isDefault == true, orElse: () => userModel.shippingAddress!.first);

                    Constant.selectedLocation = defaultAddress;
                    Get.offAll(() => const ServiceListScreen());
                  } else {
                    Get.offAll(() => const LocationPermissionScreen());
                  }
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast("This user is disabled. Please contact admin.".tr);
                  Get.offAll(() => const LoginScreen());
                }
              } else {
                await FirebaseAuth.instance.signOut();
                ShowToastDialog.showToast("This user does not exist in the customer app.".tr);
                Get.offAll(() => const LoginScreen());
              }
            } else {
              // User not in DB → go to signup
              UserModel userModel = UserModel();
              userModel.id = userCredential.user!.uid;
              userModel.email = appleCredential.email ?? userCredential.user!.email;
              userModel.firstName = appleCredential.givenName ?? "";
              userModel.lastName = appleCredential.familyName ?? "";
              userModel.provider = 'apple';

              Get.off(const SignUpScreen(), arguments: {"userModel": userModel, "type": "apple"});
            }
          });
        }
      }
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize();

      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
      if (googleUser.id.isEmpty) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      return userCredential;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      final rawNonce = generateNonce();
      final nonce = sha256ofString(rawNonce);

      AuthorizationCredentialAppleID appleCredential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName], nonce: nonce);

      final oauthCredential = OAuthProvider("apple.com").credential(idToken: appleCredential.identityToken, rawNonce: rawNonce, accessToken: appleCredential.authorizationCode);

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return {"appleCredential": appleCredential, "userCredential": userCredential};
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }
}
