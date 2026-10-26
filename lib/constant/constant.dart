import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/platform_fee_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/zone_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/utils/preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_product_model.dart';
import '../models/coupon_model.dart';
import '../models/email_template_model.dart';
import '../models/language_model.dart';
import '../models/mail_setting.dart';
import '../models/section_model.dart';
import '../utils/bidding_settings.dart';
import '../utils/driver_trip_settings.dart';
import '../service/fire_store_utils.dart';
import '../themes/show_toast_dialog.dart';
import '../widget/permission_dialog.dart';
import 'package:http/http.dart' as http;

RxList<CartProductModel> cartItem = <CartProductModel>[].obs;

class Constant {
  static const userPlaceHolder = "assets/images/user_placeholder.png";

  static String senderId = '';
  static String jsonNotificationFileURL = '';
  static String appVersion = '1.0';
  static String? country = "";
  /// Which map the in-app view draws: `osm` for the built-in OpenStreetMap
  /// view, anything else for Google Maps.
  ///
  /// Set from `settings/DriverNearBy`, which is read over the network at
  /// launch; until it lands this is what the screens draw. OpenStreetMap is
  /// the fallback because it needs no API key, so it draws on any project - a
  /// Google map on a project whose Maps key is rejected draws nothing at all.
  /// [restoreMapSettings] puts the admin's real choice back before the first
  /// frame anyway.
  static String? selectedMapType = "osm";

  /// Restores the last map configuration the admin set, from the device.
  /// Called from `main()` before `runApp`.
  static void restoreMapSettings() {
    final String cachedSelected = Preferences.getString(Preferences.selectedMapTypeKey);
    if (cachedSelected.isNotEmpty) selectedMapType = cachedSelected;
    final String cachedMapType = Preferences.getString(Preferences.mapTypeKey);
    if (cachedMapType.isNotEmpty) mapType = cachedMapType;
  }

  /// Remembers the configuration a settings read just applied.
  static void rememberMapSettings() {
    Preferences.setString(Preferences.selectedMapTypeKey, selectedMapType ?? 'osm');
    Preferences.setString(Preferences.mapTypeKey, mapType ?? 'inappmap');
  }
  static String? websiteUrl = 'https://jeomart.com/';
  static String privacyPolicyUrl = 'https://jeomart.com/privacy';
  static String termsAndConditionsUrl = 'https://jeomart.com/terms';
  static MailSettings? mailSettings;
  static bool isSubscriptionModelApplied = false;
  static CurrencyModel? currencyData;
  static SectionModel? sectionConstantModel;
  static geolocator.Position? currentLocation;

  static String cabServiceType = "cab-service";
  static String parcelServiceType = "parcel-service";

  static bool isZoneAvailable = false;
  static ZoneModel? selectedZone;
  static List<ZoneModel> zoneList = [];

  static PlatformFeeModel? platformFeeModel;

  static String? taxScope = '';
  static List<TaxModel>? taxProductList = []; //multivendor , e-commarce, ondemand
  static List<TaxModel>? orderProductTaxList = []; //multivendor , e-commarce, ondemand || parcel , rental , cabservice
  static List<TaxModel>? driverDeliveryTaxList = []; //multivendor , e-commarce, ondemand
  static List<TaxModel>? packagingTaxList = []; //multivendor , e-commarce, ondemand
  static List<TaxModel>? platformTaxList = []; //multivendor , e-commarce, ondemand  || parcel , rental , cabservice

  static List sectionColor = [
    [Color(0xFFFEF8E7), Color(0xFFF7CD59)],
    [Color(0xFFEEEBF9), Color(0xFF8F7CD8)],
    [Color(0xFFFFF8E5), Color(0xFFF7CD59)],
    [Color(0xFFF5E5FF), Color(0xFFCC80FF)],
    [Color(0xFFFAEBEB), Color(0xFFDB7474)],
    [Color(0xFFE5F9FF), Color(0xFF72DEFF)],
    [Color(0xFFEFF5F1), Color(0xFFADCEB7)],
    [Color(0xFFEAFBF1), Color(0xFF85E5AE)],
    [Color(0xFFE7F8FE), Color(0xFF529DB6)],
    [Color(0xFFEEEBF9), Color(0xFF8F7CD8)],
  ];

  static List colorList = [
    Color(0xFFFFBC99),
    const Color(0xFFCABDFF),
    const Color(0xFFB1E5FC),
    const Color(0xFFB5EBCD),
    const Color(0xFFFFD88D),
    const Color(0xFFCBEBA4),
    const Color(0xFFFB9B9B),
    const Color(0xFFF8B0ED),
    const Color(0xFFAFC6FF),
  ];

  static String userRoleDriver = 'driver';
  static String userRoleCustomer = 'customer';
  static String userRoleVendor = 'vendor';
  static String userRoleProvider = 'provider';
  static String userRoleWorker = 'worker';

  static ShippingAddress selectedLocation = ShippingAddress();

  // Default browsing location for guests (Kohat) until they set their own.
  static ShippingAddress defaultGuestLocation = ShippingAddress(
    id: 'guest_default',
    addressAs: 'Kohat',
    locality: 'Kohat, Pakistan',
    location: UserLocation(latitude: 33.5869, longitude: 71.4414),
    isDefault: true,
  );

  static UserModel? userModel;
  static const globalUrl ='https://jeomart.com/';

  static String mapAPIKey = "YOUR_GOOGLE_MAPS_API_KEY";
  static String placeHolderImage = "https://placehold.co/600x400/EEE/31343C";

  /// How long a map, route or marker-icon request may take before it is
  /// abandoned.
  ///
  /// `package:http` has **no** default timeout: a connection that opens and
  /// then stalls blocks its `await` for as long as the socket lives, which on a
  /// flaky mobile connection can be minutes. Every one of these calls is on a
  /// screen-load path, so a stalled one is a screen that never finishes
  /// drawing - and where a blocking loader is up, an app that looks frozen.
  ///
  /// These particular requests are all decoration: a route line, a marker
  /// picture. Every call site already falls back to drawing without them, so
  /// giving up is strictly better than waiting. Payment calls are deliberately
  /// *not* given this - abandoning one mid-authorisation is a worse outcome
  /// than a slow screen.
  static const Duration mapRequestTimeout = Duration(seconds: 15);
  static String defaultCountryCode = "+357";
  static String defaultCountry = "CY";

  static bool isCashbackActive = false;
  static bool isEnableOTPTripStart = false;
  static bool isEnableOTPTripStartForRental = false;

  static String distanceType = "km";

  static String googlePlayLink ="https://play.google.com/store/apps/details?id=com.jeo.customer";
  static String appStoreLink = "";
  static String termsAndConditions = "";
  static String privacyPolicy = "";
  static String supportURL = "";
  static String minimumAmountToDeposit = "0.0";
  static String minimumAmountToWithdrawal = "0.0";
  static bool? walletSetting = true;
  static bool? storyEnable = true;
  static bool? specialDiscountOffer = true;

  static const String orderPlaced = "Order Placed";
  static const String orderAccepted = "Order Accepted";
  static const String orderRejected = "Order Rejected";
  static const String orderCancelled = "Order Cancelled";
  static const String driverPending = "Driver Pending";
  static const String driverRejected = "Driver Rejected";
  static const String driverAccepted = 'Driver Accepted';
  static const String orderShipped = "Order Shipped";
  static const String orderInTransit = "In Transit";
  static const String orderCompleted = "Order Completed";

  /// Global bidding / counter-offer configuration, from `settings/biddingSettings`.
  ///
  /// Defaults to everything off, so a missing or unreadable settings document
  /// leaves the taxi flow behaving exactly as it did before bidding existed.
  static BiddingSettings biddingSettings = BiddingSettings.disabled;

  /// Whether the customer should be offered the bidding flow at all.
  ///
  /// Reduces to `biddingSettings.enabled` whenever the settings document has
  /// no `testUids` entry, which is its production state - see
  /// [BiddingSettings.testUids].
  static bool get isBiddingEnabled =>
      biddingSettings.isEnabledFor(FireStoreUtils.getCurrentUid());

  /// Driver-created trip configuration, from `settings/driverTripsSettings`.
  ///
  /// The driver app has always read this for the visibility window it writes
  /// onto a trip. The customer app reads it for the radius, because the
  /// customer is the one whose distance from a trip decides whether it is
  /// listed. Defaults to no radius, so an unreadable document shows every
  /// trip rather than none.
  static DriverTripSettings driverTripSettings = DriverTripSettings.defaults;

  static const String orderAssigned = "Order Assigned";
  static const String orderOngoing = "Order Ongoing";
  static const String bookingPlaced = "booking_placed";

  static CurrencyModel? currencyModel;
  static List<VendorModel>? restaurantList = [];

  static String walletTopup = "wallet_topup";
  static String newVendorSignup = "new_vendor_signup";
  static String payoutRequestStatus = "payout_request_status";
  static String payoutRequest = "payout_request";

  static String scheduleOrder = "schedule_order";
  static String dineInPlaced = "dinein_placed";
  static String dineInCanceled = "dinein_canceled";
  static String dineinAccepted = "dinein_accepted";
  static String restaurantRejected = "restaurant_rejected";
  static String driverCompleted = "driver_completed";
  static String restaurantAccepted = "restaurant_accepted";
  static String takeawayCompleted = "takeaway_completed";
  static String newParcelBook = "new_parcel_book";
  static String newOnDemandBook = "new_ondemand_book";
  static String newOrderPlaced = "new_order_placed";
  static String orderPlacedNotification = "order_placed";
  static String newCabRideBook = "new_ride_book";
  static String newBidOfferNotification = "new_bid_offer";
  static String bidOfferAcceptedNotification = "bid_offer_accepted";
  static String bidOfferRejectedNotification = "bid_offer_rejected";
  static String bidRequestClosedNotification = "bid_request_closed";
  static String tripReservedNotification = "trip_reserved";
  static String tripCancelledNotification = "trip_cancelled";
  static String newCarRideBook = "new_car_book";

  static String? mapType = "inappmap";

  static String? we = "google";

  static String? adminType = "admin";

  static bool isEnableAdsFeature = true;
  static bool isSelfDeliveryFeature = false;

  static double getDoubleVal(dynamic input) {
    if (input == null) return 0.1;
    if (input is int) return input.toDouble();
    if (input is double) return input;
    return 0.1;
  }

  static bool checkZoneCheck(double latitude, double longLatitude) {
    bool isZoneAvailable = false;
    for (var element in Constant.zoneList) {
      if (Constant.isPointInPolygon(LatLng(latitude, longLatitude), element.area!)) {
        isZoneAvailable = true;
        break;
      } else {
        isZoneAvailable = false;
      }
    }
    return isZoneAvailable;
  }

  static String? getZoneId(double latitude, double longLatitude) {
    String? zoneId;
    for (var element in Constant.zoneList) {
      if (Constant.isPointInPolygon(LatLng(latitude, longLatitude), element.area!)) {
        zoneId = element.id;
        break;
      }
    }
    return zoneId;
  }

  static String getReferralCode() {
    var rng = Random();
    return (rng.nextInt(900000) + 100000).toString(); // 6 digit
  }

  /// Gate for account-only actions (add to cart, favourites, checkout…).
  /// Returns true when a user is signed in. For guests it routes to the
  /// login screen and returns false, so callers show the control and guide
  /// the user to sign in instead of hiding it.
  static bool requireLogin() {
    if (userModel != null) return true;
    Get.to(() => const LoginScreen());
    return false;
  }

  static Future<void> checkPermission({required BuildContext context, required Function() onTap}) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      ShowToastDialog.showToast("You have to allow location permission to use your location");
    } else if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const PermissionDialog();
        },
      );
    } else {
      await onTap();
    }
  }

  static bool get isRtl {
    final locale = Get.locale ?? Get.deviceLocale ?? const Locale('en');
    return Bidi.isRtlLanguage(locale.languageCode);
  }

  static bool isExpire(VendorModel venderModel) {
    bool isPlanExpire = false;
    if (venderModel.subscriptionPlan?.id != null) {
      if (venderModel.subscriptionExpiryDate == null) {
        if (venderModel.subscriptionPlan?.expiryDay == '-1') {
          isPlanExpire = false;
        } else {
          isPlanExpire = true;
        }
      } else {
        DateTime expiryDate = venderModel.subscriptionExpiryDate!.toDate();
        isPlanExpire = expiryDate.isBefore(DateTime.now());
      }
    } else {
      isPlanExpire = true;
    }
    return isPlanExpire;
  }

  static bool isExpireDate({required bool expiryDay, Timestamp? subscriptionExpiryDate}) {
    bool isPlanExpire = false;
    if (expiryDay == true) {
      isPlanExpire = false;
    } else {
      if (subscriptionExpiryDate != null) {
        DateTime expiryDate = subscriptionExpiryDate.toDate();
        isPlanExpire = expiryDate.isBefore(DateTime.now());
      } else {
        isPlanExpire = true;
      }
    }

    return isPlanExpire;
  }

  static Future<void> showProgress(String message, bool isDismissible) async {
    ShowToastDialog.showLoader("$message ");
  }

  static void hideProgress() {
    ShowToastDialog.closeLoader();
  }

  static String amountShow({required String? amount}) {
    if (currencyModel!.symbolatright == true) {
      return "${double.parse(amount.toString()).toStringAsFixed(currencyModel?.decimal ?? 0)} ${currencyModel!.symbol.toString()}";
    } else {
      return "${currencyModel!.symbol.toString()} ${amount == null || amount.isEmpty ? "0.0" : double.parse(amount.toString()).toStringAsFixed(currencyModel?.decimal ?? 0)}";
    }
  }

  static Color statusColor({required String? status}) {
    if (status == orderPlaced) {
      return AppThemeData.ecommerce300;
    } else if (status == orderAccepted || status == orderCompleted) {
      return AppThemeData.success400;
    } else if (status == orderRejected) {
      return AppThemeData.danger300;
    } else {
      return AppThemeData.warning300;
    }
  }

  static Color statusText({required String? status}) {
    if (status == orderPlaced) {
      return AppThemeData.grey50;
    } else if (status == orderAccepted || status == orderCompleted) {
      return AppThemeData.grey50;
    } else if (status == orderRejected) {
      return AppThemeData.grey50;
    } else {
      return AppThemeData.grey900;
    }
  }

  static String productCommissionPrice(VendorModel vendorModel, String price) {
    String commission = "0";
    if (sectionConstantModel!.adminCommision!.isEnabled == true) {
      if (vendorModel.adminCommission == null) {
        if (sectionConstantModel!.adminCommision!.commissionType!.toLowerCase() == "Percent".toLowerCase() ||
            sectionConstantModel!.adminCommision!.commissionType?.toLowerCase() == "Percentage".toLowerCase()) {
          commission = (double.parse(price) + (double.parse(price) * double.parse(sectionConstantModel!.adminCommision!.amount.toString()) / 100)).toString();
        } else {
          commission = (double.parse(price) + double.parse(sectionConstantModel!.adminCommision!.amount.toString())).toString();
        }
      } else {
        if (vendorModel.adminCommission!.commissionType!.toLowerCase() == "Percent".toLowerCase() || vendorModel.adminCommission!.commissionType?.toLowerCase() == "Percentage".toLowerCase()) {
          commission = (double.parse(price) + (double.parse(price) * double.parse(vendorModel.adminCommission!.amount.toString()) / 100)).toString();
        } else {
          commission = (double.parse(price) + double.parse(vendorModel.adminCommission!.amount.toString())).toString();
        }
      }
    } else {
      commission = price;
    }

    return commission;
  }

  static double calculateTax({String? amount, TaxModel? taxModel}) {
    double taxAmount = 0.0;
    if (taxModel != null && taxModel.enable == true) {
      if (taxModel.type == "fix") {
        taxAmount = double.parse(taxModel.tax.toString());
      } else {
        taxAmount = (double.parse(amount.toString()) * double.parse(taxModel.tax!.toString())) / 100;
      }
    }
    return taxAmount;
  }

  static double calculateDiscount({String? amount, CouponModel? offerModel}) {
    double taxAmount = 0.0;
    if (offerModel != null) {
      if (offerModel.discountType == "Percentage" || offerModel.discountType == "percentage") {
        taxAmount = (double.parse(amount.toString()) * double.parse(offerModel.discount.toString())) / 100;
      } else {
        taxAmount = double.parse(offerModel.discount.toString());
      }
    }
    return taxAmount;
  }

  static bool statusCheckOpenORClose({required VendorModel vendorModel}) {
    final now = DateTime.now();
    var day = DateFormat('EEEE', 'en_US').format(now);
    var date = DateFormat('dd-MM-yyyy').format(now);
    for (var element in vendorModel.workingHours ?? []) {
      if (day == element.day.toString()) {
        if (element.timeslot!.isNotEmpty) {
          for (var element in element.timeslot!) {
            var start = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${element.from}");
            var end = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${element.to}");
            if (isCurrentDateInRange(start, end)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  static bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    final currentDate = DateTime.now();
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  static String calculateReview({required String? reviewCount, required String? reviewSum}) {
    if (0 == double.parse(reviewSum.toString()) && 0 == double.parse(reviewSum.toString())) {
      return "0";
    }
    return (double.parse(reviewSum.toString()) / double.parse(reviewCount.toString())).toStringAsFixed(1);
  }

  static String getUuid() {
    return const Uuid().v4();
  }

  static Widget loader() {
    return Center(child: CircularProgressIndicator(color: AppThemeData.primary300));
  }

  static Widget showEmptyView({required String message}) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Center(child: Text(message, style: TextStyle(fontFamily: AppThemeData.fontFamily, fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)));
  }

  static String maskingString(String documentId, int maskingDigit) {
    String maskedDigits = documentId;
    for (int i = 0; i < documentId.length - maskingDigit; i++) {
      maskedDigits = maskedDigits.replaceFirst(documentId[i], "*");
    }
    return maskedDigits;
  }

  String? validateRequired(String? value, String type) {
    if (value!.isEmpty) {
      return '$type required';
    }
    return null;
  }

  String? validateEmail(String? value) {
    String pattern = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = RegExp(pattern);
    if (value == null || value.isEmpty) {
      return "Email is Required";
    } else if (!regExp.hasMatch(value)) {
      return "Invalid Email";
    } else {
      return null;
    }
  }

  static String getDistance({required String lat1, required String lng1, required String lat2, required String lng2}) {
    double distance;
    double distanceInMeters = Geolocator.distanceBetween(double.parse(lat1), double.parse(lng1), double.parse(lat2), double.parse(lng2));
    if (distanceType == "miles") {
      distance = distanceInMeters / 1609;
    } else {
      distance = distanceInMeters / 1000;
    }
    return distance.toStringAsFixed(2);
  }

  bool hasValidUrl(String? value) {
    String pattern = r'(http|https)://[\w-]+(\.[\w-]+)+([\w.,@?^=%&amp;:/~+#-]*[\w@?^=%&amp;/~+#-])?';
    RegExp regExp = RegExp(pattern);
    if (value == null || value.isEmpty) {
      return false;
    } else if (!regExp.hasMatch(value)) {
      return false;
    }
    return true;
  }

  static Future<String> uploadUserImageToFireStorage(File image, String filePath, String fileName) async {
    Reference upload = FirebaseStorage.instance.ref().child('$filePath/$fileName');
    UploadTask uploadTask = upload.putFile(image);
    var downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  Future<void> launchURL(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  static Future<TimeOfDay?> selectTime(context) async {
    FocusScope.of(context).requestFocus(FocusNode()); //remove focus
    TimeOfDay? newTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (newTime != null) {
      return newTime;
    }
    return null;
  }

  static Future<DateTime?> selectDate(context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppThemeData.primary300, // header background color
              onPrimary: AppThemeData.grey900, // header text color
              onSurface: AppThemeData.grey900, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppThemeData.grey900, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
      initialDate: DateTime.now(),
      //get today's date
      firstDate: DateTime(2000),
      //DateTime.now() - not to allow to choose before today.
      lastDate: DateTime(2101),
    );
    return pickedDate;
  }

  static int calculateDifference(DateTime date) {
    DateTime now = DateTime.now();
    return DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  static String timestampToDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM dd,yyyy').format(dateTime);
  }

  static String timestampToDateTime(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM dd,yyyy hh:mm aa').format(dateTime);
  }

  static String timestampToDateTime2(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('EEE MMM d yyyy').format(dateTime);
  }

  static String timestampToTime(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('hh:mm aa').format(dateTime);
  }

  static String timestampToDateChat(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  static DateTime stringToDate(String openDineTime) {
    return DateFormat('HH:mm').parse(DateFormat('HH:mm').format(DateFormat("hh:mm a").parse((Intl.getCurrentLocale() == "en_US") ? openDineTime : openDineTime.toLowerCase())));
  }

  static LanguageModel getLanguage() {
    final String user = Preferences.getString(Preferences.languageCodeKey);
    Map<String, dynamic> userMap = jsonDecode(user);
    return LanguageModel.fromJson(userMap);
  }

  static String orderId({String orderId = ''}) {
    return "#$orderId";
    //return "#${(orderId).substring(orderId.length - 10)}";
  }

  static bool isPointInPolygon(LatLng point, List<GeoPoint> polygon) {
    int crossings = 0;
    for (int i = 0; i < polygon.length; i++) {
      int next = (i + 1) % polygon.length;
      if (polygon[i].latitude <= point.latitude && polygon[next].latitude > point.latitude || polygon[i].latitude > point.latitude && polygon[next].latitude <= point.latitude) {
        double edgeLong = polygon[next].longitude - polygon[i].longitude;
        double edgeLat = polygon[next].latitude - polygon[i].latitude;
        double interpol = (point.latitude - polygon[i].latitude) / edgeLat;
        if (point.longitude < polygon[i].longitude + interpol * edgeLong) {
          crossings++;
        }
      }
    }
    return (crossings % 2 != 0);
  }

  static SmtpServer get smtpServer => SmtpServer(
    mailSettings!.host.toString(),
    username: mailSettings!.userName.toString(),
    password: mailSettings!.password.toString(),
    port: 465,
    ignoreBadCertificate: false,
    ssl: true,
    allowInsecure: true,
  );

  /// How long a single e-mail may take before it is given up on.
  static const Duration _mailTimeout = Duration(seconds: 20);

  static Future<void> sendMail({String? subject, String? body, bool? isAdmin = false, List<dynamic>? recipients}) async {
    if (mailSettings == null) return;
    if (isAdmin == true) {
      recipients!.add(mailSettings!.userName.toString());
    }
    final message =
        Message()
          ..from = Address(mailSettings!.userName.toString(), mailSettings!.fromName.toString())
          ..recipients = recipients!
          ..subject = subject
          ..text = body
          ..html = body;

    try {
      // Bounded. `send` opens a real SMTP connection from the phone, and a mail
      // server that never answers used to leave this future hanging for the
      // operating system's own TCP timeout - minutes, on a booking that was
      // waiting for it behind a blocking loader.
      final sendReport = await send(message, smtpServer).timeout(_mailTimeout);
      print('Message sent: $sendReport');
    } on TimeoutException catch (e) {
      print('Mail timed out after ${_mailTimeout.inSeconds}s: $e');
    } on MailerException catch (e) {
      print('Mail error: $e');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    } catch (e) {
      // Catches SocketException (DNS failure, no network) and any other errors
      print('sendMail failed: $e');
    }

    // var connection = PersistentConnection(smtpServer);
    //
    // // Send the first message
    // await connection.send(message);
  }

  static Uri createCoordinatesUrl(double latitude, double longitude, [String? label]) {
    Uri uri;
    if (kIsWeb) {
      uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'});
    } else if (Platform.isAndroid) {
      var query = '$latitude,$longitude';
      if (label != null) query += '($label)';
      uri = Uri(scheme: 'geo', host: '0,0', queryParameters: {'q': query});
    } else if (Platform.isIOS) {
      var params = {'ll': '$latitude,$longitude'};
      if (label != null) params['q'] = label;
      uri = Uri.https('maps.apple.com', '/', params);
    } else {
      uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'});
    }

    return uri;
  }

  static Future<void> sendOrderEmail({required OrderModel orderModel}) async {
    double deliveryCharges = 0.0;
    double deliveryTips = 0.0;
    double subTotal = 0.0;
    double packagingCharge = 0.0;
    double platformFee = 0.0;
    double couponAmount = 0.0;
    double specialDiscountAmount = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double driverDeliveryTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;
    double platformTaxAmount = 0.0;
    double totalTaxAmount = 0.0;
    double totalAmountData = 0.0;

    for (var element in orderModel.products!) {
      final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

      final double qty = double.parse(element.quantity.toString());
      final double extras = double.parse(element.extrasPrice.toString());

      subTotal += (price * qty) + (extras * qty);
    }

    /// ---------------- DISCOUNTS ----------------
    couponAmount = double.parse(orderModel.discount.toString());

    if (orderModel.specialDiscount != null && orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = double.parse(orderModel.specialDiscount!['special_discount'].toString());
    }

    final double totalDiscount = couponAmount + specialDiscountAmount;

    /// ---------------- DISCOUNT RATIO ----------------
    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    /// ---------------- PRODUCT TAX (AFTER DISCOUNT) ----------------
    if (orderModel.taxScope == "product") {
      for (var element in orderModel.products!) {
        final double price = (double.parse(element.discountPrice.toString()) > 0) ? double.parse(element.discountPrice.toString()) : double.parse(element.price.toString());

        final double qty = double.parse(element.quantity.toString());
        final double extras = double.parse(element.extrasPrice.toString());

        final double itemAmount = (price * qty) + (extras * qty);

        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);

        for (var taxElement in element.taxSetting!) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    /// ---------------- ORDER LEVEL TAX ----------------
    if (orderModel.taxScope == "order") {
      for (var taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    /// ---------------- OTHER CHARGES ----------------
    deliveryCharges = double.parse(orderModel.deliveryCharge.toString());

    deliveryTips = double.parse(orderModel.tipAmount.toString());

    packagingCharge = double.parse(orderModel.vendor!.packagingCharge.toString());

    platformFee = double.parse(orderModel.platformFee ?? '0.0');

    /// ---------------- DELIVERY TAX ----------------
    if (orderModel.takeAway != true && orderModel.vendor?.isSelfDelivery != true) {
      for (var taxElement in orderModel.driverDeliveryTax ?? []) {
        driverDeliveryTaxAmount += Constant.calculateTax(amount: deliveryCharges.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- PACKAGING TAX ----------------
    if (packagingCharge > 0) {
      for (var taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- PLATFORM TAX ----------------
    if (platformFee > 0) {
      for (var taxElement in orderModel.platformTax ?? []) {
        platformTaxAmount += Constant.calculateTax(amount: platformFee.toString(), taxModel: taxElement);
      }
    }

    /// ---------------- TOTAL TAX ----------------
    totalTaxAmount = productTaxAmount + orderTaxAmount + driverDeliveryTaxAmount + packagingTaxAmount + platformTaxAmount;

    double driverAmount = orderModel.isFreeDelivery == true ? 0.0 : (deliveryCharges + deliveryTips);

    /// ---------------- FINAL TOTAL ----------------
    totalAmountData = (subTotal - totalDiscount) + totalTaxAmount + driverAmount + packagingCharge + platformFee;

    EmailTemplateModel? emailTemplateModel = await FireStoreUtils.getEmailTemplates(newOrderPlaced);

    if (emailTemplateModel != null) {
      String firstHTML = """
       <table style="width: 100%; border-collapse: collapse; border: 1px solid rgb(0, 0, 0);">
    <thead>
        <tr>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Product Name<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Quantity<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Price<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Extra Item Price<br></th>
            <th style="text-align: left; border: 1px solid rgb(0, 0, 0);">Total<br></th>
        </tr>
    </thead>
    <tbody>
    """;

      String newString = emailTemplateModel.message.toString();
      newString = newString.replaceAll("{username}", "${Constant.userModel!.firstName} ${Constant.userModel!.lastName}");
      newString = newString.replaceAll("{orderid}", orderModel.id.toString());
      newString = newString.replaceAll("{date}", DateFormat('yyyy-MM-dd').format(orderModel.createdAt!.toDate()));
      newString = newString.replaceAll("{address}", orderModel.address?.getFullAddress() ?? '');
      newString = newString.replaceAll("{paymentmethod}", orderModel.paymentMethod.toString());

      double total = 0.0;
      double specialDiscount = 0.0;
      double discount = 0.0;

      String specialLabel = '(${orderModel.specialDiscount!['special_discount_label']}${orderModel.specialDiscount!['specialType'] == "amount" ? currencyModel!.symbol : "%"})';
      List<String> htmlList = [];

      for (var element in orderModel.products!) {
        if (element.extrasPrice != null && element.extrasPrice!.isNotEmpty && double.parse(element.extrasPrice!) != 0.0) {
          total += double.parse(element.quantity.toString()) * double.parse(element.extrasPrice!);
        }
        total += double.parse(element.quantity.toString()) * double.parse(element.price.toString());

        List<dynamic>? addon = element.extras;
        String extrasDisVal = '';
        for (int i = 0; i < addon!.length; i++) {
          extrasDisVal += '${addon[i].toString().replaceAll("\"", "")} ${(i == addon.length - 1) ? "" : ","}';
        }
        String product = """
        <tr>
            <td style="width: 20%; border-top: 1px solid rgb(0, 0, 0);">${element.name}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${element.quantity}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${amountShow(amount: (double.parse(element.discountPrice.toString()) > 0.0 ? element.discountPrice : element.price.toString()))}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${amountShow(amount: element.extrasPrice.toString())}</td>
            <td style="width: 20%; border: 1px solid rgb(0, 0, 0);" rowspan="2">${amountShow(amount: ((double.parse(element.quantity.toString()) * double.parse(element.extrasPrice!) + (double.parse(element.quantity.toString()) * (double.parse((double.parse(element.discountPrice.toString()) > 0.0 ? element.discountPrice! : element.price!))))).toString()))}</td>
        </tr>
        <tr>
            <td style="width: 20%;">${extrasDisVal.isEmpty ? "" : "Extra Item : $extrasDisVal"}</td>
        </tr>
    """;
        htmlList.add(product);
      }

      if (orderModel.specialDiscount!.isNotEmpty) {
        specialDiscount = double.parse(orderModel.specialDiscount!['special_discount'].toString());
      }

      if (orderModel.couponId != null && orderModel.couponId!.isNotEmpty) {
        discount = double.parse(orderModel.discount.toString());
      }

      List<String> taxHtmlList = [];
      if (orderModel.taxScope == 'product') {
        for (var element in orderModel.taxSetting ?? []) {
          if (element.scope == 'product') {
            String taxHtml =
                """<span style="font-size: 1rem;">${element.title} ${'Tax on item total'}: ${amountShow(amount: calculateTax(amount: (total - discount - specialDiscount).toString(), taxModel: element).toString())}</span>""";
            taxHtmlList.add(taxHtml);
          }
        }
      }
      if (orderModel.taxScope == "product") {
        String taxHtml = """<br><span style="font-size: 1rem;">${'Tax on item total'}: ${amountShow(amount: productTaxAmount.toString())}</span>""";
        taxHtmlList.add(taxHtml);
      }

      if (orderModel.taxScope == "order") {
        String taxHtml = """<br><span style="font-size: 1rem;">${'Tax on Order Total'}: ${amountShow(amount: orderTaxAmount.toString())}</span>""";
        taxHtmlList.add(taxHtml);
      }

      if (deliveryCharges > 0.0) {
        for (var element in orderModel.driverDeliveryTax ?? []) {
          if (element.scope == 'delivery') {
            String taxHtml =
                """<br><span style="font-size: 1rem;">${element.title} ${'Tax on Delivery Fee'}: ${amountShow(amount: calculateTax(amount: (orderModel.deliveryCharge).toString(), taxModel: element).toString())}</span>""";
            taxHtmlList.add(taxHtml);
          }
        }
      }

      if (packagingCharge > 0.0) {
        for (var element in orderModel.packagingTax ?? []) {
          if (element.scope == 'packaging') {
            String taxHtml =
                """<br><span style="font-size: 1rem;">${element.title} ${'Tax on Packaging Fee'}: ${amountShow(amount: calculateTax(amount: (packagingCharge).toString(), taxModel: element).toString())}</span>""";
            taxHtmlList.add(taxHtml);
          }
        }
      }
      if (platformFee > 0.0) {
        for (var element in orderModel.platformTax ?? []) {
          if (element.scope == 'platform') {
            String taxHtml =
                """<br><span style="font-size: 1rem;">${element.title} ${'Tax on Platform Fee'}: ${amountShow(amount: calculateTax(amount: (platformFee).toString(), taxModel: element).toString())}</span>""";
            taxHtmlList.add(taxHtml);
          }
        }
      }
      taxHtmlList.add("""<br><span style="font-size: 1rem;"> Total Tax: ${amountShow(amount: totalTaxAmount.toString())}</span>""");

      newString = newString.replaceAll("{subtotal}", amountShow(amount: subTotal.toString()));
      newString = newString.replaceAll("{coupon}", orderModel.couponId ?? '');
      newString = newString.replaceAll("{discountamount}", amountShow(amount: orderModel.discount.toString()));
      newString = newString.replaceAll("{specialcoupon}", specialLabel);
      newString = newString.replaceAll("{specialdiscountamount}", amountShow(amount: specialDiscount.toString()));
      newString = newString.replaceAll("{shippingcharge}", amountShow(amount: deliveryCharges.toString()));
      newString = newString.replaceAll("{packagingcharge}", amountShow(amount: packagingCharge.toString()));
      newString = newString.replaceAll("{platformcharge}", amountShow(amount: platformFee.toString()));
      newString = newString.replaceAll("{tipamount}", amountShow(amount: deliveryTips.toString()));
      newString = newString.replaceAll("{totalAmount}", amountShow(amount: totalAmountData.toString()));

      String tableHTML = htmlList.join();
      String lastHTML = "</tbody></table>";
      newString = newString.replaceAll("{productdetails}", firstHTML + tableHTML + lastHTML);
      newString = newString.replaceAll("{taxdetails}", taxHtmlList.join());
      newString = newString.replaceAll("{newwalletbalance}.", amountShow(amount: Constant.userModel!.walletAmount.toString()));

      String subjectNewString = emailTemplateModel.subject.toString();
      subjectNewString = subjectNewString.replaceAll("{orderid}", orderModel.id.toString());

      await sendMail(subject: subjectNewString, isAdmin: emailTemplateModel.isSendToAdmin, body: newString, recipients: [Constant.userModel!.email]);
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  String getTimeInTheMinutes({required double distance}) {
    double averageSpeed = 40.0;
    double estimatedTime = (distance / averageSpeed) * 60;
    return "${estimatedTime.toStringAsFixed(2)} minutes";
  }

  static String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();

    return DateFormat("d-MM-yyyy h:mm a").format(dateTime);
  }

  /// Calculate tax amount for a single tax model
  static double getTaxValue({required String amount, required TaxModel taxModel}) {
    double taxVal = 0.0;
    if (taxModel.enable == true) {
      if (taxModel.type == "fix") {
        taxVal = double.tryParse(taxModel.tax.toString()) ?? 0.0;
      } else {
        taxVal = (double.tryParse(amount) ?? 0.0) * (double.tryParse(taxModel.tax.toString()) ?? 0.0) / 100;
      }
    }
    return taxVal;
  }

  Future<Uint8List> getBytesFromUrl(String url, {int width = 100}) async {
    try {
      final http.Response response = await http.get(Uri.parse(url)).timeout(mapRequestTimeout);
      if (response.statusCode != 200) throw Exception("Failed to load image");

      final Uint8List bytes = response.bodyBytes;
      final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      print("⚠️ getBytesFromUrl error: $e — using default cab icon");
      final ByteData data = await rootBundle.load('assets/images/ic_cab.png');
      return data.buffer.asUint8List();
    }
  }

  static double calculatePlatFormMeModel({PlatformFeeModel? platFromFeeModel}) {
    double taxAmount = 0.0;
    if (platFromFeeModel != null && platFromFeeModel.enable == true) {
      taxAmount = double.parse(platFromFeeModel.fee.toString());
    }
    return taxAmount;
  }

  static String dateAndTimeFormatTimestamp(Timestamp? timestamp) {
    var format = DateFormat('dd MMM yyyy hh:mm aa'); // <- use skeleton here
    return format.format(timestamp!.toDate());
  }

  static String getTaxDisplayText(List<TaxModel>? taxes) {
    if (taxes == null || taxes.isEmpty) return '';

    return taxes
        .map((tax) {
          if (tax.type == "fix") {
            return "${tax.title} (${Constant.amountShow(amount: tax.tax)})";
          } else {
            return "${tax.title} (${tax.tax}%)";
          }
        })
        .join(', ');
  }

  // Future<Uint8List> getBytesFromUrl(String url, {int width = 100}) async {
  //   final http.Response response = await http.get(Uri.parse(url));
  //   if (response.statusCode != 200) {
  //     throw Exception("Failed to load image from $url");
  //   }
  //
  //   final Uint8List bytes = response.bodyBytes;
  //
  //   // Decode & resize
  //   final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  //   final ui.FrameInfo frameInfo = await codec.getNextFrame();
  //
  //   final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
  //   return byteData!.buffer.asUint8List();
  // }
}

extension StringExtension on String {
  String capitalizeString() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
