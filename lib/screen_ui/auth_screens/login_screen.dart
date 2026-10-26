import 'package:customer/screen_ui/auth_screens/sign_up_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/terms_and_condition/terms_and_condition_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../constant/assets.dart';
import '../../controllers/login_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import 'package:get/get.dart';
import '../service_home_screen/service_list_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<LoginController>(
      init: LoginController(),
      builder: (controller) {
        final themeController = Get.find<ThemeController>();
        final isDark = themeController.isDark.value;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: InkWell(
              // Let guests return to browsing instead of being trapped on login.
              onTap: () => Navigator.canPop(context) ? Get.back() : Get.offAll(const ServiceListScreen()),
              child: Icon(Icons.arrow_back, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, size: 20),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 36),
                          Center(
                            child: Column(
                              children: [
                                Image.asset(
                                  AppAssets.icAppLogo,
                                  width: 112,
                                  height: 112,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'JEOM',
                                  style: AppThemeData.boldTextStyle(
                                    fontSize: 30,
                                    color:
                                        isDark
                                            ? AppThemeData.greyDark900
                                            : AppThemeData.grey900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),
                          TextFieldWidget(
                            title: "Email Address*".tr,
                            hintText: "jerome014@gmail.com",
                            controller: controller.emailController.value,
                            focusNode: controller.emailFocusNode,
                          ),
                          const SizedBox(height: 15),
                          TextFieldWidget(
                            title: "Password*".tr,
                            hintText: "Enter password".tr,
                            controller: controller.passwordController.value,
                            obscureText: controller.passwordVisible.value,
                            focusNode: controller.passwordFocusNode,
                            suffix: Padding(
                              padding: const EdgeInsets.all(12),
                              child: InkWell(
                                onTap: () {
                                  controller.passwordVisible.value =
                                      !controller.passwordVisible.value;
                                },
                                child:
                                    controller.passwordVisible.value
                                        ? SvgPicture.asset(
                                          "assets/icons/ic_password_show.svg",
                                          colorFilter: ColorFilter.mode(
                                            isDark
                                                ? AppThemeData.grey300
                                                : AppThemeData.grey600,
                                            BlendMode.srcIn,
                                          ),
                                        )
                                        : SvgPicture.asset(
                                          "assets/icons/ic_password_close.svg",
                                          colorFilter: ColorFilter.mode(
                                            isDark
                                                ? AppThemeData.grey300
                                                : AppThemeData.grey600,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  () => Get.to(
                                    () => const ForgotPasswordScreen(),
                                  ),
                              child: Text(
                                "Forgot Password".tr,
                                style: AppThemeData.semiBoldTextStyle(
                                  color: AppThemeData.info400,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          RoundedButtonFill(
                            title: "Log in".tr,
                            onPress: controller.loginWithEmail,
                            color:
                                isDark
                                    ? AppThemeData.greyDark900
                                    : AppThemeData.grey900,
                            textColor:
                                isDark
                                    ? AppThemeData.surfaceDark
                                    : AppThemeData.surface,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Get.offAll(() => const SignUpScreen()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text.rich(
                                  TextSpan(
                                    text: "Don't have an account? ".tr,
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 16,
                                      color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: "Sign up".tr,
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
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: "Privacy Policy".tr,
                            style: AppThemeData.mediumTextStyle(
                              color: AppThemeData.ecommerce300,
                              decoration: TextDecoration.underline,
                              decorationColor: AppThemeData.ecommerce300,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Get.to(() => const TermsAndConditionScreen(type: "privacy"));
                                  },
                          ),
                        ),
                        Text(
                          "  •  ",
                          style: AppThemeData.mediumTextStyle(
                            color:
                                isDark
                                    ? AppThemeData.greyDark400
                                    : AppThemeData.grey400,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            text: "Terms & Conditions".tr,
                            style: AppThemeData.mediumTextStyle(
                              color: AppThemeData.ecommerce300,
                              decoration: TextDecoration.underline,
                              decorationColor: AppThemeData.ecommerce300,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Get.to(() => const TermsAndConditionScreen(type: "termAndCondition"));
                                  },
                          ),
                        ),
                      ],
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
