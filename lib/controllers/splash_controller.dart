import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/global_setting_controller.dart';
import 'package:customer/models/language_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/service/localization_service.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:customer/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screen_ui/auth_screens/login_screen.dart';
import '../screen_ui/location_enable_screens/location_permission_screen.dart';
import '../service/fire_store_utils.dart';

class SplashController extends GetxController {
  /// The shortest time the splash art stays up, so a warm start does not flash
  /// past it.
  static const Duration _minimumSplash = Duration(milliseconds: 800);

  /// Hard cap on waiting for `settings/*`. Past this the app carries on rather
  /// than sitting on the logo: every settings document that matters after
  /// startup is behind a live listener, so a late arrival still lands.
  static const Duration _settingsWait = Duration(seconds: 6);

  @override
  void onInit() {
    super.onInit();
    unawaited(_boot());
  }

  /// Replaces `Timer(const Duration(seconds: 3), redirectScreen)`.
  ///
  /// Three problems with that timer, all of them things the client saw:
  ///
  ///  * it was three seconds of doing nothing, spent *before* `redirectScreen`
  ///    started its own chain of network round trips, so startup cost three
  ///    seconds **plus** the work rather than the longer of the two;
  ///  * it was a guess at how long `getSettings()` takes. On a slow connection
  ///    the app left the splash before the settings arrived and built its first
  ///    screen against compile-time defaults;
  ///  * nothing below it was guarded, so a single failed read left the app on
  ///    the splash art with no error and no way forward.
  ///
  /// The minimum splash time and the settings load now run together, every wait
  /// is bounded, and [redirectScreen] can no longer fail silently.
  Future<void> _boot() async {
    final Future<void> minimumSplash = Future<void>.delayed(_minimumSplash);
    _maintenanceRead = FireStoreUtils.isMaintenanceMode();
    _loginRead = FireStoreUtils.isLogin();
    try {
      await GlobalSettingController.settingsReady.timeout(_settingsWait);
    } catch (e) {
      log('splash: carrying on without settings :: $e');
    }
    await minimumSplash;
    try {
      await redirectScreen();
    } catch (e) {
      log('splash: redirect failed :: $e');
      await _continueAsGuest();
    }
  }

  /// The one exit used whenever the stored session cannot be used - a profile
  /// that no longer exists, a wrong role, an inactive account, or an error on
  /// the way to finding out.
  Future<void> _signOutTo(Widget screen) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      log('splash: sign-out failed :: $e');
    }
    Get.offAll(() => screen);
  }

  /// Where a customer with no usable session belongs: browsing, not blocked.
  /// The same place the existing not-signed-in branch already sends them.
  Future<void> _continueAsGuest() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      log('splash: sign-out failed :: $e');
    }
    if (Constant.selectedLocation.location == null) {
      Constant.selectedLocation = Constant.defaultGuestLocation;
    }
    Get.offAll(const ServiceListScreen());
  }

  Future<void> getLanguage() async {
    final jsonString = Preferences.getString(Preferences.languageCodeKey);

    if (jsonString != '' && jsonString.isNotEmpty) {
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final model = LanguageModel.fromJson(jsonData);
      LocalizationService().changeLocale(model.slug!);
    } else {
      LocalizationService().changeLocale('en');
    }
  }

  /// The two reads [redirectScreen] opens with, started by [_boot] the moment
  /// the splash appears rather than after the settings wait and the minimum
  /// splash time.
  ///
  /// Both are plain reads that decide nothing by themselves: [redirectScreen]
  /// still asks "maintenance?" first and "signed in?" second and acts on the
  /// answers in that order. Starting them early only means the answers are
  /// usually already here when it asks. Before, every launch paid the settings
  /// wait, then a round trip for `maintenance_settings`, then another for the
  /// customer's `users` document, one after the other.
  Future<bool>? _maintenanceRead;
  Future<bool>? _loginRead;

  Future<void> redirectScreen() async {
    final Future<bool> maintenanceRead = _maintenanceRead ?? FireStoreUtils.isMaintenanceMode();
    final Future<bool>? loginRead = _loginRead;
    _maintenanceRead = null;
    _loginRead = null;

    getLanguage();

    if (await maintenanceRead == true) {
      Get.offAll(() => MaintenanceModeScreen());
      return;
    }

    bool isLogin = await (loginRead ?? FireStoreUtils.isLogin());

    if (isLogin == true) {
      await FireStoreUtils.getUserProfile(
        FireStoreUtils.getCurrentUid(),
      ).then((value) async {
        if (value != null) {
          UserModel userModel = value;

          log(userModel.toJson().toString());

          if (userModel.role == Constant.userRoleCustomer) {
            if (userModel.active == true) {
              // The signed-in profile, published the moment it is read.
              //
              // It used to reach `Constant.userModel` only as a side effect of
              // the `updateUser` write below, which was fine while that write
              // was awaited. It is no longer awaited - saving the push token
              // was costing every launch a round trip - so a write that is
              // slow, or that never lands, would leave the whole session with
              // `Constant.userModel == null`. Everything gated on "is there a
              // signed-in customer" then behaves as if nobody is signed in;
              // booking a driver's full-vehicle trip, for one, reported
              // "This trip is no longer available".
              Constant.userModel = userModel;
              userModel.fcmToken = await NotificationService.getToken();
              // Not awaited: saving the push token is a write the customer
              // never sees, and holding the splash screen open for it added a
              // whole round trip to every launch. It still happens, just not in
              // front of the user.
              unawaited(FireStoreUtils.updateUser(userModel));

              if (userModel.shippingAddress != null &&
                  userModel.shippingAddress!.isNotEmpty) {
                if (userModel.shippingAddress!
                    .where((element) => element.isDefault == true)
                    .isNotEmpty) {
                  Constant.selectedLocation = userModel.shippingAddress!
                      .where((element) => element.isDefault == true)
                      .single;
                } else {
                  Constant.selectedLocation =
                      userModel.shippingAddress!.first;
                }

                Get.offAll(const ServiceListScreen());
              } else {
                Get.offAll(const LocationPermissionScreen());
              }
            } else {
              await _signOutTo(const LoginScreen());
            }
          } else {
            await _signOutTo(const LoginScreen());
          }
        } else {
          // A signed-in uid whose `users` document has gone. Nothing used to
          // handle this at all, so the app stayed on the splash screen.
          await _continueAsGuest();
        }
      });
    } else {
      // Guest users can browse the app without creating an account.
      await FirebaseAuth.instance.signOut();
      Constant.selectedLocation = Constant.defaultGuestLocation;
      Get.offAll(const ServiceListScreen());
    }
  }
}
