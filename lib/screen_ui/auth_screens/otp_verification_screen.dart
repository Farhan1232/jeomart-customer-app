import 'package:customer/screen_ui/auth_screens/sign_up_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../constant/assets.dart';
import '../../controllers/otp_verification_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';

class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OtpVerifyController>(
      init: OtpVerifyController(),
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
                  // Handle skip action
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
                            "${"Enter the OTP sent to your mobile".tr} ${controller.countryCode} ${controller.maskPhoneNumber(controller.phoneNumber.value)}",
                            style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                          ),

                          const SizedBox(height: 30),

                          /// OTP Field
                          Center(
                            child: MaterialPinField(
                              length: 6,
                              pinController: controller.otpController.value,
                              keyboardType: TextInputType.number,
                              enableAutofill: true,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              hintCharacter: "-",
                              theme: MaterialPinTheme(
                                cellSize: const Size(51, 54),
                                shape: MaterialPinShape.outlined,
                                borderRadius: BorderRadius.circular(12),
                                borderWidth: 1,
                                textStyle: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
                                fillColor: Colors.transparent,
                                borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                                focusedBorderColor: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400,
                                cursorColor: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500,
                                errorColor: AppThemeData.danger300,
                                filledFillColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey200,
                                focusedFillColor: isDark ? AppThemeData.greyDark100 : AppThemeData.grey200,
                              ),
                              onChanged: (value) {},
                              onCompleted: (pin) {
                                // OTP completed
                              },
                            ),
                          ),

                          /// Resend OTP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(AppAssets.icArrowsClockwise, height: 20, width: 20),
                              TextButton(
                                onPressed: () {
                                  controller.otpController.value.clear();
                                  controller.sendOTP();
                                },
                                child: Text("Resend OTP".tr, style: AppThemeData.semiBoldTextStyle(color: AppThemeData.info400, fontSize: 16)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          /// Verify Button
                          RoundedButtonFill(
                            title: "Verify".tr,
                            onPress: controller.verifyOtp,
                            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                            textColor: isDark ? AppThemeData.surfaceDark : Colors.white,
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
                              style: AppThemeData.mediumTextStyle(color: AppThemeData.ecommerce300, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()..onTap = () => Get.offAll(() => const SignUpScreen()),
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
