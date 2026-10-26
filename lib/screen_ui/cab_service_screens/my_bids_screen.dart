import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/my_bids_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_booking_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/utils/ride_bidding_state.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// **Choose Your Price** — the customer's own bidding section.
///
/// Built to the same pattern as the driver's My Trips, which is what the client
/// asked for: status tabs across the top, a paginated list of the customer's
/// own requests, and one button at the bottom that starts a new one.
///
/// It replaces nothing. The fare box on the booking flow still works exactly as
/// it did; this is the place a customer can *find* bidding from, and the place
/// an unanswered request can be picked back up instead of being lost as soon as
/// the booking screen is closed.
class MyBidsScreen extends StatelessWidget {
  const MyBidsScreen({super.key});

  static final DateFormat _placedFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(() {
      final bool isDark = themeController.isDark.value;
      return GetX<MyBidsController>(
        init: MyBidsController(),
        builder: (MyBidsController controller) {
          // Read one observable before the branch, always.
          //
          // A GetX builder that subscribes to nothing throws "Improper use of a
          // GetX" mid-build, and in a release build that renders as an empty
          // body with no message - which is exactly what the client saw: "in
          // guest mode ... in BID section it was not showing Login. It was a
          // blank screen." The two states with no list to draw, signed out and
          // bidding switched off, read no `.obs` of their own; this makes the
          // subscription unconditional instead of leaving it to whichever
          // branch happens to be taken.
          final bool loading = controller.isLoading.value;

          return Scaffold(
            backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppThemeData.primary300,
              title: Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 10),
                child: Text(
                  "Choose Your Price".tr,
                  style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900),
                ),
              ),
            ),
            body: !controller.isSignedIn
                ? _signedOut(isDark)
                : !Constant.isBiddingEnabled
                    ? _switchedOff(isDark)
                    : Column(
                        children: [
                          _intro(isDark),
                          _tabs(controller, isDark),
                          Expanded(child: _list(context, controller, isDark, loading)),
                        ],
                      ),
            floatingActionButton: controller.isSignedIn && Constant.isBiddingEnabled
                ? FloatingActionButton.extended(
                    backgroundColor: AppThemeData.primary300,
                    // `bidding: true` is what makes the booking flow a bid.
                    // Reached only from here and from a live request below, so
                    // Ride on the home screen can never land in it.
                    onPressed: () => Get.to(() => const CabBookingScreen(bidding: true)),
                    icon: const Icon(Icons.local_offer_outlined, color: AppThemeData.grey900),
                    label: Text(
                      "Place a Bid".tr,
                      style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.grey900),
                    ),
                  )
                : null,
          );
        },
      );
    });
  }

  /// One line saying what this section is for. The client's own words for the
  /// feature — name your fare, drivers accept it or counter it.
  Widget _intro(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_offer_outlined, size: 18, color: AppThemeData.primary300),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Set the fare you want to pay. Nearby drivers accept it or send you a counter offer.".tr,
                  style: AppThemeData.regularTextStyle(fontSize: 13, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
                ),
                const SizedBox(height: 4),
                // Says where a request goes the moment it stops being a
                // request, so the customer is not left hunting for it here.
                Text(
                  "Once you accept an offer, the ride moves to your Bookings tab.".tr,
                  style: AppThemeData.regularTextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(MyBidsController controller, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: controller.tabKeys.map((String key) {
          final bool selected = controller.selectedTab.value == key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => controller.selectTab(key),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: selected
                        ? AppThemeData.primary300
                        : isDark
                            ? AppThemeData.grey800
                            : AppThemeData.grey100,
                  ),
                  child: Text(
                    _tabTitle(key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppThemeData.semiBoldTextStyle(
                      fontSize: 14,
                      color: selected
                          ? AppThemeData.grey900
                          : isDark
                              ? AppThemeData.grey200
                              : AppThemeData.grey700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _tabTitle(String key) {
    switch (key) {
      case MyBidsController.openTab:
        return 'Waiting'.tr;
      case MyBidsController.bookedTab:
        return 'Booked'.tr;
      default:
        return 'Closed'.tr;
    }
  }

  Widget _list(BuildContext context, MyBidsController controller, bool isDark, bool loading) {
    if (loading) return Constant.loader();

    final List<CabOrderModel> bids = controller.bids;
    if (bids.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refreshBids,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Constant.showEmptyView(message: _emptyMessage(controller.selectedTab.value)),
          ],
        ),
      );
    }

    return LoadMoreListener(
      onLoadMore: controller.loadMore,
      child: RefreshIndicator(
        onRefresh: controller.refreshBids,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: bids.length + (controller.hasMore ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index >= bids.length) return const LoadMoreIndicator();
            return _bidCard(controller, bids[index], isDark);
          },
        ),
      ),
    );
  }

  static String _emptyMessage(String tab) {
    switch (tab) {
      case MyBidsController.openTab:
        return "No open bids. Tap Place a Bid to name your fare.".tr;
      case MyBidsController.bookedTab:
        return "No booked bids yet".tr;
      default:
        return "Nothing closed yet".tr;
    }
  }

  Widget _bidCard(MyBidsController controller, CabOrderModel ride, bool isDark) {
    final RideBiddingState state = controller.stateFor(ride);
    final bool live = controller.isLive(ride);
    final int offers = state.bidCount.toInt();

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      // Only an open request has an offer list to go back to. The booking
      // screen re-attaches to it through `inProgressOrderID`, which is the same
      // path a cold app start takes, so nothing here has to restore state.
      onTap: live ? () => Get.to(() => const CabBookingScreen(bidding: true)) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.greyDark50 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ride.createdAt == null ? '' : _placedFormat.format(ride.createdAt!.toDate()),
                    style: AppThemeData.semiBoldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(controller, ride, isDark),
              ],
            ),
            const SizedBox(height: 10),
            _locationRow(Icons.stop_circle_outlined, Colors.green, ride.sourceLocationName ?? '', isDark),
            const SizedBox(height: 6),
            _locationRow(Icons.radio_button_checked, Colors.red, ride.destinationLocationName ?? '', isDark),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Your offer".tr,
                    style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey600),
                  ),
                ),
                Text(
                  controller.amountFor(ride),
                  style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.primary300),
                ),
              ],
            ),
            if (live)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        offers > 0
                            ? "$offers ${offers == 1 ? 'driver offer'.tr : 'driver offers'.tr}"
                            : "Waiting for driver offers....".tr,
                        style: AppThemeData.mediumTextStyle(
                          fontSize: 13,
                          color: offers > 0 ? AppThemeData.success400 : (isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                        ),
                      ),
                    ),
                    Text(
                      "View offers".tr,
                      style: AppThemeData.semiBoldTextStyle(fontSize: 13, color: AppThemeData.primary300),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppThemeData.primary300),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(MyBidsController controller, CabOrderModel ride, bool isDark) {
    final String tab = controller.tabFor(ride);
    final String status = controller.stateFor(ride).status ?? '';

    Color color;
    String label;
    switch (tab) {
      case MyBidsController.bookedTab:
        color = AppThemeData.primary300;
        label = "Booked".tr;
        break;
      case MyBidsController.closedTab:
        color = status == RideBiddingStatus.cancelled ? AppThemeData.danger300 : (isDark ? AppThemeData.grey400 : AppThemeData.grey500);
        label = status == RideBiddingStatus.cancelled
            ? "Cancelled".tr
            : status == RideBiddingStatus.noDrivers
                ? "No driver".tr
                : "Expired".tr;
        break;
      default:
        color = AppThemeData.success400;
        label = "Waiting".tr;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: color.withValues(alpha: 0.15)),
      child: Text(label, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: color)),
    );
  }

  /// Shown when the admin has bidding switched off. The section stays in the
  /// bar so it does not appear and disappear under the customer's thumb, and
  /// says plainly why it is empty.
  Widget _switchedOff(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer_outlined, size: 48, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
          const SizedBox(height: 12),
          Text(
            "Bidding is not available right now".tr,
            textAlign: TextAlign.center,
            style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
          ),
          const SizedBox(height: 6),
          Text(
            "You can still book a ride at the normal fare from the Home tab.".tr,
            textAlign: TextAlign.center,
            style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
          ),
        ],
      ),
    );
  }

  Widget _signedOut(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Please Log In to Continue".tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
          ),
          const SizedBox(height: 5),
          Text(
            "You’re not logged in. Please sign in to access your account and explore all features.".tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
          ),
          const SizedBox(height: 20),
          RoundedButtonFill(
            title: "Log in".tr,
            width: 55,
            height: 5.5,
            color: AppThemeData.primary300,
            textColor: AppThemeData.grey50,
            onPress: () async => Get.offAll(const LoginScreen()),
          ),
        ],
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String label, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
          ),
        ),
      ],
    );
  }
}
