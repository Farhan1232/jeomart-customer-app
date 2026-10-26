import 'package:customer/constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/on_demand_payment_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../payment/create_razor_pay_order_model.dart';
import '../../payment/rozorpay_conroller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/wallet_screen/wallet_screen.dart';

class OnDemandPaymentScreen extends StatelessWidget {
  const OnDemandPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<OnDemandPaymentController>(
      init: OnDemandPaymentController(),
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
                  Text("Select Payment Method".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark200 : Colors.white),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Preferred Payment".tr, textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                          const SizedBox(height: 10),
                          if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
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
                                  style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
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
                          SizedBox(height: 20),
                          RoundedButtonFill(
                            title: "Continue".tr,
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey900,
                            onPress: () async {
                              print("getTotalAmount :::::::: ${"${controller.totalAmount.value}"}");
                              if (controller.isOrderPlaced.value == false) {
                                controller.isOrderPlaced.value = true;
                                if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                                  controller.stripeMakePayment(amount: "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                                  controller.paypalPaymentSheet("${controller.totalAmount.value}", context);
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                                  controller.payStackPayment("${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                                  controller.mercadoPagoMakePayment(context: context, amount: "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                                  controller.flutterWaveInitiatePayment(context: context, amount: "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                                  controller.payFastPayment(context: context, amount: "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                                  double totalAmount = double.parse("${controller.totalAmount.value}");
                                  double walletAmount = double.tryParse(Constant.userModel?.walletAmount?.toString() ?? "0") ?? 0;

                                  if (walletAmount == 0) {
                                    ShowToastDialog.showToast("Wallet balance is 0. Please recharge wallet.".tr);
                                  } else if (walletAmount < totalAmount) {
                                    ShowToastDialog.showToast("Insufficient wallet balance. Please add funds.".tr);
                                  } else {
                                    controller.placeOrder();
                                  }
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                                  controller.placeOrder();
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                                  controller.placeOrder();
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                                  controller.midtransMakePayment(context: context, amount: "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                                  controller.orangeMakePayment(context: context, amount: "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                                  controller.xenditPayment(context, "${controller.totalAmount.value}");
                                } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                                  RazorPayController().createOrderRazorPay(amount: double.parse("${controller.totalAmount.value}"), razorpayModel: controller.razorPayModel.value).then((value) {
                                    if (value == null) {
                                      Get.back();
                                      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                                    } else {
                                      CreateRazorPayOrderModel result = value;
                                      controller.openCheckout(amount: "${controller.totalAmount.value}", orderId: result.id);
                                    }
                                  });
                                } else {
                                  controller.isOrderPlaced.value = false;
                                  ShowToastDialog.showToast("Please select payment method".tr);
                                }
                                controller.isOrderPlaced.value = false;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
        );
      },
    );
  }

  Obx cardDecoration(controller, PaymentGateway value, isDark, String image) {
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
                              style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                            ),
                            Text(
                              Constant.amountShow(amount: Constant.userModel?.walletAmount == null ? '0.0' : Constant.userModel?.walletAmount.toString()),
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                            ),
                          ],
                        ),
                      )
                      : Expanded(
                        child: Text(
                          value.name.capitalizeString(),
                          textAlign: TextAlign.start,
                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
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
