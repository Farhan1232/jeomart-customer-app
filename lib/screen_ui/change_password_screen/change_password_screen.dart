import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/change_password_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return GetX(
      init: ChangePasswordController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: themeController.isDark.value == true ? AppThemeData.surfaceDark : AppThemeData.surface, centerTitle: false, titleSpacing: 0),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Change Password".tr,
                          style: TextStyle(
                            fontSize: 24,
                            color: themeController.isDark.value == true ? AppThemeData.grey50 : AppThemeData.grey900,
                            fontFamily: AppThemeData.semiBold,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Update your password to keep your account secure.".tr,
                          style: TextStyle(
                            fontSize: 16,
                            color: themeController.isDark.value == true ? AppThemeData.grey50 : AppThemeData.grey900,
                            fontFamily: AppThemeData.regular,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Enter your registered email address and we’ll send you a secure link to reset your password. Open the link in your inbox and follow the steps to create a new password.".tr,
                          style: TextStyle(
                            fontSize: 14,
                            color: themeController.isDark.value == true ? AppThemeData.danger300 : AppThemeData.danger300,
                            fontFamily: AppThemeData.regular,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFieldWidget(
                          title: 'Email Address'.tr,
                          textInputType: TextInputType.emailAddress,
                          controller: controller.emailEditingController.value,
                          hintText: 'Enter Email Address'.tr,
                          prefix: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SvgPicture.asset(
                              "assets/icons/ic_mail.svg",
                              colorFilter: ColorFilter.mode(themeController.isDark.value == true ? AppThemeData.grey300 : AppThemeData.grey600, BlendMode.srcIn),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        RoundedButtonFill(
                          title: "Change Password".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            controller.forgotPassword();
                          },
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }
}
