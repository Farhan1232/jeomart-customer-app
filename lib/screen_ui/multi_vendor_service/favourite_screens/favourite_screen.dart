import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/favourite_controller.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import '../../../controllers/theme_controller.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/load_more_listener.dart';
import '../../../widget/restaurant_image_view.dart';
import '../../auth_screens/login_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

class FavouriteScreen extends StatelessWidget {
  const FavouriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: FavouriteController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Your Favourites, All in One Place".tr,
                                  style: TextStyle(fontSize: 24, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                ),
                              ),
                              //SvgPicture.asset("assets/images/ic_favourite.svg"),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child:
                              Constant.userModel == null
                                  ? Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Image.asset("assets/images/login.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round()),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Please Log In to Continue".tr,
                                          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                                        ),
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
                                  : Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Container(
                                          decoration: ShapeDecoration(
                                            color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: InkWell(
                                                    onTap: () {
                                                      controller.favouriteRestaurant.value = true;
                                                    },
                                                    child: Container(
                                                      decoration:
                                                          controller.favouriteRestaurant.value == false
                                                              ? null
                                                              : ShapeDecoration(color: AppThemeData.grey900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                        child: Text(
                                                          "Favourite Store".tr,
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
                                                      controller.favouriteRestaurant.value = false;
                                                    },
                                                    child: Container(
                                                      decoration:
                                                          controller.favouriteRestaurant.value == true
                                                              ? null
                                                              : ShapeDecoration(color: AppThemeData.grey900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                        child: Text(
                                                          "Favourite Item".tr,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontFamily: AppThemeData.semiBold,
                                                            color:
                                                                controller.favouriteRestaurant.value == true
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
                                      const SizedBox(height: 20),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 18),
                                          child:
                                              controller.favouriteRestaurant.value
                                                  ? controller.favouriteVendorList.isEmpty
                                                      ? RefreshIndicator(
                                                        onRefresh: controller.refreshFavouriteVendors,
                                                        child: ListView(
                                                          physics: const AlwaysScrollableScrollPhysics(),
                                                          children: [
                                                            SizedBox(height: Responsive.height(20, context)),
                                                            Constant.showEmptyView(message: "Favourite Store not found.".tr),
                                                          ],
                                                        ),
                                                      )
                                                      : LoadMoreListener(
                                                        onLoadMore: controller.loadMoreFavouriteVendors,
                                                        child: RefreshIndicator(
                                                        onRefresh: controller.refreshFavouriteVendors,
                                                        child: ListView.builder(
                                                        shrinkWrap: true,
                                                        padding: EdgeInsets.zero,
                                                        scrollDirection: Axis.vertical,
                                                        itemCount: controller.favouriteVendorList.length + (controller.hasMoreFavouriteVendors ? 1 : 0),
                                                        itemBuilder: (BuildContext context, int index) {
                                                          if (index >= controller.favouriteVendorList.length) {
                                                            return const LoadMoreIndicator();
                                                          }
                                                          VendorModel vendorModel = controller.favouriteVendorList[index];
                                                          return InkWell(
                                                            onTap: () {
                                                              ShowToastDialog.closeLoader();
                                                              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((value) async {
                                                                await controller.getData();
                                                              });
                                                              // Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                                                            },
                                                            child: Padding(
                                                              padding: const EdgeInsets.only(bottom: 20),
                                                              child: Container(
                                                                decoration: ShapeDecoration(
                                                                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                ),
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
                                                                                  gradient: LinearGradient(
                                                                                    begin: const Alignment(-0.00, -1.00),
                                                                                    end: const Alignment(0, 1),
                                                                                    colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Positioned(
                                                                                right: 10,
                                                                                top: 10,
                                                                                child: InkWell(
                                                                                  onTap: () async {
                                                                                    if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                                                                      FavouriteModel favouriteModel = FavouriteModel(
                                                                                        restaurantId: vendorModel.id,
                                                                                        userId: FireStoreUtils.getCurrentUid(),
                                                                                      );
                                                                                      controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                                                                      controller.favouriteVendorList.removeAt(index);
                                                                                      await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                                                                    } else {
                                                                                      FavouriteModel favouriteModel = FavouriteModel(
                                                                                        restaurantId: vendorModel.id,
                                                                                        userId: FireStoreUtils.getCurrentUid(),
                                                                                      );
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
                                                                              Visibility(
                                                                                visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                                                                                child: Row(
                                                                                  children: [
                                                                                    Container(
                                                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                                                      decoration: BoxDecoration(
                                                                                        color: AppThemeData.success300,
                                                                                        borderRadius: BorderRadius.circular(120), // Optional
                                                                                      ),
                                                                                      child: Row(
                                                                                        children: [
                                                                                          SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                                                                          const SizedBox(width: 5),
                                                                                          Text(
                                                                                            "Free Delivery".tr,
                                                                                            style: TextStyle(
                                                                                              fontSize: 14,
                                                                                              color: AppThemeData.success600,
                                                                                              fontFamily: AppThemeData.semiBold,
                                                                                              fontWeight: FontWeight.w600,
                                                                                            ),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(width: 6),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                                                decoration: ShapeDecoration(
                                                                                  color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                                                ),
                                                                                child: Row(
                                                                                  children: [
                                                                                    SvgPicture.asset(
                                                                                      "assets/icons/ic_star.svg",
                                                                                      colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
                                                                                    ),
                                                                                    const SizedBox(width: 5),
                                                                                    Text(
                                                                                      "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                                                                      style: TextStyle(
                                                                                        color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                                                        fontFamily: AppThemeData.semiBold,
                                                                                        fontWeight: FontWeight.w600,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                              const SizedBox(width: 6),
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                                                decoration: ShapeDecoration(
                                                                                  color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                                                ),
                                                                                child: Row(
                                                                                  children: [
                                                                                    SvgPicture.asset(
                                                                                      "assets/icons/ic_map_distance.svg",
                                                                                      colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn),
                                                                                    ),
                                                                                    const SizedBox(width: 5),
                                                                                    Text(
                                                                                      "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                                                                      style: TextStyle(
                                                                                        fontSize: 14,
                                                                                        color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                                                                        fontFamily: AppThemeData.semiBold,
                                                                                        fontWeight: FontWeight.w600,
                                                                                      ),
                                                                                    ),
                                                                                  ],
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
                                                                            style: TextStyle(
                                                                              fontSize: 18,
                                                                              overflow: TextOverflow.ellipsis,
                                                                              fontFamily: AppThemeData.semiBold,
                                                                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                            ),
                                                                          ),
                                                                          Text(
                                                                            vendorModel.location.toString(),
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
                                                                    ),
                                                                    const SizedBox(height: 10),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      ),
                                                      )
                                                  : controller.favouriteFoodList.isEmpty
                                                  ? RefreshIndicator(
                                                    onRefresh: controller.refreshFavouriteItems,
                                                    child: ListView(
                                                      physics: const AlwaysScrollableScrollPhysics(),
                                                      children: [
                                                        SizedBox(height: Responsive.height(20, context)),
                                                        Constant.showEmptyView(message: "Favourite Item not found.".tr),
                                                      ],
                                                    ),
                                                  )
                                                  : LoadMoreListener(
                                                    onLoadMore: controller.loadMoreFavouriteItems,
                                                    child: RefreshIndicator(
                                                    onRefresh: controller.refreshFavouriteItems,
                                                    child: ListView.builder(
                                                    itemCount: controller.favouriteFoodList.length + (controller.hasMoreFavouriteItems ? 1 : 0),
                                                    shrinkWrap: true,
                                                    padding: EdgeInsets.zero,
                                                    itemBuilder: (context, index) {
                                                      if (index >= controller.favouriteFoodList.length) {
                                                        return const LoadMoreIndicator();
                                                      }
                                                      ProductModel productModel = controller.favouriteFoodList[index];
                                                      return FutureBuilder(
                                                        future: getPrice(productModel),
                                                        builder: (context, snapshot) {
                                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                                            return Constant.loader();
                                                          } else {
                                                            if (snapshot.hasError) {
                                                              return Center(child: Text('${"error".tr}: ${snapshot.error}'));
                                                            } else if (snapshot.data == null) {
                                                              return const SizedBox();
                                                            } else {
                                                              Map<String, dynamic> map = snapshot.data!;
                                                              String price = map['price'];
                                                              String disPrice = map['disPrice'];
                                                              return InkWell(
                                                                onTap: () async {
                                                                  await FireStoreUtils.getVendorById(productModel.vendorID.toString()).then((value) {
                                                                    if (value != null) {
                                                                      ShowToastDialog.closeLoader();
                                                                      Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": value})?.then((value) async {
                                                                        await controller.getData();
                                                                      });

                                                                      // Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": value});
                                                                    }
                                                                  });
                                                                },
                                                                child: Padding(
                                                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                                                  child: Container(
                                                                    decoration: ShapeDecoration(
                                                                      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                    ),
                                                                    child: Padding(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.start,
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Expanded(
                                                                            child: Column(
                                                                              mainAxisAlignment: MainAxisAlignment.start,
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                                Row(
                                                                                  children: [
                                                                                    productModel.nonveg == true
                                                                                        ? SvgPicture.asset("assets/icons/ic_nonveg.svg")
                                                                                        : SvgPicture.asset("assets/icons/ic_veg.svg"),
                                                                                    const SizedBox(width: 5),
                                                                                    Text(
                                                                                      productModel.nonveg == true ? "Non Veg.".tr : "Pure veg.".tr,
                                                                                      style: TextStyle(
                                                                                        color: productModel.nonveg == true ? AppThemeData.danger300 : AppThemeData.success400,
                                                                                        fontFamily: AppThemeData.semiBold,
                                                                                        fontWeight: FontWeight.w600,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                const SizedBox(height: 5),
                                                                                Text(
                                                                                  productModel.name.toString(),
                                                                                  style: TextStyle(
                                                                                    fontSize: 18,
                                                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                                    fontFamily: AppThemeData.semiBold,
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                                double.parse(disPrice) <= 0
                                                                                    ? Text(
                                                                                      Constant.amountShow(amount: price),
                                                                                      style: TextStyle(
                                                                                        fontSize: 16,
                                                                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                                        fontFamily: AppThemeData.semiBold,
                                                                                        fontWeight: FontWeight.w600,
                                                                                      ),
                                                                                    )
                                                                                    : Row(
                                                                                      children: [
                                                                                        Text(
                                                                                          Constant.amountShow(amount: disPrice),
                                                                                          style: TextStyle(
                                                                                            fontSize: 16,
                                                                                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                                            fontFamily: AppThemeData.semiBold,
                                                                                            fontWeight: FontWeight.w600,
                                                                                          ),
                                                                                        ),
                                                                                        const SizedBox(width: 5),
                                                                                        Text(
                                                                                          Constant.amountShow(amount: price),
                                                                                          style: TextStyle(
                                                                                            fontSize: 14,
                                                                                            decoration: TextDecoration.lineThrough,
                                                                                            decorationColor: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                                                            color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                                                            fontFamily: AppThemeData.semiBold,
                                                                                            fontWeight: FontWeight.w600,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                Row(
                                                                                  children: [
                                                                                    SvgPicture.asset(
                                                                                      "assets/icons/ic_star.svg",
                                                                                      colorFilter: const ColorFilter.mode(AppThemeData.warning300, BlendMode.srcIn),
                                                                                    ),
                                                                                    const SizedBox(width: 5),
                                                                                    Text(
                                                                                      "${Constant.calculateReview(reviewCount: productModel.reviewsCount!.toStringAsFixed(0), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsCount!.toStringAsFixed(0)})",
                                                                                      style: TextStyle(
                                                                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                                        fontFamily: AppThemeData.regular,
                                                                                        fontWeight: FontWeight.w500,
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                                Text(
                                                                                  "${productModel.description}",
                                                                                  maxLines: 2,
                                                                                  style: TextStyle(
                                                                                    overflow: TextOverflow.ellipsis,
                                                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                                    fontFamily: AppThemeData.regular,
                                                                                    fontWeight: FontWeight.w400,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          const SizedBox(width: 6),
                                                                          ClipRRect(
                                                                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                                                                            child: Stack(
                                                                              children: [
                                                                                NetworkImageWidget(
                                                                                  imageUrl: productModel.photo.toString(),
                                                                                  fit: BoxFit.cover,
                                                                                  height: Responsive.height(16, context),
                                                                                  width: Responsive.width(34, context),
                                                                                ),
                                                                                Container(
                                                                                  height: Responsive.height(16, context),
                                                                                  width: Responsive.width(34, context),
                                                                                  decoration: BoxDecoration(
                                                                                    gradient: LinearGradient(
                                                                                      begin: const Alignment(-0.00, -1.00),
                                                                                      end: const Alignment(0, 1),
                                                                                      colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                Positioned(
                                                                                  right: 10,
                                                                                  top: 10,
                                                                                  child: InkWell(
                                                                                    onTap: () async {
                                                                                      if (controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty) {
                                                                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                                                                          productId: productModel.id,
                                                                                          storeId: productModel.vendorID,
                                                                                          userId: FireStoreUtils.getCurrentUid(),
                                                                                        );
                                                                                        controller.favouriteItemList.removeWhere((item) => item.productId == productModel.id);
                                                                                        controller.favouriteFoodList.removeAt(index);
                                                                                        await FireStoreUtils.removeFavouriteItem(favouriteModel);
                                                                                      } else {
                                                                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                                                                          productId: productModel.id,
                                                                                          storeId: productModel.vendorID,
                                                                                          userId: FireStoreUtils.getCurrentUid(),
                                                                                        );
                                                                                        controller.favouriteItemList.add(favouriteModel);
                                                                                        await FireStoreUtils.setFavouriteItem(favouriteModel);
                                                                                      }
                                                                                    },
                                                                                    child: Obx(
                                                                                      () =>
                                                                                          controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty
                                                                                              ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                                                                              : SvgPicture.asset("assets/icons/ic_like.svg"),
                                                                                    ),
                                                                                  ),
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
                                                            }
                                                          }
                                                        },
                                                      );
                                                    },
                                                  ),
                                        ),
                                                  ),
                                                  ),
                                      ),
                                    ],
                                  ),
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> getPrice(ProductModel productModel) async {
    String price = "0.0";
    String disPrice = "0.0";
    List<String> selectedVariants = [];
    List<String> selectedIndexVariants = [];
    List<String> selectedIndexArray = [];

    print("=======>");
    print(productModel.price);
    print(productModel.disPrice);

    VendorModel? vendorModel = await FireStoreUtils.getVendorById(productModel.vendorID.toString());
    if (productModel.itemAttribute != null) {
      if (productModel.itemAttribute!.attributes!.isNotEmpty) {
        for (var element in productModel.itemAttribute!.attributes!) {
          if (element.attributeOptions!.isNotEmpty) {
            selectedVariants.add(productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString());
            selectedIndexVariants.add('${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}');
            selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
          }
        }
      }
      if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
        price = Constant.productCommissionPrice(vendorModel!, productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0');
        disPrice = Constant.productCommissionPrice(vendorModel, '0');
      }
    } else {
      price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
      disPrice = Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
    }

    return {'price': price, 'disPrice': disPrice};
  }
}
