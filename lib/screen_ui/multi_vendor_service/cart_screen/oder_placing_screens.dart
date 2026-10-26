import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dash_board_controller.dart';
import 'package:customer/controllers/dash_board_ecommarce_controller.dart';
import 'package:customer/controllers/order_placing_controller.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/screen_ui/ecommarce/dash_board_e_commerce_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../dash_board_screens/dash_board_screen.dart';

class OrderPlacingScreen extends StatelessWidget {
  const OrderPlacingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: OrderPlacingController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface, centerTitle: false, titleSpacing: 0),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : controller.isPlacing.value
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order Placed".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey900, fontSize: 34, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w400),
                        ),
                        Text(
                          "Hang tight — your items are being delivered quickly and safely!".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_location.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Order ID".tr,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  controller.orderModel.value.id.toString(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Image.asset("assets/images/ic_timer.gif", height: 140, cacheHeight: (140 * MediaQuery.devicePixelRatioOf(context)).round())),
                        const SizedBox(height: 20),
                        Text(
                          "Placing your order".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey900, fontSize: 34, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w400),
                        ),
                        Text(
                          "Take a moment to review your order before proceeding to checkout.".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_location.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Delivery Address".tr,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  controller.orderModel.value.address!.getFullAddress(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_book.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn), height: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Order Summary".tr,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: controller.orderModel.value.products!.length,
                                  itemBuilder: (context, index) {
                                    CartProductModel cartProductModel = controller.orderModel.value.products![index];
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${cartProductModel.quantity} x".tr,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                        ),
                                        Text(
                                          "${cartProductModel.name}".tr,
                                          textAlign: TextAlign.start,
                                          style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child:
                  controller.isPlacing.value
                      ? RoundedButtonFill(
                        title: "Track Order".tr,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        fontSizes: 16,
                        onPress: () async {
                          if (Constant.sectionConstantModel!.serviceTypeFlag == "ecommerce-service") {
                            Get.offAll(const DashBoardEcommerceScreen());
                            DashBoardEcommerceController controller = Get.put(DashBoardEcommerceController());
                            controller.selectedIndex.value = 3;
                          } else {
                            Get.offAll(const DashBoardScreen());
                            DashBoardController controller = Get.put(DashBoardController());
                            controller.selectedIndex.value = 3;
                          }
                        },
                      )
                      : RoundedButtonFill(
                        title: "Track Order".tr,
                        height: 5.5,
                        color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                        textColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                        fontSizes: 16,
                        onPress: () async {},
                      ),
            ),
          ),
        );
      },
    );
  }
}
