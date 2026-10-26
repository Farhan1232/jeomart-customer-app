import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/history_gift_card_controller.dart';
import 'package:customer/models/gift_cards_order_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../widget/my_separator.dart';

class HistoryGiftCard extends StatelessWidget {
  const HistoryGiftCard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: HistoryGiftCardController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface, centerTitle: false, titleSpacing: 0),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                        controller.giftCardsOrderList.isEmpty
                            ? Constant.showEmptyView(message: "Purchased Gift card not found".tr)
                            : ListView.builder(
                              itemCount: controller.giftCardsOrderList.length,
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                GiftCardsOrderModel giftCardOrderModel = controller.giftCardsOrderList[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                giftCardOrderModel.giftTitle.toString(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                                  fontFamily: AppThemeData.semiBold,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              Constant.amountShow(amount: giftCardOrderModel.price.toString()),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Gift Code".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            Text(
                                              giftCardOrderModel.giftCode.toString().replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)} "),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Gift Pin".tr,
                                                style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            giftCardOrderModel.isPasswordShow == true
                                                ? Text(
                                                  giftCardOrderModel.giftPin.toString(),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                    fontFamily: AppThemeData.semiBold,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                )
                                                : Text(
                                                  "****",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                    fontFamily: AppThemeData.semiBold,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            const SizedBox(width: 10),
                                            giftCardOrderModel.isPasswordShow == true
                                                ? InkWell(
                                                  onTap: () {
                                                    controller.updateList(index);
                                                    controller.update();
                                                  },
                                                  child: const Icon(Icons.visibility_off),
                                                )
                                                : InkWell(
                                                  onTap: () {
                                                    controller.updateList(index);
                                                    controller.update();
                                                  },
                                                  child: const Icon(Icons.remove_red_eye),
                                                ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                controller.share(
                                                  giftCardOrderModel.giftCode.toString(),
                                                  giftCardOrderModel.giftPin.toString(),
                                                  giftCardOrderModel.message.toString(),
                                                  giftCardOrderModel.price.toString(),
                                                  giftCardOrderModel.expireDate!,
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                decoration: ShapeDecoration(
                                                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Share'.tr,
                                                      style: TextStyle(
                                                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                                        fontSize: 14,
                                                        fontFamily: AppThemeData.semiBold,
                                                        fontWeight: FontWeight.w600,
                                                        height: 0.11,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.share),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Expanded(child: SizedBox()),
                                            Text(
                                              giftCardOrderModel.redeem == true ? "Redeemed".tr : "Not Redeem".tr,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: giftCardOrderModel.redeem == true ? AppThemeData.success400 : AppThemeData.danger300,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
}
