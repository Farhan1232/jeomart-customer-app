import 'package:customer/utils/firestore_cache.dart';
import 'package:customer/utils/user_cache.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/my_profile_controller.dart';
import 'package:customer/screen_ui/change_password_screen/change_password_screen.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/on_demand_service/provider_inbox_screen.dart';
import 'package:customer/screen_ui/on_demand_service/worker_inbox_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:customer/themes/responsive.dart';
import 'package:in_app_review/in_app_review.dart';
import '../../../controllers/theme_controller.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../auth_screens/login_screen.dart';
import '../../auth_screens/sign_up_screen.dart';
import '../cashback_screen/cashback_offers_list.dart';
import '../change_language/change_language_screen.dart';
import '../chat_screens/driver_inbox_screen.dart';
import '../chat_screens/restaurant_inbox_screen.dart';
import '../dine_in_booking/dine_in_booking_screen.dart';
import '../dine_in_screeen/dine_in_screen.dart';
import '../edit_profile_screen/edit_profile_screen.dart';
import '../gift_card/gift_card_screen.dart';
import '../refer_friend_screen/refer_friend_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../terms_and_condition/terms_and_condition_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Scaffold(
      body: Obx(() {
        final isDark = themeController.isDark.value;
        return GetX(
          init: MyProfileController(),
          builder: (controller) {
            return controller.isLoading.value
                ? Constant.loader()
                : Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "My Profile".tr,
                            style: TextStyle(fontSize: 24, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "Manage your personal information, preferences, and settings all in one place.".tr,
                            style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "General Information".tr,
                            style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                children: [
                                  Constant.userModel == null
                                      ? const SizedBox()
                                      : cardDecoration(isDark, controller, "assets/images/ic_profile.svg", "Profile Information".tr, () {
                                        Get.to(const EditProfileScreen());
                                      }),
                                  if (Constant.sectionConstantModel!.dineInActive == true)
                                    cardDecoration(isDark, controller, "assets/images/ic_dinin.svg", "Dine-In".tr, () {
                                      Get.to(const DineInScreen());
                                    }),
                                  cardDecoration(isDark, controller, "assets/images/ic_gift.svg", "Gift Card".tr, () {
                                    Get.to(const GiftCardScreen());
                                  }),
                                  if (Constant.isCashbackActive == true)
                                    cardDecoration(isDark, controller, "assets/icons/ic_cashback_Offer.svg", "Cashback Offers".tr, () {
                                      Get.to(const CashbackOffersListScreen());
                                    }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Constant.sectionConstantModel!.dineInActive == true
                              ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bookings Information".tr,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: Responsive.width(100, context),
                                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      child: Column(
                                        children: [
                                          cardDecoration(isDark, controller, "assets/icons/ic_dinin_order.svg", "Dine-In Booking".tr, () {
                                            Get.to(const DineInBookingScreen());
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : const SizedBox(),
                          const SizedBox(height: 10),
                          Text(
                            "Preferences".tr,
                            style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                children: [
                                  cardDecoration(isDark, controller, "assets/icons/ic_change_language.svg", "Change Language".tr, () {
                                    Get.to(const ChangeLanguageScreen());
                                  }),
                                  cardDecoration(isDark, controller, "assets/icons/ic_light_dark.svg", "Dark Mode".tr, () {}),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Social".tr,
                            style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                children: [
                                  Constant.userModel == null
                                      ? const SizedBox()
                                      : cardDecoration(isDark, controller, "assets/icons/ic_refer.svg", "Refer a Friend".tr, () {
                                        Get.to(const ReferFriendScreen());
                                      }),
                                  cardDecoration(isDark, controller, "assets/icons/ic_share.svg", "Share app".tr, () {
                                    Share.share(
                                      '${'Check out JEOM, the ultimate all-in-one multi-vendor eBusiness platform.'.tr} \n\n${'Google Play:'.tr} ${Constant.googlePlayLink} \n\n${'App Store:'.tr} ${Constant.appStoreLink}',
                                      subject: 'Look what I made!'.tr,
                                    );
                                  }),
                                  cardDecoration(isDark, controller, "assets/icons/ic_rate.svg", "Rate the app".tr, () {
                                    final InAppReview inAppReview = InAppReview.instance;
                                    inAppReview.requestReview();
                                  }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Constant.userModel == null
                              ? const SizedBox()
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Communication".tr,
                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: Responsive.width(100, context),
                                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Column(
                                        children: [
                                          cardDecoration(isDark, controller, "assets/icons/ic_restaurant_chat.svg", "Store Inbox".tr, () {
                                            Get.to(const RestaurantInboxScreen());
                                          }),
                                          cardDecoration(isDark, controller, "assets/icons/ic_restaurant_driver.svg", "Driver Inbox".tr, () {
                                            Get.to(const DriverInboxScreen());
                                          }),
                                          cardDecoration(isDark, controller, "assets/icons/ic_restaurant_chat.svg", "Provider Inbox".tr, () {
                                            Get.to(const ProviderInboxScreen());
                                          }),
                                          cardDecoration(isDark, controller, "assets/icons/ic_restaurant_driver.svg", "Worker Inbox".tr, () {
                                            Get.to(const WorkerInboxScreen());
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                          Text("Legal".tr, style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                children: [
                                  if (Constant.userModel?.id != null)
                                    cardDecoration(isDark, controller, "assets/icons/ic_help_support.svg", "Help & Support", () {
                                      Get.to(HelpSupportScreen(isNavigateViaNotification: false));
                                    }),
                                  cardDecoration(isDark, controller, "assets/icons/ic_privacy_policy.svg", "Privacy Policy".tr, () {
                                    Get.to(const TermsAndConditionScreen(type: "privacy"));
                                  }),
                                  cardDecoration(isDark, controller, "assets/icons/ic_tearm_condition.svg", "Terms and Conditions".tr, () {
                                    Get.to(const TermsAndConditionScreen(type: "termAndCondition"));
                                  }),
                                  if (Constant.userModel?.provider == 'email')
                                    cardDecoration(isDark, controller, "assets/icons/ic_lock.svg", "Change Password".tr, () {
                                      Get.to(const ChangePasswordScreen());
                                    }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: Responsive.width(100, context),
                            decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Column(
                                children: [
                                  Constant.userModel == null
                                      ? cardDecoration(isDark, controller, "assets/icons/ic_logout.svg", "Log In".tr, () {
                                        Get.offAll(const LoginScreen());
                                      })
                                      : cardDecoration(isDark, controller, "assets/icons/ic_logout.svg", "Log out".tr, () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return CustomDialogBox(
                                              title: "Log out".tr,
                                              descriptions: "Are you sure you want to log out? You will need to enter your credentials to log back in.".tr,
                                              positiveString: "Log out".tr,
                                              negativeString: "Cancel".tr,
                                              positiveClick: () async {
                                                Constant.userModel!.fcmToken = "";
                                                await FireStoreUtils.updateUser(Constant.userModel!);
                                                Constant.userModel = null;
                                                await FirebaseAuth.instance.signOut();
                                                // Nothing user-scoped is memoised, but a sign-out is the
                                                // natural point to start the next session with nothing held.
                                                UserCache.clear();
                                                FirestoreCache.clear();
                                                Get.offAll(const LoginScreen());
                                              },
                                              negativeClick: () {
                                                Get.back();
                                              },
                                              img: Image.asset('assets/images/ic_logout.gif', height: 50, width: 50, cacheWidth: (50 * MediaQuery.devicePixelRatioOf(context)).round()),
                                            );
                                          },
                                        );
                                      }),
                                  if (Constant.userModel == null)
                                    cardDecoration(isDark, controller, "assets/icons/ic_user.svg", "Sign Up".tr, () {
                                      Get.to(() => const SignUpScreen());
                                    }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Constant.userModel == null
                              ? const SizedBox()
                              : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return CustomDialogBox(
                                          title: "Delete Account".tr,
                                          descriptions: "Are you sure you want to delete your account? This action is irreversible and will permanently remove all your data.".tr,
                                          positiveString: "Delete".tr,
                                          negativeString: "Cancel".tr,
                                          positiveClick: () async {
                                            ShowToastDialog.showLoader("Please wait...".tr);
                                            await controller.deleteUserFromServer();
                                            await FireStoreUtils.deleteUser().then((value) {
                                              ShowToastDialog.closeLoader();
                                              if (value == true) {
                                                ShowToastDialog.showToast("Account deleted successfully".tr);
                                                Get.offAll(const LoginScreen());
                                              } else {
                                                ShowToastDialog.showToast("Contact Administrator".tr);
                                              }
                                            });
                                          },
                                          negativeClick: () {
                                            Get.back();
                                          },
                                          img: Image.asset('assets/icons/delete_dialog.gif', height: 50, width: 50, cacheWidth: (50 * MediaQuery.devicePixelRatioOf(context)).round()),
                                        );
                                      },
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset("assets/icons/ic_delete.svg"),
                                      const SizedBox(width: 10),
                                      Text(
                                        "Delete Account".tr,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.danger300 : AppThemeData.danger300),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          Center(
                            child: Text(
                              "V : ${Constant.appVersion}",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
          },
        );
      }),
    );
  }

  Padding cardDecoration(bool isDark, MyProfileController controller, String image, String title, Function()? onPress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          onPress?.call();
        },
        child: Row(
          children: [
            SvgPicture.asset(
              image,
              colorFilter:
                  title == "Help & Support"
                      ? ColorFilter.mode(isDark == true ? AppThemeData.success50 : AppThemeData.success600, BlendMode.srcIn)
                      : title == "Change Password".tr
                      ? ColorFilter.mode(AppThemeData.successDark300, BlendMode.srcIn)
                      : title == "Log In".tr || title == "Cashbacks".tr
                      ? const ColorFilter.mode(AppThemeData.success500, BlendMode.srcIn)
                      : null,
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.tr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: AppThemeData.medium,
                  fontSize: 16,
                  color:
                      title == "Log out".tr
                          ? AppThemeData.danger300
                          : title == "Log In".tr
                          ? AppThemeData.success500
                          : (isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                ),
              ),
            ),
            title == "Dark Mode".tr
                ? Transform.scale(
                  scale: 0.8,
                  child: Obx(() => CupertinoSwitch(value: controller.isDarkModeSwitch.value, activeTrackColor: AppThemeData.primary300, onChanged: controller.toggleDarkMode)),
                )
                : Icon(Icons.keyboard_arrow_right, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
          ],
        ),
      ),
    );
  }
}
