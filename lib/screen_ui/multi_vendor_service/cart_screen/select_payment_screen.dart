import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cart_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../wallet_screen/wallet_screen.dart';

class SelectPaymentScreen extends StatelessWidget {
  const SelectPaymentScreen({super.key});

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
            title: Text("Payment Option".tr, textAlign: TextAlign.start, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
          ),
          body:
              controller.isLoading.value == true
                  ? Align(
                    alignment: Alignment.center,
                    child: Text(
                      "Loading, please wait...".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Preferred Payment".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                          ),
                          const SizedBox(height: 10),
                          if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                            Container(
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                shadows: const [BoxShadow(color: Color(0x07000000), blurRadius: 20, offset: Offset(0, 0), spreadRadius: 0)],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Visibility(
                                      visible: controller.walletSettingModel.value.isEnabled == true,
                                      child: cardDecoration(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png"),
                                    ),
                                    Visibility(
                                      visible: controller.cashOnDeliverySettingModel.value.isEnabled == true,
                                      child: cardDecoration(controller, PaymentGateway.cod, isDark, "assets/images/ic_cash.png"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                            Column(
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  "Other Payment Options".tr,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          Container(
                            decoration: ShapeDecoration(
                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              shadows: const [BoxShadow(color: Color(0x07000000), blurRadius: 20, offset: Offset(0, 0), spreadRadius: 0)],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")),
                                  Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")),
                                  Visibility(
                                    visible: controller.payStackModel.value.isEnable == true,
                                    child: cardDecoration(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png"),
                                  ),
                                  Visibility(
                                    visible: controller.mercadoPagoModel.value.isEnabled == true,
                                    child: cardDecoration(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png"),
                                  ),
                                  Visibility(
                                    visible: controller.flutterWaveModel.value.isEnable == true,
                                    child: cardDecoration(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png"),
                                  ),
                                  Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")),
                                  Visibility(
                                    visible: controller.razorPayModel.value.isEnabled == true,
                                    child: cardDecoration(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png"),
                                  ),
                                  Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")),
                                  Visibility(
                                    visible: controller.orangeMoneyModel.value.enable == true,
                                    child: cardDecoration(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png"),
                                  ),
                                  Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "${'Pay Now'.tr} | ${Constant.amountShow(amount: controller.totalAmount.value.toString())}".tr,
                height: 5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  Get.back();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Obx cardDecoration(CartController controller, PaymentGateway value, isDark, String image) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                controller.selectedPaymentMethod.value = value.name;
              },
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: ShapeDecoration(shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8))),
                    child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: Image.asset(image)),
                  ),
                  const SizedBox(width: 10),
                  value.name == "wallet"
                      ? Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value.name.capitalizeString(),
                              textAlign: TextAlign.start,
                              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                            ),
                            Text(
                              Constant.amountShow(amount: controller.userModel.value.walletAmount == null ? '0.0' : controller.userModel.value.walletAmount.toString()),
                              textAlign: TextAlign.start,
                              style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                            ),
                          ],
                        ),
                      )
                      : Expanded(
                        child: Text(
                          value.name.capitalizeString(),
                          textAlign: TextAlign.start,
                          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                        ),
                      ),
                  const Expanded(child: SizedBox()),
                  Radio(
                    value: value.name,
                    groupValue: controller.selectedPaymentMethod.value,
                    activeColor: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                    onChanged: (value) {
                      controller.selectedPaymentMethod.value = value.toString();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
