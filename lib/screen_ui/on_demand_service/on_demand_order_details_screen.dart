import 'package:clipboard/clipboard.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/on_demand_order_details_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../constant/constant.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/chat_screens/chat_screen.dart';
import 'on_demand_payment_screen.dart';
import 'on_demand_review_screen.dart';
import 'package:customer/utils/app_image_cache.dart';

class OnDemandOrderDetailsScreen extends StatelessWidget {
  const OnDemandOrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: OnDemandOrderDetailsController(),
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
                  Text("Order Details".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
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
                        (controller.onProviderOrder.value?.status ?? '') == Constant.orderCancelled
                            ? Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cancel Reason'.tr, style: AppThemeData.mediumTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                    Text(controller.onProviderOrder.value?.reason ?? '', style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.danger300)),
                                  ],
                                ),
                              ),
                            )
                            : Container(),
                        (controller.onProviderOrder.value?.status ?? '') == Constant.orderCancelled ? SizedBox(height: 10) : SizedBox.shrink(),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Booking ID'.tr, style: AppThemeData.mediumTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                    InkWell(
                                      onTap: () {
                                        FlutterClipboard.copy(controller.onProviderOrder.value?.id ?? '').then((value) {
                                          SnackBar snackBar = SnackBar(
                                            content: Text(
                                              "Booking ID Copied".tr,
                                              textAlign: TextAlign.center,
                                              style: AppThemeData.mediumTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                            ),
                                            backgroundColor: Colors.black38,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                        });
                                      },
                                      child: Text('# ${controller.onProviderOrder.value?.id ?? ''}', style: AppThemeData.mediumTextStyle(fontSize: 15, color: AppThemeData.primary300)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "${'Booking Address :'.tr}  ${controller.onProviderOrder.value?.address?.getFullAddress()}",
                                  style: AppThemeData.mediumTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Container(
                                  height: 80,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        (controller.onProviderOrder.value != null && controller.onProviderOrder.value!.provider.photos.isNotEmpty)
                                            ? controller.onProviderOrder.value!.provider.photos.first
                                            : Constant.placeHolderImage,
                                      cacheManager: AppImageCache.manager,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        controller.onProviderOrder.value?.provider.title ?? "",
                                        style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text('${'Date:'.tr} ', style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            controller.onProviderOrder.value?.scheduleDateTime != null
                                                ? DateFormat('dd-MMM-yyyy').format(controller.onProviderOrder.value!.scheduleDateTime!.toDate())
                                                : "",
                                            style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text('${'Time:'.tr} ', style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            controller.onProviderOrder.value?.scheduleDateTime != null
                                                ? DateFormat('hh:mm a').format(controller.onProviderOrder.value!.scheduleDateTime!.toDate())
                                                : "",
                                            style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        (controller.onProviderOrder.value?.status == Constant.orderAccepted ||
                                    controller.onProviderOrder.value?.status == Constant.orderAssigned ||
                                    controller.onProviderOrder.value?.status == Constant.orderOngoing ||
                                    controller.onProviderOrder.value?.status == Constant.orderCompleted) &&
                                (controller.onProviderOrder.value?.workerId != null && controller.onProviderOrder.value!.workerId!.isNotEmpty)
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text('About Worker'.tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 30,
                                                    backgroundImage: CachedNetworkImageProvider(
                                                      controller.worker.value?.profilePictureURL.isNotEmpty == true ? controller.worker.value!.profilePictureURL : Constant.placeHolderImage,
                                                    cacheManager: AppImageCache.manager,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          controller.worker.value?.fullName() ?? '',
                                                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14, fontWeight: FontWeight.bold),
                                                        ),
                                                        const SizedBox(height: 5),
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 3),
                                                              child: Icon(Icons.location_on_outlined, size: 15, color: isDark ? Colors.white : Colors.black),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                controller.worker.value?.address ?? '',
                                                                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 10),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            // Rating Box
                                            Container(
                                              decoration: BoxDecoration(color: AppThemeData.warning400, borderRadius: BorderRadius.circular(16)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.star, size: 16, color: Colors.white),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    (controller.worker.value != null && double.parse(controller.worker.value!.reviewsCount.toString()) != 0)
                                                        ? (double.parse(controller.worker.value!.reviewsSum.toString()) / double.parse(controller.worker.value!.reviewsCount.toString()))
                                                            .toStringAsFixed(1)
                                                        : '0',
                                                    style: const TextStyle(letterSpacing: 0.5, fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, color: Colors.white),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Visibility(
                                          visible: controller.onProviderOrder.value?.status == Constant.orderCompleted ? true : false,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            child: SizedBox(
                                              width: MediaQuery.of(context).size.width,
                                              child: ElevatedButton(
                                                // onPressed: () async {
                                                //   Get.to(() => OnDemandReviewScreen(), arguments: {'order': controller.onProviderOrder.value, 'reviewFor': "Worker"});
                                                // },
                                                onPressed: () async {
                                                  final result = await Get.to(() => OnDemandReviewScreen(), arguments: {'order': controller.onProviderOrder.value, 'reviewFor': "Worker"});

                                                  // If review was submitted successfully
                                                  if (result == true) {
                                                    await controller.getData();
                                                  }
                                                },

                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                                child: Text('Add Review'.tr, style: AppThemeData.regularTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        controller.onProviderOrder.value?.status == Constant.orderAccepted ||
                                                controller.onProviderOrder.value?.status == Constant.orderOngoing ||
                                                controller.onProviderOrder.value?.status == Constant.orderAssigned
                                            ? Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        Constant.makePhoneCall(controller.worker.value!.phoneNumber.toString());
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6839), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.call, color: AppThemeData.grey50),
                                                          SizedBox(width: 10),
                                                          Text('Call'.tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.grey50)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        ShowToastDialog.showLoader("Please wait...".tr);
                                                        ShowToastDialog.closeLoader();

                                                        Get.to(
                                                          const ChatScreen(),
                                                          arguments: {
                                                            "senderName": Constant.userModel?.fullName(),
                                                            "receivedName": "${controller.worker.value?.firstName ?? ''} ${controller.worker.value?.lastName ?? ''}",
                                                            "orderId": controller.onProviderOrder.value?.id,
                                                            "receivedId": controller.worker.value?.id,
                                                            "senderId": Constant.userModel?.id,
                                                            "senderProfileUrl": Constant.userModel?.profilePictureURL,
                                                            "receivedProfileUrl": controller.worker.value?.profilePictureURL,
                                                            "token": controller.worker.value?.fcmToken,
                                                            "chatType": Constant.userRoleWorker,
                                                          },
                                                        );
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppThemeData.primary300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Icon(Icons.chat_bubble, color: AppThemeData.grey50),
                                                          SizedBox(width: 10),
                                                          Text('Chat'.tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.grey50)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            : SizedBox(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : SizedBox(),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text("About provider".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundImage: CachedNetworkImageProvider(
                                              controller.providerUser.value?.profilePictureURL?.isNotEmpty == true ? controller.providerUser.value!.profilePictureURL! : Constant.placeHolderImage,
                                            cacheManager: AppImageCache.manager,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  controller.providerUser.value?.fullName() ?? '',
                                                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  controller.providerUser.value?.email ?? '',
                                                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14),
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rating Box
                                    Container(
                                      decoration: BoxDecoration(color: AppThemeData.warning400, borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, size: 16, color: Colors.white),
                                          const SizedBox(width: 3),
                                          Text(
                                            (controller.providerUser.value != null && double.parse(controller.providerUser.value!.reviewsCount.toString()) != 0)
                                                ? (double.parse(controller.providerUser.value!.reviewsSum.toString()) / double.parse(controller.providerUser.value!.reviewsCount.toString()))
                                                    .toStringAsFixed(1)
                                                : '0',
                                            style: const TextStyle(letterSpacing: 0.5, fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Visibility(
                                  visible: controller.onProviderOrder.value?.status == Constant.orderCompleted ? true : false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final result = await Get.to(() => OnDemandReviewScreen(), arguments: {'order': controller.onProviderOrder.value, 'reviewFor': "Provider"});
                                          if (result == true) {
                                            await controller.getData();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                        child: Text('Add Review'.tr, style: AppThemeData.regularTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                      ),
                                    ),
                                  ),
                                ),
                                controller.onProviderOrder.value?.status == Constant.orderAccepted ||
                                        controller.onProviderOrder.value?.status == Constant.orderOngoing ||
                                        controller.onProviderOrder.value?.status == Constant.orderAssigned
                                    ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                Constant.makePhoneCall(controller.providerUser.value!.phoneNumber.toString());
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6839), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.call, color: AppThemeData.grey50),
                                                  SizedBox(width: 10),
                                                  Text('Call'.tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.grey50)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if ((Constant.isSubscriptionModelApplied == false && Constant.sectionConstantModel?.adminCommision?.isEnabled == false) ||
                                              ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) &&
                                                  controller.onProviderOrder.value?.provider.subscriptionPlan?.features?.chat == true))
                                            const SizedBox(width: 10),
                                          if ((Constant.isSubscriptionModelApplied == false && Constant.sectionConstantModel?.adminCommision?.isEnabled == false) ||
                                              ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) &&
                                                  controller.onProviderOrder.value?.provider.subscriptionPlan?.features?.chat == true))
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  ShowToastDialog.showLoader("Please wait...".tr);

                                                  ShowToastDialog.closeLoader();

                                                  Get.to(
                                                    const ChatScreen(),
                                                    arguments: {
                                                      "senderName": Constant.userModel?.fullName(),
                                                      "receivedName": "${controller.providerUser.value?.firstName ?? ''} ${controller.providerUser.value?.lastName ?? ''}",
                                                      "orderId": controller.onProviderOrder.value?.id,
                                                      "receivedId": controller.providerUser.value?.id,
                                                      "senderId": Constant.userModel?.id,
                                                      "senderProfileUrl": Constant.userModel?.profilePictureURL,
                                                      "receivedProfileUrl": controller.providerUser.value?.profilePictureURL,
                                                      "token": controller.providerUser.value?.fcmToken,
                                                      "chatType": Constant.userRoleProvider,
                                                    },
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: AppThemeData.primary300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.chat_bubble, color: AppThemeData.grey50),
                                                    SizedBox(width: 10),
                                                    Text('Chat'.tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.grey50)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                    : SizedBox(),
                              ],
                            ),
                          ),
                        ),
                        (controller.onProviderOrder.value?.status != Constant.orderCompleted || controller.onProviderOrder.value?.status != Constant.orderCancelled) &&
                                controller.onProviderOrder.value?.provider.priceUnit == "Fixed"
                            ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text("Price Detail".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                ),
                                priceTotalRow(context, controller, isDark),
                              ],
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                controller.onProviderOrder.value?.paymentStatus == false || controller.onProviderOrder.value?.extraPaymentStatus == false
                                    ? Column(
                                      children: [
                                        controller.couponList.isNotEmpty
                                            ? SizedBox(
                                              height: 85,
                                              child: ListView.builder(
                                                itemCount: controller.couponList.length,
                                                scrollDirection: Axis.horizontal,
                                                itemBuilder: (context, index) {
                                                  final coupon = controller.couponList[index];
                                                  return GestureDetector(onTap: () => controller.applyCoupon(coupon), child: buildOfferItem(controller, index, isDark));
                                                },
                                              ),
                                            )
                                            : Container(),
                                        buildPromoCode(controller, isDark),
                                      ],
                                    )
                                    : Offstage(),
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text("Price Detail".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                ),
                                priceTotalRow(context, controller, isDark),
                              ],
                            ),
                        controller.onProviderOrder.value?.extraCharges.toString() != ""
                            ? Container(
                              margin: EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Total Extra Charges : ".tr, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500)),
                                        Text(
                                          Constant.amountShow(amount: controller.onProviderOrder.value?.extraCharges.toString()),
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "Extra charge Notes : ".tr,
                                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        Text(
                                          controller.onProviderOrder.value?.extraChargesDescription ?? '',
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : SizedBox(),
                        SizedBox(height: 10),
                        Visibility(
                          visible: controller.onProviderOrder.value?.status == Constant.orderPlaced || controller.onProviderOrder.value?.newScheduleDateTime != null ? true : false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                child: Column(
                                  children: [
                                    controller.onProviderOrder.value?.newScheduleDateTime != null
                                        ? Row(
                                          children: [
                                            Text("New Date : ".tr, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500)),
                                            Text(
                                              DateFormat('dd-MMM-yyyy hh:mm a').format(controller.onProviderOrder.value!.newScheduleDateTime!.toDate()),
                                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        )
                                        : SizedBox(),
                                    controller.onProviderOrder.value?.status == Constant.orderPlaced || controller.onProviderOrder.value?.status == Constant.orderAccepted
                                        ? Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: RoundedButtonFill(
                                            title: "Cancel Booking".tr,
                                            color: AppThemeData.primary300,
                                            textColor: AppThemeData.grey50,
                                            onPress: () {
                                              showCancelBookingDialog(controller, isDark);
                                            },
                                          ),
                                        )
                                        : SizedBox(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        controller.onProviderOrder.value?.extraPaymentStatus == false && controller.onProviderOrder.value?.status == Constant.orderOngoing
                            ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: RoundedButtonFill(
                                title: 'Pay Extra Amount'.tr,
                                color: AppThemeData.primary300,
                                textColor: AppThemeData.grey50,
                                onPress: () async {
                                  double finalTotalAmount = 0.0;
                                  finalTotalAmount = double.parse(controller.onProviderOrder.value!.extraCharges.toString());
                                  Get.to(() => OnDemandPaymentScreen(), arguments: {'onDemandOrderModel': controller.onProviderOrder, 'totalAmount': finalTotalAmount, 'isExtra': true});
                                },
                              ),
                            )
                            : SizedBox(),
                        controller.onProviderOrder.value?.provider.priceUnit != "Fixed" && controller.onProviderOrder.value?.paymentStatus == false
                            ? Visibility(
                              visible: controller.onProviderOrder.value?.status == Constant.orderOngoing ? true : false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: RoundedButtonFill(
                                  title: 'Pay Now'.tr,
                                  color: AppThemeData.primary300,
                                  textColor: AppThemeData.grey50,
                                  onPress: () async {
                                    double finalTotalAmount = 0.0;
                                    finalTotalAmount =
                                        controller.totalAmount.value +
                                        double.parse(controller.onProviderOrder.value!.extraCharges!.isNotEmpty ? controller.onProviderOrder.value!.extraCharges.toString() : "0.0");
                                    controller.onProviderOrder.value?.discount = controller.discountAmount.toString();
                                    controller.onProviderOrder.value?.discountType = controller.discountType.toString();
                                    controller.onProviderOrder.value?.discountLabel = controller.discountLabel.toString();
                                    controller.onProviderOrder.value?.couponCode = controller.offerCode.toString();

                                    Get.to(() => OnDemandPaymentScreen(), arguments: {'onDemandOrderModel': controller.onProviderOrder, 'totalAmount': finalTotalAmount, 'isExtra': false});
                                  },
                                ),
                              ),
                            )
                            : SizedBox(),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  Widget buildOfferItem(OnDemandOrderDetailsController controller, int index, bool isDark) {
    return Obx(() {
      final coupon = controller.couponList[index];

      return Container(
        margin: const EdgeInsets.fromLTRB(7, 10, 7, 10),
        height: 85,
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(10), color: AppThemeData.primary300),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Image(image: AssetImage('assets/images/offer_icon.png'), height: 25, width: 25),
                    const SizedBox(width: 10),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      child: Text(
                        coupon.discountType == "Fix Price" ? "${Constant.amountShow(amount: coupon.discount.toString())} ${'OFF'.tr}" : "${coupon.discount} ${'% Off'.tr}",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.7, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coupon.code ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5, color: Colors.orange)),
                    Container(margin: const EdgeInsets.only(left: 15, right: 15, top: 3), width: 1, color: AppThemeData.grey50),
                    Text(
                      "valid till ".tr + controller.getDate(coupon.expiresAt!.toDate().toString()),
                      style: TextStyle(letterSpacing: 0.5, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget buildPromoCode(OnDemandOrderDetailsController controller, bool isDark) {
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100, width: 0.3),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset("assets/images/reedem.png", height: 50, width: 50),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Promo Code".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Text(
                            "Apply promo code".tr,
                            style: AppThemeData.mediumTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                onPressed: () {
                  Get.bottomSheet(promoCodeSheet(controller, isDark), isScrollControlled: true, isDismissible: true, backgroundColor: Colors.transparent, enableDrag: true);
                },
                mini: true,
                backgroundColor: Colors.blueGrey.shade50,
                elevation: 0,
                child: const Icon(Icons.add, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget promoCodeSheet(OnDemandOrderDetailsController controller, bool isDark) {
    return Container(
      padding: EdgeInsets.only(bottom: Get.height / 4.3, left: 25, right: 25),
      height: Get.height * 0.88,
      decoration: BoxDecoration(color: Colors.transparent, border: Border.all(style: BorderStyle.none)),
      child: Column(
        children: [
          InkWell(
            onTap: () => Get.back(),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100, width: 0.3),
                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                shape: BoxShape.circle,
              ),
              child: Center(child: Icon(Icons.close, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, size: 28)),
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(padding: const EdgeInsets.only(top: 30), child: const Image(image: AssetImage('assets/images/redeem_coupon.png'), width: 100)),
                    Container(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text('Redeem Your Coupons'.tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16)),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.only(top: 10, left: 22, right: 22),
                        child: Text("Voucher or Coupon code".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                      child: DottedBorder(
                        options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(12), color: AppThemeData.primary300),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            alignment: Alignment.center,
                            child: TextFormField(
                              textAlign: TextAlign.center,
                              style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                              controller: controller.couponTextController.value,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Write Coupon Code".tr,
                                hintStyle: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 30, bottom: 30, left: 15, right: 15),
                      child: RoundedButtonFill(
                        title: "REDEEM NOW".tr,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () {
                          final inputCode = controller.couponTextController.value.text.trim().toLowerCase();
                          print("Entered code: $inputCode");
                          print("Available coupons: ${controller.couponList.map((e) => e.code).toList()}");

                          final matchingCoupon = controller.couponList.firstWhereOrNull((c) => (c.code ?? '').trim().toLowerCase() == inputCode);

                          if (matchingCoupon != null) {
                            print("✅ Coupon matched: ${matchingCoupon.code}");
                            controller.applyCoupon(matchingCoupon);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              Get.back();
                            });
                          } else {
                            print("❌ No matching coupon found");
                            ShowToastDialog.showToast("Applied coupon not valid.".tr);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget priceTotalRow(BuildContext context, OnDemandOrderDetailsController controller, bool isDark) {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        ),
        child: Column(
          children: [
            const SizedBox(height: 5),
            rowText(
              "Price".tr,
              //Constant.amountShow(amount: controller.price.value.toString()),
              controller.onProviderOrder.value?.provider.disPrice == "" || controller.onProviderOrder.value?.provider.disPrice == "0"
                  ? "${Constant.amountShow(amount: controller.onProviderOrder.value?.provider.price.toString())} × ${controller.onProviderOrder.value?.quantity.toStringAsFixed(2)}    ${Constant.amountShow(amount: controller.price.value.toString())}"
                  : "${Constant.amountShow(amount: controller.onProviderOrder.value?.provider.disPrice.toString())} × ${controller.onProviderOrder.value?.quantity.toStringAsFixed(2)}    ${Constant.amountShow(amount: controller.price.value.toString())}",
              isDark,
            ),
            controller.discountAmount.value != 0 ? const Divider() : const SizedBox(),
            controller.discountAmount.value != 0
                ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"Discount".tr} ${controller.discountType.value == 'Percentage' || controller.discountType.value == 'Percent' ? "(${controller.discountLabel.value}%)" : "(${Constant.amountShow(amount: controller.discountLabel.value)})"}",
                              style: TextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            ),
                            Text(controller.offerCode.value, style: TextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                          ],
                        ),
                      ),
                      Text("(-${Constant.amountShow(amount: controller.discountAmount.value.toString())})", style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                )
                : const SizedBox(),

            const Divider(),
            if (Constant.platformFeeModel?.enable == true) rowText("Platform fee".tr, Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()), isDark),
            if (Constant.platformFeeModel?.enable == true) const Divider(),
            InkWell(
              onTap: () {
                showBillBifurcationDialog(context, isDark, controller);
              },
              child: rowText("Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString()), isDark, underline: true),
            ),
            // Total Amount
            const Divider(),
            rowText("Total Amount".tr, Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark),
            const SizedBox(height: 5),
          ],
        ),
      );
    });
  }

  Widget rowText(String title, String value, bool isDark, {bool? underline}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, decoration: underline == true ? TextDecoration.underline : TextDecoration.none),
          ),
          Text(value, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        ],
      ),
    );
  }

  Future<void> showCancelBookingDialog(OnDemandOrderDetailsController controller, bool isDark) {
    return Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        title: Text('Please give reason for canceling this Booking'.tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        content: TextFormField(
          controller: controller.cancelBookingController.value,
          maxLines: 5,
          decoration: InputDecoration(hintText: "Specify your reason here".tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(7))),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel'.tr, style: TextStyle(color: Colors.red))),
          TextButton(
            onPressed: () async {
              if (controller.cancelBookingController.value.text.trim().isEmpty) {
                ShowToastDialog.showToast("Please enter reason".tr);
              } else {
                await controller.cancelBooking();
              }
            },
            child: Text('Continue'.tr, style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, OnDemandOrderDetailsController controller) {
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
