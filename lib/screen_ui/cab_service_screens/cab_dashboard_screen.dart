import 'package:badges/badges.dart' as badges;
import 'package:customer/controllers/cab_dashboard_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:customer/widget/lazy_indexed_stack.dart';

class CabDashboardScreen extends StatelessWidget {
  const CabDashboardScreen({super.key});

  /// Icon and label per tab, in one place.
  ///
  /// The bar and the page list are both generated from
  /// `CabDashboardController.tabs`, so an index can only ever mean one thing.
  /// Before this they were two hand-written lists that had to be kept in step
  /// by hand across a `walletSetting` branch.
  static const Map<String, String> _icons = <String, String>{
    CabDashboardController.homeTab: "assets/icons/ic_home_cab.svg",
    CabDashboardController.bookingsTab: "assets/icons/ic_booking_cab.svg",
    CabDashboardController.walletTab: "assets/icons/ic_wallet_cab.svg",
    CabDashboardController.profileTab: "assets/icons/ic_profile.svg",
  };

  /// The two tabs that draw a Material glyph rather than a bundled SVG.
  ///
  /// A price tag for My Price and a route for Trips, replacing icons that did
  /// not say what either section does. Glyphs rather than new SVG assets so the
  /// icon is one line to change, and because these two are the only tabs whose
  /// artwork the client asked to replace.
  static const Map<String, IconData> _glyphs = <String, IconData>{
    CabDashboardController.bidTab: Icons.sell_outlined,
    CabDashboardController.tripsTab: Icons.route_outlined,
  };

  /// Tabs carrying the green NEW ribbon.
  ///
  /// Same mark, colour and corner as the driver app's bar, so the two apps
  /// flag a new section the same way.
  static const Set<String> _newTabs = <String>{
    CabDashboardController.bidTab,
    CabDashboardController.tripsTab,
  };

  static String _label(String tab) {
    switch (tab) {
      case CabDashboardController.bookingsTab:
        return 'Bookings'.tr;
      case CabDashboardController.bidTab:
        // "Bid" named the mechanism; "My Price" names what the customer does
        // here. Display text only - `bidTab`, the route it selects and every
        // backend field keep the name they had.
        return 'My Price'.tr;
      case CabDashboardController.tripsTab:
        // The client asked for the bar to read the same as the screen it opens.
        // It is by some way the longest label here, which is what `labelSize`
        // below now measures for.
        return 'Available Trips'.tr;
      case CabDashboardController.walletTab:
        return 'Wallet'.tr;
      case CabDashboardController.profileTab:
        return 'Profile'.tr;
      default:
        return 'Home'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetX(
        init: CabDashboardController(),
        builder: (controller) {
          final List<String> tabs = CabDashboardController.tabs;

          // Six items on a narrow phone need a smaller label than four do, or
          // the words run into each other - and so does one long label among
          // short ones. `BottomNavigationBar` neither shrinks nor ellipsises a
          // label that does not fit: it paints it over its neighbours. So the
          // size is taken from the widest label against the width one fixed tab
          // actually gets, rather than from the number of tabs alone.
          //
          // 0.58em is roughly the average advance of this bar's bold face; the
          // 8px is the horizontal breathing room a tile keeps either side of
          // its label. The ceiling of 12 is the size the bar has always used,
          // so a bar of short labels is unchanged, and the floor of 8 is where
          // a label stops being readable - past that the ellipsis below takes
          // over rather than the text shrinking into nothing.
          final double perTab = MediaQuery.sizeOf(context).width / tabs.length;
          final int longestLabel = tabs.map((String tab) => _label(tab).length).reduce((int a, int b) => a > b ? a : b);
          final double labelSize = ((perTab - 8) / (longestLabel * 0.58)).clamp(8.0, 12.0);

          // Guard against an index left over from a rebuild with fewer tabs.
          final int index = controller.selectedIndex.value.clamp(0, tabs.length - 1);

          return Scaffold(
            // Tabs already opened stay alive, so moving between them no
            // longer disposes and re-runs each one's controller. See
            // [LazyIndexedStack].
            body: LazyIndexedStack(
              index: index,
              children: <WidgetBuilder>[
                for (final Widget page in controller.pageList.cast<Widget>()) (BuildContext _) => page,
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              showSelectedLabels: true,
              selectedFontSize: labelSize,
              unselectedFontSize: labelSize,
              // `BottomNavigationBar` builds its labels as a bare `Text`, which
              // takes its overflow from the style it is given. Without this a
              // label too wide for its tile is painted straight over its
              // neighbour - the sizing above is an estimate off an average
              // glyph width, and this is what stops a bad estimate looking
              // like a bug on a narrow phone.
              selectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold, overflow: TextOverflow.ellipsis),
              unselectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold, overflow: TextOverflow.ellipsis),
              currentIndex: index,
              backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              selectedItemColor: AppThemeData.primary300,
              unselectedItemColor: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
              onTap: (int tapped) {
                if (tapped == 0) {
                  Get.put(CabDashboardController());
                }
                controller.selectedIndex.value = tapped;
              },
              items: <BottomNavigationBarItem>[
                for (int i = 0; i < tabs.length; i++)
                  navigationBarItem(
                    isDark,
                    index: i,
                    tab: tabs[i],
                    label: _label(tabs[i]),
                    controller: controller,
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  BottomNavigationBarItem navigationBarItem(bool isDark, {required int index, required String label, required String tab, required CabDashboardController controller}) {
    final Color color = controller.selectedIndex.value == index
        ? AppThemeData.primary300
        : isDark
            ? AppThemeData.grey300
            : AppThemeData.grey600;
    final IconData? glyph = _glyphs[tab];
    final Widget icon = glyph != null
        ? Icon(glyph, size: 22, color: color)
        : SvgPicture.asset(
            _icons[tab] ?? "assets/icons/ic_home_cab.svg",
            height: 22,
            width: 22,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          );
    return BottomNavigationBarItem(
      // A ribboned tab needs its headroom above the glyph rather than split
      // evenly around it: the bar clips at the item's box, and a badge hung
      // off the top of a vertically centred icon is cut in half by it. The box
      // is the same 32px either way, so the bar's height does not move.
      icon: Padding(
        padding: _newTabs.contains(tab) ? const EdgeInsets.only(top: 9, bottom: 1) : const EdgeInsets.symmetric(vertical: 5),
        child: _newTabs.contains(tab) ? _withNewRibbon(icon, isDark) : icon,
      ),
      label: label,
    );
  }

  /// The green NEW ribbon, on the icon's top-left corner.
  ///
  /// Top-*start* rather than top-end: the end corner is where a count badge
  /// would go, and the driver app already puts its NEW mark on the start side.
  Widget _withNewRibbon(Widget icon, bool isDark) {
    return badges.Badge(
      badgeContent: Text(
        "NEW".tr,
        style: const TextStyle(color: Colors.white, fontSize: 7, fontFamily: AppThemeData.bold, letterSpacing: 0.3),
      ),
      position: badges.BadgePosition.topStart(top: -8, start: -11),
      badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.square,
        borderRadius: BorderRadius.circular(9),
        badgeColor: AppThemeData.success400,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        // A ring in the bar's own colour, so the ribbon reads as an object
        // sitting on the icon rather than part of the glyph.
        borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1.2),
        elevation: 0,
      ),
      child: icon,
    );
  }
}
