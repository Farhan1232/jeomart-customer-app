import 'dart:async';
import 'package:customer/utils/parallel.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as maths;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/cashback_model.dart';
import '../models/cashback_redeem_model.dart';
import '../models/payment_model/cod_setting_model.dart';
import '../models/payment_model/flutter_wave_model.dart';
import '../models/payment_model/mercado_pago_model.dart';
import '../models/payment_model/mid_trans.dart';
import '../models/payment_model/orange_money.dart';
import '../models/payment_model/pay_fast_model.dart';
import '../models/payment_model/pay_stack_model.dart';
import '../models/payment_model/paypal_model.dart';
import '../models/payment_model/paytm_model.dart';
import '../models/payment_model/razorpay_model.dart';
import '../models/payment_model/stripe_model.dart';
import '../models/payment_model/wallet_setting_model.dart';
import '../models/payment_model/xendit.dart';
import '../models/wallet_transaction_model.dart';
import '../payment/mercado_pago_screen.dart';
import '../payment/pay_fast_screen.dart';
import '../payment/get_paytm_txt_token.dart';
import '../payment/midtrans_screen.dart';
import '../payment/orange_pay_screen.dart';
import '../payment/paystack/pay_stack_screen.dart';
import '../payment/paystack/pay_stack_url_model.dart';
import '../payment/paystack/paystack_url_genrater.dart';
import '../payment/stripe_failed_model.dart';
import '../payment/xendit_model.dart';
import '../payment/xendit_screen.dart';
import '../screen_ui/multi_vendor_service/cart_screen/oder_placing_screens.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import '../service/send_notification.dart';
import '../themes/show_toast_dialog.dart';

class CartController extends GetxController {
  /// Firestore and cart listeners opened by this controller.
  ///
  /// They used to run for the rest of the session because nothing cancelled
  /// them when the screen closed - and because a GetX controller is rebuilt
  /// every time its route is pushed, re-entering the screen opened another set
  /// on top. Five visits meant five live vendor streams all rewriting the same
  /// list, which is Firestore traffic and list rebuilds multiplied by however
  /// many times the customer had been in and out.
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.onClose();
  }

  RxBool isCashbackApply = false.obs;
  Rx<CashbackModel> bestCashback = CashbackModel().obs;

  final CartProvider cartProvider = CartProvider();
  Rx<TextEditingController> reMarkController = TextEditingController().obs;
  Rx<TextEditingController> couponCodeController = TextEditingController().obs;
  Rx<TextEditingController> tipsController = TextEditingController().obs;

  Rx<ShippingAddress> selectedAddress = ShippingAddress().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  Rx<DeliveryCharge> deliveryChargeModel = DeliveryCharge().obs;
  Rx<UserModel> userModel = UserModel().obs;
  RxList<CouponModel> couponList = <CouponModel>[].obs;
  RxList<CouponModel> allCouponList = <CouponModel>[].obs;
  RxString selectedFoodType = "Delivery".obs;

  RxString selectedPaymentMethod = ''.obs;
  RxBool isOrderPlaced = false.obs;

  RxString deliveryType = "instant".obs;
  Rx<DateTime> scheduleDateTime = DateTime.now().obs;
  RxDouble totalDistance = 0.0.obs;
  RxDouble deliveryCharges = 0.0.obs;
  RxDouble subTotal = 0.0.obs;
  RxDouble couponAmount = 0.0.obs;

  RxDouble specialDiscountAmount = 0.0.obs;
  RxDouble specialDiscount = 0.0.obs;
  RxString specialType = "".obs;

  RxDouble deliveryTips = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  Rx<CouponModel> selectedCouponModel = CouponModel().obs;

  RxDouble packagingCharge = 0.0.obs;
  RxDouble platformFee = 0.0.obs;
  RxDouble productTaxAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble driverDeliveryTaxAmount = 0.0.obs;
  RxDouble packagingTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;
  RxDouble totalTaxAmount = 0.0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    selectedAddress.value = Constant.selectedLocation;
    getCartData();
    getPaymentSettings();
    super.onInit();
  }

  Future<void> getCartData() async {
    _subscriptions.add(cartProvider.cartStream.listen((event) async {
      cartItem.clear();
      cartItem.addAll(event);
      if (cartItem.isNotEmpty) {
        await FireStoreUtils.getVendorById(cartItem.first.vendorID.toString()).then((value) {
          if (value != null) {
            vendorModel.value = value;
          }
        });
      }
      calculatePrice();
    }));
    selectedFoodType.value = Preferences.getString(Preferences.foodDeliveryType, defaultValue: "Delivery");

    // The profile and the delivery charge are unrelated to each other and to
    // the coupons; the two coupon reads both look at the same vendor id and
    // neither writes it. Four round trips in series became two waves.
    await Future.wait(<Future<void>>[
      FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
        if (value != null) {
          userModel.value = value;
        }
      }),
      FireStoreUtils.getDeliveryCharge().then((value) {
        if (value != null) {
          deliveryChargeModel.value = value;
          calculatePrice();
        }
      }),
    ]);

    await Future.wait(<Future<void>>[
      FireStoreUtils.getAllVendorPublicCoupons(vendorModel.value.id.toString()).then((value) {
        couponList.value = value;
      }),
      FireStoreUtils.getAllVendorCoupons(vendorModel.value.id.toString()).then((value) {
        allCouponList.value = value;
      }),
    ]);
  }

  Future<void> calculatePrice() async {
    // Reset values
    deliveryCharges.value = 0.0;
    subTotal.value = 0.0;
    couponAmount.value = 0.0;
    specialDiscountAmount.value = 0.0;

    productTaxAmount.value = 0.0;
    orderTaxAmount.value = 0.0;
    driverDeliveryTaxAmount.value = 0.0;
    packagingTaxAmount.value = 0.0;
    platformTaxAmount.value = 0.0;
    totalTaxAmount.value = 0.0;

    totalAmount.value = 0.0;
    packagingCharge.value = 0.0;
    platformFee.value = 0.0;

    /// ---------------- DELIVERY CHARGES ----------------
    if (cartItem.isNotEmpty) {
      if (selectedFoodType.value == "Delivery") {
        totalDistance.value = double.parse(
          Constant.getDistance(
            lat1: selectedAddress.value.location!.latitude.toString(),
            lng1: selectedAddress.value.location!.longitude.toString(),
            lat2: vendorModel.value.latitude.toString(),
            lng2: vendorModel.value.longitude.toString(),
          ),
        );
        if (Constant.sectionConstantModel?.serviceType == 'Ecommerce Service') {
          deliveryCharges.value = double.parse(Constant.sectionConstantModel?.deliveryCharge ?? '0.0');
        } else if (vendorModel.value.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true) {
          deliveryCharges.value = 0.0;
        } else if (deliveryChargeModel.value.vendorCanModify == false) {
          deliveryCharges.value =
              totalDistance.value > deliveryChargeModel.value.minimumDeliveryChargesWithinKm!
                  ? totalDistance.value * deliveryChargeModel.value.deliveryChargesPerKm!
                  : deliveryChargeModel.value.minimumDeliveryCharges!.toDouble();
        } else {
          final charge = vendorModel.value.deliveryCharge ?? deliveryChargeModel.value;
          deliveryCharges.value = totalDistance.value > charge.minimumDeliveryChargesWithinKm! ? totalDistance.value * charge.deliveryChargesPerKm! : charge.minimumDeliveryCharges!.toDouble();
        }
      }
    }

    /// ---------------- PACKAGING & PLATFORM ----------------
    if (Constant.sectionConstantModel?.packagingChargeEnable == true) {
      packagingCharge.value = vendorModel.value.packagingCharge != null ? double.parse(vendorModel.value.packagingCharge.toString()) : 0.0;
    }
    if (Constant.sectionConstantModel?.platformFee?.enable == true) {
      platformFee.value = Constant.calculatePlatFormMeModel(platFromFeeModel: Constant.platformFeeModel);
    }

    log("TaxScope :: ${Constant.taxScope}");

    /// ---------------- SUBTOTAL ----------------
    for (var element in cartItem) {
      final price = double.parse((element.discountPrice != null && double.parse(element.discountPrice.toString()) > 0) ? element.discountPrice.toString() : element.price.toString());

      final qty = double.parse(element.quantity.toString());
      final extras = double.parse(element.extrasPrice.toString());

      subTotal.value += (price * qty) + (extras * qty);
    }

    /// ---------------- COUPON ----------------
    if (selectedCouponModel.value.id != null) {
      couponAmount.value = Constant.calculateDiscount(amount: subTotal.value.toString(), offerModel: selectedCouponModel.value);
    }

    /// ---------------- SPECIAL DISCOUNT ----------------
    if (vendorModel.value.specialDiscountEnable == true && Constant.specialDiscountOffer == true) {
      final now = DateTime.now();
      final day = DateFormat('EEEE', 'en_US').format(now);
      final date = DateFormat('dd-MM-yyyy').format(now);

      for (var element in vendorModel.value.specialDiscount!) {
        if (day == element.day.toString()) {
          for (var slot in element.timeslot ?? []) {
            if (slot.discountType == "delivery") {
              final start = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${slot.from}");
              final end = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${slot.to}");

              if (isCurrentDateInRange(start, end)) {
                specialDiscount.value = double.parse(slot.discount.toString());
                specialType.value = slot.type.toString();

                specialDiscountAmount.value = slot.type == "percentage" ? (subTotal.value * specialDiscount.value / 100) : specialDiscount.value;
              }
            }
          }
        }
      }
    }

    /// ---------------- DISCOUNT RATIO ----------------
    final totalDiscount = couponAmount.value + specialDiscountAmount.value;
    double discountRatio = 0.0;

    if (subTotal.value > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal.value;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (Constant.taxScope == "product") {
      for (var element in cartItem) {
        final price = double.parse((element.discountPrice != null && double.parse(element.discountPrice.toString()) > 0) ? element.discountPrice.toString() : element.price.toString());

        final qty = double.parse(element.quantity.toString());
        final extras = double.parse(element.extrasPrice.toString());

        final itemAmount = (price * qty) + (extras * qty);
        final discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount.value += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount.value += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER TAX ----------------
    if (Constant.taxScope == "order") {
      for (var taxElement in Constant.orderProductTaxList ?? []) {
        orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    /// ---------------- DELIVERY TAX ----------------
    if (selectedFoodType.value != 'TakeAway' && vendorModel.value.isSelfDelivery != true) {
      for (var taxElement in Constant.driverDeliveryTaxList ?? []) {
        driverDeliveryTaxAmount.value += Constant.calculateTax(amount: deliveryCharges.value.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- PACKAGING TAX ----------------
    if (Constant.sectionConstantModel!.packagingChargeEnable == true && packagingCharge.value > 0) {
      for (var taxElement in Constant.packagingTaxList ?? []) {
        packagingTaxAmount.value += Constant.calculateTax(amount: packagingCharge.value.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- PLATFORM TAX ----------------
    if (Constant.platformFeeModel?.enable == true && platformFee.value > 0) {
      for (var taxElement in Constant.platformTaxList ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: platformFee.value.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL ----------------
    totalTaxAmount.value = productTaxAmount.value + orderTaxAmount.value + driverDeliveryTaxAmount.value + packagingTaxAmount.value + platformTaxAmount.value;
    log("totalTaxAmount.value :: ${productTaxAmount.value} + ${orderTaxAmount.value} + ${driverDeliveryTaxAmount.value} + ${packagingTaxAmount.value} + ${platformTaxAmount.value}");
    log("totalAmount.value :: ${(subTotal.value - totalDiscount)} + ${totalTaxAmount.value} + ${deliveryCharges.value} + ${deliveryTips.value} + ${packagingCharge.value} + ${platformFee.value}");
    totalAmount.value = (subTotal.value - totalDiscount) + totalTaxAmount.value + deliveryCharges.value + deliveryTips.value + packagingCharge.value + platformFee.value;

    getCashback();
  }

  Future<void> getCashback() async {
    if (Constant.isCashbackActive == true) {
      final paymentMethod = selectedPaymentMethod.value;
      final orderTotal = subTotal.value;
      final now = DateTime.now();

      List<CashbackModel> eligibleCashbacks = [];
      double maxCashbackValue = 0.0;

      final cashbackModelList = await FireStoreUtils.getAllCashbak();

      // The redemption count for each offer, fetched in one wave instead of one
      // query per offer in series while the customer waits at the cart.
      final Map<String, List<CashbackRedeemModel>> redeemsByCashback = <String, List<CashbackRedeemModel>>{};
      await Parallel.map<CashbackModel, void>(cashbackModelList, (CashbackModel cashback) async {
        redeemsByCashback[cashback.id ?? ''] = await FireStoreUtils.getRedeemedCashbacks(cashback.id ?? '');
        return null;
      });

      for (final cashback in cashbackModelList) {
        final startDate = cashback.startDate;
        final endDate = cashback.endDate;

        if (startDate == null || endDate == null) continue;

        final withinDateRange = startDate.toDate().isBefore(now) && endDate.toDate().isAfter(now);
        final meetsMinAmount = orderTotal >= (cashback.minimumPurchaseAmount ?? 0);
        final allPayment = cashback.allPayment ?? false;
        final paymentMatch = allPayment || (cashback.paymentMethods ?? []).contains(paymentMethod);
        final allCustomer = cashback.allCustomer ?? false;
        final customerMatch = allCustomer || (cashback.customerIds ?? []).contains(FireStoreUtils.getCurrentUid());

        final redeemData = redeemsByCashback[cashback.id ?? ''] ?? <CashbackRedeemModel>[];
        final underLimit = redeemData.length < (cashback.redeemLimit ?? 0);

        if (withinDateRange && meetsMinAmount && paymentMatch && customerMatch && underLimit) {
          eligibleCashbacks.add(cashback);
        }
      }
      bestCashback.value = CashbackModel();
      for (final cashback in eligibleCashbacks) {
        double cashbackValue = 0.0;

        if (cashback.cashbackType == 'Percent') {
          final percentage = cashback.cashbackAmount ?? 0.0;
          cashbackValue = (percentage / 100.0) * orderTotal;
        } else if (cashback.cashbackType == 'Fixed') {
          cashbackValue = cashback.cashbackAmount ?? 0.0;
        }

        final maxDiscount = cashback.maximumDiscount ?? cashbackValue;
        if (cashbackValue > maxDiscount) cashbackValue = maxDiscount;

        if (cashbackValue > maxCashbackValue) {
          maxCashbackValue = cashbackValue;
          bestCashback.value = cashback;
        }
      }

      if (bestCashback.value.id != null) {
        final cashbackValue = maxCashbackValue;
        isCashbackApply.value = true;
        bestCashback.value.cashbackValue = cashbackValue;
      } else {
        bestCashback.value = CashbackModel();
        isCashbackApply.value = false;
      }
    } else {
      bestCashback.value = CashbackModel();
      isCashbackApply.value = false;
    }
  }

  Future<void> addToCart({required CartProductModel cartProductModel, required bool isIncrement, required int quantity}) async {
    if (isIncrement) {
      cartProvider.addToCart(Get.context!, cartProductModel, quantity);
    } else {
      cartProvider.removeFromCart(cartProductModel, quantity);
    }
    update();
  }

  List<CartProductModel> tempProduc = [];

  Future<void> placeOrder() async {
    if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
      if (double.parse(userModel.value.walletAmount.toString()) >= totalAmount.value) {
        setOrder();
      } else {
        ShowToastDialog.showToast("You don't have sufficient wallet balance to place order".tr);
      }
    } else {
      setOrder();
    }
  }

  Future<void> setOrder() async {
    ShowToastDialog.showLoader("Please wait...".tr);

    if ((Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) && vendorModel.value.subscriptionPlan != null) {
      await FireStoreUtils.getVendorById(vendorModel.value.id!).then((vender) async {
        if (vender?.subscriptionTotalOrders == '0' || vender?.subscriptionTotalOrders == null) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("This vendor has reached their maximum order capacity. Please select a different vendor or try again later.".tr);
          return;
        }
      });
    }

    for (CartProductModel cartProduct in cartItem) {
      CartProductModel tempCart = cartProduct;
      if (cartProduct.extrasPrice == '0') {
        tempCart.extras = [];
      }
      tempProduc.add(tempCart);
    }

    Map<String, dynamic> specialDiscountMap = {'special_discount': specialDiscountAmount.value, 'special_discount_label': specialDiscount.value, 'specialType': specialType.value};

    OrderModel orderModel = OrderModel();
    orderModel.id = Constant.getUuid();
    orderModel.address = selectedAddress.value;
    orderModel.authorID = FireStoreUtils.getCurrentUid();
    orderModel.author = userModel.value;
    orderModel.vendorID = vendorModel.value.id;
    orderModel.vendor = vendorModel.value;
    orderModel.adminCommission =
        Constant.sectionConstantModel?.adminCommision?.isEnabled == false
            ? '0'
            : vendorModel.value.adminCommission != null
            ? vendorModel.value.adminCommission!.amount.toString()
            : Constant.sectionConstantModel?.adminCommision?.amount.toString();
    orderModel.adminCommissionType =
        Constant.sectionConstantModel?.adminCommision?.isEnabled == false
            ? 'fixed'
            : vendorModel.value.adminCommission != null
            ? vendorModel.value.adminCommission!.commissionType
            : Constant.sectionConstantModel?.adminCommision?.commissionType;
    orderModel.status = Constant.orderPlaced;
    orderModel.discount = couponAmount.value;
    orderModel.couponId = selectedCouponModel.value.id;
    orderModel.paymentMethod = selectedPaymentMethod.value;
    orderModel.products = cartItem;
    orderModel.sectionId = Constant.sectionConstantModel?.id;
    orderModel.specialDiscount = specialDiscountMap;
    orderModel.couponCode = selectedCouponModel.value.code;
    orderModel.deliveryCharge = deliveryCharges.value.toString();
    orderModel.tipAmount = deliveryTips.value.toString();
    orderModel.notes = reMarkController.value.text;
    orderModel.takeAway = selectedFoodType.value == "Delivery" ? false : true;
    orderModel.createdAt = Timestamp.now();
    orderModel.scheduleTime = deliveryType.value == "schedule" ? Timestamp.fromDate(scheduleDateTime.value) : null;
    orderModel.cashback = bestCashback.value.id == null ? null : bestCashback.value;

    orderModel.taxSetting = Constant.taxScope == "order" ? Constant.orderProductTaxList : [];
    orderModel.driverDeliveryTax = Constant.driverDeliveryTaxList;
    orderModel.packagingTax = Constant.packagingTaxList;
    orderModel.platformTax = Constant.platformTaxList;
    orderModel.taxScope = Constant.taxScope;
    orderModel.platformFee = platformFee.value.toString();
    orderModel.packagingChargeEnable = Constant.sectionConstantModel?.packagingChargeEnable == true;
    if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: double.parse(totalAmount.value.toString()),
        date: Timestamp.now(),
        paymentMethod: PaymentGateway.wallet.name,
        transactionUser: "customer",
        userId: FireStoreUtils.getCurrentUid(),
        isTopup: false,
        orderId: orderModel.id,
        note: "Order Amount debited".tr,
        paymentStatus: "success".tr,
      );

      await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(amount: "-${totalAmount.value.toString()}", userId: FireStoreUtils.getCurrentUid()).then((value) {});
        }
      });
    }

    for (int i = 0; i < tempProduc.length; i++) {
      await FireStoreUtils.getProductById(tempProduc[i].id!.split('~').first).then((value) async {
        ProductModel? productModel = value;
        if (tempProduc[i].variantInfo != null) {
          if (productModel!.itemAttribute != null) {
            for (int j = 0; j < productModel.itemAttribute!.variants!.length; j++) {
              if (productModel.itemAttribute!.variants![j].variantId == tempProduc[i].id!.split('~').last) {
                if (productModel.itemAttribute!.variants![j].variantQuantity != "-1") {
                  productModel.itemAttribute!.variants![j].variantQuantity = (int.parse(productModel.itemAttribute!.variants![j].variantQuantity.toString()) - tempProduc[i].quantity!).toString();
                }
              }
            }
          } else {
            if (productModel.quantity != -1) {
              productModel.quantity = (productModel.quantity! - tempProduc[i].quantity!);
            }
          }
        } else {
          if (productModel!.quantity != -1) {
            productModel.quantity = (productModel.quantity! - tempProduc[i].quantity!);
          }
        }

        await FireStoreUtils.setProduct(productModel);
      });
    }
    if (Constant.isCashbackActive == true && bestCashback.value.id != null) {
      CashbackRedeemModel cashbackRedeemModel = CashbackRedeemModel(
        id: Constant.getUuid(),
        cashbackId: bestCashback.value.id,
        userId: FireStoreUtils.getCurrentUid(),
        orderId: orderModel.id,
        createdAt: Timestamp.now(),
      );
      await FireStoreUtils.setCashbackRedeemModel(cashbackRedeemModel);
    }
    await FireStoreUtils.setOrder(orderModel).then((value) async {
      await FireStoreUtils.getUserProfile(orderModel.vendor!.author.toString()).then((value) async {
        if (value != null) {
          if (orderModel.scheduleTime != null) {
            await SendNotification.sendFcmMessage(Constant.scheduleOrder, value.fcmToken ?? '', {});
          } else {
            await SendNotification.sendFcmMessage(Constant.orderPlacedNotification, value.fcmToken ?? '', {});
          }
        }
      });
      await Constant.sendOrderEmail(orderModel: orderModel);
      ShowToastDialog.closeLoader();
      Get.off(const OrderPlacingScreen(), arguments: {"orderModel": orderModel});
    });
  }

  Rx<WalletSettingModel> walletSettingModel = WalletSettingModel().obs;
  Rx<CodSettingModel> cashOnDeliverySettingModel = CodSettingModel().obs;
  Rx<PayFastModel> payFastModel = PayFastModel().obs;
  Rx<MercadoPagoModel> mercadoPagoModel = MercadoPagoModel().obs;
  Rx<PayPalModel> payPalModel = PayPalModel().obs;
  Rx<StripeModel> stripeModel = StripeModel().obs;
  Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  Rx<PayStackModel> payStackModel = PayStackModel().obs;
  Rx<PaytmModel> paytmModel = PaytmModel().obs;
  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;

  Rx<MidTrans> midTransModel = MidTrans().obs;
  Rx<OrangeMoney> orangeMoneyModel = OrangeMoney().obs;
  Rx<Xendit> xenditModel = Xendit().obs;
  RxBool isLoading = true.obs;

  Future<void> getPaymentSettings() async {
    isLoading.value = true;
    await FireStoreUtils.getPaymentSettingsData().then((value) {
      stripeModel.value = StripeModel.fromJson(jsonDecode(Preferences.getString(Preferences.stripeSettings)));
      payPalModel.value = PayPalModel.fromJson(jsonDecode(Preferences.getString(Preferences.paypalSettings)));
      payStackModel.value = PayStackModel.fromJson(jsonDecode(Preferences.getString(Preferences.payStack)));
      mercadoPagoModel.value = MercadoPagoModel.fromJson(jsonDecode(Preferences.getString(Preferences.mercadoPago)));
      flutterWaveModel.value = FlutterWaveModel.fromJson(jsonDecode(Preferences.getString(Preferences.flutterWave)));
      paytmModel.value = PaytmModel.fromJson(jsonDecode(Preferences.getString(Preferences.paytmSettings)));
      payFastModel.value = PayFastModel.fromJson(jsonDecode(Preferences.getString(Preferences.payFastSettings)));
      razorPayModel.value = RazorPayModel.fromJson(jsonDecode(Preferences.getString(Preferences.razorpaySettings)));
      midTransModel.value = MidTrans.fromJson(jsonDecode(Preferences.getString(Preferences.midTransSettings)));
      orangeMoneyModel.value = OrangeMoney.fromJson(jsonDecode(Preferences.getString(Preferences.orangeMoneySettings)));
      xenditModel.value = Xendit.fromJson(jsonDecode(Preferences.getString(Preferences.xenditSettings)));
      walletSettingModel.value = WalletSettingModel.fromJson(jsonDecode(Preferences.getString(Preferences.walletSettings)));
      cashOnDeliverySettingModel.value = CodSettingModel.fromJson(jsonDecode(Preferences.getString(Preferences.codSettings)));

      if (walletSettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.wallet.name;
      } else if (cashOnDeliverySettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.cod.name;
      } else if (stripeModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.stripe.name;
      } else if (payPalModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.paypal.name;
      } else if (payStackModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payStack.name;
      } else if (mercadoPagoModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.mercadoPago.name;
      } else if (flutterWaveModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.flutterWave.name;
      } else if (payFastModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payFast.name;
      } else if (razorPayModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.razorpay.name;
      } else if (midTransModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.midTrans.name;
      } else if (orangeMoneyModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.orangeMoney.name;
      } else if (xenditModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.xendit.name;
      }
      Stripe.publishableKey = stripeModel.value.clientpublishableKey.toString();
      Stripe.merchantIdentifier = 'Foodie Customer';
      Stripe.instance.applySettings();
      setRef();

      razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
      razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWaller);
      razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    });
    isLoading.value = false;
  }

  // Strip
  Future<void> stripeMakePayment({required String amount}) async {
    log(double.parse(amount).toStringAsFixed(0));
    try {
      Map<String, dynamic>? paymentIntentData = await createStripeIntent(amount: amount);
      log("stripe Responce====>$paymentIntentData");
      if (paymentIntentData!.containsKey("error")) {
        Get.back();
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentData['client_secret'],
            allowsDelayedPaymentMethods: false,
            googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: true, currencyCode: "USD"),
            customFlow: true,
            style: ThemeMode.system,
            appearance: PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: AppThemeData.primary300)),
            merchantDisplayName: 'GoRide',
          ),
        );
        displayStripePaymentSheet(amount: amount);
      }
    } catch (e, s) {
      log("$e \n$s");
      ShowToastDialog.showToast("exception:$e \n$s");
    }
  }

  Future<void> displayStripePaymentSheet({required String amount}) async {
    try {
      await Stripe.instance.presentPaymentSheet().then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        placeOrder();
      });
    } on StripeException catch (e) {
      var lo1 = jsonEncode(e);
      var lo2 = jsonDecode(lo1);
      StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
      ShowToastDialog.showToast(lom.error.message);
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }
  }

  Future createStripeIntent({required String amount}) async {
    try {
      Map<String, dynamic> body = {
        'amount': ((double.parse(amount) * 100).round()).toString(),
        'currency': "USD",
        'payment_method_types[]': 'card',
        "description": "Strip Payment",
        "shipping[name]": userModel.value.fullName(),
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      var stripeSecret = stripeModel.value.stripeSecret;
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {'Authorization': 'Bearer $stripeSecret', 'Content-Type': 'application/x-www-form-urlencoded'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      log(e.toString());
    }
  }

  //mercadoo
  Future<Null> mercadoPagoMakePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final headers = {'Authorization': 'Bearer ${mercadoPagoModel.value.accessToken}', 'Content-Type': 'application/json'};

    final body = jsonEncode({
      "items": [
        {
          "title": "Test",
          "description": "Test Payment",
          "quantity": 1,
          "currency_id": "BRL", // or your preferred currency
          "unit_price": double.parse(amount),
        },
      ],
      "payer": {"email": userModel.value.email},
      "back_urls": {"failure": "${Constant.globalUrl}payment/failure", "pending": "${Constant.globalUrl}payment/pending", "success": "${Constant.globalUrl}payment/success"},
      "auto_return": "approved",
      // Automatically return after payment is approved
    });

    final response = await http.post(Uri.parse("https://api.mercadopago.com/checkout/preferences"), headers: headers, body: body);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("MercadoPago Preference Created: $data");
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['init_point']))!.then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("${data['message']}".tr);
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  //Paypal
  void paypalPaymentSheet(String amount, context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.parkme://paypalpay",
              cancelURL: "com.parkme://paypalpay",
              transactions: [
                {
                  "amount": {
                    "total": amount,
                    "currency": "USD",
                    "details": {"subtotal": amount},
                  },
                },
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (Map params) async {
                placeOrder();
                ShowToastDialog.showToast("Payment Successful!!".tr);
              },
              onError: (error) {
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
              onCancel: (params) {
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
            ),
      ),
    );
  }

  ///PayStack Payment Method
  Future<void> payStackPayment(String totalAmount) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await PayStackURLGen.payStackURLGen(
      amount: (double.parse(totalAmount) * 100).round().toString(),
      currency: "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: userModel.value,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel payStackModel0 = value;
        ShowToastDialog.closeLoader();
        Get.to(
          PayStackScreen(
            secretKey: payStackModel.value.secretKey.toString(),
            callBackUrl: payStackModel.value.callbackURL.toString(),
            initialURl: payStackModel0.data.authorizationUrl,
            amount: totalAmount,
            reference: payStackModel0.data.reference,
          ),
        )!.then((value) {
          if (value) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            placeOrder();
          } else {
            ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
          }
        });
      } else {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      }
    });
  }

  //flutter wave Payment Method
  Future<Null> flutterWaveInitiatePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}', 'Content-Type': 'application/json'};

    final body = jsonEncode({
      "tx_ref": _ref,
      "amount": amount,
      "currency": "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      "payment_options": "ussd, card, barter, payattitude",
      "customer": {
        "email": userModel.value.email.toString(),
        "phonenumber": userModel.value.phoneNumber, // Add a real phone number
        "name": userModel.value.fullName(), // Add a real customer name
      },
      "customizations": {"title": "Payment for Services", "description": "Payment for XYZ services"},
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!.then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      print('Payment initialization failed: ${response.body}');
      return null;
    }
  }

  String? _ref;

  void setRef() {
    maths.Random numRef = maths.Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      _ref = "AndroidRef$year$refNumber";
    } else if (Platform.isIOS) {
      _ref = "IOSRef$year$refNumber";
    }
  }

  // payFast
  void payFastPayment({required BuildContext context, required String amount}) {
    ShowToastDialog.showLoader("Please wait".tr);
    PayStackURLGen.getPayHTML(payFastSettingData: payFastModel.value, amount: amount.toString(), userModel: userModel.value).then((String? value) async {
      ShowToastDialog.closeLoader();
      bool isDone = await Get.to(PayFastScreen(htmlData: value!, payFastSettingData: payFastModel.value));
      if (isDone) {
        ShowToastDialog.showToast("Payment successfully".tr);
        placeOrder();
      } else {
        ShowToastDialog.showToast("Payment Failed".tr);
      }
    });
  }

  ///Paytm payment function
  Future<void> getPaytmCheckSum(context, {required double amount}) async {
    final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    String getChecksum = "${Constant.globalUrl}payments/getpaytmchecksum";

    final response = await http.post(
      Uri.parse(getChecksum),
      headers: {},
      body: {"mid": paytmModel.value.paytmMID.toString(), "order_id": orderId, "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString()},
    );

    final data = jsonDecode(response.body);
    await verifyCheckSum(checkSum: data["code"], amount: amount, orderId: orderId).then((value) {
      initiatePayment(amount: amount, orderId: orderId).then((value) {
        String callback = "";
        if (paytmModel.value.isSandboxEnabled == true) {
          callback = "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
        } else {
          callback = "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
        }

        GetPaymentTxtTokenModel result = value;
        startTransaction(context, txnTokenBy: result.body.txnToken ?? '', orderId: orderId, amount: amount, callBackURL: callback, isStaging: paytmModel.value.isSandboxEnabled);
      });
    });
  }

  Future<void> startTransaction(context, {required String txnTokenBy, required orderId, required double amount, required callBackURL, required isStaging}) async {
    // try {
    //   var response = AllInOneSdk.startTransaction(
    //     paytmModel.value.paytmMID.toString(),
    //     orderId,
    //     amount.toString(),
    //     txnTokenBy,
    //     callBackURL,
    //     isStaging,
    //     true,
    //     true,
    //   );
    //
    //   response.then((value) {
    //     if (value!["RESPMSG"] == "Txn Success") {
    //       print("txt done!!");
    //       ShowToastDialog.showToast("Payment Successful!!");
    //       placeOrder();
    //     }
    //   }).catchError((onError) {
    //     if (onError is PlatformException) {
    //       Get.back();
    //
    //       ShowToastDialog.showToast(onError.message.toString());
    //     } else {
    //       log("======>>2");
    //       Get.back();
    //       ShowToastDialog.showToast(onError.message.toString());
    //     }
    //   });
    // } catch (err) {
    //   Get.back();
    //   ShowToastDialog.showToast(err.toString());
    // }
  }

  Future verifyCheckSum({required String checkSum, required double amount, required orderId}) async {
    String getChecksum = "${Constant.globalUrl}payments/validatechecksum";
    final response = await http.post(
      Uri.parse(getChecksum),
      headers: {},
      body: {"mid": paytmModel.value.paytmMID.toString(), "order_id": orderId, "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString(), "checksum_value": checkSum},
    );
    final data = jsonDecode(response.body);
    return data['status'];
  }

  Future<GetPaymentTxtTokenModel> initiatePayment({required double amount, required orderId}) async {
    String initiateURL = "${Constant.globalUrl}payments/initiatepaytmpayment";
    String callback = "";
    if (paytmModel.value.isSandboxEnabled == true) {
      callback = "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    } else {
      callback = "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    }
    final response = await http.post(
      Uri.parse(initiateURL),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID,
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY,
        "amount": amount.toString(),
        "currency": "INR",
        "callback_url": callback,
        "custId": FireStoreUtils.getCurrentUid(),
        "issandbox": paytmModel.value.isSandboxEnabled == true ? "1" : "2",
      },
    );
    log(response.body);
    final data = jsonDecode(response.body);
    if (data["body"]["txnToken"] == null || data["body"]["txnToken"].toString().isEmpty) {
      Get.back();
      ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
    }
    return GetPaymentTxtTokenModel.fromJson(data);
  }

  ///RazorPay payment function
  final Razorpay razorPay = Razorpay();

  void openCheckout({required amount, required orderId}) async {
    var options = {
      'key': razorPayModel.value.razorpayKey,
      'amount': amount * 100,
      'name': 'JEOM',
      'order_id': orderId,
      "currency": "INR",
      'description': 'wallet Topup',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {'contact': userModel.value.phoneNumber, 'email': userModel.value.email},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      razorPay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    ShowToastDialog.showToast("Payment Successful!!".tr);
    placeOrder();
  }

  void handleExternalWaller(ExternalWalletResponse response) {
    ShowToastDialog.showToast("Payment Processing!! via".tr);
  }

  void handlePaymentError(PaymentFailureResponse response) {
    ShowToastDialog.showToast("Payment Failed!!".tr);
  }

  bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    final currentDate = DateTime.now();
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  //Midtrans payment
  Future<void> midtransMakePayment({required String amount, required BuildContext context}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await createPaymentLink(amount: amount).then((url) {
      ShowToastDialog.closeLoader();
      if (url != '') {
        Get.to(() => MidtransScreen(initialURl: url))!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            placeOrder();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<String> createPaymentLink({required var amount}) async {
    var ordersId = const Uuid().v1();
    final url = Uri.parse(midTransModel.value.isSandbox! ? 'https://api.sandbox.midtrans.com/v1/payment-links' : 'https://api.midtrans.com/v1/payment-links');

    final response = await http.post(
      url,
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': generateBasicAuthHeader(midTransModel.value.serverKey!)},
      body: jsonEncode({
        'transaction_details': {'order_id': ordersId, 'gross_amount': double.parse(amount.toString()).toInt()},
        'usage_limit': 2,
        "callbacks": {"finish": "https://www.google.com?merchant_order_id=$ordersId"},
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData['payment_url'];
    } else {
      ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
      return '';
    }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }

  //Orangepay payment
  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  Future<void> orangeMakePayment({required String amount, required BuildContext context}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    reset();
    var id = const Uuid().v4();
    var paymentURL = await fetchToken(context: context, orderId: id, amount: amount, currency: 'USD');
    ShowToastDialog.closeLoader();
    if (paymentURL.toString() != '') {
      Get.to(() => OrangeMoneyScreen(initialURl: paymentURL, accessToken: accessToken, amount: amount, orangePay: orangeMoneyModel.value, orderId: orderId, payToken: payToken))!.then((value) {
        if (value == true) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
          ();
        }
      });
    } else {
      ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
    }
  }

  Future fetchToken({required String orderId, required String currency, required BuildContext context, required String amount}) async {
    String apiUrl = 'https://api.orange.com/oauth/v3/token';
    Map<String, String> requestBody = {'grant_type': 'client_credentials'};

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{'Authorization': "Basic ${orangeMoneyModel.value.auth!}", 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: requestBody,
    );

    // Handle the response

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);

      accessToken = responseData['access_token'];
      // ignore: use_build_context_synchronously
      return await webpayment(context: context, amountData: amount, currency: currency, orderIdData: orderId);
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  Future webpayment({required String orderIdData, required BuildContext context, required String currency, required String amountData}) async {
    orderId = orderIdData;
    amount = amountData;
    String apiUrl = orangeMoneyModel.value.isSandbox! == true ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment' : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment';
    Map<String, String> requestBody = {
      "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
      "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : currency,
      "order_id": orderId,
      "amount": amount,
      "reference": 'Y-Note Test',
      "lang": "en",
      "return_url": orangeMoneyModel.value.returnUrl!.toString(),
      "cancel_url": orangeMoneyModel.value.cancelUrl!.toString(),
      "notif_url": orangeMoneyModel.value.notifUrl!.toString(),
    };

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(requestBody),
    );

    // Handle the response
    if (response.statusCode == 201) {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['message'] == 'OK') {
        payToken = responseData['pay_token'];
        return responseData['payment_url'];
      } else {
        return '';
      }
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  static void reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
  }

  //XenditPayment
  Future<void> xenditPayment(context, amount) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await createXenditInvoice(amount: amount).then((model) {
      ShowToastDialog.closeLoader();
      if (model.id != null) {
        Get.to(() => XenditScreen(initialURl: model.invoiceUrl ?? '', transId: model.id ?? '', apiKey: xenditModel.value.apiKey!.toString()))!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            placeOrder();
            ();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<XenditModel> createXenditInvoice({required var amount}) async {
    const url = 'https://api.xendit.co/v2/invoices';
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': generateBasicAuthHeader(xenditModel.value.apiKey!.toString()),
      // 'Cookie': '__cf_bm=yERkrx3xDITyFGiou0bbKY1bi7xEwovHNwxV1vCNbVc-1724155511-1.0.1.1-jekyYQmPCwY6vIJ524K0V6_CEw6O.dAwOmQnHtwmaXO_MfTrdnmZMka0KZvjukQgXu5B.K_6FJm47SGOPeWviQ',
    };

    final body = jsonEncode({
      'external_id': const Uuid().v1(),
      'amount': amount,
      'payer_email': 'customer@domain.com',
      'description': 'Test - VA Successful invoice payment',
      'currency': 'IDR', //IDR, PHP, THB, VND, MYR
    });

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        XenditModel model = XenditModel.fromJson(jsonDecode(response.body));
        return model;
      } else {
        return XenditModel();
      }
    } catch (e) {
      return XenditModel();
    }
  }

  bool isSelectedDateRestaurantOpen({required DateTime selectedDateTime}) {
    bool isOpen = false;
    final now = selectedDateTime;
    var day = DateFormat('EEEE', 'en_US').format(now);
    var date = DateFormat('dd-MM-yyyy').format(now);
    for (var element in vendorModel.value.workingHours!) {
      if (day == element.day.toString()) {
        if (element.timeslot!.isNotEmpty) {
          for (var element in element.timeslot!) {
            var start = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${element.from}");
            var end = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${element.to}");
            if (isCurrentDateInRange(start, end)) {
              isOpen = true;
            }
          }
        }
      }
    }
    return isOpen;
  }
}
