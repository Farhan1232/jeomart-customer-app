import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/discount_restaurant_list_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

class DiscountRestaurantListScreen extends StatelessWidget {
  const DiscountRestaurantListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: DiscountRestaurantListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              controller.title.value,
              textAlign: TextAlign.start,
              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.vendorList.length,
                      itemBuilder: (context, index) {
                        VendorModel vendorModel = controller.vendorList[index];
                        CouponModel offerModel = controller.couponList[index];
                        return InkWell(
                          onTap: () {
                            Get.to(RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Container(
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                                    child: Stack(
                                      children: [
                                        NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, height: Responsive.height(16, context), width: Responsive.width(28, context)),
                                        Container(
                                          height: Responsive.height(16, context),
                                          width: Responsive.width(28, context),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            decoration: ShapeDecoration(
                                              color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              child: Text(
                                                "${offerModel.discountType == "Fix Price" ? Constant.currencyModel!.symbol : ""}${offerModel.discount}${offerModel.discountType == "Percentage" ? "% off".toUpperCase().tr : " off".toUpperCase().tr}",
                                                textAlign: TextAlign.start,
                                                maxLines: 1,
                                                style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
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
                                              ),
                                              Row(
                                                children: [
                                                  SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                                    style: TextStyle(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.location_on, size: 18, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  vendorModel.location.toString(),
                                                  style: TextStyle(
                                                    fontFamily: AppThemeData.medium,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                    color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Container(
                                            color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                            child: DottedBorder(
                                              options: RoundedRectDottedBorderOptions(
                                                radius: const Radius.circular(6),
                                                color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                strokeWidth: 1,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                                child: Text(
                                                  "${offerModel.code}",
                                                  textAlign: TextAlign.start,
                                                  style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        );
      },
    );
  }

  // vhhv(){
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Stack(
  //         children: [
  //           ClipRRect(
  //             borderRadius: const BorderRadius.only(topLeft: Radius.circular(16),topRight:  Radius.circular(16)),
  //             child: Stack(
  //               children: [
  //                 RestaurantImageView(
  //                   vendorModel: vendorModel,
  //                 ),
  //                 Container(
  //                   height: Responsive.height(20, context),
  //                   width: Responsive.width(100, context),
  //                   decoration: BoxDecoration(
  //                     gradient: LinearGradient(
  //                       begin: const Alignment(-0.00, -1.00),
  //                       end: const Alignment(0, 1),
  //                       colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           Transform.translate(
  //             offset: Offset(Responsive.width(-3, context), Responsive.height(17.5, context)),
  //             child: Row(
  //               mainAxisAlignment: MainAxisAlignment.end,
  //               crossAxisAlignment: CrossAxisAlignment.end,
  //               children: [
  //                 Container(
  //                   decoration: ShapeDecoration(
  //                     color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
  //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
  //                   ),
  //                   child: Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //                     child: Row(
  //                       children: [
  //                         SvgPicture.asset(
  //                           "assets/icons/ic_star.svg",
  //                           colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn),
  //                         ),
  //                         const SizedBox(
  //                           width: 5,
  //                         ),
  //                         Text(
  //                           "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
  //                           style: TextStyle(
  //                             color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
  //                             fontFamily: AppThemeData.semiBold,
  //                             fontWeight: FontWeight.w600,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(
  //                   width: 10,
  //                 ),
  //                 Container(
  //                   decoration: ShapeDecoration(
  //                     color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
  //                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
  //                   ),
  //                   child: Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  //                     child: Row(
  //                       children: [
  //                         SvgPicture.asset(
  //                           "assets/icons/ic_map_distance.svg",
  //                           colorFilter: const ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn),
  //                         ),
  //                         const SizedBox(
  //                           width: 5,
  //                         ),
  //                         Text(
  //                           "${Constant.getDistance(
  //                             lat1: vendorModel.latitude.toString(),
  //                             lng1: vendorModel.longitude.toString(),
  //                             lat2: Constant.selectedLocation.location!.latitude.toString(),
  //                             lng2: Constant.selectedLocation.location!.longitude.toString(),
  //                           )} ${Constant.distanceType}",
  //                           style: TextStyle(
  //                             color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
  //                             fontFamily: AppThemeData.semiBold,
  //                             fontWeight: FontWeight.w600,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           )
  //         ],
  //       ),
  //       const SizedBox(
  //         height: 15,
  //       ),
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               vendorModel.title.toString(),
  //               textAlign: TextAlign.start,
  //               maxLines: 1,
  //               style: TextStyle(
  //                 fontSize: 18,
  //                 overflow: TextOverflow.ellipsis,
  //                 fontFamily: AppThemeData.semiBold,
  //                 color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
  //               ),
  //             ),
  //             Text(
  //               vendorModel.location.toString(),
  //               textAlign: TextAlign.start,
  //               maxLines: 1,
  //               style: TextStyle(
  //                 overflow: TextOverflow.ellipsis,
  //                 fontFamily: AppThemeData.medium,
  //                 fontWeight: FontWeight.w500,
  //                 color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
  //               ),
  //             )
  //           ],
  //         ),
  //       ),
  //       const SizedBox(
  //         height: 10,
  //       ),
  //     ],
  //   );
  // }
}
