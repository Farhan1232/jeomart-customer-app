import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/gift_card_controller.dart';
import 'package:customer/models/gift_cards_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/gift_card/redeem_gift_card_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/gift_card/select_gift_payment_screen.dart';
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
import '../../../themes/show_toast_dialog.dart';
import 'history_gift_card.dart';

class GiftCardScreen extends StatelessWidget {
  const GiftCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: GiftCardController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              "Customize Gift Card".tr,
              textAlign: TextAlign.start,
              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            ),
            actions: [
              InkWell(
                onTap: () {
                  Get.to(const HistoryGiftCard());
                },
                child: SvgPicture.asset("assets/icons/ic_history.svg"),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  Get.to(const RedeemGiftCardScreen());
                },
                child: SvgPicture.asset("assets/icons/ic_redeem.svg"),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: Responsive.height(22, context),
                            child: PageView.builder(
                              itemCount: controller.giftCardList.length,
                              onPageChanged: (value) {
                                controller.selectedPageIndex.value = value;
                                controller.selectedGiftCard.value = controller.giftCardList[controller.selectedPageIndex.value];

                                controller.messageController.value.text = controller.giftCardList[controller.selectedPageIndex.value].message.toString();
                              },
                              scrollDirection: Axis.horizontal,
                              controller: controller.pageController,
                              itemBuilder: (context, index) {
                                GiftCardsModel giftCardModel = controller.giftCardList[index];
                                return InkWell(
                                  onTap: () {
                                    controller.selectedGiftCard.value = giftCardModel;
                                    controller.messageController.value.text = controller.selectedGiftCard.value.message.toString();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Container(
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemeData.primary300)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: NetworkImageWidget(imageUrl: giftCardModel.image.toString(), width: Responsive.width(80, context), fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFieldWidget(
                            title: 'Choose an amount'.tr,
                            controller: controller.amountController.value,
                            hintText: 'Enter gift card amount'.tr,
                            textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                            prefix: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(
                                Constant.currencyModel!.symbol.tr,
                                style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontSize: 18),
                              ),
                            ),
                            onchange: (value) {
                              controller.selectedAmount.value = value;
                            },
                          ),
                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              itemCount: controller.amountList.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                return Obx(
                                  () => InkWell(
                                    onTap: () {
                                      controller.selectedAmount.value = controller.amountList[index];
                                      controller.amountController.value.text = controller.amountList[index];
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(Radius.circular(40)),
                                          border: Border.all(
                                            color:
                                                controller.selectedAmount == controller.amountList[index]
                                                    ? AppThemeData.primary300
                                                    : isDark
                                                    ? AppThemeData.grey400
                                                    : AppThemeData.grey200,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Center(
                                            child: Text(
                                              Constant.amountShow(amount: controller.amountList[index]),
                                              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 40),
                          TextFieldWidget(title: 'Add Message (Optional)'.tr, controller: controller.messageController.value, hintText: 'Add message here....'.tr, maxLine: 6),
                        ],
                      ),
                    ),
                  ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Continue".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  if (controller.amountController.value.text.isNotEmpty) {
                    if (Constant.userModel == null) {
                      ShowToastDialog.showToast("Please log in to the application. You are not logged in.".tr);
                    } else {
                      giftCardBottomSheet(context, controller);
                    }
                  } else {
                    ShowToastDialog.showToast("Please enter Amount".tr);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future giftCardBottomSheet(BuildContext context, GiftCardController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: 0.7,
            child: StatefulBuilder(
              builder: (context1, setState) {
                final themeController = Get.find<ThemeController>();
                final isDark = themeController.isDark.value;
                return Obx(
                  () => Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: NetworkImageWidget(imageUrl: controller.selectedGiftCard.value.image.toString(), height: Responsive.height(20, context), width: Responsive.width(100, context)),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: ShapeDecoration(color: AppThemeData.ecommerce50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: Text(
                                  'Complete payment and share this e-gift card with loved ones using any app'.tr,
                                  style: TextStyle(color: AppThemeData.ecommerce300, fontSize: 14, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Bill Details".tr,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: Responsive.width(100, context),
                                  decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Sub Total".tr,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                                              ),
                                            ),
                                            Text(
                                              Constant.amountShow(amount: controller.amountController.value.text),
                                              textAlign: TextAlign.start,
                                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Grand Total".tr,
                                                textAlign: TextAlign.start,
                                                style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 16),
                                              ),
                                            ),
                                            Text(
                                              Constant.amountShow(amount: controller.amountController.value.text),
                                              textAlign: TextAlign.start,
                                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Text(
                                "${'Gift Card expire'.tr} ${controller.selectedGiftCard.value.expiryDay} ${'days after purchase'.tr}".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey500 : AppThemeData.grey400),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    bottomNavigationBar: Container(
                      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: RoundedButtonFill(
                          title: "${'Pay'.tr} ${Constant.amountShow(amount: controller.amountController.value.text)}",
                          height: 5.5,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          fontSizes: 16,
                          onPress: () async {
                            Get.off(const SelectGiftPaymentScreen());
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}
