import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/utils/registration_field_visibility.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import '../../constant/constant.dart';
import '../../controllers/sign_up_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../widget/legal_consent_text.dart';
import 'package:get/get.dart';
import 'login_screen.dart';
import 'mobile_login_screen.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<SignUpController>(
      init: SignUpController(),
      builder: (controller) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            actions: [
              TextButton(
                onPressed: () {
                  Get.to(() => LocationPermissionScreen());
                },
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 40), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Skip".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                    Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sign up to explore all our services and start shopping, riding, and more.".tr,
                      style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: TextFieldWidget(title: "First Name*".tr, hintText: "Jerome".tr, controller: controller.firstNameEditingController.value)),
                        const SizedBox(width: 10),
                        Expanded(child: TextFieldWidget(title: "Last Name*".tr, hintText: "Bell".tr, controller: controller.lastNameEditingController.value)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFieldWidget(
                      title: "Email Address*".tr,
                      hintText: "jerome014@gmail.com",
                      enable: controller.type.value == "google" || controller.type.value == "apple" ? false : true,
                      controller: controller.emailEditingController.value,
                      focusNode: controller.emailFocusNode,
                    ),
                    const SizedBox(height: 15),
                    TextFieldWidget(
                      title: "Mobile Number*".tr,
                      hintText: "Enter Mobile number".tr,
                      enable: controller.type.value == "mobileNumber" ? false : true,
                      controller: controller.phoneNUmberEditingController.value,
                      textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
                      prefix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CountryCodePicker(
                            onInit: (value) {
                              controller.countryCodeEditingController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                              controller.countryISOCodeEditingController.value.text = value?.code ?? Constant.defaultCountryCode;
                            },
                            onChanged: (value) {
                              controller.countryCodeEditingController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                              controller.countryISOCodeEditingController.value.text = value.code ?? Constant.defaultCountryCode;
                            },
                            initialSelection: controller.countryISOCodeEditingController.value.text.isNotEmpty ? controller.countryISOCodeEditingController.value.text : Constant.defaultCountryCode,
                            showCountryOnly: false,
                            showOnlyCountryWhenClosed: false,
                            alignLeft: false,
                            enabled: controller.type.value != "mobileNumber",
                            textStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : Colors.black),
                            dialogTextStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            searchStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            dialogBackgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                            padding: EdgeInsets.zero,
                          ),
                          // const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: AppThemeData.grey400),
                          Container(height: 24, width: 1, color: AppThemeData.grey400),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    controller.type.value == "google" || controller.type.value == "apple" || controller.type.value == "mobileNumber"
                        ? SizedBox()
                        : Column(
                          children: [
                            const SizedBox(height: 15),
                            TextFieldWidget(
                              title: "Password*".tr,
                              hintText: "Enter password".tr,
                              controller: controller.passwordEditingController.value,
                              obscureText: controller.passwordVisible.value,
                              focusNode: controller.passwordFocusNode,
                              suffix: Padding(
                                padding: const EdgeInsets.all(12),
                                child: InkWell(
                                  onTap: () {
                                    controller.passwordVisible.value = !controller.passwordVisible.value;
                                  },
                                  child:
                                      controller.passwordVisible.value
                                          ? SvgPicture.asset("assets/icons/ic_password_show.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn))
                                          : SvgPicture.asset(
                                            "assets/icons/ic_password_close.svg",
                                            colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                                          ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextFieldWidget(
                              title: "Confirm Password*".tr,
                              hintText: "Enter confirm password".tr,
                              controller: controller.conformPasswordEditingController.value,
                              obscureText: controller.conformPasswordVisible.value,
                              suffix: Padding(
                                padding: const EdgeInsets.all(12),
                                child: InkWell(
                                  onTap: () {
                                    controller.conformPasswordVisible.value = !controller.conformPasswordVisible.value;
                                  },
                                  child:
                                      controller.conformPasswordVisible.value
                                          ? SvgPicture.asset("assets/icons/ic_password_show.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn))
                                          : SvgPicture.asset(
                                            "assets/icons/ic_password_close.svg",
                                            colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    // "Hide Referral Code from registration page - Customer App".
                    // The field and its spacer are hidden together so the form
                    // does not leave a gap where the input used to be. Nothing
                    // else about registration changes: the new customer's own
                    // referral document is still created, and Refer a Friend
                    // still works.
                    if (RegistrationFieldVisibility.showReferralCode) ...[
                      const SizedBox(height: 15),
                      TextFieldWidget(title: "Referral Code".tr, hintText: "Enter referral code".tr, controller: controller.referralCodeEditingController.value),
                    ],
                    const SizedBox(height: 20),
                    LegalConsentText(
                      value: controller.agreedToTerms.value,
                      onChanged: (value) {
                        controller.agreedToTerms.value = value ?? false;
                      },
                    ),
                    const SizedBox(height: 24),
                    RoundedButtonFill(
                      title: "Sign up".tr,
                      onPress: () {
                        if (!controller.agreedToTerms.value) {
                          ShowToastDialog.showToast("Please accept the Terms & Conditions and Privacy Policy to continue".tr);
                          return;
                        }
                        if (controller.type.value == "google" || controller.type.value == "apple" || controller.type.value == "mobileNumber") {
                          if (controller.firstNameEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter first name".tr);
                          } else if (controller.lastNameEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter last name".tr);
                          } else if (controller.emailEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter valid email".tr);
                          } else if (controller.phoneNUmberEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter Phone number".tr);
                          } else {
                            controller.signUpWithEmailAndPassword();
                          }
                        } else {
                          if (controller.firstNameEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter first name".tr);
                          } else if (controller.lastNameEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter last name".tr);
                          } else if (controller.emailEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter valid email".tr);
                          } else if (controller.phoneNUmberEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter Phone number".tr);
                          } else if (controller.passwordEditingController.value.text.trim().length < 6) {
                            ShowToastDialog.showToast("Please enter minimum 6 characters password".tr);
                          } else if (controller.passwordEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter password".tr);
                          } else if (controller.conformPasswordEditingController.value.text.trim().isEmpty) {
                            ShowToastDialog.showToast("Please enter Confirm password".tr);
                          } else if (controller.passwordEditingController.value.text.trim() != controller.conformPasswordEditingController.value.text.trim()) {
                            ShowToastDialog.showToast("Password and Confirm password doesn't match".tr);
                          } else {
                            controller.signUpWithEmailAndPassword();
                          }
                        }
                      },
                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                      textColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Get.offAll(() => const LoginScreen()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text.rich(
                            TextSpan(
                              text: "Already have an account? ".tr,
                              style: AppThemeData.mediumTextStyle(
                                fontSize: 16,
                                color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                              ),
                              children: [
                                TextSpan(
                                  text: "Log in".tr,
                                  style: AppThemeData.semiBoldTextStyle(
                                    fontSize: 16,
                                    color: AppThemeData.ecommerce300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 52, height: 1, color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey300),
                        const SizedBox(width: 15),
                        Text("or continue with".tr, style: AppThemeData.regularTextStyle(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400)),
                        const SizedBox(width: 15),
                        Container(width: 52, height: 1, color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey300),
                      ],
                    ),
                    const SizedBox(height: 25),
                    RoundedButtonFill(
                      title: "Mobile number".tr,
                      onPress: () => Get.to(() => const MobileLoginScreen()),
                      isRight: false,
                      isCenter: true,
                      icon: Icon(Icons.mobile_friendly_outlined, size: 20, color: isDark ? AppThemeData.greyDark900 : null),
                      //Image.asset(AppAssets.icMessage, width: 20, height: 18, color: isDark ? AppThemeData.greyDark900 : null),
                      color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                      textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
