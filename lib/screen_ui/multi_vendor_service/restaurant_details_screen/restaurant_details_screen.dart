import 'package:badges/badges.dart' as badges;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/restaurant_details_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../cart_screen/cart_screen.dart';
import '../dine_in_screeen/dine_in_details_screen.dart';
import '../review_list_screen/review_list_screen.dart';

class RestaurantDetailsScreen extends StatelessWidget {
  const RestaurantDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: RestaurantDetailsController(),
      autoRemove: false,
      builder: (controller) {
        return Scaffold(
          bottomNavigationBar:
              cartItem.isEmpty
                  ? null
                  : InkWell(
                    onTap: () {
                      Get.to(const CartScreen());
                    },
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(color: AppThemeData.primary300),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${cartItem.length} ${"items".tr}', style: TextStyle(fontFamily: AppThemeData.medium, color: AppThemeData.grey50, fontSize: 16)),
                          Text('View Cart'.tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: AppThemeData.grey50, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
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
                      Visibility(
                        visible: (controller.vendorModel.value.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppThemeData.primary300,
                                borderRadius: BorderRadius.circular(120), // Optional
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                  const SizedBox(width: 5),
                                  Text("Free Delivery".tr, style: TextStyle(fontSize: 14, color: AppThemeData.carRent600, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
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
                      const SizedBox(width: 10),
                      Obx(
                        () => badges.Badge(
                          showBadge: cartItem.isEmpty ? false : true,
                          badgeContent: Text(
                            "${cartItem.length}",
                            style: TextStyle(
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                              fontFamily: AppThemeData.semiBold,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                            ),
                          ),
                          badgeStyle: badges.BadgeStyle(shape: badges.BadgeShape.circle, badgeColor: AppThemeData.ecommerce300),
                          child: InkWell(
                            onTap: () {
                              Get.to(const CartScreen());
                            },
                            child: ClipOval(
                              child: SvgPicture.asset("assets/icons/ic_shoping_cart.svg", width: 24, height: 24, colorFilter: const ColorFilter.mode(AppThemeData.grey50, BlendMode.srcIn)),
                            ),
                          ),
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
                              allowImplicitScrolling: true,
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
                                                      reviewCount: controller.vendorModel.value.reviewsCount.toString(),
                                                      reviewSum: controller.vendorModel.value.reviewsSum.toString(),
                                                    ),
                                                    style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
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
                                  Constant.sectionConstantModel!.serviceTypeFlag == "ecommerce-service"
                                      ? SizedBox()
                                      : Row(
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
                                              if (controller.vendorModel.value.workingHours!.isEmpty) {
                                                ShowToastDialog.showToast("Timing is not added by store".tr);
                                              } else {
                                                timeShowBottomSheet(context, controller);
                                              }
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
                                        ],
                                      ),
                                  controller.vendorModel.value.dineInActive == true || (controller.vendorModel.value.openDineTime != null && controller.vendorModel.value.openDineTime!.isNotEmpty)
                                      ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          Text(
                                            "Also applicable on table booking".tr,
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
                                              Get.to(const DineInDetailsScreen(), arguments: {"vendorModel": controller.vendorModel.value});
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
                                                    Image.asset("assets/images/ic_table.gif", cacheHeight: (60 * MediaQuery.devicePixelRatioOf(context)).round()),
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
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                      : const SizedBox(),
                                  controller.couponList.isEmpty
                                      ? const SizedBox()
                                      : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 20),
                                          Text(
                                            "Additional Offers".tr,
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
                                          CouponListView(controller: controller),
                                        ],
                                      ),
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
                                  const SizedBox(height: 10),
                                  TextFieldWidget(
                                    controller: controller.searchEditingController.value,
                                    hintText: 'Search the item and more...'.tr,
                                    onchange: (value) {
                                      controller.searchProduct(value);
                                    },
                                    prefix: Padding(padding: const EdgeInsets.all(12), child: SvgPicture.asset("assets/icons/ic_search.svg")),
                                  ),
                                  const SizedBox(height: 10),
                                  Constant.sectionConstantModel!.isProductDetails == false
                                      ? SizedBox()
                                      : Row(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (controller.isVag.value == true) {
                                                controller.isVag.value = false;
                                              } else {
                                                controller.isVag.value = true;
                                              }
                                              controller.filterRecord();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration:
                                                  controller.isVag.value
                                                      ? ShapeDecoration(
                                                        color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                        shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: AppThemeData.primary300), borderRadius: BorderRadius.circular(120)),
                                                      )
                                                      : ShapeDecoration(
                                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                        shape: RoundedRectangleBorder(
                                                          side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                          borderRadius: BorderRadius.circular(120),
                                                        ),
                                                      ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset("assets/icons/ic_veg.svg", height: 20, width: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Veg'.tr,
                                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          InkWell(
                                            onTap: () {
                                              if (controller.isNonVag.value == true) {
                                                controller.isNonVag.value = false;
                                              } else {
                                                controller.isNonVag.value = true;
                                              }
                                              controller.filterRecord();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration:
                                                  controller.isNonVag.value
                                                      ? ShapeDecoration(
                                                        color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                        shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: AppThemeData.primary300), borderRadius: BorderRadius.circular(120)),
                                                      )
                                                      : ShapeDecoration(
                                                        color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                                        shape: RoundedRectangleBorder(
                                                          side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                          borderRadius: BorderRadius.circular(120),
                                                        ),
                                                      ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset("assets/icons/ic_nonveg.svg", height: 20, width: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Non Veg'.tr,
                                                    style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ProductListView(controller: controller),
                          ],
                        ),
                      ),
                    ),
          ),
          // floatingActionButton: PopupMenuButton(
          //   offset: const Offset(0, -260),
          //   onOpened: () {
          //     controller.isMenuOpen.value = true;
          //   },
          //   onCanceled: () {
          //     controller.isMenuOpen.value = false;
          //   },
          //   onSelected: (value) {
          //     controller.isMenuOpen.value = false;
          //   },
          //   color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          //   shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
          //   itemBuilder: (context) {
          //     return List.generate(controller.vendorCategoryList.length, (index) {
          //       VendorCategoryModel vendorCategoryModel = controller.vendorCategoryList[index];
          //       return PopupMenuItem(
          //         value: index,
          //         onTap: () {},
          //         child: SizedBox(
          //           width: 230,
          //           child: Text(
          //             vendorCategoryModel.title.toString(),
          //             textAlign: TextAlign.start,
          //             maxLines: 1,
          //             style: TextStyle(
          //               fontSize: 14,
          //               overflow: TextOverflow.ellipsis,
          //               fontFamily: AppThemeData.semiBold,
          //               fontWeight: FontWeight.w600,
          //               color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
          //             ),
          //           ),
          //         ),
          //       );
          //     });
          //   },
          //   child: Container(
          //     width: 60,
          //     height: 60,
          //     padding: const EdgeInsets.all(10),
          //     decoration: ShapeDecoration(
          //       color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(120),
          //       ),
          //     ),
          //     child: controller.isMenuOpen.value
          //         ? Icon(
          //             Icons.close,
          //             color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          //           )
          //         : Column(
          //             mainAxisSize: MainAxisSize.min,
          //             mainAxisAlignment: MainAxisAlignment.center,
          //             crossAxisAlignment: CrossAxisAlignment.center,
          //             children: [
          //               SvgPicture.asset("assets/icons/ic_book.svg"),
          //               Text(
          //                 "Menu",
          //                 textAlign: TextAlign.start,
          //                 maxLines: 1,
          //                 style: TextStyle(
          //                   fontSize: 12,
          //                   overflow: TextOverflow.ellipsis,
          //                   fontFamily: AppThemeData.medium,
          //                   fontWeight: FontWeight.w500,
          //                   color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          //                 ),
          //               ),
          //             ],
          //           ),
          //   ),
          // ),
        );
      },
    );
  }

  Future timeShowBottomSheet(BuildContext context, RestaurantDetailsController productModel) {
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

class CouponListView extends StatelessWidget {
  final RestaurantDetailsController controller;

  const CouponListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return SizedBox(
      height: Responsive.height(9, context),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.couponList.length,
        itemBuilder: (BuildContext context, int index) {
          CouponModel offerModel = controller.couponList[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100), borderRadius: BorderRadius.circular(16)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: SizedBox(
                  width: Responsive.width(80, context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        // Decoded near badge size. The GIF is 2000x2000, so every
                        // frame used to be decoded to a 16 MB bitmap for a badge
                        // 60 points wide.
                        decoration: BoxDecoration(image: DecorationImage(image: ResizeImage(const AssetImage("assets/images/offer_gif.gif"), width: (120 * MediaQuery.devicePixelRatioOf(context)).round()), fit: BoxFit.fill)),
                        child: Center(
                          child: Text(
                            offerModel.discountType == "Fix Price" ? Constant.amountShow(amount: offerModel.discount) : "${offerModel.discount}%",
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offerModel.description.toString(),
                            style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: offerModel.code.toString())).then((value) {
                                ShowToastDialog.showToast("Copied".tr);
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  offerModel.code.toString(),
                                  style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 5),
                                SvgPicture.asset("assets/icons/ic_copy.svg"),
                                const SizedBox(height: 10, child: VerticalDivider()),
                                const SizedBox(width: 5),
                                Text(
                                  Constant.timestampToDateTime(offerModel.expiresAt!),
                                  style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class ProductListView extends StatelessWidget {
  final RestaurantDetailsController controller;

  const ProductListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: controller.vendorCategoryList.length,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          VendorCategoryModel vendorCategoryModel = controller.vendorCategoryList[index];
          return ExpansionTile(
            childrenPadding: EdgeInsets.zero,
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            initiallyExpanded: true,
            title: Text(
              "${vendorCategoryModel.title.toString()} (${controller.productList.where((p0) => p0.categoryID == vendorCategoryModel.id).toList().length})",
              style: TextStyle(fontSize: 18, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            ),
            children: [
              Obx(
                () => ListView.builder(
                  itemCount: controller.productList.where((p0) => p0.categoryID == vendorCategoryModel.id).toList().length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    ProductModel productModel = controller.productList.where((p0) => p0.categoryID == vendorCategoryModel.id).toList()[index];

                    String price = "0.0";
                    String disPrice = "0.0";
                    List<String> selectedVariants = [];
                    List<String> selectedIndexVariants = [];
                    List<String> selectedIndexArray = [];
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
                        price = Constant.productCommissionPrice(
                          controller.vendorModel.value,
                          productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0',
                        );
                        disPrice = "0";
                      }
                    } else {
                      price = Constant.productCommissionPrice(controller.vendorModel.value, productModel.price.toString());
                      disPrice = double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(controller.vendorModel.value, productModel.disPrice.toString());
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Constant.sectionConstantModel!.isProductDetails == false
                                    ? SizedBox()
                                    : Row(
                                      children: [
                                        productModel.nonveg == true ? SvgPicture.asset("assets/icons/ic_nonveg.svg") : SvgPicture.asset("assets/icons/ic_veg.svg"),
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
                                  style: TextStyle(fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                ),
                                double.parse(disPrice) <= 0
                                    ? Text(
                                      Constant.amountShow(amount: price),
                                      style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                    )
                                    : Row(
                                      children: [
                                        Text(
                                          Constant.amountShow(amount: disPrice),
                                          style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
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
                                    SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: const ColorFilter.mode(AppThemeData.warning300, BlendMode.srcIn)),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${Constant.calculateReview(reviewCount: productModel.reviewsCount!.toStringAsFixed(0), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsCount!.toStringAsFixed(0)})",
                                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
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
                                const SizedBox(height: 5),
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return infoDialog(controller, isDark, productModel);
                                      },
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.info, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Info".tr,
                                        maxLines: 2,
                                        style: TextStyle(
                                          overflow: TextOverflow.ellipsis,
                                          fontSize: 16,
                                          color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                          fontFamily: AppThemeData.regular,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                            child: Stack(
                              children: [
                                NetworkImageWidget(imageUrl: productModel.photo.toString(), fit: BoxFit.cover, height: Responsive.height(16, context), width: Responsive.width(34, context)),
                                Container(
                                  height: Responsive.height(16, context),
                                  width: Responsive.width(34, context),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
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
                                          storeId: controller.vendorModel.value.id,
                                          userId: FireStoreUtils.getCurrentUid(),
                                        );
                                        controller.favouriteItemList.removeWhere((item) => item.productId == productModel.id);
                                        await FireStoreUtils.removeFavouriteItem(favouriteModel);
                                      } else {
                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                          productId: productModel.id,
                                          storeId: controller.vendorModel.value.id,
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
                                controller.isOpen.value == false
                                    ? const SizedBox()
                                    : Positioned(
                                      bottom: 10,
                                      left: 20,
                                      right: 20,
                                      child:
                                          selectedVariants.isNotEmpty || (productModel.addOnsTitle != null && productModel.addOnsTitle!.isNotEmpty)
                                              ? RoundedButtonFill(
                                                title: "Add".tr,
                                                width: 10,
                                                height: 4,
                                                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                textColor: AppThemeData.primary300,
                                                onPress: () async {
                                                  if (!Constant.requireLogin()) return;
                                                  controller.selectedVariants.clear();
                                                  controller.selectedIndexVariants.clear();
                                                  controller.selectedIndexArray.clear();
                                                  controller.selectedAddOns.clear();
                                                  controller.quantity.value = 1;
                                                  if (productModel.itemAttribute != null) {
                                                    if (productModel.itemAttribute!.attributes!.isNotEmpty) {
                                                      for (var element in productModel.itemAttribute!.attributes!) {
                                                        if (element.attributeOptions!.isNotEmpty) {
                                                          controller.selectedVariants.add(
                                                            productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString(),
                                                          );
                                                          controller.selectedIndexVariants.add(
                                                            '${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}',
                                                          );
                                                          controller.selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
                                                        }
                                                      }
                                                    }
                                                    final bool productIsInList = cartItem.any(
                                                      (product) =>
                                                          product.id ==
                                                          "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}",
                                                    );

                                                    if (productIsInList) {
                                                      CartProductModel element = cartItem.firstWhere(
                                                        (product) =>
                                                            product.id ==
                                                            "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}",
                                                      );
                                                      controller.quantity.value = element.quantity!;
                                                      if (element.extras != null) {
                                                        for (var element in element.extras!) {
                                                          controller.selectedAddOns.add(element);
                                                        }
                                                      }
                                                    }
                                                  } else {
                                                    if (cartItem.where((product) => product.id == "${productModel.id}").isNotEmpty) {
                                                      CartProductModel element = cartItem.firstWhere((product) => product.id == "${productModel.id}");
                                                      controller.quantity.value = element.quantity!;
                                                      if (element.extras != null) {
                                                        for (var element in element.extras!) {
                                                          controller.selectedAddOns.add(element);
                                                        }
                                                      }
                                                    }
                                                  }
                                                  controller.update();
                                                  controller.calculatePrice(productModel);
                                                  productDetailsBottomSheet(context, productModel);
                                                },
                                              )
                                              : Obx(
                                                () =>
                                                    cartItem.where((p0) => p0.id == productModel.id).isNotEmpty
                                                        ? Container(
                                                          width: Responsive.width(100, context),
                                                          height: Responsive.height(4, context),
                                                          decoration: ShapeDecoration(
                                                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(200)),
                                                          ),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              InkWell(
                                                                onTap: () {
                                                                  controller.addToCart(
                                                                    productModel: productModel,
                                                                    price: price,
                                                                    discountPrice: disPrice,
                                                                    isIncrement: false,
                                                                    quantity: cartItem.where((p0) => p0.id == productModel.id).first.quantity! - 1,
                                                                  );
                                                                },
                                                                child: Icon(Icons.remove, color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50),
                                                              ),
                                                              Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                                                child: Text(
                                                                  cartItem.where((p0) => p0.id == productModel.id).first.quantity.toString(),
                                                                  textAlign: TextAlign.start,
                                                                  maxLines: 1,
                                                                  style: TextStyle(
                                                                    fontSize: 16,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    fontFamily: AppThemeData.medium,
                                                                    fontWeight: FontWeight.w500,
                                                                    color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                                                  ),
                                                                ),
                                                              ),
                                                              InkWell(
                                                                onTap: () {
                                                                  if ((cartItem.where((p0) => p0.id == productModel.id).first.quantity ?? 0) < (productModel.quantity ?? 0) ||
                                                                      (productModel.quantity ?? 0) == -1) {
                                                                    controller.addToCart(
                                                                      productModel: productModel,
                                                                      price: price,
                                                                      discountPrice: disPrice,
                                                                      isIncrement: true,
                                                                      quantity: cartItem.where((p0) => p0.id == productModel.id).first.quantity! + 1,
                                                                    );
                                                                  } else {
                                                                    ShowToastDialog.showToast("Out of stock".tr);
                                                                  }
                                                                },
                                                                child: Icon(Icons.add, color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                        : RoundedButtonFill(
                                                          title: "Add".tr,
                                                          width: 10,
                                                          height: 4,
                                                          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                          textColor: AppThemeData.primary300,
                                                          onPress: () async {
                                                            if (!Constant.requireLogin()) return;
                                                            if (1 <= (productModel.quantity ?? 0) || (productModel.quantity ?? 0) == -1) {
                                                              controller.addToCart(productModel: productModel, price: price, discountPrice: disPrice, isIncrement: true, quantity: 1);
                                                            } else {
                                                              ShowToastDialog.showToast("Out of stock".tr);
                                                            }
                                                          },
                                                        ),
                                              ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future productDetailsBottomSheet(BuildContext context, ProductModel productModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: 0.85,
            child: StatefulBuilder(
              builder: (context1, setState) {
                return ProductDetailsView(productModel: productModel);
              },
            ),
          ),
    );
  }

  Dialog infoDialog(RestaurantDetailsController controller, isDark, ProductModel productModel) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Product Information's".tr,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontFamily: AppThemeData.bold, fontWeight: FontWeight.w700, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                      ),
                      Text(
                        productModel.description.toString(),
                        textAlign: TextAlign.start,
                        style: TextStyle(fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                      ),
                    ],
                  ),
                ),
                productModel.grams == 0 && Constant.sectionConstantModel!.isProductDetails == false
                    ? SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Gram".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                            ),
                          ),
                          Text(
                            productModel.grams.toString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                productModel.calories == 0 && Constant.sectionConstantModel!.isProductDetails == false
                    ? SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Calories".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                            ),
                          ),
                          Text(
                            productModel.calories.toString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                productModel.proteins == 0 && Constant.sectionConstantModel!.isProductDetails == false
                    ? SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Proteins".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                            ),
                          ),
                          Text(
                            productModel.proteins.toString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                productModel.fats == 0 && Constant.sectionConstantModel!.isProductDetails == false
                    ? SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              "Fats".tr,
                              textAlign: TextAlign.start,
                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                            ),
                          ),
                          Text(
                            productModel.fats.toString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                        ],
                      ),
                    ),

                productModel.productSpecification != null && productModel.productSpecification!.isNotEmpty
                    ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Specification".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w700, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          ListView.builder(
                            itemCount: productModel.productSpecification!.length,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productModel.productSpecification!.keys.elementAt(index),
                                      textAlign: TextAlign.start,
                                      style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                                    ),
                                    Text(
                                      productModel.productSpecification!.values.elementAt(index),
                                      textAlign: TextAlign.start,
                                      style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                    : const SizedBox(),

                productModel.brandId != null && productModel.brandId!.isNotEmpty
                    ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Brand".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontWeight: FontWeight.w700, fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                          SizedBox(height: 5),
                          Text(
                            controller.getBrandName(productModel.brandId!),
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox(),
                const SizedBox(height: 20),
                RoundedButtonFill(
                  title: "Back".tr,
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey50,
                  onPress: () async {
                    Get.back();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProductDetailsView extends StatelessWidget {
  final ProductModel productModel;

  const ProductDetailsView({super.key, required this.productModel});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: RestaurantDetailsController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                          child: Stack(
                            children: [
                              NetworkImageWidget(imageUrl: productModel.photo.toString(), height: Responsive.height(11, context), width: Responsive.width(22, context), fit: BoxFit.cover),
                              Container(
                                height: Responsive.height(11, context),
                                width: Responsive.width(22, context),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      productModel.name.toString(),
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
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      if (controller.favouriteItemList.where((p0) => p0.productId == productModel.id).isNotEmpty) {
                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                          productId: productModel.id,
                                          storeId: controller.vendorModel.value.id,
                                          userId: FireStoreUtils.getCurrentUid(),
                                        );
                                        controller.favouriteItemList.removeWhere((item) => item.productId == productModel.id);
                                        await FireStoreUtils.removeFavouriteItem(favouriteModel);
                                      } else {
                                        FavouriteItemModel favouriteModel = FavouriteItemModel(
                                          productId: productModel.id,
                                          storeId: controller.vendorModel.value.id,
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
                                              : SvgPicture.asset("assets/icons/ic_like.svg", colorFilter: const ColorFilter.mode(AppThemeData.grey500, BlendMode.srcIn)),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                productModel.description.toString(),
                                textAlign: TextAlign.start,
                                style: TextStyle(fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                productModel.itemAttribute == null || productModel.itemAttribute!.attributes!.isEmpty
                    ? const SizedBox()
                    : ListView.builder(
                      itemCount: productModel.itemAttribute!.attributes!.length,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        String title = "";
                        for (var element in controller.attributesList) {
                          if (productModel.itemAttribute!.attributes![index].attributeId == element.id) {
                            title = element.title.toString();
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: Container(
                            decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  productModel.itemAttribute!.attributes![index].attributeOptions!.isNotEmpty
                                      ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(
                                              "Required • Select any 1 option".tr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.medium,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                              ),
                                            ),
                                          ),
                                          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                                        ],
                                      )
                                      : Offstage(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Wrap(
                                      spacing: 6.0,
                                      runSpacing: 6.0,
                                      children:
                                          List.generate(productModel.itemAttribute!.attributes![index].attributeOptions!.length, (i) {
                                            return InkWell(
                                              onTap: () async {
                                                if (controller.selectedIndexVariants.where((element) => element.contains('$index _')).isEmpty) {
                                                  controller.selectedVariants.insert(index, productModel.itemAttribute!.attributes![index].attributeOptions![i].toString());
                                                  controller.selectedIndexVariants.add('$index _${productModel.itemAttribute!.attributes![index].attributeOptions![i].toString()}');
                                                  controller.selectedIndexArray.add('${index}_$i');
                                                } else {
                                                  controller.selectedIndexArray.remove(
                                                    '${index}_${productModel.itemAttribute!.attributes![index].attributeOptions?.indexOf(controller.selectedIndexVariants.where((element) => element.contains('$index _')).first.replaceAll('$index _', ''))}',
                                                  );
                                                  controller.selectedVariants.removeAt(index);
                                                  controller.selectedIndexVariants.remove(controller.selectedIndexVariants.where((element) => element.contains('$index _')).first);
                                                  controller.selectedVariants.insert(index, productModel.itemAttribute!.attributes![index].attributeOptions![i].toString());
                                                  controller.selectedIndexVariants.add('$index _${productModel.itemAttribute!.attributes![index].attributeOptions![i].toString()}');
                                                  controller.selectedIndexArray.add('${index}_$i');
                                                }

                                                final bool productIsInList = cartItem.any(
                                                  (product) =>
                                                      product.id ==
                                                      "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}",
                                                );
                                                if (productIsInList) {
                                                  CartProductModel element = cartItem.firstWhere(
                                                    (product) =>
                                                        product.id ==
                                                        "${productModel.id}~${productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).isNotEmpty ? productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantId.toString() : ""}",
                                                  );
                                                  controller.quantity.value = element.quantity!;
                                                } else {
                                                  controller.quantity.value = 1;
                                                }

                                                controller.update();
                                                controller.calculatePrice(productModel);
                                              },
                                              child: Chip(
                                                shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.transparent), borderRadius: BorderRadius.all(Radius.circular(20))),
                                                label: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      productModel.itemAttribute!.attributes![index].attributeOptions![i].toString(),
                                                      style: TextStyle(
                                                        overflow: TextOverflow.ellipsis,
                                                        fontFamily: AppThemeData.medium,
                                                        fontWeight: FontWeight.w500,
                                                        color:
                                                            controller.selectedVariants.contains(productModel.itemAttribute!.attributes![index].attributeOptions![i].toString())
                                                                ? Colors.white
                                                                : isDark
                                                                ? AppThemeData.greyDark800
                                                                : AppThemeData.grey800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor:
                                                    controller.selectedVariants.contains(productModel.itemAttribute!.attributes![index].attributeOptions![i].toString())
                                                        ? AppThemeData.primary300
                                                        : isDark
                                                        ? AppThemeData.grey800
                                                        : AppThemeData.grey100,
                                                elevation: 6.0,
                                                padding: const EdgeInsets.all(8.0),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                productModel.addOnsTitle == null || productModel.addOnsTitle!.isEmpty
                    ? const SizedBox()
                    : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      child: Container(
                        decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  "Addons".tr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    overflow: TextOverflow.ellipsis,
                                    fontFamily: AppThemeData.semiBold,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                  ),
                                ),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                              ListView.builder(
                                itemCount: productModel.addOnsTitle!.length,
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  String title = productModel.addOnsTitle![index];
                                  String price = productModel.addOnsPrice![index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            textAlign: TextAlign.start,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 16,
                                              overflow: TextOverflow.ellipsis,
                                              fontFamily: AppThemeData.medium,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          Constant.amountShow(amount: Constant.productCommissionPrice(controller.vendorModel.value, price)),
                                          textAlign: TextAlign.start,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 16,
                                            overflow: TextOverflow.ellipsis,
                                            fontFamily: AppThemeData.medium,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Obx(
                                          () => SizedBox(
                                            height: 24.0,
                                            width: 24.0,
                                            child: Checkbox(
                                              value: controller.selectedAddOns.contains(title),
                                              activeColor: AppThemeData.primary300,
                                              onChanged: (value) {
                                                if (value != null) {
                                                  if (value == true) {
                                                    controller.selectedAddOns.add(title);
                                                  } else {
                                                    controller.selectedAddOns.remove(title);
                                                  }
                                                  controller.update();
                                                }
                                              },
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
                        ),
                      ),
                    ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      width: Responsive.width(100, context),
                      height: Responsive.height(5.5, context),
                      decoration: ShapeDecoration(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(200))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              if (controller.quantity.value > 1) {
                                controller.quantity.value -= 1;
                                controller.update();
                              }
                            },
                            child: Icon(Icons.remove, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              controller.quantity.value.toString(),
                              textAlign: TextAlign.start,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 16,
                                overflow: TextOverflow.ellipsis,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              if (productModel.itemAttribute == null) {
                                if (controller.quantity.value < (productModel.quantity ?? 0) || (productModel.quantity ?? 0) == -1) {
                                  controller.quantity.value += 1;
                                  controller.update();
                                } else {
                                  ShowToastDialog.showToast("Out of stock".tr);
                                }
                              } else {
                                int totalQuantity = int.parse(
                                  productModel.itemAttribute!.variants!.where((element) => element.variantSku == controller.selectedVariants.join('-')).first.variantQuantity.toString(),
                                );
                                if (controller.quantity.value < totalQuantity || totalQuantity == -1) {
                                  controller.quantity.value += 1;
                                  controller.update();
                                } else {
                                  ShowToastDialog.showToast("Out of stock".tr);
                                }
                              }
                            },
                            child: Icon(Icons.add, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: RoundedButtonFill(
                      title: "${'Add item'.tr} ${Constant.amountShow(amount: controller.calculatePrice(productModel))}".tr,
                      height: 5.5,
                      color: AppThemeData.primary300,
                      textColor: AppThemeData.grey50,
                      fontSizes: 16,
                      onPress: () async {
                        if (productModel.itemAttribute == null) {
                          await controller.addToCart(
                            productModel: productModel,
                            price: Constant.productCommissionPrice(controller.vendorModel.value, productModel.price.toString()),
                            discountPrice: double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(controller.vendorModel.value, productModel.disPrice.toString()),
                            isIncrement: true,
                            quantity: controller.quantity.value,
                          );
                        } else {
                          String variantPrice = "0";
                          if (productModel.itemAttribute!.variants!.any((e) => e.variantSku == controller.selectedVariants.join('-'))) {
                            variantPrice = Constant.productCommissionPrice(
                              controller.vendorModel.value,
                              productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantPrice ?? '0',
                            );
                          }

                          Map<String, String> mapData = {};
                          for (var element in productModel.itemAttribute!.attributes!) {
                            mapData.addEntries([
                              MapEntry(
                                controller.attributesList.firstWhere((e) => e.id == element.attributeId).title.toString(),
                                controller.selectedVariants[productModel.itemAttribute!.attributes!.indexOf(element)],
                              ),
                            ]);
                          }

                          VariantInfo variantInfo = VariantInfo(
                            variantPrice: productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantPrice ?? '0',
                            variantSku: controller.selectedVariants.join('-'),
                            variantOptions: mapData,
                            variantImage: productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantImage ?? '',
                            variantId: productModel.itemAttribute!.variants!.firstWhere((e) => e.variantSku == controller.selectedVariants.join('-')).variantId ?? '0',
                          );

                          await controller.addToCart(
                            productModel: productModel,
                            price: variantPrice,
                            discountPrice: "0",
                            isIncrement: true,
                            variantInfo: variantInfo,
                            quantity: controller.quantity.value,
                          );
                        }
                        controller.update();
                        Get.back();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
