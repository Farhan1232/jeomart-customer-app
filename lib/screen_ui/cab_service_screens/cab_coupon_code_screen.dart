import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_coupon_code_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CabCouponCodeScreen extends StatelessWidget {
  const CabCouponCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabCouponCodeController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Coupon".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : controller.cabCouponList.isEmpty
                  ? Constant.showEmptyView(message: "Coupon not found".tr)
                  : ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.cabCouponList.length,
                    itemBuilder: (context, index) {
                      CouponModel couponModel = controller.cabCouponList[index];
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
                                              Get.back(result: couponModel);
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
