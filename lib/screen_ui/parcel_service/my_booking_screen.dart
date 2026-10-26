import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:customer/screen_ui/parcel_service/parcel_order_details.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_my_booking_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:customer/widget/tab_selection_listener.dart';

class MyBookingScreen extends StatelessWidget {
  const MyBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<ParcelMyBookingController>(
      init: ParcelMyBookingController(),
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
                child: Row(children: [const SizedBox(width: 10), Text("Parcel History".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))]),
              ),
              bottom: TabBar(
                // don't re-subscribe onTap — just update selectedTab (optional)
                onTap: (index) {
                  controller.selectTab(controller.tabTitles[index]);
                },
                indicatorColor: AppThemeData.parcelService500,
                labelColor: AppThemeData.parcelService500,
                unselectedLabelColor: AppThemeData.parcelService500,
                labelStyle: AppThemeData.boldTextStyle(fontSize: 15),
                unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 15),
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
                                     final orders = controller.getOrdersForTab(title);

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
                                             final order = orders[index];
                                             return GestureDetector(
                                               onTap: () {
                                                 Get.to(() => const ParcelOrderDetails(), arguments: order);
                                               },
                                               child: Container(
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
                                                     Padding(
                                                       padding: const EdgeInsets.only(bottom: 8.0),
                                                       child: Text(
                                                         "${'Order Date:'.tr}${order.isSchedule == true ? controller.formatDate(order.createdAt!) : controller.formatDate(order.senderPickupDateTime!)}",
                                                         style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.info400),
                                                       ),
                                                     ),
                                                     Row(
                                                       crossAxisAlignment: CrossAxisAlignment.start,
                                                       children: [
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
                                                         Expanded(
                                                           child: Column(
                                                             crossAxisAlignment: CrossAxisAlignment.start,
                                                             children: [
                                                               _infoSection(
                                                                 "Pickup Address (Sender):".tr,
                                                                 order.sender?.name ?? '',
                                                                 order.sender?.address ?? '',
                                                                 order.sender?.phone ?? '',
                                                                 // order.senderPickupDateTime != null
                                                                 //     ? "Pickup Time: ${controller.formatDate(order.senderPickupDateTime!)}"
                                                                 //     : '',
                                                                 order.status,
                                                                 isDark,
                                                               ),
                                                               const SizedBox(height: 16),
                                                               _infoSection(
                                                                 "Delivery Address (Receiver):".tr,
                                                                 order.receiver?.name ?? '',
                                                                 order.receiver?.address ?? '',
                                                                 order.receiver?.phone ?? '',
                                                                 // order.receiverPickupDateTime != null
                                                                 //     ? "Delivery Time: ${controller.formatDate(order.receiverPickupDateTime!)}"
                                                                 //     : '',
                                                                 null,
                                                                 isDark,
                                                               ),
                                                             ],
                                                           ),
                                                         ),
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

  Widget _infoSection(String title, String name, String address, String phone, String? status, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (status != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(color: AppThemeData.info50, border: Border.all(color: AppThemeData.info300), borderRadius: BorderRadius.circular(12)),
                child: Text(status, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.info500)),
              ),
            ],
          ],
        ),
        Text(name, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(address, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(phone, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        //Text(time, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
    );
  }
}
