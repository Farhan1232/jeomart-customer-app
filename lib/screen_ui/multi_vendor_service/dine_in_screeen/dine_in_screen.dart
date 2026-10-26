import 'package:customer/utils/banner_tap.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_controller.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/dine_in_screeen/view_all_category_dine_in_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../models/banner_model.dart';
import '../../../service/fire_store_utils.dart';
import '../../../widget/restaurant_image_view.dart';
import '../home_screen/category_restaurant_screen.dart';
import 'dine_in_details_screen.dart';
import 'dine_in_restaurant_list_screen.dart';

class DineInScreen extends StatelessWidget {
  const DineInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: DineInController(),
      builder: (controller) {
        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  expandedHeight: Responsive.height(38, context),
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
                    ],
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      children: [
                        Image.asset("assets/images/dine_in_bg.png", fit: BoxFit.fill, width: Responsive.width(100, context)),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "Dine-In Reservations".tr,
                                  style: TextStyle(fontSize: 24, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, color: isDark ? AppThemeData.grey900 : AppThemeData.grey900),
                                ),
                                Text(
                                  "Book a table at your favorite restaurant and enjoy a delightful dining experience.".tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey900 : AppThemeData.grey900),
                                ),
                              ],
                            ),
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
                    : Constant.isZoneAvailable == false || controller.allNearestRestaurant.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset("assets/images/location.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round()),
                          const SizedBox(height: 12),
                          Text(
                            "No Dine-In Reservations Found in Your Area".tr,
                            style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Currently, there are no available Dine-In Reservations in your zone. Try changing your location to find nearby options.".tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                          ),
                          const SizedBox(height: 20),
                          RoundedButtonFill(
                            title: "Change Zone".tr,
                            width: 55,
                            height: 5.5,
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey50,
                            onPress: () async {
                              Get.offAll(const LocationPermissionScreen(autoDetect: false));
                            },
                          ),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                titleView(isDark, "Explore the Categories".tr, () {
                                  Get.to(const ViewAllCategoryDineInScreen());
                                }),
                                const SizedBox(height: 10),
                                CategoryView(controller: controller),
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                          controller.newArrivalRestaurantList.isEmpty
                              ? const SizedBox()
                              : Container(
                                decoration: const BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/ic_new_arrival_dinein.png"), fit: BoxFit.cover)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "New Arrivals".tr,
                                              textAlign: TextAlign.start,
                                              style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              Get.to(const DineInRestaurantListScreen(), arguments: {"vendorList": controller.newArrivalRestaurantList, "title": "New Arrival"});
                                            },
                                            child: Text(
                                              "View all".tr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      NewArrival(controller: controller),
                                    ],
                                  ),
                                ),
                              ),
                          controller.bannerBottomModel.isEmpty
                              ? const SizedBox()
                              : Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), child: BannerBottomView(controller: controller)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          controller.isPopular.value = true;
                                        },
                                        child: Container(
                                          decoration:
                                              controller.isPopular.value == false
                                                  ? null
                                                  : ShapeDecoration(color: AppThemeData.grey900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Text(
                                              "Popular Stores".tr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          controller.isPopular.value = false;
                                        },
                                        child: Container(
                                          decoration:
                                              controller.isPopular.value == true
                                                  ? null
                                                  : ShapeDecoration(color: AppThemeData.grey900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Text(
                                              "All Stores".tr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: AppThemeData.semiBold,
                                                color:
                                                    controller.isPopular.value == true
                                                        ? isDark
                                                            ? AppThemeData.grey400
                                                            : AppThemeData.grey500
                                                        : isDark
                                                        ? AppThemeData.primary300
                                                        : AppThemeData.primary300,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: controller.isPopular.value ? PopularRestaurant(controller: controller) : AllRestaurant(controller: controller),
                          ),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }

  Row titleView(isDark, String name, Function()? onPress) {
    return Row(
      children: [
        Expanded(child: Text(name, textAlign: TextAlign.start, style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900))),
        InkWell(
          onTap: () {
            onPress!();
          },
          child: Text("View all".tr, textAlign: TextAlign.center, style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300)),
        ),
      ],
    );
  }
}

class PopularRestaurant extends StatelessWidget {
  final DineInController controller;

  const PopularRestaurant({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: controller.popularRestaurantList.length,
      itemBuilder: (BuildContext context, int index) {
        VendorModel vendorModel = controller.popularRestaurantList[index];
        return InkWell(
          onTap: () {
            Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": vendorModel});
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        child: Stack(
                          children: [
                            RestaurantImageView(vendorModel: vendorModel),
                            Container(
                              height: Responsive.height(20, context),
                              width: Responsive.width(100, context),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () async {
                                  if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                    await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                  } else {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.add(favouriteModel);
                                    await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                  }
                                },
                                child: Obx(
                                  () =>
                                      controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                          ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                          : SvgPicture.asset("assets/icons/ic_like.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(Responsive.width(-3, context), Responsive.height(17.5, context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.primary600 : AppThemeData.primary50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                      style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_map_distance.svg", colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn)),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                      style: TextStyle(color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendorModel.title.toString(),
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          style: TextStyle(fontSize: 18, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        ),
                        Text(
                          vendorModel.location.toString(),
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AllRestaurant extends StatelessWidget {
  final DineInController controller;

  const AllRestaurant({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: controller.allNearestRestaurant.length,
      itemBuilder: (BuildContext context, int index) {
        VendorModel vendorModel = controller.allNearestRestaurant[index];
        return InkWell(
          onTap: () {
            Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": vendorModel});
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        child: Stack(
                          children: [
                            RestaurantImageView(vendorModel: vendorModel),
                            Container(
                              height: Responsive.height(20, context),
                              width: Responsive.width(100, context),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () async {
                                  if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                    await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                  } else {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.add(favouriteModel);
                                    await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                  }
                                },
                                child: Obx(
                                  () =>
                                      controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                          ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                          : SvgPicture.asset("assets/icons/ic_like.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(Responsive.width(-3, context), Responsive.height(17.5, context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.primary600 : AppThemeData.primary50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                      style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_map_distance.svg", colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn)),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                      style: TextStyle(color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendorModel.title.toString(),
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          style: TextStyle(fontSize: 18, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        ),
                        Text(
                          vendorModel.location.toString(),
                          textAlign: TextAlign.start,
                          maxLines: 1,
                          style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NewArrival extends StatelessWidget {
  final DineInController controller;

  const NewArrival({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return SizedBox(
      height: Responsive.height(24, context),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: controller.newArrivalRestaurantList.length >= 10 ? 10 : controller.newArrivalRestaurantList.length,
        itemBuilder: (BuildContext context, int index) {
          VendorModel vendorModel = controller.newArrivalRestaurantList[index];
          return InkWell(
            onTap: () {
              Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": vendorModel});
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: Responsive.width(55, context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        child: Stack(
                          children: [
                            NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, height: Responsive.height(100, context), width: Responsive.width(100, context)),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: const Alignment(0.00, 1.00), end: const Alignment(0, -1), colors: [Colors.black.withOpacity(0), AppThemeData.grey900]),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () async {
                                  if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                    await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                  } else {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.add(favouriteModel);
                                    await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                  }
                                },
                                child: Obx(
                                  () =>
                                      controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                          ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                          : SvgPicture.asset("assets/icons/ic_like.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      vendorModel.title.toString(),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: TextStyle(fontSize: 16, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                    ),
                    Row(
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                            const SizedBox(width: 10),
                            Text(
                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                              textAlign: TextAlign.start,
                              maxLines: 1,
                              style: TextStyle(
                                overflow: TextOverflow.ellipsis,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Row(
                          children: [
                            SvgPicture.asset("assets/icons/ic_map_distance.svg"),
                            const SizedBox(width: 10),
                            Text(
                              "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                              textAlign: TextAlign.start,
                              maxLines: 1,
                              style: TextStyle(
                                overflow: TextOverflow.ellipsis,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      vendorModel.location.toString(),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CategoryView extends StatelessWidget {
  final DineInController controller;

  const CategoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return SizedBox(
      height: 124,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: controller.vendorCategoryModel.length,
        itemBuilder: (context, index) {
          VendorCategoryModel vendorCategoryModel = controller.vendorCategoryModel[index];
          return InkWell(
            onTap: () {
              Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": true});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 78,
                child: Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(width: 1, strokeAlign: BorderSide.strokeAlignOutside, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 60, height: 60, child: ClipOval(child: NetworkImageWidget(imageUrl: vendorCategoryModel.photo.toString(), fit: BoxFit.cover))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(
                          '${vendorCategoryModel.title}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BannerBottomView extends StatelessWidget {
  final DineInController controller;

  const BannerBottomView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: controller.pageBottomController.value,
            scrollDirection: Axis.horizontal,
            itemCount: controller.bannerBottomModel.length,
            padEnds: false,
            pageSnapping: true,
            onPageChanged: (value) {
              controller.currentBottomPage.value = value;
            },
            itemBuilder: (BuildContext context, int index) {
              BannerModel bannerModel = controller.bannerBottomModel[index];
              return InkWell(
                onTap: () async {
                  await openBanner(bannerModel);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(12)), child: NetworkImageWidget(imageUrl: bannerModel.photo.toString(), fit: BoxFit.cover)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(controller.bannerBottomModel.length, (index) {
              return Obx(
                () => Container(
                  margin: const EdgeInsets.only(right: 5),
                  alignment: Alignment.centerLeft,
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: controller.currentBottomPage.value == index ? AppThemeData.primary300 : Colors.black12),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
