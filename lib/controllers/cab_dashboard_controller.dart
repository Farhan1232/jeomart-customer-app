import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_home_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screen_ui/cab_service_screens/available_trips_screen.dart';
import '../screen_ui/cab_service_screens/my_bids_screen.dart';
import '../screen_ui/cab_service_screens/my_cab_booking_screen.dart';
import 'my_cab_booking_controller.dart';

class CabDashboardController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  /// The bar has one entry per page, always in this order.
  ///
  /// Wallet is the only conditional one, so the bar and the page list are built
  /// from the same source rather than from two hand-written lists that have to
  /// be kept in step - the pattern that made an index mean two different things
  /// on the two branches.
  static const String homeTab = 'home';
  static const String bookingsTab = 'bookings';
  static const String bidTab = 'bid';
  static const String tripsTab = 'trips';
  static const String walletTab = 'wallet';
  static const String profileTab = 'profile';

  /// The tabs in bar order.
  ///
  /// Bid sits next to Home because it is a way of *starting* a ride, which is
  /// what the client asked for: their customers could not find bidding while it
  /// only existed on the last sheet of the booking flow.
  static List<String> get tabs => <String>[
        homeTab,
        bookingsTab,
        bidTab,
        tripsTab,
        if (Constant.walletSetting != false) walletTab,
        profileTab,
      ];

  @override
  void onInit() {
    pageList.value = tabs.map(_pageFor).toList();
    super.onInit();
  }

  /// Switches the bar to **Bookings**.
  ///
  /// The client's rule for the whole cab section: *"when a bid is accepted OR
  /// when my trip is accepted then all bookings goes to my bookings tab."* The
  /// other sections call this once their part is done, so a customer is never
  /// left looking at the list a booking has just left.
  ///
  /// A no-op when the dashboard is not on screen - the sections are also
  /// reachable outside it - rather than putting one there.
  ///
  /// [bookingTab], when given, is the Ride History tab to open on - a booked
  /// full-vehicle trip is listed under On Going, not under the default New.
  static void openBookings({String? bookingTab}) {
    if (!Get.isRegistered<CabDashboardController>()) return;
    final int index = tabs.indexOf(bookingsTab);
    if (index < 0) return;
    if (bookingTab != null) MyCabBookingController.showTab(bookingTab);
    Get.find<CabDashboardController>().selectedIndex.value = index;
  }

  static Widget _pageFor(String tab) {
    switch (tab) {
      case bookingsTab:
        return const MyCabBookingScreen();
      case bidTab:
        return const MyBidsScreen();
      case tripsTab:
        return const AvailableTripsScreen();
      case walletTab:
        return const WalletScreen();
      case profileTab:
        return const ProfileScreen();
      default:
        return CabHomeScreen();
    }
  }
}
