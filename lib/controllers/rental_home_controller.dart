import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/models/rental_package_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/rental_service/rental_conformation_screen.dart';
import 'package:customer/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;
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
import '../models/rental_vehicle_type.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../service/fire_store_utils.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/preferences.dart';
import '../utils/utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:customer/utils/city_filter.dart';

class RentalHomeController extends GetxController {
  RxBool isLoading = false.obs;

  // Location input
  final Rx<TextEditingController> sourceTextEditController = TextEditingController().obs;

  // Selected date
  Rx<DateTime> selectedDate = DateTime.now().obs;

  // Vehicle list + selected vehicle
  RxList<RentalVehicleType> vehicleTypes = <RentalVehicleType>[].obs;
  Rx<RentalVehicleType?> selectedVehicleType = Rx<RentalVehicleType?>(null);

  RxList<RentalPackageModel> rentalPackages = <RentalPackageModel>[].obs;
  Rx<RentalPackageModel?> selectedPackage = Rx<RentalPackageModel?>(null);

  Rx<UserModel> userModel = UserModel().obs;

  final RxString selectedPaymentMethod = ''.obs;

  final Rx<gmaps.LatLng> departureLatLong = gmaps.LatLng(0.0, 0.0).obs;
  final Rx<latlong.LatLng> departureLatLongOsm = latlong.LatLng(0.0, 0.0).obs;

  @override
  void onInit() {
    super.onInit();
    if (Constant.userModel != null) {
      userModel.value = Constant.userModel!;
    }
    getVehicleType();
    fetchCurrentLocation();
  }

  void fetchCurrentLocation() async {
    try {
      Position? position = await Utils.getCurrentLocation();
      if (position != null) {
        Constant.currentLocation = position;

        // Set default coordinates for Google or OSM
        departureLatLong.value = gmaps.LatLng(position.latitude, position.longitude);
        departureLatLongOsm.value = latlong.LatLng(position.latitude, position.longitude);

        // Get readable address
        String address = await Utils.getAddressFromCoordinates(position.latitude, position.longitude);
        sourceTextEditController.value.text = address;
      }
    } catch (e) {
      ShowToastDialog.showToast("Unable to fetch current location".tr);
    }
  }

  /// Fetch Vehicle Types
  Future<void> getVehicleType() async {
    isLoading.value = true;
    await FireStoreUtils.getRentalVehicleType().then((value) async {
      // Only the vehicle types offered in the customer's city (admin panel).
      vehicleTypes.value = CityFilter.keep(value, (RentalVehicleType v) => v.zoneIds, await CityFilter.customerZones());
      if (vehicleTypes.isNotEmpty) {
        selectedVehicleType.value = vehicleTypes[0];
        await getRentalPackage();
      }
    });
    await getPaymentSettings();
    isLoading.value = false;
  }

  /// Date Picker
  Future<void> pickDateTime(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(2100));
    if (pickedDate == null) return;
    final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime == null) return;
    final DateTime pickedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    if (!pickedDateTime.isAfter(now)) {
      ShowToastDialog.showToast("Please select a future date & time".tr);
      return;
    }

    selectedDate.value = pickedDateTime;
  }

  Future<void> getRentalPackage() async {
    await FireStoreUtils.getRentalPackage(selectedVehicleType.value!.id.toString()).then((value) {
      rentalPackages.value = value;
      if (rentalPackages.isNotEmpty) {
        selectedPackage.value = rentalPackages[0];
      }
    });
  }

  void completeOrder() {
    DestinationLocation sourceLocation = DestinationLocation(
      latitude: Constant.selectedMapType == 'osm' ? departureLatLongOsm.value.latitude : departureLatLong.value.latitude,
      longitude: Constant.selectedMapType == 'osm' ? departureLatLongOsm.value.longitude : departureLatLong.value.longitude,
    );

    print("=====>");
    print(sourceTextEditController.value.text);

    RentalOrderModel rentalOrderModel = RentalOrderModel();
    rentalOrderModel.id = Constant.getUuid();
    rentalOrderModel.authorID = userModel.value.id;
    rentalOrderModel.author = userModel.value;
    rentalOrderModel.rentalVehicleType = selectedVehicleType.value;
    rentalOrderModel.vehicleId = selectedVehicleType.value!.id;
    rentalOrderModel.sectionId = Constant.sectionConstantModel!.id;
    rentalOrderModel.sourceLocationName = sourceTextEditController.value.text;
    rentalOrderModel.bookingDateTime = Timestamp.fromDate(selectedDate.value);
    rentalOrderModel.paymentMethod = selectedPaymentMethod.value;
    rentalOrderModel.paymentStatus = false;
    rentalOrderModel.status = Constant.orderPlaced;
    rentalOrderModel.subTotal = selectedPackage.value!.baseFare;
    rentalOrderModel.rentalPackageModel = selectedPackage.value;
    rentalOrderModel.taxSetting = Constant.orderProductTaxList;
    rentalOrderModel.createdAt = Timestamp.now();
    rentalOrderModel.sourceLocation = sourceLocation;
    rentalOrderModel.adminCommission = Constant.sectionConstantModel!.adminCommision!.amount;
    rentalOrderModel.adminCommissionType = Constant.sectionConstantModel!.adminCommision!.commissionType;
    rentalOrderModel.sourcePoint = G(
      geopoint: GeoPoint(sourceLocation.latitude ?? 0.0, sourceLocation.longitude ?? 0.0),
      geohash: Geoflutterfire().point(latitude: sourceLocation.latitude ?? 0.0, longitude: sourceLocation.longitude ?? 0.0).hash,
    );
    rentalOrderModel.zoneId = Constant.getZoneId(sourceLocation.latitude ?? 0.0, sourceLocation.longitude ?? 0.0);

    log(rentalOrderModel.toJson().toString());
    Get.back();
    Get.back();

    Get.to(() => RentalConformationScreen(), arguments: {"rentalOrderModel": rentalOrderModel});
  }

  void setDepartureMarker(double lat, double lng) {
    if (Constant.selectedMapType == 'osm') {
      departureLatLongOsm.value = latlong.LatLng(lat, lng);
    } else {
      departureLatLong.value = gmaps.LatLng(lat, lng);
    }
  }

  // final Rx<LatLng> departureLatLong = const LatLng(0.0, 0.0).obs;
  // final Rx<latlong.LatLng> departureLatLongOsm = latlong.LatLng(0.0, 0.0).obs;

  // void setDepartureMarker(double lat, double long) {
  //   if (Constant.selectedMapType == 'osm') {
  //     departureLatLongOsm.value = latlong.LatLng(lat, long);
  //   } else {
  //     departureLatLong.value = LatLng(lat, long);
  //   }
  // }

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
    });
  }
}
