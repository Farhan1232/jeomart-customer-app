import 'package:customer/themes/responsive.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/cab_order_details_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/app_them_data.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as osm;
import '../../themes/round_button_border.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../../utils/network_image_widget.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';
import 'cab_review_screen.dart';
import 'complain_screen.dart';

class CabOrderDetails extends StatelessWidget {
  const CabOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabOrderDetailsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Ride Details".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            "${'Order Id:'.tr} ${Constant.orderId(orderId: controller.cabOrder.value.id.toString())}".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
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
                                "${'Booking Date:'.tr} ${controller.formatDate(controller.cabOrder.value.scheduleDateTime!)}".tr,
                                textAlign: TextAlign.start,
                                style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Icon(Icons.stop_circle_outlined, color: Colors.green),
                                      DottedBorder(
                                        options: CustomPathDottedBorderOptions(
                                          color: Colors.grey.shade400,
                                          strokeWidth: 2,
                                          dashPattern: [4, 4],
                                          customPath:
                                              (size) =>
                                                  Path()
                                                    ..moveTo(size.width / 2, 0)
                                                    ..lineTo(size.width / 2, size.height),
                                        ),
                                        child: const SizedBox(width: 20, height: 55),
                                      ),
                                      Icon(Icons.radio_button_checked, color: Colors.red),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Source Location Name
                                            Expanded(
                                              child: Text(
                                                controller.cabOrder.value.sourceLocationName.toString(),
                                                style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppThemeData.warning300, width: 1),
                                                color: AppThemeData.warning50,
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                              child: Text(
                                                controller.cabOrder.value.status.toString(),
                                                style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.warning500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 15),
                                        DottedBorder(
                                          options: CustomPathDottedBorderOptions(
                                            color: Colors.grey.shade400,
                                            strokeWidth: 2,
                                            dashPattern: [4, 4],
                                            customPath:
                                                (size) =>
                                                    Path()
                                                      ..moveTo(0, size.height / 2) // start from left center
                                                      ..lineTo(size.width, size.height / 2), // draw to right center
                                          ),
                                          child: const SizedBox(width: 295, height: 3),
                                        ),
                                        SizedBox(height: 15),
                                        Text(
                                          controller.cabOrder.value.destinationLocationName.toString(),
                                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // map view show
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child:
                                Constant.selectedMapType == "osm"
                                    ? fm.FlutterMap(
                                      options: fm.MapOptions(
                                        initialCenter: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                                        initialZoom: 13,
                                      ),
                                      children: [
                                        fm.TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.jeo.customer'),

                                        // Only show polyline if points exist
                                        if (controller.osmPolyline.isNotEmpty) fm.PolylineLayer(polylines: [fm.Polyline(points: controller.osmPolyline.toList(), color: Colors.blue, strokeWidth: 4)]),

                                        fm.MarkerLayer(
                                          markers: [
                                            fm.Marker(
                                              point: osm.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                                              width: 20,
                                              height: 20,
                                              child: Image.asset('assets/icons/ic_cab_pickup.png', width: 10, height: 10),
                                            ),
                                            fm.Marker(
                                              point: osm.LatLng(controller.cabOrder.value.destinationLocation!.latitude!, controller.cabOrder.value.destinationLocation!.longitude!),
                                              width: 20,
                                              height: 20,
                                              child: Image.asset('assets/icons/ic_cab_destination.png', width: 10, height: 10),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                    : gmap.GoogleMap(
                                      initialCameraPosition: gmap.CameraPosition(
                                        target: gmap.LatLng(controller.cabOrder.value.sourceLocation!.latitude!, controller.cabOrder.value.sourceLocation!.longitude!),
                                        zoom: 13,
                                      ),
                                      polylines: controller.googlePolylines.toSet(),
                                      markers: controller.googleMarkers.toSet(),
                                    ),
                          ),
                        ),
                        controller.cabOrder.value.driver != null
                            ? Column(
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Ride & Fare Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 52,
                                                height: 52,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadiusGeometry.circular(10),
                                                  child: NetworkImageWidget(imageUrl: controller.cabOrder.value.driver?.profilePictureURL ?? '', height: 70, width: 70, borderRadius: 35),
                                                ),
                                              ),
                                              SizedBox(width: 20),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    controller.cabOrder.value.driver?.fullName() ?? '',
                                                    style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                                  ),
                                                  Builder(builder: (_) {
                                                    final sid = controller.cabOrder.value.sectionId ?? '';
                                                    final vehicle = controller.cabOrder.value.driver?.vehicleDetails?[sid];
                                                    if (vehicle == null) return const SizedBox.shrink();
                                                    final vType = vehicle['vehicleType']?.toString() ?? '';
                                                    final brand = vehicle['carBrand']?.toString() ?? '';
                                                    final carModel = vehicle['carModel']?.toString() ?? '';
                                                    final plate = vehicle['carPlateNumber']?.toString() ?? '';
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (vType.isNotEmpty)
                                                          Text(
                                                            vType,
                                                            style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                                          ),
                                                        if (brand.isNotEmpty || carModel.isNotEmpty)
                                                          Text(
                                                            "$brand $carModel".trim(),
                                                            style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                                          ),
                                                        if (plate.isNotEmpty)
                                                          Text(
                                                            plate.toUpperCase(),
                                                            style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 16),
                                                          ),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              ),
                                            ],
                                          ),
                                          RoundedButtonBorder(
                                            title: controller.driverUser.value.averageRating.toStringAsFixed(1),
                                            width: 20,
                                            height: 3.5,
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Visibility(
                                              visible: controller.cabOrder.value.status == Constant.orderCompleted ? true : false,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                child: RoundedButtonFill(
                                                  title: controller.ratingModel.value.id != null && controller.ratingModel.value.id!.isNotEmpty ? 'Update Review'.tr : 'Add Review'.tr,
                                                  onPress: () async {
                                                    final result = await Get.to(() => CabReviewScreen(), arguments: {'order': controller.cabOrder.value});

                                                    // If review was submitted successfully
                                                    if (result == true) {
                                                      await controller.fetchDriverDetails();
                                                    }
                                                  },
                                                  height: 5,
                                                  borderRadius: 15,
                                                  color: Colors.orange,
                                                  textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 5),
                                          Expanded(
                                            child: Visibility(
                                              visible: controller.cabOrder.value.status == Constant.orderCompleted ? true : false,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                child: RoundedButtonFill(
                                                  title: 'Complain'.tr,
                                                  onPress: () async {
                                                    Get.to(() => ComplainScreen(), arguments: {'order': controller.cabOrder.value});
                                                  },
                                                  height: 5,
                                                  borderRadius: 15,
                                                  color: Colors.orange,
                                                  textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (controller.cabOrder.value.status != Constant.orderCompleted)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                Constant.makePhoneCall(controller.cabOrder.value.driver!.phoneNumber.toString());
                                              },
                                              child: Container(
                                                width: 150,
                                                height: 42,
                                                decoration: ShapeDecoration(
                                                  shape: RoundedRectangleBorder(
                                                    side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                    borderRadius: BorderRadius.circular(120),
                                                  ),
                                                ),
                                                child: Padding(padding: const EdgeInsets.all(8.0), child: SvgPicture.asset("assets/icons/ic_phone_call.svg")),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            InkWell(
                                              onTap: () async {
                                                ShowToastDialog.showLoader("Please wait...".tr);

                                                UserModel? customer = await FireStoreUtils.getUserProfile(controller.cabOrder.value.authorID ?? '');
                                                UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.cabOrder.value.driverId ?? '');

                                                ShowToastDialog.closeLoader();

                                                Get.to(
                                                  const ChatScreen(),
                                                  arguments: {
                                                    "senderName": customer?.fullName(),
                                                    "receivedName": driverUser?.fullName(),
                                                    "orderId": controller.cabOrder.value.id,
                                                    // senderId is the customer and receivedId the
                                                    // driver. These two were swapped and mis-keyed
                                                    // ("customerId"), which left the controller with
                                                    // no receiver at all.
                                                    "senderId": customer?.id,
                                                    "receivedId": driverUser?.id,
                                                    "senderProfileUrl": customer?.profilePictureURL,
                                                    "receivedProfileUrl": driverUser?.profilePictureURL,
                                                    "token": driverUser?.fcmToken,
                                                    "chatType": Constant.userRoleDriver,
                                                  },
                                                );
                                              },
                                              child: Container(
                                                width: 150,
                                                height: 42,
                                                decoration: ShapeDecoration(
                                                  shape: RoundedRectangleBorder(
                                                    side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                    borderRadius: BorderRadius.circular(120),
                                                  ),
                                                ),
                                                child: Padding(padding: const EdgeInsets.all(8.0), child: SvgPicture.asset("assets/icons/ic_wechat.svg")),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : SizedBox(),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _iconTile("${double.parse(controller.cabOrder.value.distance.toString()).toStringAsFixed(2)} ${'KM'.tr}", "Distance".tr, "assets/icons/ic_distance_parcel.svg", isDark),
                              _iconTile(controller.cabOrder.value.duration ?? '--', "Duration".tr, "assets/icons/ic_duration.svg", isDark),
                              _iconTile(Constant.amountShow(amount: controller.cabOrder.value.subTotal), "${controller.cabOrder.value.paymentMethod}".tr, "assets/icons/ic_rate_parcel.svg", isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Order Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
                              const SizedBox(height: 8),

                              // Subtotal
                              _summaryTile("Subtotal", Constant.amountShow(amount: controller.subTotal.value.toString()), isDark),

                              // Discount
                              _summaryTile("Discount", Constant.amountShow(amount: controller.discount.value.toString()), isDark),

                              // Tax List
                              if (Constant.platformFeeModel?.enable == true)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Platform fee".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                      Text(
                                        Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                    ],
                                  ),
                                ),

                              InkWell(
                                onTap: () {
                                  showBillBifurcationDialog(context, isDark, controller);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Tax amount".tr,
                                        style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, decoration: TextDecoration.underline),
                                      ),
                                      Text(
                                        Constant.amountShow(amount: controller.taxAmount.value.toString()),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const Divider(),

                              // Total
                              _summaryTile("Order Total", Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  Widget _iconTile(String value, title, icon, bool isDark) {
    return Column(
      children: [
        // Icon(icon, color: AppThemeData.primary300),
        SvgPicture.asset(icon, height: 28, width: 28, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
        const SizedBox(height: 6),
        Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
        const SizedBox(height: 6),
        Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, CabOrderDetailsController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10), // 🔥 KEY FIX
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: Responsive.width(100, context), // ✅ 90% width
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10),
                  Text("Tax Details".tr, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                  const SizedBox(height: 5),
                  sectionDivider(isDark),
                  const SizedBox(height: 5),
                  amountRow(title: "Tax on Order Total".tr, amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString()), isDark: isDark),
                  sectionDivider(isDark),
                  amountRow(title: "Tax on Platform Fee".tr, amount: Constant.amountShow(amount: controller.platformTaxAmount.value.toString()), isDark: isDark),
                  sectionDivider(isDark),
                  amountRow(title: "Total Tax Amount".tr, amount: Constant.amountShow(amount: controller.taxAmount.value.toString()), amountColor: AppThemeData.primary300, isDark: isDark),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: Text("Close".tr))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget amountRow({required String title, required String amount, required bool isDark, Color? textColour, Color? amountColor, bool? underline, Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title.tr,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: textColour ?? (isDark ? AppThemeData.grey300 : AppThemeData.grey600),
              fontSize: 16,
              decoration: underline == true ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
        trailing ?? Text(amount, style: TextStyle(fontFamily: AppThemeData.regular, color: amountColor ?? (isDark ? AppThemeData.grey50 : AppThemeData.grey900), fontSize: 16)),
      ],
    );
  }

  Widget sectionDivider(bool isDark) {
    return Column(children: [const SizedBox(height: 10), MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200), const SizedBox(height: 10)]);
  }

  Widget _summaryTile(String title, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
          Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: title == "Order Total" ? 18 : 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        ],
      ),
    );
  }
}
