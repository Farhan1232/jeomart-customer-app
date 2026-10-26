import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_restaurant_details_controller.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import '../../../controllers/theme_controller.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../chat_screens/full_screen_image_viewer.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../review_list_screen/review_list_screen.dart';
import 'book_table_screen.dart';

class DineInDetailsScreen extends StatelessWidget {
  const DineInDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: DineInRestaurantDetailsController(),
      builder: (controller) {
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  expandedHeight: Responsive.height(30, context),
                  floating: true,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: AppThemeData.primary300,
                  title: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Get.back();
                        },
                        child: Icon(Icons.arrow_back, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                      ),
                      const Expanded(child: SizedBox()),
                      InkWell(
                        onTap: () async {
                          if (controller.favouriteList.where((p0) => p0.restaurantId == controller.vendorModel.value.id).isNotEmpty) {
                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                            controller.favouriteList.removeWhere((item) => item.restaurantId == controller.vendorModel.value.id);
                            await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                          } else {
                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: controller.vendorModel.value.id, userId: FireStoreUtils.getCurrentUid());
                            controller.favouriteList.add(favouriteModel);
                            await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                          }
                        },
                        child: Obx(
                          () =>
                              controller.favouriteList.where((p0) => p0.restaurantId == controller.vendorModel.value.id).isNotEmpty
                                  ? SvgPicture.asset("assets/icons/ic_like_fill.svg", colorFilter: const ColorFilter.mode(AppThemeData.grey50, BlendMode.srcIn))
                                  : SvgPicture.asset("assets/icons/ic_like.svg"),
                        ),
                      ),
                    ],
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        controller.vendorModel.value.photos == null || controller.vendorModel.value.photos!.isEmpty
                            ? Stack(
                              children: [
                                NetworkImageWidget(
                                  imageUrl: controller.vendorModel.value.photo.toString(),
                                  fit: BoxFit.cover,
                                  width: Responsive.width(100, context),
                                  height: Responsive.height(40, context),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(begin: const Alignment(0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), Colors.black]),
                                  ),
                                ),
                              ],
                            )
                            : PageView.builder(
                              physics: const BouncingScrollPhysics(),
                              controller: controller.pageController.value,
                              scrollDirection: Axis.horizontal,
                              itemCount: controller.vendorModel.value.photos!.length,
                              padEnds: false,
                              pageSnapping: true,
                              onPageChanged: (value) {
                                controller.currentPage.value = value;
                              },
                              itemBuilder: (BuildContext context, int index) {
                                String image = controller.vendorModel.value.photos![index];
                                return Stack(
                                  children: [
                                    NetworkImageWidget(imageUrl: image.toString(), fit: BoxFit.cover, width: Responsive.width(100, context), height: Responsive.height(40, context)),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(begin: const Alignment(0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), Colors.black]),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        Positioned(
                          bottom: 10,
                          right: 0,
                          left: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(controller.vendorModel.value.photos!.length, (index) {
                              return Obx(
                                () => Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  alignment: Alignment.centerLeft,
                                  height: 9,
                                  width: 9,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: controller.currentPage.value == index ? AppThemeData.primary300 : AppThemeData.grey300),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body:
                controller.isLoading.value
                    ? Constant.loader()
                    : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              controller.vendorModel.value.title.toString(),
                                              textAlign: TextAlign.start,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 22,
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                              ),
                                            ),
                                            SizedBox(
                                              width: Responsive.width(78, context),
                                              child: Text(
                                                controller.vendorModel.value.location.toString(),
                                                textAlign: TextAlign.start,
                                                style: TextStyle(fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Container(
                                            decoration: ShapeDecoration(
                                              color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              child: Row(
                                                children: [
                                                  SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    Constant.calculateReview(
                                                      reviewCount: controller.vendorModel.value.reviewsCount!.toStringAsFixed(0),
                                                      reviewSum: controller.vendorModel.value.reviewsSum.toString(),
                                                    ),
                                                    style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          InkWell(
                                            onTap: () {
                                              Get.to(const ReviewListScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                                            },
                                            child: Text(
                                              "${controller.vendorModel.value.reviewsCount} ${'Ratings'.tr}",
                                              style: TextStyle(decoration: TextDecoration.underline, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700, fontFamily: AppThemeData.regular),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        controller.isOpen.value ? "Open".tr : "Close".tr,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: AppThemeData.semiBold,
                                          fontWeight: FontWeight.w600,
                                          color: controller.isOpen.value ? AppThemeData.success400 : AppThemeData.danger300,
                                        ),
                                      ),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.circle, size: 5, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500)),
                                      InkWell(
                                        onTap: () {
                                          timeShowBottomSheet(context, controller);
                                        },
                                        child: Text(
                                          "View Timings".tr,
                                          textAlign: TextAlign.start,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 14,
                                            decoration: TextDecoration.underline,
                                            decorationColor: AppThemeData.ecommerce300,
                                            overflow: TextOverflow.ellipsis,
                                            fontFamily: AppThemeData.semiBold,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                          ),
                                        ),
                                      ),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.circle, size: 5, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500)),
                                      Text(
                                        "${Constant.amountShow(amount: controller.vendorModel.value.restaurantCost)} ${'for two'.tr}".tr,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: AppThemeData.semiBold,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      Text(
                                        "Also applicable on food delivery".tr,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: AppThemeData.semiBold,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () {
                                          if (Constant.userModel == null) {
                                            ShowToastDialog.showToast("Please log in to the application. You are not logged in.".tr);
                                          } else {
                                            Get.to(const BookTableScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                                          }
                                        },
                                        child: Container(
                                          height: 80,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: ShapeDecoration(
                                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                            shape: RoundedRectangleBorder(
                                              side: BorderSide(width: 1, color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: Image.asset(isDark ? "assets/images/ic_table_dark.gif" : "assets/images/ic_table.gif"),
                                                ),

                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Table Booking".tr,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        "Quick Confirmations".tr,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                          fontFamily: AppThemeData.medium,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () {
                                          Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": controller.vendorModel.value});
                                        },
                                        child: Container(
                                          height: 80,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: ShapeDecoration(
                                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                            shape: RoundedRectangleBorder(
                                              side: BorderSide(width: 1, color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Container(
                                                  decoration: ShapeDecoration(
                                                    color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(4),
                                                    child: Image.asset(isDark ? "assets/images/food_delivery_dark.gif" : "assets/images/food_delivery.gif"),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Available food delivery".tr,
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                          fontFamily: AppThemeData.semiBold,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      Text(
                                                        "in 30-45 mins.".tr,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                          fontFamily: AppThemeData.medium,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  controller.vendorModel.value.restaurantMenuPhotos == null || controller.vendorModel.value.restaurantMenuPhotos!.isEmpty
                                      ? const SizedBox()
                                      : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          Text(
                                            "Menu".tr,
                                            textAlign: TextAlign.start,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 16,
                                              overflow: TextOverflow.ellipsis,
                                              fontFamily: AppThemeData.semiBold,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                            ),
                                          ),
                                          SizedBox(
                                            height: Responsive.height(12, context),
                                            child: ListView.builder(
                                              itemCount: controller.vendorModel.value.restaurantMenuPhotos!.length,
                                              scrollDirection: Axis.horizontal,
                                              padding: EdgeInsets.zero,
                                              itemBuilder: (context, index) {
                                                return InkWell(
                                                  onTap: () {
                                                    Get.to(FullScreenImageViewer(imageUrl: controller.vendorModel.value.restaurantMenuPhotos![index]));
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(6.0),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: NetworkImageWidget(
                                                        imageUrl: controller.vendorModel.value.restaurantMenuPhotos![index],
                                                        height: Responsive.height(12, context),
                                                        width: Responsive.height(12, context),
                                                        fit: BoxFit.fill,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                  const SizedBox(height: 20),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Location, Timing & Costs".tr,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: AppThemeData.semiBold,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SvgPicture.asset("assets/icons/ic_location.svg"),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  controller.vendorModel.value.location.toString(),
                                                  textAlign: TextAlign.start,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.regular,
                                                    fontWeight: FontWeight.w400,
                                                    color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    launchUrl(
                                                      Constant.createCoordinatesUrl(
                                                        controller.vendorModel.value.latitude ?? 0.0,
                                                        controller.vendorModel.value.longitude ?? 0.0,
                                                        controller.vendorModel.value.title,
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    "View on Map".tr,
                                                    textAlign: TextAlign.start,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontFamily: AppThemeData.semiBold,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SvgPicture.asset("assets/icons/ic_alarm_clock.svg", height: 20),
                                          const SizedBox(width: 14),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Timing".tr,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.regular,
                                                  fontWeight: FontWeight.w400,
                                                  color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {},
                                                child: Text(
                                                  "${controller.vendorModel.value.openDineTime == '' ? "10:00 AM" : controller.vendorModel.value.openDineTime.toString()} ${"To".tr} ${controller.vendorModel.value.closeDineTime == '' ? "10:00 PM" : controller.vendorModel.value.closeDineTime.toString()}",
                                                  textAlign: TextAlign.start,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontFamily: AppThemeData.semiBold,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            Constant.currencyModel!.symbol.toString(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 24, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                          ),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Cost for Two".tr,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.regular,
                                                  fontWeight: FontWeight.w400,
                                                  color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                                ),
                                              ),
                                              Text(
                                                "${Constant.amountShow(amount: controller.vendorModel.value.restaurantCost ?? "0.0")} ${'(approx)'.tr}",
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Cuisines".tr,
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: AppThemeData.semiBold,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 5.0,
                                        children: <Widget>[
                                          ...controller.tags.map(
                                            (tag) => FilterChip(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                              side: BorderSide.none,
                                              backgroundColor: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                              labelStyle: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                              label: Text("$tag"),
                                              onSelected: (bool value) {},
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        );
      },
    );
  }

  Future timeShowBottomSheet(BuildContext context, DineInRestaurantDetailsController productModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: 0.70,
            child: StatefulBuilder(
              builder: (context1, setState) {
                final themeController = Get.find<ThemeController>();
                final isDark = themeController.isDark.value;
                return Scaffold(
                  backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Container(
                              width: 134,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey50 : AppThemeData.grey800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: productModel.vendorModel.value.workingHours!.length,
                            itemBuilder: (context, dayIndex) {
                              WorkingHours workingHours = productModel.vendorModel.value.workingHours![dayIndex];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${workingHours.day}",
                                      textAlign: TextAlign.start,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 16,
                                        overflow: TextOverflow.ellipsis,
                                        fontFamily: AppThemeData.semiBold,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    workingHours.timeslot == null || workingHours.timeslot!.isEmpty
                                        ? const SizedBox()
                                        : ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: workingHours.timeslot!.length,
                                          itemBuilder: (context, timeIndex) {
                                            Timeslot timeSlotModel = workingHours.timeslot![timeIndex];
                                            return Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      decoration: BoxDecoration(
                                                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                                                        border: Border.all(color: isDark ? AppThemeData.grey400 : AppThemeData.grey200),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          timeSlotModel.from.toString(),
                                                          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                                      decoration: BoxDecoration(
                                                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                                                        border: Border.all(color: isDark ? AppThemeData.grey400 : AppThemeData.grey200),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          timeSlotModel.to.toString(),
                                                          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}
