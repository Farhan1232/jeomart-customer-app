import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<ThemeController>(context);
    return Scaffold(
      backgroundColor: themeChange.isDark.value == true ? AppThemeData.surfaceDark : AppThemeData.surface,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(child: Image.asset('assets/images/maintenance.png', height: 200, width: 200)),
          const SizedBox(height: 20),
          Text("We'll be back soon!".tr, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: themeChange.isDark.value ? AppThemeData.grey100 : AppThemeData.grey800)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Sorry for the inconvenience but we're performing some maintenance at the moment. We'll be back online shortly!".tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: themeChange.isDark.value ? AppThemeData.grey100 : AppThemeData.grey800),
            ),
          ),
        ],
      ),
    );
  }
}
