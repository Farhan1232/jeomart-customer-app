import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import '../controllers/theme_controller.dart';

Future<void> configEasyLoading() async {
  final themeController = Get.find<ThemeController>();

  final isDark = themeController.isDark.value;

  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..backgroundColor = isDark ? AppThemeData.greyDark50 : AppThemeData.grey800
    ..indicatorColor = isDark ? Colors.white : Colors.white
    ..textColor = isDark ? Colors.white : AppThemeData.greyDark900
    ..maskColor = Colors.black.withOpacity(0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
}
