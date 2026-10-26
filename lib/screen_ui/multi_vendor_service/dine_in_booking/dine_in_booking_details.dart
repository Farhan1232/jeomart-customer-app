import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_booking_details_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../controllers/theme_controller.dart';

class DineInBookingDetails extends StatelessWidget {
  const DineInBookingDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: DineInBookingDetailsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            title: Text(
              "Dine in Bookings".tr,
              style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${'Order'.tr} ${Constant.orderId(orderId: controller.bookingModel.value.id.toString())}",
                                    style: TextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    "${controller.bookingModel.value.totalGuest} ${'Peoples'.tr}",
                                    style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: ShapeDecoration(
                                color: Constant.statusColor(status: controller.bookingModel.value.status),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Text(
                                  "${controller.bookingModel.value.status}",
                                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_building.svg"),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller.bookingModel.value.vendor!.title.toString(),
                                            style: TextStyle(fontSize: 18, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                                          ),
                                          Text(
                                            controller.bookingModel.value.vendor!.location.toString(),
                                            style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        launchUrl(
                                          Constant.createCoordinatesUrl(
                                            controller.bookingModel.value.vendor!.latitude ?? 0.0,
                                            controller.bookingModel.value.vendor!.longitude ?? 0.0,
                                            controller.bookingModel.value.vendor!.title,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        "View in Map".tr,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                          fontFamily: AppThemeData.medium,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppThemeData.primary300,
                                        ),
                                      ),
                                    ),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(height: 16, child: VerticalDivider(width: 1))),
                                    InkWell(
                                      onTap: () {
                                        if (controller.bookingModel.value.vendor!.phonenumber!.isNotEmpty) {
                                          final Uri launchUri = Uri(scheme: 'tel', path: controller.bookingModel.value.vendor!.phonenumber);
                                          launchUrl(launchUri);
                                        }
                                      },
                                      child: Text(
                                        "Call Now".tr,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                          fontFamily: AppThemeData.medium,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppThemeData.primary300,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Booking Details".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Name".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "${controller.bookingModel.value.guestFirstName} ${controller.bookingModel.value.guestLastName}",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Phone number".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "${controller.bookingModel.value.guestPhone}",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Date and Time".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        Constant.timestampToDateTime(controller.bookingModel.value.date!),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Guest".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "${controller.bookingModel.value.totalGuest}",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Discount".tr,
                                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        "${controller.bookingModel.value.discount} %",
                                        textAlign: TextAlign.end,
                                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }
}
