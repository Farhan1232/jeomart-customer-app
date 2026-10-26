import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as maths;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/parcel_order_model.dart';
import '../constant/constant.dart';
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
import '../models/user_model.dart';
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
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../screen_ui/parcel_service/order_successfully_placed.dart';
import '../service/fire_store_utils.dart';
import '../themes/app_them_data.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/preferences.dart';

class ParcelOrderConfirmationController extends GetxController {
  RxBool isLoading = true.obs;
  final Rx<ParcelOrderModel> parcelOrder = ParcelOrderModel().obs;
  final RxList<XFile> images = <XFile>[].obs;
  final RxString paymentBy = "Receiver".obs;

  RxString selectedPaymentMethod = ''.obs;
  RxBool isOrderPlaced = false.obs;

  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;
  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;

  Rx<TextEditingController> couponController = TextEditingController().obs;
  Rx<UserModel> userModel = UserModel().obs;

  @override
  void onInit() {
    super.onInit();
    getArgument();
  }

  Rx<CouponModel> selectedCouponModel = CouponModel().obs;

  Future<void> getArgument() async {
    final dynamic args = Get.arguments;
    if (args != null) {
      parcelOrder.value = args['parcelOrder'];
      images.value = List<XFile>.from(args['images'] ?? []);
      calculatePrice();
    }

    userModel.value = Constant.userModel!;
    await fetchCoupons();
    await getPaymentSettings();
    isLoading.value = false;
    update();
  }

  void calculatePrice() {
    subTotal.value = 0;
    discount.value = 0;
    taxAmount.value = 0;
    orderTaxAmount.value = 0;
    platformTaxAmount.value = 0;

    subTotal.value = double.tryParse(parcelOrder.value.subTotal ?? '0') ?? 0.0;

    if (selectedCouponModel.value.id != null) {
      discount.value = Constant.calculateDiscount(amount: subTotal.value.toString(), offerModel: selectedCouponModel.value);
    }

    /// ---------------- ORDER TAX ----------------
    for (var taxElement in Constant.orderProductTaxList ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

    /// ---------------- PLATFORM TAX ----------------
    if (Constant.platformFeeModel?.enable == true && double.parse(Constant.platformFeeModel?.fee ?? '0.0') > 0.0) {
      for (var taxElement in Constant.platformTaxList ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: Constant.platformFeeModel?.fee ?? '0.0', taxModel: taxElement);
      }
    }

    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;

    totalAmount.value = (subTotal.value - discount.value) + double.parse(Constant.platformFeeModel?.fee ?? '0.0') + taxAmount.value;
  }

  RxList<CouponModel> couponList = <CouponModel>[].obs;

  Future<void> fetchCoupons() async {
    try {
      await FireStoreUtils.getParcelCoupon().then((value) {
        couponList.value = value;
      });
    } catch (e) {
      print("Error fetching coupons: $e");
    }
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  Future<void> placeOrder() async {
    ShowToastDialog.showLoader("Please wait...".tr);

    try {
      List<String> parcelImages = [];
      if (images.isNotEmpty) {
        for (var image in images) {
          final upload = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), Get.context!);
          parcelImages.add(upload.url);
        }
      }

      parcelOrder.value.parcelImages = parcelImages;
      parcelOrder.value.discount = discount.value.toString();
      parcelOrder.value.discountType = selectedCouponModel.value.discountType.toString();
      parcelOrder.value.discountLabel = selectedCouponModel.value.code.toString();
      parcelOrder.value.adminCommission = Constant.sectionConstantModel?.adminCommision?.amount?.toString();
      parcelOrder.value.adminCommissionType = Constant.sectionConstantModel?.adminCommision?.commissionType;
      parcelOrder.value.status = Constant.orderPlaced;
      parcelOrder.value.createdAt = Timestamp.now();
      parcelOrder.value.author = userModel.value;
      parcelOrder.value.authorID = FireStoreUtils.getCurrentUid();
      parcelOrder.value.paymentMethod = paymentBy.value == "Receiver" ? "cod" : selectedPaymentMethod.value;
      parcelOrder.value.paymentCollectByReceiver = paymentBy.value == "Receiver";
      parcelOrder.value.senderZoneId = Constant.getZoneId(parcelOrder.value.senderLatLong!.latitude ?? 0.0, parcelOrder.value.senderLatLong!.longitude ?? 0.0);
      parcelOrder.value.receiverZoneId = Constant.getZoneId(parcelOrder.value.receiverLatLong!.latitude ?? 0.0, parcelOrder.value.receiverLatLong!.longitude ?? 0.0);

      if (paymentBy.value != "Receiver") {
        if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
          WalletTransactionModel transactionModel = WalletTransactionModel(
            id: Constant.getUuid(),
            amount: double.parse(totalAmount.value.toString()),
            date: Timestamp.now(),
            paymentMethod: PaymentGateway.wallet.name,
            transactionUser: "customer",
            userId: FireStoreUtils.getCurrentUid(),
            isTopup: false,
            orderId: parcelOrder.value.id,
            note: "Parcel Amount debited",
            paymentStatus: "success",
            serviceType: Constant.parcelServiceType,
          );

          await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
            if (value == true) {
              await FireStoreUtils.updateUserWallet(amount: "-${totalAmount.value.toString()}", userId: FireStoreUtils.getCurrentUid());
            }
          });
        }
      }

      await FireStoreUtils.parcelOrderPlace(parcelOrder.value).then((value) async {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Order placed successfully".tr);
        Get.offAll(() => OrderSuccessfullyPlaced(), arguments: {'parcelOrder': parcelOrder.value});
        await FireStoreUtils.sendParcelBookEmail(orderModel: parcelOrder.value);
      });
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
    }
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

  Future<void> getPaymentSettings() async {
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
      Stripe.merchantIdentifier = 'JEOM';
      Stripe.instance.applySettings();
      setRef();

      razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
      razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWaller);
      razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    });
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
        "shipping[name]": Constant.userModel?.fullName(),
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
      "payer": {"email": Constant.userModel?.email},
      "back_urls": {"failure": "${Constant.globalUrl}payment/failure", "pending": "${Constant.globalUrl}payment/pending", "success": "${Constant.globalUrl}payment/success"},
      "auto_return": "approved",
      // Automatically return after payment is approved
    });

    final response = await http.post(Uri.parse("https://api.mercadopago.com/checkout/preferences"), headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
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
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  //Paypal
  void paypalPaymentSheet(String amount, BuildContext context) {
    // ✅ Ensure amount format is correct (e.g. 10.00)
    final formattedAmount = double.parse(amount).toStringAsFixed(2);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.jeo.customer://paypalpay",
              cancelURL: "com.jeo.customer://paypalcancel",

              transactions: [
                {
                  "amount": {
                    "total": formattedAmount,
                    "currency": "USD",
                    "details": {"subtotal": formattedAmount},
                  },
                },
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (Map params) async {
                debugPrint("✅ PayPal Payment Success: $params");
                placeOrder();
                ShowToastDialog.showToast("Payment Successful!!".tr);
              },
              onError: (error) {
                debugPrint("❌ PayPal Payment Error: $error");
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
              onCancel: (params) {
                debugPrint("⚠️ PayPal Payment Canceled: $params");
                Get.back();
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
            ),
      ),
    );
  }

  // void paypalPaymentSheet(String amount, context) {
  //   Navigator.of(context).push(
  //     MaterialPageRoute(
  //       builder:
  //           (BuildContext context) => UsePaypal(
  //             sandboxMode: payPalModel.value.isLive == true ? false : true,
  //             clientId: payPalModel.value.paypalClient ?? '',
  //             secretKey: payPalModel.value.paypalSecret ?? '',
  //             returnURL: "https://success.emart.com/return",
  //             cancelURL: "https://cancel.emart.com/cancel",
  //             // returnURL: "com.emart.customer://paypalpay",
  //             // cancelURL: "com.emart.customer://paypalpay",
  //             transactions: [
  //               {
  //                 "amount": {
  //                   "total": amount,
  //                   "currency": "USD",
  //                   "details": {"subtotal": amount},
  //                 },
  //               },
  //             ],
  //             note: "Contact us for any questions on your order.",
  //             onSuccess: (Map params) async {
  //               placeOrder();
  //               ShowToastDialog.showToast("Payment Successful!!".tr);
  //             },
  //             onError: (error) {
  //               Get.back();
  //               ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
  //             },
  //             onCancel: (params) {
  //               Get.back();
  //               ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
  //             },
  //           ),
  //     ),
  //   );
  // }

  ///PayStack Payment Method
  Future<void> payStackPayment(String totalAmount) async {
    // Convert to int (kobo/cents)
    int amountInCents = (double.parse(totalAmount) * 100).round();

    ShowToastDialog.showLoader("Please wait".tr);
    await PayStackURLGen.payStackURLGen(
      amount: amountInCents.toString(), //integer string
      currency: "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: Constant.userModel!,
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

  ///flutter wave Payment Method
  Future<void> flutterWaveInitiatePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    setRef(); // make sure you generate reference

    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}', 'Content-Type': 'application/json'};

    final body = jsonEncode({
      "tx_ref": _ref,
      "amount": amount,
      "currency": "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      "payment_options": "ussd, card, barter, payattitude",
      "customer": {"email": Constant.userModel?.email.toString(), "phonenumber": Constant.userModel?.phoneNumber, "name": Constant.userModel?.fullName()},
      "customizations": {"title": "Payment for Services", "description": "Payment for XYZ services"},
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!.then((value) async {
        bool isVerified = await verifyFlutterWavePayment(_ref!);

        if (isVerified) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          placeOrder();
        } else {
          ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          Get.back();
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      debugPrint('Payment initialization failed: ${response.body}');
    }
  }

  Future<bool> verifyFlutterWavePayment(String txRef) async {
    try {
      final url = Uri.parse("https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=$txRef");
      final headers = {'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}', 'Content-Type': 'application/json'};

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data']['status'] == 'successful') {
          return true; // ✅ Payment confirmed
        }
      }
      return false; // ❌ Payment not verified
    } catch (e) {
      debugPrint("Error verifying payment: $e");
      return false;
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
    PayStackURLGen.getPayHTML(payFastSettingData: payFastModel.value, amount: amount.toString(), userModel: Constant.userModel!).then((String? value) async {
      ShowToastDialog.closeLoader();
      bool isDone = await Get.to(PayFastScreen(htmlData: value!, payFastSettingData: payFastModel.value));
      if (isDone) {
        Get.back();
        ShowToastDialog.showToast("Payment successfully".tr);
        placeOrder();
      } else {
        Get.back();
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

  Future<GetPaymentTxtTokenModel> initiatePayment({required double amount, required String orderId}) async {
    String initiateURL = "${Constant.globalUrl}payments/initiatepaytmpayment";

    String callback =
        (paytmModel.value.isSandboxEnabled ?? false) ? "https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId" : "https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";

    print("INITIATE PAYMENT CALL:");
    print("MID: ${paytmModel.value.paytmMID}");
    print("OrderId: $orderId");
    print("Amount: $amount");
    print("Env: ${(paytmModel.value.isSandboxEnabled ?? false) ? "STAGING" : "LIVE"}");

    final response = await http.post(
      Uri.parse(initiateURL),
      body: {
        "mid": paytmModel.value.paytmMID ?? "",
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY ?? "",
        "amount": amount.toStringAsFixed(0), // Paytm requires integer
        "currency": "INR",
        "callback_url": callback,
        "custId": FireStoreUtils.getCurrentUid(),
        "issandbox": (paytmModel.value.isSandboxEnabled ?? false) ? "1" : "0",
      },
    );

    log("Paytm Initiate Response: ${response.body}");

    final data = jsonDecode(response.body);
    if (data["body"]["txnToken"] == null || data["body"]["txnToken"].toString().isEmpty) {
      Get.back();
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
    }

    return GetPaymentTxtTokenModel.fromJson(data);
  }

  // Future<GetPaymentTxtTokenModel> initiatePayment({required double amount, required orderId}) async {
  //   String initiateURL = "${Constant.globalUrl}payments/initiatepaytmpayment";
  //   String callback = "";
  //   if (paytmModel.value.isSandboxEnabled == true) {
  //     callback = "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
  //   } else {
  //     callback = "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
  //   }
  //   final response = await http.post(
  //     Uri.parse(initiateURL),
  //     headers: {},
  //     body: {
  //       "mid": paytmModel.value.paytmMID,
  //       "order_id": orderId,
  //       "key_secret": paytmModel.value.pAYTMMERCHANTKEY,
  //       "amount": amount.toString(),
  //       "currency": "INR",
  //       "callback_url": callback,
  //       "custId": FireStoreUtils.getCurrentUid(),
  //       "issandbox": paytmModel.value.isSandboxEnabled == true ? "1" : "2",
  //     },
  //   );
  //   log(response.body);
  //   final data = jsonDecode(response.body);
  //   if (data["body"]["txnToken"] == null || data["body"]["txnToken"].toString().isEmpty) {
  //     Get.back();
  //     ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
  //   }
  //   return GetPaymentTxtTokenModel.fromJson(data);
  // }

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
      'prefill': {'contact': Constant.userModel?.phoneNumber, 'email': Constant.userModel?.email},
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
    Get.back();
    ShowToastDialog.showToast("Payment Successful!!".tr);
    placeOrder();
  }

  void handleExternalWaller(ExternalWalletResponse response) {
    Get.back();
    ShowToastDialog.showToast("Payment Processing!! via".tr);
  }

  void handlePaymentError(PaymentFailureResponse response) {
    Get.back();
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

  // 🟠 ORANGE MONEY PAYMENT INTEGRATION
  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  Future<void> orangeMakePayment({required String amount, required BuildContext context}) async {
    reset();
    var id = const Uuid().v4();
    debugPrint('🟩 Starting OrangePay Payment...');
    debugPrint('💰 Amount: $amount | 🆔 Order ID: $id');

    ShowToastDialog.showLoader("Initializing payment...".tr);

    var paymentURL = await fetchToken(context: context, orderId: id, amount: amount, currency: 'USD');

    ShowToastDialog.closeLoader();

    if (paymentURL.toString().isNotEmpty) {
      debugPrint('✅ Payment URL fetched successfully: $paymentURL');

      Get.to(() => OrangeMoneyScreen(initialURl: paymentURL, accessToken: accessToken, amount: amount, orangePay: orangeMoneyModel.value, orderId: orderId, payToken: payToken))?.then((value) async {
        if (value == true) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          debugPrint('🎉 Payment Successful for Order ID: $orderId');

          if (Get.isBottomSheetOpen ?? false) Get.back();
          await placeOrder();
        } else {
          ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          debugPrint('⚠️ Payment flow closed without success.');

          if (Get.isBottomSheetOpen ?? false) Get.back();
        }
      });
    } else {
      ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
      if (Get.isBottomSheetOpen ?? false) Get.back();
    }
  }

  Future fetchToken({required String orderId, required String currency, required BuildContext context, required String amount}) async {
    const String apiUrl = 'https://api.orange.com/oauth/v3/token';
    final Map<String, String> requestBody = {'grant_type': 'client_credentials'};

    debugPrint('🔐 Fetching access token from Orange API...');
    debugPrint('📡 POST $apiUrl');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Authorization': "Basic ${orangeMoneyModel.value.auth!}", 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: requestBody,
    );

    debugPrint('🔍 Response Code: ${response.statusCode}');
    debugPrint('📨 Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      accessToken = responseData['access_token'];
      debugPrint('✅ Access Token Received: $accessToken');

      return await webpayment(context: context, amountData: amount, currency: currency, orderIdData: orderId);
    } else {
      debugPrint('❌ Failed to fetch access token.');
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  Future webpayment({required String orderIdData, required BuildContext context, required String currency, required String amountData}) async {
    orderId = orderIdData;
    amount = amountData;

    String apiUrl = orangeMoneyModel.value.isSandbox == true ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment' : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment';

    // ✅ Ensure amount formatted correctly
    String formattedAmount = double.parse(amountData).toStringAsFixed(2);

    Map<String, String> requestBody = {
      "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
      "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : currency,
      "order_id": orderId,
      "amount": formattedAmount,
      "reference": 'Y-Note Test',
      "lang": "en",
      "return_url": orangeMoneyModel.value.returnUrl!.toString(),
      "cancel_url": orangeMoneyModel.value.cancelUrl!.toString(),
      "notif_url": orangeMoneyModel.value.notifyUrl ?? '',
    };

    debugPrint('💳 Creating Web Payment...');
    debugPrint('📡 POST $apiUrl');
    debugPrint('📦 Request Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(requestBody),
    );

    debugPrint('🔍 Response Code: ${response.statusCode}');
    debugPrint('📨 Response Body: ${response.body}');

    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['message'] == 'OK') {
        payToken = responseData['pay_token'];
        debugPrint('✅ Payment Token: $payToken');
        debugPrint('🌍 Payment URL: ${responseData['payment_url']}');
        return responseData['payment_url'];
      } else {
        debugPrint('⚠️ Unexpected message: ${responseData['message']}');
        return '';
      }
    } else {
      debugPrint('❌ Payment request failed.');
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  static void reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
    debugPrint('🌀 OrangePay reset completed.');
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
}
