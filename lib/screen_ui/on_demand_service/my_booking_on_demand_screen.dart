import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constant/constant.dart';
import '../../controllers/my_booking_on_demand_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/onprovider_order_model.dart';
import '../../models/worker_model.dart';
import '../../themes/app_them_data.dart';
import 'on_demand_order_details_screen.dart';
import 'package:customer/widget/tab_selection_listener.dart';
import 'package:customer/utils/app_image_cache.dart';

class MyBookingOnDemandScreen extends StatelessWidget {
  const MyBookingOnDemandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<MyBookingOnDemandController>(
      init: MyBookingOnDemandController(),
      builder: (controller) {
        return DefaultTabController(
          length: controller.tabTitles.length,
          initialIndex: controller.tabTitles.indexOf(controller.selectedTab.value),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppThemeData.primary300,
              centerTitle: false,
              title: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text("Booking History".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  onTap: (index) {
                    controller.selectTab(controller.tabTitles[index]);
                  },
                  indicatorColor: AppThemeData.grey900,
                  labelColor: AppThemeData.grey900,
                  unselectedLabelColor: AppThemeData.grey900,
                  labelStyle: AppThemeData.boldTextStyle(fontSize: 16),
                  unselectedLabelStyle: AppThemeData.mediumTextStyle(fontSize: 16),
                  tabs: controller.tabTitles.map((title) => Tab(child: Center(child: Text(title)))).toList(),
                ),
              ),
            ),
            body:
                controller.isLoading.value
                    ? Constant.loader()
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
                                             Center(child: Text("No bookings found".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
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
                                             OnProviderOrderModel onProviderOrder = orders[index];
                                             WorkerModel? worker = controller.getWorker(onProviderOrder.workerId);

                                             return InkWell(
                                               onTap: () {
                                                 Get.to(() => OnDemandOrderDetailsScreen(), arguments: onProviderOrder);
                                               },
                                               child: Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                                 margin: const EdgeInsets.only(bottom: 15),
                                                 decoration: BoxDecoration(
                                                   borderRadius: BorderRadius.circular(10),
                                                   border: Border.all(color: isDark ? AppThemeData.grey500 : Colors.grey.shade100, width: 1),
                                                   color: isDark ? AppThemeData.grey500 : Colors.white,
                                                 ),
                                                 child: Column(
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                     Row(
                                                       children: [
                                                         Padding(
                                                           padding: const EdgeInsets.symmetric(horizontal: 10),
                                                           child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                                             imageUrl: onProviderOrder.provider.photos.first,
                                                             height: 80,
                                                             width: 80,
                                                             imageBuilder:
                                                                 (context, imageProvider) => Container(
                                                                   decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: imageProvider, fit: BoxFit.cover)),
                                                                 ),
                                                             placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                                             errorWidget:
                                                                 (context, url, error) => ClipRRect(
                                                                   borderRadius: BorderRadius.circular(10),
                                                                   child: CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover, memCacheHeight: 80, memCacheWidth: 80),
                                                                 ),
                                                             fit: BoxFit.cover,
                                                           ),
                                                         ),
                                                         Expanded(
                                                           child: Padding(
                                                             padding: const EdgeInsets.symmetric(horizontal: 20),
                                                             child: Column(
                                                               crossAxisAlignment: CrossAxisAlignment.start,
                                                               children: [
                                                                 Container(
                                                                   padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                                                   decoration: BoxDecoration(
                                                                     color: AppThemeData.info50,
                                                                     border: Border.all(color: AppThemeData.info300),
                                                                     borderRadius: BorderRadius.circular(12),
                                                                   ),
                                                                   child: Text(onProviderOrder.status, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.info500)),
                                                                 ),
                                                                 Padding(
                                                                   padding: const EdgeInsets.only(top: 6),
                                                                   child: Text(
                                                                     onProviderOrder.provider.title.toString(),
                                                                     style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                   ),
                                                                 ),
                                                                 Padding(padding: const EdgeInsets.only(top: 6), child: buildPriceText(onProviderOrder)),
                                                                 const SizedBox(height: 6),
                                                                 if (onProviderOrder.status != Constant.orderCompleted &&
                                                                     onProviderOrder.status != Constant.orderCancelled &&
                                                                     onProviderOrder.otp != null &&
                                                                     onProviderOrder.otp!.isNotEmpty)
                                                                   Text(
                                                                     "${'OTP :'.tr} ${onProviderOrder.otp}",
                                                                     style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                   ),
                                                               ],
                                                             ),
                                                           ),
                                                         ),
                                                       ],
                                                     ),

                                                     /// Bottom Details (Date, Provider, Worker)
                                                     buildBottomDetails(context, onProviderOrder, isDark, worker),
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

  Widget buildPriceText(OnProviderOrderModel order) {
    final hasDiscount = order.provider.disPrice != "" && order.provider.disPrice != "0";
    final price = hasDiscount ? order.provider.disPrice.toString() : order.provider.price.toString();

    return Text(
      order.provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: price) : "${Constant.amountShow(amount: price)}/${'hr'.tr}",
      style: AppThemeData.mediumTextStyle(fontSize: 16, color: AppThemeData.primary300),
    );
  }

  Widget buildBottomDetails(BuildContext context, OnProviderOrderModel order, bool isDark, WorkerModel? worker) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppThemeData.grey400 : AppThemeData.grey100, width: 1),
        color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            detailRow("Date & Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.scheduleDateTime!.toDate()), isDark),
            const Divider(thickness: 1),
            detailRow("Provider", order.provider.authorName.toString(), isDark),

            if (order.provider.priceUnit == "Hourly") ...[
              if (order.startTime != null) ...[const Divider(thickness: 1), detailRow("Start Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.startTime!.toDate()), isDark)],
              if (order.endTime != null) ...[const Divider(thickness: 1), detailRow("End Time", DateFormat('dd-MMM-yyyy hh:mm a').format(order.endTime!.toDate()), isDark)],
            ],

            if (worker != null) ...[const Divider(thickness: 1), detailRow("Worker", worker.fullName().toString(), isDark)],
          ],
        ),
      ),
    );
  }

  Widget detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
          Text(value.tr, style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        ],
      ),
    );
  }
}
