import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import 'package:customer/widget/lazy_indexed_stack.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: DashBoardController(),
        builder: (controller) {
          // The bar has four tabs with the wallet switched off and five with it
          // on, and the selected tab is not only set by tapping the bar: a
          // notification tap sets it too. `BottomNavigationBar` builds one
          // animation controller per item and then indexes that list with
          // `currentIndex`, so a value past the end throws a RangeError while
          // the bar is being built. In a release build a throw during build is
          // drawn as a bare grey page - the "screen hangs and becomes white"
          // the client saw after backing out of the chat inbox, because the
          // dashboard underneath had been left on tab 4 of a four-tab bar.
          //
          // Clamped here so no caller can blank the app by naming a tab that
          // is not on the bar. `LazyIndexedStack` already clamps the body.
          final int tabCount = controller.pageList.length;
          final int selectedTab = tabCount == 0 ? 0 : controller.selectedIndex.value.clamp(0, tabCount - 1);
          return Scaffold(
            // Tabs already opened stay alive - see [LazyIndexedStack].
            body: LazyIndexedStack(
              index: selectedTab,
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
              currentIndex: selectedTab,
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

  BottomNavigationBarItem navigationBarItem(isDark, {required int index, required String label, required String assetIcon, required DashBoardController controller}) {
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
