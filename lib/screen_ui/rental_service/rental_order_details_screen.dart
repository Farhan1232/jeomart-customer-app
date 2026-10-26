import 'package:customer/constant/constant.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_review_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../controllers/rental_order_details_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_border.dart';
import '../../themes/round_button_fill.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';

class RentalOrderDetailsScreen extends StatelessWidget {
  const RentalOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: RentalOrderDetailsController(),
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
                    onTap: () {
                      Get.back();
                    },
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Order Details".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Center(child: Constant.loader())
                  : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "${'Booking Id :'.tr} ${controller.order.value.id}",
                                              style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: controller.order.value.id.toString()));
                                              ShowToastDialog.showToast("Booking ID copied to clipboard".tr);
                                            },
                                            child: Icon(Icons.copy),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(padding: const EdgeInsets.only(top: 5), child: Image.asset("assets/icons/pickup.png", height: 15, width: 15)),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  controller.order.value.sourceLocationName ?? "-",
                                                  style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                ),
                                                if (controller.order.value.bookingDateTime != null)
                                                  Text(
                                                    Constant.timestampToDate(controller.order.value.bookingDateTime!),
                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 15),
                                if (controller.order.value.rentalPackageModel != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                      border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Your Preference".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                        SizedBox(height: 10),

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    controller.order.value.rentalPackageModel!.name ?? "-",
                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    controller.order.value.rentalPackageModel!.description ?? "",
                                                    style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              Constant.amountShow(amount: controller.order.value.rentalPackageModel!.baseFare.toString()),
                                              style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 15),
                                if (controller.order.value.driver != null)
                                  Column(
                                    children: [
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
                                            Text("About Driver".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
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
                                                        child: NetworkImageWidget(imageUrl: controller.driverUser.value?.profilePictureURL ?? '', height: 70, width: 70, borderRadius: 35),
                                                      ),
                                                    ),
                                                    SizedBox(width: 20),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          controller.order.value.driver?.fullName() ?? '',
                                                          style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                                        ),
                                                        Builder(builder: (_) {
                                                          final sid = controller.order.value.sectionId ?? '';
                                                          final vehicle = controller.order.value.driver?.vehicleDetails?[sid];
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
                                                  title: controller.driverUser.value?.averageRating.toString() ?? '',
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
                                            Visibility(
                                              visible: controller.order.value.status == Constant.orderCompleted ? true : false,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                child: RoundedButtonFill(
                                                  title: controller.ratingModel.value.id != null && controller.ratingModel.value.id!.isNotEmpty ? 'Update Review'.tr : 'Add Review'.tr,
                                                  onPress: () async {
                                                    final result = await Get.to(() => RentalReviewScreen(), arguments: {'order': controller.order.value});

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
                                            controller.order.value.status == Constant.orderCompleted || controller.order.value.status == Constant.orderCancelled
                                                ? SizedBox()
                                                : Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        Constant.makePhoneCall(controller.order.value.driver!.phoneNumber ?? '');
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

                                                        UserModel? customer = await FireStoreUtils.getUserProfile(controller.order.value.authorID ?? '');
                                                        UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.order.value.driverId ?? '');

                                                        ShowToastDialog.closeLoader();

                                                        Get.to(
                                                          const ChatScreen(),
                                                          arguments: {
                                                            "senderName": customer?.fullName(),
                                                            "receivedName": driverUser?.fullName(),
                                                            "orderId": controller.order.value.id,
                                                            "receivedId": driverUser?.id,
                                                            "senderId": customer?.id,
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
                                      const SizedBox(height: 15),
                                    ],
                                  ),
                                if (controller.order.value.rentalVehicleType != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                      border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Vehicle Type".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                        SizedBox(height: 10),
                                        Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: NetworkImageWidget(imageUrl: controller.order.value.rentalVehicleType!.rentalVehicleIcon ?? "", height: 50, width: 50),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    controller.order.value.rentalVehicleType!.name ?? "",
                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                  ),
                                                  Text(
                                                    controller.order.value.rentalVehicleType!.shortDescription ?? "",
                                                    style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 15),

                                Container(
                                  width: Responsive.width(100, context),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Rental Details".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                        Divider(color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Rental Package'.tr,
                                                  textAlign: TextAlign.start,
                                                  style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                ),
                                              ),
                                              Text(
                                                controller.order.value.rentalPackageModel!.name.toString().tr,
                                                textAlign: TextAlign.start,
                                                style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Rental Package Price'.tr,
                                                  textAlign: TextAlign.start,
                                                  style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                ),
                                              ),
                                              Text(
                                                Constant.amountShow(amount: controller.order.value.rentalPackageModel!.baseFare.toString()).tr,
                                                textAlign: TextAlign.start,
                                                style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${'Including'.tr} ${Constant.distanceType.tr}',
                                                  textAlign: TextAlign.start,
                                                  style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                ),
                                              ),
                                              Text(
                                                "${controller.order.value.rentalPackageModel!.includedDistance.toString()} ${Constant.distanceType}".tr,
                                                textAlign: TextAlign.start,
                                                style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Including Hours'.tr,
                                                  textAlign: TextAlign.start,
                                                  style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                ),
                                              ),
                                              Text(
                                                "${controller.order.value.rentalPackageModel!.includedHours.toString()} ${'Hr'.tr}".tr,
                                                textAlign: TextAlign.start,
                                                style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${'Extra'.tr} ${Constant.distanceType}',
                                                  textAlign: TextAlign.start,
                                                  style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                ),
                                              ),
                                              Text(
                                                controller.getExtraKm(),
                                                textAlign: TextAlign.start,
                                                style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Padding(
                                        //   padding: const EdgeInsets.symmetric(vertical: 10),
                                        //   child: Row(
                                        //     children: [
                                        //       Expanded(
                                        //         child: Text(
                                        //           'Extra ${Constant.distanceType}',
                                        //           textAlign: TextAlign.start,
                                        //           style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                        //         ),
                                        //       ),
                                        //       Text(
                                        //         "${(double.parse(controller.order.value.endKitoMetersReading!.toString()) - double.parse(controller.order.value.startKitoMetersReading!.toString()) - double.parse(controller.order.value.rentalPackageModel!.includedDistance!.toString()))} ${Constant.distanceType}",
                                        //         textAlign: TextAlign.start,
                                        //         style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                        //       ),
                                        //     ],
                                        //   ),
                                        // ),
                                        controller.order.value.endTime == null
                                            ? SizedBox()
                                            : Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Extra Minutes'.tr,
                                                      textAlign: TextAlign.start,
                                                      style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                    ),
                                                  ),
                                                  Text(
                                                    "${controller.order.value.endTime == null ? "0" : (((controller.order.value.endTime!.toDate().difference(controller.order.value.startTime!.toDate()).inMinutes) - (int.parse(controller.order.value.rentalPackageModel!.includedHours.toString()) * 60)).clamp(0, double.infinity).toInt().toString())} ${'Min'.tr}",
                                                    textAlign: TextAlign.start,
                                                    style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Order Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
                                      const SizedBox(height: 8),

                                      _summaryTile("Subtotal".tr, Constant.amountShow(amount: controller.subTotal.value.toString()), isDark, null),
                                      _summaryTile("Discount".tr, Constant.amountShow(amount: controller.discount.value.toString()), isDark, AppThemeData.dangerDark300),
                                      if (double.parse(controller.order.value.platformFee ?? '0.0') > 0)
                                        _summaryTile("Platform fee".tr, Constant.amountShow(amount: controller.order.value.platformFee.toString()), isDark, null),
                                      InkWell(
                                        onTap: () {
                                          showBillBifurcationDialog(context, isDark, controller);
                                        },
                                        child: _summaryTile("Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString()), isDark, null, underline: true),
                                      ),

                                      const Divider(),
                                      _summaryTile("Order Total".tr, Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark, null),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            if (controller.order.value.status == Constant.orderInTransit && controller.order.value.paymentStatus == false)
                              Expanded(
                                child: RoundedButtonFill(
                                  title: "Pay Now".tr,
                                  onPress: () {
                                    if (controller.order.value.endKitoMetersReading == null ||
                                        controller.order.value.endKitoMetersReading == "0.0" ||
                                        controller.order.value.endKitoMetersReading!.isEmpty) {
                                      ShowToastDialog.showToast("You are not able to pay now until driver adds kilometer".tr);
                                    } else {
                                      Get.bottomSheet(paymentBottomSheet(context, controller, isDark, controller.order.value), isScrollControlled: true, backgroundColor: Colors.transparent);
                                    }
                                  },
                                  color: AppThemeData.primary300,
                                  textColor: AppThemeData.grey900,
                                ),
                              ),
                            if (controller.order.value.status == Constant.orderPlaced || controller.order.value.status == Constant.driverAccepted)
                              Expanded(
                                child: RoundedButtonFill(
                                  title: "Cancel Booking",
                                  onPress: () {
                                    controller.cancelRentalRequest(controller.order.value);
                                  },
                                  color: AppThemeData.danger300,
                                  textColor: AppThemeData.surface,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
        );
      },
    );
  }

  Widget _summaryTile(String title, String value, bool isDark, Color? colors, {bool? underline}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppThemeData.mediumTextStyle(
              fontSize: 16,
              color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800,
              decoration: underline == true ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
          Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: title == "Order Total" ? 18 : 16, color: colors ?? (isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
        ],
      ),
    );
  }

  Widget paymentBottomSheet(BuildContext context, RentalOrderDetailsController controller, bool isDark, RentalOrderModel orderModel) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      // Start height
      minChildSize: 0.30,
      // Minimum height
      maxChildSize: 0.8,
      // Maximum height
      expand: false,
      //Prevents full-screen takeover
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: isDark ? AppThemeData.grey500 : Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Select Payment Method".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                  GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  controller: scrollController,
                  children: [
                    Text("Preferred Payment".tr, textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                    const SizedBox(height: 10),
                    if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Visibility(
                                visible: controller.walletSettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png"),
                              ),
                              Visibility(
                                visible: controller.cashOnDeliverySettingModel.value.isEnabled == true,
                                child: cardDecoration(controller, PaymentGateway.cod, isDark, "assets/images/ic_cash.png"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(
                            "Other Payment Options".tr,
                            textAlign: TextAlign.start,
                            style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")),
                            Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")),
                            Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png")),
                            Visibility(
                              visible: controller.mercadoPagoModel.value.isEnabled == true,
                              child: cardDecoration(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png"),
                            ),
                            Visibility(
                              visible: controller.flutterWaveModel.value.isEnable == true,
                              child: cardDecoration(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png"),
                            ),
                            Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")),
                            Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png")),
                            Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")),
                            Visibility(
                              visible: controller.orangeMoneyModel.value.enable == true,
                              child: cardDecoration(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png"),
                            ),
                            Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
              RoundedButtonFill(
                title: "Continue".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey900,
                onPress: () async {
                  if (controller.selectedPaymentMethod.value.isEmpty) {
                    ShowToastDialog.showToast("Please select a payment method".tr);
                  } else {
                    if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                      controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                      controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                      controller.payStackPayment(controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                      controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                      controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                      controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                      controller.completeOrder();
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                      if (Constant.userModel!.walletAmount == null || Constant.userModel!.walletAmount! < controller.totalAmount.value) {
                        ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                      } else {
                        controller.completeOrder();
                      }
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                      controller.completeOrder();
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                      controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                      controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                      controller.xenditPayment(context, controller.totalAmount.value.toString());
                    } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                      RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()), razorpayModel: controller.razorPayModel.value).then((value) {
                        if (value == null) {
                          Get.back();
                          ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                        } else {
                          CreateRazorPayOrderModel result = value;
                          controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
                        }
                      });
                    } else {
                      ShowToastDialog.showToast("Please select payment method".tr);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Obx cardDecoration(RentalOrderDetailsController controller, PaymentGateway value, isDark, String image) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: ShapeDecoration(shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8))),
                    child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: Image.asset(image)),
                  ),
                  const SizedBox(width: 10),
                  value.name == "wallet"
                      ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.name.capitalizeString(),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                            ),
                            Text(
                              Constant.amountShow(amount: Constant.userModel!.walletAmount == null ? '0.0' : Constant.userModel!.walletAmount.toString()),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                            ),
                          ],
                        ),
                      )
                      : Expanded(
                        child: Text(
                          value.name.capitalizeString(),
                          textAlign: TextAlign.start,
                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        ),
                      ),
                  const Expanded(child: SizedBox()),
                  Radio(
                    value: value.name,
                    groupValue: controller.selectedPaymentMethod.value,
                    activeColor: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                    onChanged: (value) {
                      controller.selectedPaymentMethod.value = value.toString();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, RentalOrderDetailsController controller) {
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
                  const SizedBox(height: 20),
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
}
