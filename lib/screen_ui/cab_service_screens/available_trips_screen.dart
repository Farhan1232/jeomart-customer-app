import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/available_trips_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_border.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Available Trips - full-vehicle trips drivers have posted.
///
/// Browsing only. It used to carry a second *My Bookings* tab as well, which is
/// the confusion the client asked to remove: *"My booking section will be same
/// for all kind of trips so nobody will get confused. Only to place bid or to
/// see trips that sections will work."* A trip this customer takes now appears
/// in Ride History with every other booking, and booking one from here moves
/// straight to that tab.
///
/// Every component on this screen is one the app already had:
/// `NetworkImageWidget` for the cached driver photo, `RoundedButtonBorder` for
/// the rating pill (the same one the bidding offer card uses),
/// `RoundedButtonFill` for the action, `MySeparator`, and AppThemeData
/// typography and colours.
class AvailableTripsScreen extends StatelessWidget {
  const AvailableTripsScreen({super.key});

  static final DateFormat _tripFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();
    final bool isDark = themeController.isDark.value;

    return GetX<AvailableTripsController>(
      init: AvailableTripsController(),
      builder: (AvailableTripsController controller) {
        // Read one observable before the branch, always. A GetX builder that
        // subscribes to nothing throws, and the signed-out branch below reads
        // none of its own - which is exactly how the Bid section came to render
        // a blank screen for a guest instead of its Log in prompt.
        final bool loading = controller.isLoading.value;

        return Scaffold(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 10),
              child: Text("Available Trips".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
            ),
          ),
          body: !controller.isSignedIn ? _signedOut(isDark) : _availableList(context, controller, isDark, loading),
        );
      },
    );
  }

  Widget _signedOut(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Please Log In to Continue".tr,
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
            onPress: () async {
              Get.offAll(const LoginScreen());
            },
          ),
        ],
      ),
    );
  }

  Widget _availableList(BuildContext context, AvailableTripsController controller, bool isDark, bool loading) {
    if (loading) return Constant.loader();
    if (controller.trips.isEmpty) {
      return _emptyList(context, controller.refreshTrips, "No trips available right now".tr);
    }
    return LoadMoreListener(
      onLoadMore: controller.loadMoreTrips,
      child: RefreshIndicator(
        onRefresh: controller.refreshTrips,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: controller.trips.length + (controller.hasMoreTrips ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (index >= controller.trips.length) return const LoadMoreIndicator();
            return _tripCard(controller, controller.trips[index], isDark);
          },
        ),
      ),
    );
  }

  Widget _emptyList(BuildContext context, Future<void> Function() onRefresh, String message) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Constant.showEmptyView(message: message),
        ],
      ),
    );
  }

  Widget _tripCard(AvailableTripsController controller, DriverTripModel trip, bool isDark) {
    final bool busy = controller.bookingInFlight.value.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trip.tripDateTime == null ? '' : _tripFormat.format(trip.tripDateTime!.toDate()),
            style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
          ),
          const SizedBox(height: 10),
          _locationRow(Icons.stop_circle_outlined, Colors.green, trip.fromAddress ?? '', isDark),
          const SizedBox(height: 6),
          _locationRow(Icons.radio_button_checked, Colors.red, trip.toAddress ?? '', isDark),
          if ((trip.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                trip.note!,
                style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: NetworkImageWidget(imageUrl: trip.driverPhoto ?? '', height: 56, width: 56, borderRadius: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.driverName ?? '',
                      style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                    if ((trip.vehicleType ?? '').isNotEmpty)
                      Text(
                        trip.vehicleType!,
                        style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                    if (trip.vehicleDescription.isNotEmpty)
                      Text(
                        trip.vehicleDescription,
                        style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                    if ((trip.vehiclePlate ?? '').isNotEmpty)
                      Text(
                        trip.vehiclePlate!.toUpperCase(),
                        style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Constant.amountShow(amount: (trip.fullVehiclePrice ?? 0).toString()),
                    style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.primary300),
                  ),
                  const SizedBox(height: 6),
                  RoundedButtonBorder(
                    title: (trip.driverRating ?? 0).toStringAsFixed(1),
                    width: 18,
                    height: 3.2,
                    radius: 10,
                    isRight: false,
                    isCenter: true,
                    textColor: AppThemeData.warning400,
                    borderColor: AppThemeData.warning400,
                    color: AppThemeData.warning50,
                    icon: SvgPicture.asset("assets/icons/ic_start.svg"),
                    onPress: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip("Full Vehicle".tr, isDark),
              _chip("${trip.driverCompletedTrips ?? 0} ${'trips'.tr}", isDark),
              if (trip.airConditioning != null) _chip(trip.airConditioning! ? "AC".tr : "Non-AC".tr, isDark),
            ],
          ),
          const SizedBox(height: 12),
          RoundedButtonFill(
            title: "Book Full Vehicle".tr,
            height: 5,
            color: AppThemeData.primary300,
            textColor: AppThemeData.grey50,
            onPress: () {
              if (busy) return;
              _confirmBooking(controller, trip, isDark);
            },
          ),
        ],
      ),
    );
  }

  void _confirmBooking(AvailableTripsController controller, DriverTripModel trip, bool isDark) {
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppThemeData.grey800 : Colors.white,
        title: Text(
          "Book Full Vehicle".tr,
          style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
        ),
        content: Text(
          "${'You are booking the whole vehicle for'.tr} ${Constant.amountShow(amount: (trip.fullVehiclePrice ?? 0).toString())}. "
          "${'The driver will be told straight away.'.tr}",
          style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey300 : AppThemeData.grey700),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(),
            child: Text("No".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.bookTrip(trip);
            },
            child: Text("Yes".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.primary300)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? AppThemeData.grey700 : AppThemeData.grey100),
      child: Text(
        label,
        style: AppThemeData.mediumTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
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
