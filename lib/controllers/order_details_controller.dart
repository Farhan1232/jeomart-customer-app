import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:get/get.dart';

import '../service/cart_provider.dart';

class OrderDetailsController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
    }
    calculatePrice();
    update();
  }

  RxDouble totalDistance = 0.0.obs;
  RxDouble deliveryCharges = 0.0.obs;
  RxDouble deliveryTips = 0.0.obs;
  RxDouble subTotal = 0.0.obs;
  RxDouble packagingCharge = 0.0.obs;
  RxDouble platformFee = 0.0.obs;
  RxDouble couponAmount = 0.0.obs;
  RxDouble specialDiscountAmount = 0.0.obs;
  RxDouble productTaxAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble driverDeliveryTaxAmount = 0.0.obs;
  RxDouble packagingTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;
  RxDouble totalTaxAmount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;

  Future<void> calculatePrice() async {
    // Reset
    subTotal.value = 0.0;
    specialDiscountAmount.value = 0.0;
    couponAmount.value = 0.0;

    productTaxAmount.value = 0.0;
    orderTaxAmount.value = 0.0;
    driverDeliveryTaxAmount.value = 0.0;
    packagingTaxAmount.value = 0.0;
    platformTaxAmount.value = 0.0;
    totalTaxAmount.value = 0.0;

    /// ---------------- SUBTOTAL ----------------
    for (var element in orderModel.value.products!) {
      final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal.value += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount.value = double.parse(orderModel.value.discount.toString());

    if (orderModel.value.specialDiscount != null && orderModel.value.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount.value = double.parse(orderModel.value.specialDiscount!['special_discount'].toString());
    }

    if (orderModel.value.taxSetting != null) {
      for (var element in orderModel.value.taxSetting!) {
        taxAmount.value =
            taxAmount.value + Constant.calculateTax(amount: (subTotal.value - double.parse(orderModel.value.discount.toString()) - specialDiscountAmount.value).toString(), taxModel: element);
      }
    }

    final double totalDiscount = couponAmount.value + specialDiscountAmount.value;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal.value > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal.value;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (orderModel.value.taxScope == "product") {
      for (var element in orderModel.value.products!) {
        final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount.value += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount.value += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.value.taxScope == "order") {
      for (var taxElement in orderModel.value.taxSetting ?? []) {
        orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    /// ---------------- OTHER CHARGES ----------------
    deliveryCharges.value = double.parse(orderModel.value.deliveryCharge.toString());

    deliveryTips.value = double.parse(orderModel.value.tipAmount.toString());

    packagingCharge.value = orderModel.value.packagingChargeEnable == true
        ? double.parse(orderModel.value.vendor!.packagingCharge.toString())
        : 0.0;

    platformFee.value = double.parse(orderModel.value.platformFee ?? '0.0');

    /// ---------------- DELIVERY TAX ----------------
    if (orderModel.value.takeAway != true && orderModel.value.vendor?.isSelfDelivery != true) {
      for (var taxElement in orderModel.value.driverDeliveryTax ?? []) {
        driverDeliveryTaxAmount.value += Constant.calculateTax(amount: deliveryCharges.value.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge.value > 0) {
      for (var taxElement in orderModel.value.packagingTax ?? []) {
        packagingTaxAmount.value += Constant.calculateTax(amount: packagingCharge.value.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- PLATFORM TAX ----------------
    if (platformFee.value > 0) {
      for (var taxElement in orderModel.value.platformTax ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: platformFee.value.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount.value = productTaxAmount.value + orderTaxAmount.value + driverDeliveryTaxAmount.value + packagingTaxAmount.value + platformTaxAmount.value;

    /// ---------------- FINAL TOTAL ----------------
    totalAmount.value = (subTotal.value - totalDiscount) + totalTaxAmount.value + (deliveryCharges.value + deliveryTips.value) + packagingCharge.value + platformFee.value;

    isLoading.value = false;
  }

  final CartProvider cartProvider = CartProvider();

  void addToCart({required CartProductModel cartProductModel}) {
    cartProvider.addToCart(Get.context!, cartProductModel, cartProductModel.quantity!);
    update();
  }
}
