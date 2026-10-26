import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cart_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../themes/show_toast_dialog.dart';

class CouponListScreen extends StatelessWidget {
  const CouponListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CartController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text("Coupon Code".tr, textAlign: TextAlign.start, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFieldWidget(
                  hintText: 'Enter coupon code'.tr,
                  controller: controller.couponCodeController.value,
                  suffix: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: InkWell(
                      onTap: () {
                        if (controller.couponCodeController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter coupon code".tr);
                          return;
                        }
                        CouponModel? matchedCoupon = controller.couponList.firstWhereOrNull((coupon) => coupon.code!.toLowerCase() == controller.couponCodeController.value.text.toLowerCase());
                        if (matchedCoupon != null) {
                          double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: matchedCoupon);

                          if (couponAmount < controller.subTotal.value) {
                            controller.selectedCouponModel.value = matchedCoupon;
                            controller.calculatePrice();
                            Get.back();
                          } else {
                            ShowToastDialog.showToast("Coupon code not applied".tr);
                          }
                        } else {
                          ShowToastDialog.showToast("Invalid Coupon".tr);
                        }
                      },
                      child: Text(
                        "Apply".tr,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: ListView.builder(
            shrinkWrap: true,
            itemCount: controller.couponList.length,
            itemBuilder: (context, index) {
              CouponModel couponModel = controller.couponList[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  height: Responsive.height(16, context),
                  decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                        child: Stack(
                          children: [
                            Image.asset("assets/images/ic_coupon_image.png", height: Responsive.height(16, context), fit: BoxFit.fill),
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Align(
                                alignment: Alignment.center,
                                child: RotatedBox(
                                  quarterTurns: -1,
                                  child: Text(
                                    "${couponModel.discountType == "Fix Price" ? Constant.amountShow(amount: couponModel.discount) : "${couponModel.discount}%"} ${'Off'.tr}",
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  DottedBorder(
                                    options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(6), color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        "${couponModel.code}",
                                        textAlign: TextAlign.start,
                                        style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: SizedBox(height: 10)),
                                  InkWell(
                                    onTap: () {
                                      double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);

                                      if (couponAmount < controller.subTotal.value) {
                                        controller.selectedCouponModel.value = couponModel;
                                        controller.calculatePrice();
                                        Get.back();
                                      } else {
                                        ShowToastDialog.showToast("Coupon code not applied".tr);
                                      }
                                    },
                                    child: Text(
                                      "Tap To Apply".tr,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                              const SizedBox(height: 20),
                              Text(
                                "${couponModel.description}",
                                textAlign: TextAlign.start,
                                style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
