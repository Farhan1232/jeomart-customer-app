import 'package:customer/models/coupon_model.dart';
import 'package:customer/screen_ui/parcel_service/parcel_coupon_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/parcel_order_confirmation_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../payment/create_razor_pay_order_model.dart';
import '../../payment/rozorpay_conroller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../multi_vendor_service/wallet_screen/wallet_screen.dart';

class ParcelOrderConfirmationScreen extends StatelessWidget {
  const ParcelOrderConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ParcelOrderConfirmationController(),
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
                  Text("Order Confirmation".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pickup and Delivery Info
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
                              // Timeline with icons and line
                              Column(
                                children: [
                                  Image.asset("assets/images/image_parcel.png", height: 32, width: 32),
                                  DottedBorder(
                                    options: CustomPathDottedBorderOptions(
                                      color: Colors.grey.shade400,
                                      strokeWidth: 2,
                                      dashPattern: [4, 4],
                                      customPath:
                                          (size) =>
                                              Path()
                                                ..moveTo(size.width / 2, 0)
                                                ..lineTo(size.width / 2, size.height),
                                    ),
                                    child: const SizedBox(width: 20, height: 95),
                                  ),
                                  Image.asset("assets/images/image_parcel.png", height: 32, width: 32),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Address Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _infoSection(
                                      "Pickup Address (Sender):".tr,
                                      controller.parcelOrder.value.sender?.name ?? '',
                                      controller.parcelOrder.value.sender?.address ?? '',
                                      controller.parcelOrder.value.sender?.phone ?? '',
                                      // controller.parcelOrder.value.senderPickupDateTime != null
                                      //     ? "Pickup Time: ${controller.formatDate(controller.parcelOrder.value.senderPickupDateTime!)}"
                                      //     : '',
                                      isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _infoSection(
                                      "Delivery Address (Receiver):".tr,
                                      controller.parcelOrder.value.receiver?.name ?? '',
                                      controller.parcelOrder.value.receiver?.address ?? '',
                                      controller.parcelOrder.value.receiver?.phone ?? '',
                                      // controller.parcelOrder.value.receiverPickupDateTime != null
                                      //     ? "Delivery Time: ${controller.formatDate(controller.parcelOrder.value.receiverPickupDateTime!)}"
                                      //     : '',
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Distance, Weight, Rate
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _iconTile("${controller.parcelOrder.value.distance ?? '--'} ${'KM'.tr}", "Distance".tr, "assets/icons/ic_distance_parcel.svg", isDark),
                              _iconTile(controller.parcelOrder.value.parcelWeight ?? '--', "Weight".tr, "assets/icons/ic_weight_parcel.svg", isDark),
                              _iconTile(Constant.amountShow(amount: controller.parcelOrder.value.subTotal), "Rate".tr, "assets/icons/ic_rate_parcel.svg", isDark),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(child: Text("Coupons".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                            InkWell(
                              onTap: () {
                                Get.to(ParcelCouponScreen())!.then((value) {
                                  if (value != null) {
                                    double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: value);
                                    if (couponAmount < controller.subTotal.value) {
                                      controller.selectedCouponModel.value = value;
                                      controller.calculatePrice();
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
                                  child: TextField(
                                    controller: controller.couponController.value,
                                    style: AppThemeData.semiBoldTextStyle(color: AppThemeData.parcelService500, fontSize: 16),
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
                                          controller.calculatePrice();
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
                        const SizedBox(height: 24),
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
                              _summaryTile("Discount".tr, "-${Constant.amountShow(amount: controller.discount.value.toString())}", isDark, AppThemeData.dangerDark300),
                              if (Constant.platformFeeModel?.enable == true) _summaryTile("Platform fee".tr, Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()), isDark, null),

                              // Tax List
                              InkWell(
                                onTap: () {
                                  showBillBifurcationDialog(context, isDark, controller);
                                },
                                child: _summaryTile("Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString()), isDark, null, underline: true),
                              ),

                              // ...List.generate(Constant.orderProductTaxList!.length, (index) {
                              //                                 final taxModel = Constant.orderProductTaxList![index];
                              //                                 final taxTitle = "${taxModel.title} ${taxModel.type == 'fix' ? '(${Constant.amountShow(amount: taxModel.tax)})' : '(${taxModel.tax}%)'}";
                              //                                 final taxAmount = Constant.getTaxValue(amount: (controller.subTotal.value - controller.discount.value).toString(), taxModel: taxModel).toString();

                              //                                 return _summaryTile(taxTitle, Constant.amountShow(amount: (double.parse(taxAmount) + controller.platformTaxAmount.value).toString()), isDark, null);
                              //                               })
                              const Divider(),

                              // Total
                              _summaryTile("Order Total".tr, Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark, null),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
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
                              // Title
                              Text("Payment by".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                              const SizedBox(height: 12),

                              // Row with Sender and Receiver options
                              Row(
                                children: [
                                  // Sender
                                  GestureDetector(
                                    onTap: () => controller.paymentBy.value = "Sender",
                                    child: Row(
                                      children: [
                                        Icon(
                                          controller.paymentBy.value == "Sender" ? Icons.radio_button_checked : Icons.radio_button_off,
                                          color: controller.paymentBy.value == "Sender" ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text("Sender".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 60),

                                  // Receiver
                                  GestureDetector(
                                    onTap: () => controller.paymentBy.value = "Receiver",
                                    child: Row(
                                      children: [
                                        Icon(
                                          controller.paymentBy.value == "Receiver" ? Icons.radio_button_checked : Icons.radio_button_off,
                                          color: controller.paymentBy.value == "Receiver" ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text("Receiver".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Continue button
                        RoundedButtonFill(
                          title: controller.paymentBy.value == "Sender" ? "Select Payment Method".tr : "Continue".tr,
                          onPress: () async {
                            if (controller.paymentBy.value == "Sender") {
                              Get.bottomSheet(
                                paymentBottomSheet(context, controller, isDark), // your widget
                                isScrollControlled: true, // ✅ allows full drag scrolling
                                backgroundColor: Colors.transparent, // so your rounded corners are visible
                              );
                            } else {
                              controller.placeOrder();
                            }
                          },
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey900,
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  Widget _infoSection(String title, String name, String address, String phone, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(name, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(address, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        Text(phone, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        // Text(time, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
    );
  }

  Widget _iconTile(String value, title, icon, bool isDark) {
    return Column(
      children: [
        // Icon(icon, color: AppThemeData.primary300),
        SvgPicture.asset(icon, height: 28, width: 28, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
        const SizedBox(height: 6),
        Text(value, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
        const SizedBox(height: 6),
        Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
      ],
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

  Widget paymentBottomSheet(BuildContext context, ParcelOrderConfirmationController controller, bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.30,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: isDark ? AppThemeData.grey500 : Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Select Payment Method".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                  GestureDetector(
                    onTap: () {
                      Get.back();
                    },
                    child: Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
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
                    if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true) const SizedBox(height: 10),
                    Text("Other Payment Options".tr, textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                    const SizedBox(height: 10),
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
                  ],
                ),
              ),
              RoundedButtonFill(
                title: "Continue".tr,
                color: AppThemeData.taxiBooking300,
                textColor: AppThemeData.grey900,
                onPress: () async {
                  if (controller.selectedPaymentMethod.value == PaymentGateway.stripe.name) {
                    controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.paypal.name) {
                    controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.payStack.name) {
                    controller.payStackPayment(controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name) {
                    controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name) {
                    controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.payFast.name) {
                    controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.cod.name) {
                    controller.placeOrder();
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                    double walletBalance = double.tryParse(controller.userModel.value.walletAmount.toString()) ?? 0.0;
                    double amountToPay = double.tryParse(controller.totalAmount.value.toString()) ?? 0.0;
                    if (walletBalance < amountToPay) {
                      ShowToastDialog.showToast("Insufficient wallet balance".tr);
                      return;
                    }
                    controller.placeOrder();
                  }
                  // else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                  //   controller.placeOrder();
                  // }
                  else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
                    controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name) {
                    controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.xendit.name) {
                    controller.xenditPayment(context, controller.totalAmount.value.toString());
                  } else if (controller.selectedPaymentMethod.value == PaymentGateway.razorpay.name) {
                    RazorPayController().createOrderRazorPay(amount: double.parse(controller.totalAmount.value.toString()), razorpayModel: controller.razorPayModel.value).then((value) {
                      if (value == null) {
                        Get.back();
                        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                      } else {
                        CreateRazorPayOrderModel result = value;
                        controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
                      }
                    });
                  } else {
                    ShowToastDialog.showToast("Please select payment method".tr);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Obx cardDecoration(controller, PaymentGateway value, isDark, String image) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
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

  void showBillBifurcationDialog(BuildContext context, bool isDark, ParcelOrderConfirmationController controller) {
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
