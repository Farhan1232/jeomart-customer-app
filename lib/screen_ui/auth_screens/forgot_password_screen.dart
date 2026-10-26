import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/forgot_password_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import 'login_screen.dart';
import '../location_enable_screens/location_permission_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ForgotPasswordController>(
      init: ForgotPasswordController(),
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
              padding: const EdgeInsets.only(left: 15, right: 15, bottom: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enter your registered email to receive a reset link.".tr,
                            style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                          ),
                          const SizedBox(height: 24),
                          TextFieldWidget(title: "Email Address*".tr, hintText: "jerome014@gmail.com", controller: controller.emailEditingController.value),
                          const SizedBox(height: 30),
                          RoundedButtonFill(
                            title: "Send Link".tr,
                            onPress: controller.forgotPassword,
                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                            textColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
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
                          text: "Remember Password?".tr,
                          style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
                          children: [
                            TextSpan(
                              text: "Log in".tr,
                              style: AppThemeData.mediumTextStyle(color: AppThemeData.ecommerce300, decoration: TextDecoration.underline, decorationColor: AppThemeData.ecommerce300),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      Get.offAll(() => const LoginScreen());
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
