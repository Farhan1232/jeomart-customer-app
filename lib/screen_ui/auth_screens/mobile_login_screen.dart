import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/screen_ui/auth_screens/sign_up_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../constant/assets.dart';
import '../../constant/constant.dart';
import '../../controllers/mobile_login_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';

class MobileLoginScreen extends StatelessWidget {
  const MobileLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<MobileLoginController>(
      init: MobileLoginController(),
      builder: (controller) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
              onPressed: () {
                Get.back();
              },
            ),
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
                    Padding(padding: const EdgeInsets.only(top: 2, left: 4), child: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Use your mobile number to Log in easily and securely.".tr,
                            style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                          ),
                          const SizedBox(height: 25),
                          TextFieldWidget(
                            title: "Mobile Number*".tr,
                            hintText: "Enter Mobile number".tr,
                            controller: controller.mobileController.value,
                            textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
                            prefix: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CountryCodePicker(
                                  onInit: (value) {
                                    controller.countryCodeController.value.text = value?.dialCode ?? Constant.defaultCountryCode;
                                    controller.countryISOCodeController.value.text = value?.code ?? Constant.defaultCountryCode;
                                  },
                                  onChanged: (value) {
                                    controller.countryCodeController.value.text = value.dialCode ?? Constant.defaultCountryCode;
                                    controller.countryISOCodeController.value.text = value.code ?? Constant.defaultCountryCode;
                                  },
                                  initialSelection: controller.countryISOCodeController.value.text.isNotEmpty ? controller.countryISOCodeController.value.text : Constant.defaultCountryCode,
                                  showCountryOnly: false,
                                  showOnlyCountryWhenClosed: false,
                                  alignLeft: false,
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
                          const SizedBox(height: 30),
                          RoundedButtonFill(
                            title: "Send Code".tr,
                            onPress: controller.sendOtp,
                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                            textColor: isDark ? AppThemeData.surfaceDark : Colors.white,
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 52, height: 1, color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300),
                              const SizedBox(width: 15),
                              Text("or continue with".tr, style: AppThemeData.regularTextStyle(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400)),
                              const SizedBox(width: 15),
                              Container(width: 52, height: 1, color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                            ],
                          ),
                          const SizedBox(height: 25),
                          RoundedButtonFill(
                            title: "Email address".tr,
                            onPress: () => Get.to(() => const SignUpScreen()),
                            isRight: false,
                            isCenter: true,
                            icon: Image.asset(AppAssets.icMessage, width: 20, height: 18, color: isDark ? AppThemeData.greyDark900 : null),
                            color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                            textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          text: "Didn't have an account? ".tr,
                          style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
                          children: [
                            TextSpan(
                              text: "Sign up".tr,
                              style: AppThemeData.mediumTextStyle(
                                color: AppThemeData.ecommerce300,
                                decoration: TextDecoration.underline,
                                decorationColor: AppThemeData.ecommerce300,
                                decorationStyle: TextDecorationStyle.solid,
                              ),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      Get.offAll(() => const SignUpScreen());
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
