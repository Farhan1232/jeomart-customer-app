import 'package:customer/constant/constant.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/screen_ui/rental_service/rental_coupon_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../controllers/rental_conformation_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';

class RentalConformationScreen extends StatelessWidget {
  const RentalConformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: RentalConformationController(),
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
                    onTap: () {
                      Get.back();
                    },
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Confirm Rent a Car".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Center(child: Constant.loader())
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.asset("assets/icons/pickup.png", height: 15, width: 15),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${controller.rentalOrderModel.value.sourceLocationName}",
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                      Text(
                                        Constant.timestampToDate(controller.rentalOrderModel.value.bookingDateTime!),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Your Preference".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            controller.rentalOrderModel.value.rentalPackageModel!.name.toString(),
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            controller.rentalOrderModel.value.rentalPackageModel!.description.toString(),
                                            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      Constant.amountShow(amount: controller.rentalOrderModel.value.rentalPackageModel!.baseFare.toString()),
                                      style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Vehicle Type".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadiusGeometry.circular(10),
                                      child: NetworkImageWidget(imageUrl: controller.rentalOrderModel.value.rentalVehicleType!.rentalVehicleIcon.toString(), height: 50, width: 50, borderRadius: 10),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${controller.rentalOrderModel.value.rentalVehicleType!.name}",
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                          Text(
                                            "${controller.rentalOrderModel.value.rentalVehicleType!.shortDescription}",
                                            style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(child: Text("Coupons".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                              InkWell(
                                onTap: () {
                                  Get.to(RentalCouponScreen())!.then((value) {
                                    if (value != null) {
                                      double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: value);
                                      if (couponAmount < controller.subTotal.value) {
                                        controller.selectedCouponModel.value = value;
                                        controller.calculateAmount();
                                      } else {
                                        ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                                      }
                                    }
                                  });
                                },
                                child: Text(
                                  "View All".tr,
                                  style: AppThemeData.boldTextStyle(decoration: TextDecoration.underline, fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // Coupon input
                          DottedBorder(
                            options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(10), color: isDark ? AppThemeData.parcelServiceDark300 : AppThemeData.primary300),
                            child: Container(
                              decoration: BoxDecoration(color: AppThemeData.parcelService50, borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/icons/ic_coupon_parcel.svg", height: 28, width: 28),
                                  SizedBox(width: 15),
                                  Expanded(
                                    child: TextFormField(
                                      controller: controller.couponController.value,
                                      style: AppThemeData.semiBoldTextStyle(color: AppThemeData.grey900),
                                      decoration: InputDecoration(
                                        hintText: "Write coupon code".tr,
                                        hintStyle: AppThemeData.mediumTextStyle(fontSize: 16, color: AppThemeData.parcelService500),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  RoundedButtonFill(
                                    title: "Redeem now".tr,
                                    onPress: () {
                                      if (controller.couponList.where((element) => element.code!.toLowerCase() == controller.couponController.value.text.toLowerCase()).isNotEmpty) {
                                        CouponModel couponModel = controller.couponList.firstWhere((p0) => p0.code!.toLowerCase() == controller.couponController.value.text.toLowerCase());
                                        if (couponModel.expiresAt!.toDate().isAfter(DateTime.now())) {
                                          double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);
                                          if (couponAmount < controller.subTotal.value) {
                                            controller.selectedCouponModel.value = couponModel;
                                            controller.calculateAmount();
                                            controller.update();
                                          } else {
                                            ShowToastDialog.showToast("This offer not eligible for this booking".tr);
                                          }
                                        } else {
                                          ShowToastDialog.showToast("This coupon code has been expired".tr);
                                        }
                                      } else {
                                        ShowToastDialog.showToast("Invalid coupon code".tr);
                                      }
                                    },
                                    borderRadius: 10,
                                    height: 4,
                                    width: 28,
                                    fontSizes: 14,
                                    color: AppThemeData.primary300,
                                    textColor: AppThemeData.grey900,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Order Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey500)),
                                const SizedBox(height: 8),

                                // Subtotal
                                _summaryTile("Subtotal".tr, Constant.amountShow(amount: controller.subTotal.value.toString()), isDark, null),

                                // Discount
                                _summaryTile("Discount".tr, Constant.amountShow(amount: controller.discount.value.toString()), isDark, AppThemeData.dangerDark300),
                                if (Constant.platformFeeModel?.enable == true) _summaryTile("Platform fee".tr, Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()), isDark, null),
                                InkWell(
                                  onTap: () {
                                    showBillBifurcationDialog(context, isDark, controller);
                                  },
                                  child: _summaryTile("Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString()), isDark, null, underline: true),
                                ),

                                const Divider(),

                                // Total
                                _summaryTile("Order Total".tr, Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark, null),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          RoundedButtonFill(
                            title: "Book now".tr,
                            onPress: () {
                              controller.placeOrder();
                            },
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey900,
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
        );
      },
    );
  }

  Widget _summaryTile(String title, String value, bool isDark, Color? colors, {bool? underline}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppThemeData.mediumTextStyle(
              fontSize: 16,
              color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800,
              decoration: underline == true ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
          Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: title == "Order Total" ? 18 : 16, color: colors ?? (isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
        ],
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, RentalConformationController controller) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10), // 🔥 KEY FIX
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            width: Responsive.width(100, context), // ✅ 90% width
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10),
                  Text("Tax Details".tr, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 18, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                  const SizedBox(height: 5),
                  sectionDivider(isDark),
                  const SizedBox(height: 5),
                  amountRow(title: "Tax on Order Total".tr, amount: Constant.amountShow(amount: controller.orderTaxAmount.value.toString()), isDark: isDark),
                  sectionDivider(isDark),
                  amountRow(title: "Tax on Platform Fee".tr, amount: Constant.amountShow(amount: controller.platformTaxAmount.value.toString()), isDark: isDark),
                  sectionDivider(isDark),
                  amountRow(title: "Total Tax Amount".tr, amount: Constant.amountShow(amount: controller.taxAmount.value.toString()), amountColor: AppThemeData.primary300, isDark: isDark),
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: Text("Close".tr))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget amountRow({required String title, required String amount, required bool isDark, Color? textColour, Color? amountColor, bool? underline, Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title.tr,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: textColour ?? (isDark ? AppThemeData.grey300 : AppThemeData.grey600),
              fontSize: 16,
              decoration: underline == true ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
        trailing ?? Text(amount, style: TextStyle(fontFamily: AppThemeData.regular, color: amountColor ?? (isDark ? AppThemeData.grey50 : AppThemeData.grey900), fontSize: 16)),
      ],
    );
  }

  Widget sectionDivider(bool isDark) {
    return Column(children: [const SizedBox(height: 10), MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200), const SizedBox(height: 10)]);
  }
}
