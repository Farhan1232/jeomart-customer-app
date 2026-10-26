import 'package:customer/screen_ui/parcel_service/parcel_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import '../../controllers/parcel_dashboard_controller.dart';
import '../../controllers/theme_controller.dart';

class OrderSuccessfullyPlaced extends StatelessWidget {
  const OrderSuccessfullyPlaced({super.key});

  @override
  Widget build(BuildContext context) {
    final parcelOrder = Get.arguments['parcelOrder'];
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset("assets/images/parcel_order_successfully_placed.png"),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Your Order Has Been Placed!".tr,
                    style: AppThemeData.boldTextStyle(fontSize: 22, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    "We’ve received your parcel booking and it’s now being processed. You can track its status in real time.".tr,
                    style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                RoundedButtonFill(
                  title: "Track Your Order".tr,
                  onPress: () {
                    print("Tracking Order: $parcelOrder");
                    //Get.to(() => TrackOrderScreen(), arguments: {'order': parcelOrder});
                    Get.offAll(const ParcelDashboardScreen());
                    ParcelDashboardController controller = Get.put(ParcelDashboardController());
                    controller.selectedIndex.value = 1;
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
