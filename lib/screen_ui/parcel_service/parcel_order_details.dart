import 'package:customer/screen_ui/parcel_service/parcel_review_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_details_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_border.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../../utils/network_image_widget.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';

class ParcelOrderDetails extends StatelessWidget {
  const ParcelOrderDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ParcelOrderDetailsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => Get.back(),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Order Details".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                        Text(
                          "Your parcel is on the way. Track it in real time below.".tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.grey900),
                        ),
                      ],
                    ),
                  ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            "${'Order Id:'.tr} ${Constant.orderId(orderId: controller.parcelOrder.value.id.toString())}".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline with icons and line
                                  Column(
                                    children: [
                                      Image.asset("assets/images/image_parcel.png", height: 32, width: 32),
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
                                        child: const SizedBox(width: 20, height: 95),
                                      ),
                                      Image.asset("assets/images/image_parcel.png", height: 32, width: 32),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Address Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _infoSection(
                                          "Pickup Address (Sender):".tr,
                                          controller.parcelOrder.value.sender?.name ?? '',
                                          controller.parcelOrder.value.sender?.address ?? '',
                                          controller.parcelOrder.value.sender?.phone ?? '',
                                          // controller.parcelOrder.value.senderPickupDateTime != null
                                          //     ? "Pickup Time: ${controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}"
                                          //     : '',
                                          isDark,
                                        ),
                                        const SizedBox(height: 16),
                                        _infoSection(
                                          "Delivery Address (Receiver):".tr,
                                          controller.parcelOrder.value.receiver?.name ?? '',
                                          controller.parcelOrder.value.receiver?.address ?? '',
                                          controller.parcelOrder.value.receiver?.phone ?? '',
                                          // controller.parcelOrder.value.receiverPickupDateTime != null
                                          //     ? "Delivery Time: ${controller.formatDate(controller.parcelOrder.value.receiverPickupDateTime!)}"
                                          //     : '',
                                          isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(),

                              if (controller.parcelOrder.value.isSchedule == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    "${'Schedule Pickup time:'.tr} ${controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}",
                                    style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.info400),
                                  ),
                                ),

                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  "${'Order Date:'.tr}${controller.parcelOrder.value.isSchedule == true ? controller.formatDate(controller.parcelOrder.value.createdAt!) : controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}",
                                  style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.info400),
                                ),
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Parcel Type:".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                  Row(
                                    children: [
                                      Text(
                                        controller.parcelOrder.value.parcelType ?? '',
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
                                      ),
                                      const SizedBox(width: 8),
                                      if (controller.getSelectedCategory()?.image != null && controller.getSelectedCategory()!.image!.isNotEmpty)
                                        NetworkImageWidget(imageUrl: controller.getSelectedCategory()?.image ?? '', height: 20, width: 20),
                                    ],
                                  ),
                                ],
                              ),
                              controller.parcelOrder.value.parcelImages!.isEmpty
                                  ? SizedBox()
                                  : SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      itemCount: controller.parcelOrder.value.parcelImages!.length,
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: NetworkImageWidget(imageUrl: controller.parcelOrder.value.parcelImages![index], width: 100, fit: BoxFit.cover, borderRadius: 10),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Distance, Weight, Rate
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
                              _iconTile("${controller.parcelOrder.value.distance ?? '--'} ${Constant.distanceType}", "Distance".tr, "assets/icons/ic_distance_parcel.svg", isDark),
                              _iconTile(controller.parcelOrder.value.parcelWeight ?? '--', "Weight".tr, "assets/icons/ic_weight_parcel.svg", isDark),
                              _iconTile(Constant.amountShow(amount: controller.parcelOrder.value.subTotal), "Rate".tr, "assets/icons/ic_rate_parcel.svg", isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (controller.parcelOrder.value.driver != null)
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
                                      crossAxisAlignment: CrossAxisAlignment.center,
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
                                            Text(
                                              controller.parcelOrder.value.driver?.fullName() ?? '',
                                              style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                            ),
                                          ],
                                        ),
                                        RoundedButtonBorder(
                                          title: controller.driverUser.value!.averageRating.toStringAsFixed(1),
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
                                      visible: controller.parcelOrder.value.status == Constant.orderCompleted ? true : false,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        child: RoundedButtonFill(
                                          title: controller.ratingModel.value.id != null && controller.ratingModel.value.id!.isNotEmpty ? 'Update Review'.tr : 'Add Review'.tr,
                                          onPress: () async {
                                            final result = await Get.to(() => ParcelReviewScreen(), arguments: {'order': controller.parcelOrder.value});

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
                                    if (controller.parcelOrder.value.status != Constant.orderCompleted)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              Constant.makePhoneCall(controller.parcelOrder.value.driver!.phoneNumber.toString());
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

                                              UserModel? customer = await FireStoreUtils.getUserProfile(controller.parcelOrder.value.authorID ?? '');
                                              UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.parcelOrder.value.driverId ?? '');

                                              ShowToastDialog.closeLoader();

                                              Get.to(
                                                const ChatScreen(),
                                                arguments: {
                                                  "senderName": customer?.fullName(),
                                                  "receivedName": driverUser?.fullName(),
                                                  "orderId": controller.parcelOrder.value.id,
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
                              _summaryTile("Subtotal".tr, Constant.amountShow(amount: controller.subTotal.value.toString()), isDark),

                              // Discount
                              _summaryTile("Discount".tr, "-${(Constant.amountShow(amount: controller.discount.value.toString()))}", isDark),

                              // Tax List
                              if (double.parse(controller.parcelOrder.value.platformFee ?? '0.0') > 0.0)
                                _summaryTile("Platform fee".tr, Constant.amountShow(amount: controller.parcelOrder.value.platformFee ?? '0.0'), isDark),
                              InkWell(
                                onTap: () {
                                  showBillBifurcationDialog(context, isDark, controller);
                                },
                                child: _summaryTile("Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString()), isDark, underline: true),
                              ),
                              const Divider(),

                              // Total
                              _summaryTile("Order Total".tr, Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          bottomNavigationBar:
              controller.parcelOrder.value.status == Constant.orderPlaced
                  ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: RoundedButtonFill(
                      title: "Cancel Parcel".tr,
                      onPress: () {
                        controller.cancelParcelOrder();
                      },
                      height: 5,
                      borderRadius: 15,
                      color: AppThemeData.primary300,
                      textColor: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,
                    ),
                  )
                  : SizedBox(),
        );
      },
    );
  }

  Widget statusBottomSheet(BuildContext context, ParcelOrderDetailsController controller, bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.20,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: isDark ? AppThemeData.grey500 : Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Parcel Status Timeline".tr, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18)),
                const SizedBox(height: 8),

                // Dynamic List
                Obx(() {
                  final history = controller.parcelOrder.value.statusHistory ?? [];

                  if (history.isEmpty) {
                    return SizedBox(
                      height: 80,
                      child: Center(child: Text("No status updates yet".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                    );
                  }

                  return SizedBox(
                    height: history.length * 70.0,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final statusUpdate = history[index];
                        final isCompleted = index < history.length;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(isCompleted ? "assets/images/image_status_timeline.png" : "assets/images/image_timeline.png", height: 48, width: 48),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  statusUpdate.status ?? '',
                                  style: AppThemeData.semiBoldTextStyle(color: isCompleted ? (isDark ? AppThemeData.greyDark900 : AppThemeData.grey900) : AppThemeData.grey500, fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoSection(String title, String name, String address, String phone, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(name, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(address, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(phone, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        // Text(time, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
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

  Widget _summaryTile(String title, String value, bool isDark, {bool? underline}) {
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
          Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: title == "Order Total".tr ? 18 : 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        ],
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, ParcelOrderDetailsController controller) {
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
