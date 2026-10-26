import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/parcel_dashboard_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:customer/widget/lazy_indexed_stack.dart';

class ParcelDashboardScreen extends StatelessWidget {
  const ParcelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: ParcelDashboardController(),
        builder: (controller) {
          return Scaffold(
            // Tabs already opened stay alive - see [LazyIndexedStack].
            body: LazyIndexedStack(
              index: controller.selectedIndex.value,
              children: <WidgetBuilder>[
                for (final Widget page in controller.pageList.cast<Widget>()) (BuildContext _) => page,
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              showSelectedLabels: true,
              selectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold),
              unselectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold),
              currentIndex: controller.selectedIndex.value,
              backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              selectedItemColor: isDark ? AppThemeData.parcelServiceDark300 : AppThemeData.primary300,
              unselectedItemColor: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500,
              onTap: (int index) {
                if (index == 0) {
                  Get.put(ParcelDashboardController());
                }
                controller.selectedIndex.value = index;
              },
              items:
                  Constant.walletSetting == false
                      ? [
                        navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_parcel.svg", label: 'Home'.tr, controller: controller),
                        navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_mybooking_parcel.svg", label: 'My Bookings'.tr, controller: controller),
                        navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_profile_parcel.svg", label: 'Profile'.tr, controller: controller),
                      ]
                      : [
                        navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_parcel.svg", label: 'Home'.tr, controller: controller),
                        navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_mybooking_parcel.svg", label: 'My Bookings'.tr, controller: controller),
                        navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_wallet_parcel.svg", label: 'Wallet'.tr, controller: controller),
                        navigationBarItem(isDark, index: 3, assetIcon: "assets/icons/ic_profile_parcel.svg", label: 'Profile'.tr, controller: controller),
                      ],
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(isDark, {required int index, required String label, required String assetIcon, required ParcelDashboardController controller}) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SvgPicture.asset(
          assetIcon,
          height: label == 'Wallet'.tr ? 18 : 22,
          width: label == 'Wallet'.tr ? 18 : 22,
          color:
              controller.selectedIndex.value == index
                  ? isDark
                      ? AppThemeData.parcelServiceDark300
                      : AppThemeData.primary300
                  : isDark
                  ? AppThemeData.grey300
                  : AppThemeData.grey600,
        ),
      ),
      label: label,
    );
  }
}
