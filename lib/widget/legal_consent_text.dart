import 'package:customer/screen_ui/multi_vendor_service/terms_and_condition/terms_and_condition_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';

class LegalConsentText extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const LegalConsentText({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    final textColor = isDark ? AppThemeData.greyDark800 : AppThemeData.grey800;
    final linkColor = AppThemeData.ecommerce300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          value: value,
          activeColor: AppThemeData.primary300,
          onChanged: onChanged,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text.rich(
              TextSpan(
                text: "I agree to the ".tr,
                style: AppThemeData.mediumTextStyle(color: textColor, fontSize: 13),
                children: [
                  TextSpan(
                    text: "Terms & Conditions".tr,
                    style: AppThemeData.mediumTextStyle(
                      color: linkColor,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(() => const TermsAndConditionScreen(type: "termAndCondition"));
                          },
                  ),
                  TextSpan(
                    text: " and ".tr,
                    style: AppThemeData.mediumTextStyle(color: textColor, fontSize: 13),
                  ),
                  TextSpan(
                    text: "Privacy Policy".tr,
                    style: AppThemeData.mediumTextStyle(
                      color: linkColor,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: linkColor,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            Get.to(() => const TermsAndConditionScreen(type: "privacy"));
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
