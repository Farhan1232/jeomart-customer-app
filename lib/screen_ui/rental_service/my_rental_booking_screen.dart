import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_order_details_screen.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/my_rental_booking_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import 'package:customer/widget/tab_selection_listener.dart';
import 'package:customer/utils/app_image_cache.dart';

class MyRentalBookingScreen extends StatelessWidget {
  const MyRentalBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<MyRentalBookingController>(
      init: MyRentalBookingController(),
      builder: (controller) {
        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppThemeData.primary300,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [const SizedBox(width: 10), Text("Rental History".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))]),
              ),
              bottom: TabBar(
                onTap: (index) {
                  controller.selectTab(controller.tabTitles[index]);
                },
                indicatorColor: AppThemeData.parcelService500,
                labelColor: AppThemeData.parcelService500,
                unselectedLabelColor: AppThemeData.parcelService500,
                labelStyle: AppThemeData.boldTextStyle(fontSize: 13),
                unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 13),
                tabs: controller.tabTitles.map((title) => Tab(child: Center(child: Text(title)))).toList(),
              ),
            ),
            body:
                controller.isLoading.value
                    ? Constant.loader()
                    : Constant.userModel == null
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text("Please Log In to Continue".tr, style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold)),
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
                    )
                    : TabSelectionListener(
                        // A swipe between tabs has to do what a tap does: tell the paginator
                        // which tab is on screen, so it tops the list up for that tab.
                        onChanged: (index) => controller.selectTab(controller.tabTitles[index]),
                        child: TabBarView(
                               children:
                                   controller.tabTitles.map((title) {
                                     List<RentalOrderModel> orders = controller.getOrdersForTab(title);

                                     if (orders.isEmpty) {
                                       return RefreshIndicator(
                                         // An empty tab has to stay refreshable. It used to be a bare
                                         // Center, which scrolls nowhere - so a tab that looked empty
                                         // offered the user no way to ask again.
                                         onRefresh: controller.refreshOrders,
                                         child: ListView(
                                           physics: const AlwaysScrollableScrollPhysics(),
                                           children: [
                                             SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                                             Center(child: Text("No orders found".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                                           ],
                                         ),
                                       );
                                     }
                                     return LoadMoreListener(
                                       onLoadMore: controller.loadMoreOrders,
                                       child: RefreshIndicator(
                                         onRefresh: controller.refreshOrders,
                                         child: ListView.builder(
                                           padding: const EdgeInsets.all(16),
                                           itemCount: orders.length + (controller.hasMoreOrders ? 1 : 0),
                                           itemBuilder: (context, index) {
                                             if (index >= orders.length) {
                                               return const LoadMoreIndicator();
                                             }
                                             RentalOrderModel order = orders[index]; //use this
                                             return InkWell(
                                               onTap: () {
                                                 Get.to(() => RentalOrderDetailsScreen(), arguments: order);
                                               },
                                               child: Container(
                                                 decoration: BoxDecoration(
                                                   borderRadius: BorderRadius.circular(15),
                                                   color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                                   border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                                 ),
                                                 padding: const EdgeInsets.all(16),
                                                 margin: const EdgeInsets.only(bottom: 10),
                                                 child: Column(
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                     Row(
                                                       crossAxisAlignment: CrossAxisAlignment.start,
                                                       children: [
                                                         Padding(padding: const EdgeInsets.only(top: 5), child: Image.asset("assets/icons/pickup.png", height: 18, width: 18)),
                                                         const SizedBox(width: 10),
                                                         Expanded(
                                                           //prevents overflow
                                                           child: Column(
                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                             children: [
                                                               Row(
                                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                                 children: [
                                                                   Expanded(
                                                                     //text wraps if too long
                                                                     child: Text(
                                                                       order.sourceLocationName ?? "-",
                                                                       style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                       overflow: TextOverflow.ellipsis, //safe cutoff
                                                                       maxLines: 2,
                                                                     ),
                                                                   ),
                                                                   if (order.status != null) ...[
                                                                     const SizedBox(width: 8),
                                                                     Container(
                                                                       padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                                                       decoration: BoxDecoration(
                                                                         color: AppThemeData.info50,
                                                                         border: Border.all(color: AppThemeData.info300),
                                                                         borderRadius: BorderRadius.circular(12),
                                                                       ),
                                                                       child: Text(order.status ?? '', style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.info500)),
                                                                     ),
                                                                   ],
                                                                 ],
                                                               ),
                                                               if (order.bookingDateTime != null)
                                                                 Text(
                                                                   Constant.timestampToDateTime(order.bookingDateTime!),
                                                                   style: AppThemeData.mediumTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                                 ),
                                                             ],
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                     const SizedBox(height: 12),
                                                     Text("Vehicle Type :".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                                     Padding(
                                                       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                                       child: Row(
                                                         children: [
                                                           ClipRRect(
                                                             //borderRadius: BorderRadius.circular(10),
                                                             child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                                               imageUrl: order.rentalVehicleType!.rentalVehicleIcon.toString(),
                                                               height: 60,
                                                               width: 60,
                                                               imageBuilder:
                                                                   (context, imageProvider) => Container(
                                                                     decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: imageProvider, fit: BoxFit.cover)),
                                                                   ),
                                                               placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                                               errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover),
                                                               fit: BoxFit.cover,
                                                             ),
                                                           ),
                                                           Expanded(
                                                             child: Padding(
                                                               padding: const EdgeInsets.symmetric(horizontal: 10),
                                                               child: Column(
                                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                                 children: [
                                                                   Text(
                                                                     "${order.rentalVehicleType!.name}",
                                                                     style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                   ),
                                                                   Padding(
                                                                     padding: const EdgeInsets.only(top: 2.0),
                                                                     child: Text(
                                                                       "${order.rentalVehicleType!.shortDescription}",
                                                                       style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                                     ),
                                                                   ),
                                                                 ],
                                                               ),
                                                             ),
                                                           ),
                                                         ],
                                                       ),
                                                     ),
                                                     Text("Package info :".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                                     Padding(
                                                       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                                       child: Row(
                                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                         children: [
                                                           Expanded(
                                                             child: Column(
                                                               crossAxisAlignment: CrossAxisAlignment.start,
                                                               children: [
                                                                 Text(
                                                                   order.rentalPackageModel!.name.toString(),
                                                                   style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                 ),
                                                                 const SizedBox(height: 4),
                                                                 Text(
                                                                   order.rentalPackageModel!.description.toString(),
                                                                   style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                                 ),
                                                               ],
                                                             ),
                                                           ),
                                                           SizedBox(width: 10),
                                                           Text(
                                                             Constant.amountShow(amount: order.rentalPackageModel!.baseFare.toString()),
                                                             style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                           ),
                                                         ],
                                                       ),
                                                     ),
                                                     if (Constant.isEnableOTPTripStartForRental == true)
                                                       Text("${'OTP :'.tr} ${order.otpCode}", style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                                     SizedBox(height: 10),
                                                     Row(
                                                       children: [
                                                         order.status == Constant.orderInTransit && order.paymentStatus == false
                                                             ? Expanded(
                                                               child: RoundedButtonFill(
                                                                 title: "Pay Now".tr,
                                                                 onPress: () {
                                                                   Get.to(() => RentalOrderDetailsScreen(), arguments: order);
                                                                 },
                                                                 color: AppThemeData.primary300,
                                                                 textColor: AppThemeData.grey900,
                                                               ),
                                                             )
                                                             : SizedBox(),
                                                         order.status == Constant.orderPlaced || order.status == Constant.driverAccepted
                                                             ? Expanded(
                                                               child: RoundedButtonFill(
                                                                 title: "Cancel Booking",
                                                                 onPress: () => controller.cancelRentalRequest(order, taxList: order.taxSetting),
                                                                 color: AppThemeData.danger300,
                                                                 textColor: AppThemeData.surface,
                                                               ),
                                                             )
                                                             : SizedBox(),
                                                       ],
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                             );
                                           },
                                         ),
                                       ),
                                     );
                                   }).toList(),
                             ),
                      ),
          ),
        );
      },
    );
  }

  Obx cardDecoration(MyRentalBookingController controller, PaymentGateway value, isDark, String image) {
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
}
