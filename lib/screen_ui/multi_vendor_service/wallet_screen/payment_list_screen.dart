import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/wallet_controller.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../themes/show_toast_dialog.dart';

class PaymentListScreen extends StatelessWidget {
  const PaymentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: WalletController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text("Top up Wallet".tr, style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500)),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFieldWidget(
                    title: 'Amount'.tr,
                    hintText: 'Enter Amount'.tr,
                    controller: controller.topUpAmountController.value,
                    textInputType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    prefix: Padding(padding: const EdgeInsets.all(12.0), child: Text(Constant.currencyModel!.symbol.toString(), style: const TextStyle(fontSize: 20, color: AppThemeData.grey800))),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    "Select Top up Options".tr,
                    style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.circular(20)), color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                    child: Column(
                      children: [
                        Visibility(visible: controller.stripeModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")),
                        Visibility(visible: controller.payPalModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")),
                        Visibility(visible: controller.payStackModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png")),
                        Visibility(
                          visible: controller.mercadoPagoModel.value.isEnabled == true,
                          child: cardDecoration(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png"),
                        ),
                        Visibility(
                          visible: controller.flutterWaveModel.value.isEnable == true,
                          child: cardDecoration(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png"),
                        ),
                        Visibility(visible: controller.payFastModel.value.isEnable == true, child: cardDecoration(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")),
                        Visibility(visible: controller.razorPayModel.value.isEnabled == true, child: cardDecoration(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png")),
                        Visibility(visible: controller.midTransModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")),
                        Visibility(visible: controller.orangeMoneyModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png")),
                        Visibility(visible: controller.xenditModel.value.enable == true, child: cardDecoration(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")),
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
              child: RoundedButtonFill(
                title: "Top-up".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  if (controller.topUpAmountController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please Enter Amount".tr);
                  } else {
                    if (double.parse(controller.topUpAmountController.value.text) >= double.parse(Constant.minimumAmountToDeposit.toString())) {
                      if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                        controller.stripeMakePayment(amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                        controller.paypalPaymentSheet(controller.topUpAmountController.value.text, context);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                        controller.payStackPayment(controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                        controller.mercadoPagoMakePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                        controller.flutterWaveInitiatePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                        controller.payFastPayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                        controller.midtransMakePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                        controller.orangeMakePayment(context: context, amount: controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                        controller.xenditPayment(context, controller.topUpAmountController.value.text);
                      } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                        RazorPayController().createOrderRazorPay(amount: double.parse(controller.topUpAmountController.value.text), razorpayModel: controller.razorPayModel.value).then((value) {
                          if (value == null) {
                            Get.back();
                            ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                          } else {
                            CreateRazorPayOrderModel result = value;
                            controller.openCheckout(amount: controller.topUpAmountController.value.text, orderId: result.id);
                          }
                        });
                      } else {
                        ShowToastDialog.showToast("Please select payment method".tr);
                      }
                    } else {
                      ShowToastDialog.showToast("${'Please Enter minimum amount of'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToDeposit)}");
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Obx cardDecoration(WalletController controller, PaymentGateway value, isDark, String image) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: InkWell(
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
              Expanded(
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
      ),
    );
  }
}
