import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/controllers/dash_board_ecommarce_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../controllers/theme_controller.dart';
import 'package:customer/widget/lazy_indexed_stack.dart';

class DashBoardEcommerceScreen extends StatelessWidget {
  const DashBoardEcommerceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: DashBoardEcommerceController(),
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
              selectedItemColor: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
              unselectedItemColor: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
              onTap: (int index) {
                if (index == 0) {
                  Get.put(DashBoardController());
                }
                controller.selectedIndex.value = index;
              },
              items:
                  Constant.walletSetting == false
                      ? [
                        navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_cab.svg", label: 'Home'.tr, controller: controller),
                        navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_fav.svg", label: 'Favourites'.tr, controller: controller),
                        navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_orders.svg", label: 'Orders'.tr, controller: controller),
                        navigationBarItem(isDark, index: 3, assetIcon: "assets/icons/ic_profile.svg", label: 'Profile'.tr, controller: controller),
                      ]
                      : [
                        navigationBarItem(isDark, index: 0, assetIcon: "assets/icons/ic_home_cab.svg", label: 'Home'.tr, controller: controller),
                        navigationBarItem(isDark, index: 1, assetIcon: "assets/icons/ic_fav.svg", label: 'Favourites'.tr, controller: controller),
                        navigationBarItem(isDark, index: 2, assetIcon: "assets/icons/ic_wallet.svg", label: 'Wallet'.tr, controller: controller),
                        navigationBarItem(isDark, index: 3, assetIcon: "assets/icons/ic_orders.svg", label: 'Orders'.tr, controller: controller),
                        navigationBarItem(isDark, index: 4, assetIcon: "assets/icons/ic_profile.svg", label: 'Profile'.tr, controller: controller),
                      ],
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(isDark, {required int index, required String label, required String assetIcon, required DashBoardEcommerceController controller}) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SvgPicture.asset(
          assetIcon,
          height: 22,
          width: 22,
          color:
              controller.selectedIndex.value == index
                  ? isDark
                      ? AppThemeData.primary300
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
