import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/utils/vehicle_display.dart';
import 'package:customer/models/ride_bid_model.dart';
import 'package:customer/utils/ride_bidding_state.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_coupon_code_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_border.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:latlong2/latlong.dart' as latlong;
import '../../constant/constant.dart';
import '../../controllers/cab_booking_controller.dart';
import '../../controllers/cab_dashboard_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../service/fire_store_utils.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../../themes/text_field_widget.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import 'package:location/location.dart';
import 'package:customer/utils/app_image_cache.dart';

class CabBookingScreen extends StatelessWidget {
  const CabBookingScreen({super.key, this.bidding = false});

  /// Whether this screen was opened from the **Bid** section to name a price,
  /// rather than from **Ride** on the home screen to book an ordinary metered
  /// city trip.
  ///
  /// This one flag is the whole difference between the two flows, and it is
  /// what was missing. The bidding UI used to be switched on by the global
  /// admin-panel setting alone, so the moment bidding was enabled the normal
  /// "choose a vehicle, pay the metered fare" booking was *replaced* by the
  /// offer flow for every customer, with no way back to it. Booking a normal
  /// ride and placing a bid are two different things and now live in two
  /// different places: Ride books, Bid bids.
  final bool bidding;

  /// The bidding UI appears only when the customer actually asked for it *and*
  /// the feature is switched on in the admin panel. Opened from Ride this is
  /// always false, so the normal booking flow is untouched by that setting.
  bool get isBidMode => bidding && Constant.isBiddingEnabled;

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabBookingController(),
      builder: (controller) {
        // A plain field, not an observable, so assigning it can never schedule
        // a rebuild - which makes it safe from here, and re-asserts the mode
        // on every rebuild even when GetX hands back a controller that an
        // earlier screen created.
        controller.bidMode = bidding;
        return Scaffold(
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Stack(
                    children: [
                      Constant.selectedMapType == "osm"
                          ? flutterMap.FlutterMap(
                            mapController: controller.mapOsmController,
                            options: flutterMap.MapOptions(
                              // Resolved before `isLoading` went false, so this
                              // is already the customer's own location on the
                              // very first frame. An in-progress ride still
                              // wins, because the map should open on the ride.
                              initialCenter:
                                  controller.currentOrder.value.id != null && controller.currentOrder.value.sourceLocation != null
                                      ? latlong.LatLng(
                                        double.parse(controller.currentOrder.value.sourceLocation!.latitude.toString()),
                                        double.parse(controller.currentOrder.value.sourceLocation!.longitude.toString()),
                                      )
                                      : controller.mapStart.value,
                              initialZoom: 16,
                            ),
                            children: [
                              flutterMap.TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: Platform.isAndroid ? "com.jeo.customer" : "com.jeomart.customer",
                              ),
                              flutterMap.MarkerLayer(markers: controller.osmMarker),
                              if (controller.routePoints.isNotEmpty) flutterMap.PolylineLayer(polylines: [flutterMap.Polyline(points: controller.routePoints, strokeWidth: 5.0, color: Colors.blue)]),
                            ],
                          )
                          : GoogleMap(
                            onMapCreated: controller.onGoogleMapCreated,
                            initialCameraPosition: CameraPosition(target: controller.currentPosition.value, zoom: 16),
                            myLocationEnabled: true,
                            zoomControlsEnabled: true,
                            zoomGesturesEnabled: true,
                            polylines: Set<Polyline>.of(controller.polyLines.values),
                            markers: controller.markers.toSet(), // reactive marker set
                          ),
                      Positioned(
                        top: 50,
                        left: Constant.isRtl ? null : 20,
                        right: Constant.isRtl ? 20 : null,
                        child: InkWell(
                          onTap: () {
                            if (controller.bottomSheetType.value == "vehicleSelection") {
                              controller.bottomSheetType.value = "location";
                            } else if (controller.bottomSheetType.value == "payment") {
                              controller.bottomSheetType.value = "vehicleSelection";
                            } else if (controller.bottomSheetType.value == "conformRide") {
                              controller.bottomSheetType.value = "payment";
                            } else if (controller.bottomSheetType.value == "waitingDriver" || controller.bottomSheetType.value == "driverDetails") {
                              Get.back(result: true);
                            } else {
                              Get.back();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50, borderRadius: BorderRadius.circular(30)),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Center(child: Icon(Icons.arrow_back_ios_new, color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50, size: 20)),
                            ),
                          ),
                        ),
                      ),
                      controller.bottomSheetType.value == "location"
                          ? searchLocationBottomSheet(context, controller, isDark)
                          : controller.bottomSheetType.value == "vehicleSelection"
                          ? vehicleSelection(context, controller, isDark)
                          : controller.bottomSheetType.value == "payment"
                          ? paymentBottomSheet(context, controller, isDark)
                          : controller.bottomSheetType.value == "conformRide"
                          ? conformBottomSheet(context, isDark)
                          : controller.bottomSheetType.value == "waitingForDriver"
                          ? waitingDialog(context, controller, isDark)
                          : controller.bottomSheetType.value == "driverDetails"
                          ? driverDialog(context, controller, isDark)
                          : controller.bottomSheetType.value == "bidOffers"
                          ? bidOffersDialog(context, controller, isDark)
                          : SizedBox(),
                    ],
                  ),
        );
      },
    );
  }

  Widget searchLocationBottomSheet(BuildContext context, CabBookingController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.30,
        // Start height
        minChildSize: 0.30,
        // Minimum height
        maxChildSize: 0.8,
        // Maximum height
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.grey400), height: 4, width: 33),
                SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pickup Location
                          InkWell(
                            onTap: () async {
                              if (Constant.selectedMapType == 'osm') {
                                final result = await Get.to(() => MapPickerPage());
                                if (result != null) {
                                  controller.sourceTextEditController.value.text = '';
                                  final firstPlace = result;
                                  if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                                    final lat = firstPlace.coordinates.latitude;
                                    final lng = firstPlace.coordinates.longitude;
                                    final address = firstPlace.address;
                                    controller.sourceTextEditController.value.text = address.toString();
                                    controller.setDepartureMarker(lat, lng);
                                    // Unnamed OSM street (e.g. KDA Kohat): add the nearest named place.
                                    controller.addNearbyPlace(pickup: true, lat: lat, lng: lng);
                                  } else {
                                    ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                                  }
                                }
                              } else {
                                Get.to(LocationPickerScreen())!.then((value) async {
                                  if (value != null) {
                                    SelectedLocationModel selectedLocationModel = value;

                                    if (Constant.checkZoneCheck(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude) == true) {
                                      controller.sourceTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      controller.setDepartureMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                    } else {
                                      ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                                    }
                                  }
                                });
                              }
                            },
                            child: TextFieldWidget(
                              controller: controller.sourceTextEditController.value,
                              hintText: "Pickup Location".tr,
                              enable: false,
                              prefix: Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Image.asset("assets/icons/pickup.png", height: 22, width: 22)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Destination Location
                          InkWell(
                            onTap: () async {
                              if (Constant.selectedMapType == 'osm') {
                                final result = await Get.to(() => MapPickerPage());
                                if (result != null) {
                                  controller.destinationTextEditController.value.text = '';
                                  final firstPlace = result;
                                  final lat = firstPlace.coordinates.latitude;
                                  final lng = firstPlace.coordinates.longitude;
                                  final address = firstPlace.address;
                                  controller.destinationTextEditController.value.text = address.toString();
                                  controller.setDestinationMarker(lat, lng);
                                  // Unnamed OSM street (e.g. KDA Kohat): add the nearest named place.
                                  controller.addNearbyPlace(pickup: false, lat: lat, lng: lng);
                                }
                              } else {
                                Get.to(LocationPickerScreen())!.then((value) async {
                                  if (value != null) {
                                    SelectedLocationModel selectedLocationModel = value;

                                    controller.destinationTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                    controller.setDestinationMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                  }
                                });
                              }
                            },
                            child: TextFieldWidget(
                              controller: controller.destinationTextEditController.value,
                              // backgroundColor: AppThemeData.grey50,
                              // borderColor: AppThemeData.grey50,
                              hintText: "Destination Location".tr,
                              enable: false,
                              prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Icon(Icons.radio_button_checked, color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 33,
                      child: DottedBorder(
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
                        child: const SizedBox(width: 20, height: 40),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                RoundedButtonFill(
                  title: "Continue".tr,
                  onPress: () {
                    if (controller.sourceTextEditController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please select source location".tr);
                    } else if (controller.destinationTextEditController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please select destination location".tr);
                    } else {
                      controller.bottomSheetType.value = "vehicleSelection";
                    }
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget vehicleSelection(BuildContext context, CabBookingController controller, bool isDark) {
    // In bid mode this sheet also carries the fare box, and at 0.40 the
    // vehicle list underneath it collapsed to about one row. The sheet is only
    // taller when there is something extra in it; a normal ride keeps exactly
    // the height it always had.
    final double sheetSize = isBidMode ? 0.58 : 0.40;
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: sheetSize,
        minChildSize: sheetSize,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.grey400), height: 4, width: 33),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Select Your Vehicle Type".tr,
                        style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: controller.vehicleTypes.length,
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: 20),
                      controller: scrollController,
                      scrollDirection: Axis.vertical,
                      itemBuilder: (context, index) {
                        VehicleType vehicleType = controller.vehicleTypes[index];
                        return Obx(
                          () => InkWell(
                            onTap: () {
                              controller.selectedVehicleType.value = controller.vehicleTypes[index];
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? controller.selectedVehicleType.value.id == vehicleType.id
                                                ? Colors.white
                                                : AppThemeData.grey500
                                            : controller.selectedVehicleType.value.id == vehicleType.id
                                            ? AppThemeData.grey300
                                            : Colors.transparent,
                                    width: 1,
                                  ),
                                  color:
                                      controller.selectedVehicleType.value.id == vehicleType.id
                                          ? AppThemeData.grey50
                                          : isDark
                                          ? AppThemeData.grey300
                                          : Colors.white,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        //borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                          imageUrl: vehicleType.vehicleIcon.toString(),
                                          height: 60,
                                          width: 60,
                                          imageBuilder:
                                              (context, imageProvider) =>
                                                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: imageProvider, fit: BoxFit.cover))),
                                          placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                          errorWidget:
                                              (context, url, error) =>
                                                  ClipRRect(borderRadius: BorderRadius.circular(20), child: CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${vehicleType.name} | ${controller.distance.toStringAsFixed(2)}${'km'.tr}",
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                // Duration, and how many people this vehicle
                                                // seats - the difference between a motorcycle,
                                                // a rickshaw and a ten-seater in the same list.
                                                child: Text(
                                                  VehicleDisplay.subtitle(
                                                    duration: controller.duration.value,
                                                    seats: VehicleDisplay.seatsLabel(vehicleType.seats),
                                                  ),
                                                  style: const TextStyle(fontWeight: FontWeight.w400, letterSpacing: 1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        Constant.amountShow(amount: controller.getAmount(vehicleType).toString()),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // The bid box, on the screen straight after the destination.
                  //
                  // The client's report was that bidding "is in last part of
                  // the order and thats not good" - by the time a customer got
                  // to the confirm sheet they had already been quoted a metered
                  // price. The field is the same controller the confirm sheet
                  // edits, so whatever is typed here carries all the way
                  // through and can still be changed later.
                  //
                  // Only in bid mode: on a normal ride nothing is added to this
                  // sheet at all. The box is filled by a worker in the
                  // controller rather than from inside this builder - writing
                  // to a TextEditingController that a TextField is already
                  // listening to marks the tree dirty in the middle of a build,
                  // which is a framework error on screen, not a silent one.
                  if (isBidMode) Obx(() => offeredFareField(controller, isDark, compact: true)),
                  Obx(() {
                    // Read the observable before the branch, always.
                    //
                    // An Obx whose builder subscribes to nothing throws
                    // "[Get] the improper use of a GetX has been detected",
                    // and in a release build that is drawn as an error box
                    // where the widget should be - which is what the client
                    // photographed on the vehicle sheet. The bidding title is
                    // a constant string, so on that branch nothing below was
                    // ever read and the button threw instead of rendering.
                    final VehicleType selected = controller.selectedVehicleType.value;
                    return RoundedButtonFill(
                      title: isBidMode
                          ? "Continue".tr
                          : 'pay_amount'.trParams({
                              'amount': selected.id == null
                                  ? Constant.amountShow(amount: "0.0")
                                  : Constant.amountShow(amount: controller.getAmount(selected).toString()),
                            }),
                      onPress: () async {
                        if (controller.selectedVehicleType.value.id == null) {
                          ShowToastDialog.showToast("Please select a vehicle type first.".tr);
                          return;
                        }
                        // Refuse an unusable offer here rather than three sheets
                        // later, while the fare box is still on screen. Never on
                        // a normal ride, which has no offer to check.
                        if (isBidMode) {
                          final String? problem = controller.validateOfferedFare();
                          if (problem != null) {
                            ShowToastDialog.showToast(problem);
                            return;
                          }
                        }
                        controller.calculateTotalAmount();
                        controller.bottomSheetType.value = "payment";
                      },
                      color: AppThemeData.primary300,
                      textColor: AppThemeData.grey900,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget paymentBottomSheet(BuildContext context, CabBookingController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.30,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                      child: Icon(Icons.close, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    controller: scrollController,
                    children: [
                      Text("Preferred Payment".tr, textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                      const SizedBox(height: 10),
                      if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey50,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey50,
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
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                  onPress: () async {
                    if (controller.selectedPaymentMethod.value.isEmpty) {
                      ShowToastDialog.showToast("Please select a payment method".tr);
                      return;
                    }
                    if (controller.selectedPaymentMethod.value == "wallet") {
                      num walletAmount = controller.userModel.value.walletAmount ?? 0;
                      if (walletAmount <= 0) {
                        ShowToastDialog.showToast("Insufficient wallet balance. Please select another payment method.".tr);
                        return;
                      }
                    }
                    if (controller.currentOrder.value.id != null) {
                      controller.bottomSheetType.value = "driverDetails";
                    } else {
                      // Start the offer box at the metered price so the
                      // customer edits a number instead of an empty field.
                      if (isBidMode && controller.offeredFareTextEditController.value.text.trim().isEmpty) {
                        controller.primeOfferedFare();
                      }
                      controller.bottomSheetType.value = "conformRide";
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget conformBottomSheet(BuildContext context, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          // No `init`: the screen's own GetX has already registered this
          // controller, so an `init` here only built - and threw away - a whole
          // second controller on every rebuild of this sheet.
          return GetX<CabBookingController>(
            builder: (controller) {
              return Container(
                decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.grey400), height: 4, width: 33),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            const SizedBox(height: 10),
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(color: isDark ? Colors.transparent : Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Pickup Location
                                      InkWell(
                                        onTap: () async {
                                          if (Constant.selectedMapType == 'osm') {
                                            final result = await Get.to(() => MapPickerPage());
                                            if (result != null) {
                                              controller.sourceTextEditController.value.text = '';
                                              final firstPlace = result;
                                              final lat = firstPlace.coordinates.latitude;
                                              final lng = firstPlace.coordinates.longitude;
                                              final address = firstPlace.address;
                                              controller.sourceTextEditController.value.text = address.toString();
                                              controller.setDepartureMarker(lat, lng);
                                              // Unnamed OSM street (e.g. KDA Kohat): add the nearest named place.
                                              controller.addNearbyPlace(pickup: true, lat: lat, lng: lng);
                                            }
                                          } else {
                                            Get.to(LocationPickerScreen())!.then((value) async {
                                              if (value != null) {
                                                SelectedLocationModel selectedLocationModel = value;

                                                controller.sourceTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                                controller.setDepartureMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                              }
                                            });
                                          }
                                        },
                                        child: TextFieldWidget(
                                          controller: controller.sourceTextEditController.value,
                                          hintText: "Pickup Location".tr,
                                          enable: false,
                                          prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Icon(Icons.stop_circle_outlined, color: Colors.green)),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Destination Location
                                      InkWell(
                                        onTap: () async {
                                          if (Constant.selectedMapType == 'osm') {
                                            final result = await Get.to(() => MapPickerPage());
                                            if (result != null) {
                                              controller.destinationTextEditController.value.text = '';
                                              final firstPlace = result;
                                              final lat = firstPlace.coordinates.latitude;
                                              final lng = firstPlace.coordinates.longitude;
                                              final address = firstPlace.address;
                                              controller.destinationTextEditController.value.text = address.toString();
                                              controller.setDestinationMarker(lat, lng);
                                              // Unnamed OSM street (e.g. KDA Kohat): add the nearest named place.
                                              controller.addNearbyPlace(pickup: false, lat: lat, lng: lng);
                                            }
                                          } else {
                                            Get.to(LocationPickerScreen())!.then((value) async {
                                              if (value != null) {
                                                SelectedLocationModel selectedLocationModel = value;

                                                controller.destinationTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                                controller.setDestinationMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                              }
                                            });
                                          }
                                        },
                                        child: TextFieldWidget(
                                          controller: controller.destinationTextEditController.value,
                                          // backgroundColor: AppThemeData.grey50,
                                          // borderColor: AppThemeData.grey50,
                                          hintText: "Destination Location".tr,
                                          enable: false,
                                          prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Icon(Icons.radio_button_checked, color: Colors.red)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 10,
                                  top: 33,
                                  child: DottedBorder(
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
                                    child: const SizedBox(width: 20, height: 40),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text("Promo code".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                                InkWell(
                                  onTap: () {
                                    Get.to(CabCouponCodeScreen())!.then((value) {
                                      if (value != null) {
                                        controller.couponCodeTextEditController.value.text = value.code ?? '';
                                        double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: value);
                                        if (couponAmount < controller.subTotal.value) {
                                          controller.selectedCouponModel.value = value;
                                          controller.calculateTotalAmount();
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: Responsive.width(100, context),
                                height: Responsive.height(6, context),
                                color: AppThemeData.carRent50,
                                child: DottedBorder(
                                  options: RectDottedBorderOptions(dashPattern: [10, 5], strokeWidth: 1, padding: EdgeInsets.all(0), color: AppThemeData.carRent400),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset("assets/icons/ic_coupon.svg"),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: TextFormField(
                                              controller: controller.couponCodeTextEditController.value,
                                              style: AppThemeData.semiBoldTextStyle(color: AppThemeData.parcelService500, fontSize: 16),
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                hintText: 'Write coupon Code'.tr,
                                                contentPadding: EdgeInsets.only(bottom: 10),
                                                hintStyle: AppThemeData.semiBoldTextStyle(color: AppThemeData.parcelService500, fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        ),
                                        RoundedButtonFill(
                                          title: "Redeem now".tr,
                                          width: 27,
                                          borderRadius: 10,
                                          fontSizes: 14,
                                          onPress: () async {
                                            if (controller.couponCodeTextEditController.value.text.trim().isEmpty) {
                                              ShowToastDialog.showToast("Please enter a coupon code".tr);
                                              return;
                                            }

                                            List matchedCoupons =
                                                controller.cabCouponList
                                                    .where((element) => element.code!.toLowerCase().trim() == controller.couponCodeTextEditController.value.text.toLowerCase().trim())
                                                    .toList();

                                            if (matchedCoupons.isNotEmpty) {
                                              CouponModel couponModel = matchedCoupons.first;

                                              if (couponModel.expiresAt != null && couponModel.expiresAt!.toDate().isAfter(DateTime.now())) {
                                                double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);

                                                if (couponAmount < controller.subTotal.value) {
                                                  controller.selectedCouponModel.value = couponModel;
                                                  controller.discount.value = couponAmount;
                                                  controller.calculateTotalAmount();
                                                  ShowToastDialog.showToast("Coupon applied successfully".tr);
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
                                          color: AppThemeData.parcelService300,
                                          textColor: AppThemeData.grey50,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
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
                                  Text("Order Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                                  const SizedBox(height: 8),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Subtotal".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                        Text(
                                          Constant.amountShow(amount: controller.subTotal.value.toString()),
                                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text("Discount".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                            SizedBox(width: 5),
                                            Text(
                                              controller.selectedCouponModel.value.id == null ? "" : "(${controller.selectedCouponModel.value.code})",
                                              style: AppThemeData.mediumTextStyle(fontSize: 16, color: AppThemeData.primary300),
                                            ),
                                          ],
                                        ),
                                        Text(Constant.amountShow(amount: controller.discount.value.toString()), style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.danger300)),
                                      ],
                                    ),
                                  ),
                                  if (Constant.platformFeeModel?.enable == true)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Platform fee".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                          Text(
                                            Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()),
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                        ],
                                      ),
                                    ),

                                  InkWell(
                                    onTap: () {
                                      showBillBifurcationDialog(context, isDark, controller);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Tax amount".tr,
                                            style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, decoration: TextDecoration.underline),
                                          ),
                                          Text(
                                            Constant.amountShow(amount: controller.taxAmount.value.toString()),
                                            style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Tax List
                                  const Divider(),

                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Order Total".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                        Text(
                                          Constant.amountShow(amount: controller.totalAmount.value.toString()),
                                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isBidMode) offeredFareField(controller, isDark),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  controller.selectedPaymentMethod.value == ''
                                      ? cardDecorationScreen(controller, PaymentGateway.wallet, isDark, "")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.wallet.name
                                      ? cardDecorationScreen(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.cod.name
                                      ? cardDecorationScreen(controller, PaymentGateway.cod, isDark, "assets/images/ic_cash.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.stripe.name
                                      ? cardDecorationScreen(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.paypal.name
                                      ? cardDecorationScreen(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.payStack.name
                                      ? cardDecorationScreen(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name
                                      ? cardDecorationScreen(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name
                                      ? cardDecorationScreen(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.payFast.name
                                      ? cardDecorationScreen(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name
                                      ? cardDecorationScreen(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name
                                      ? cardDecorationScreen(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png")
                                      : controller.selectedPaymentMethod.value == PaymentGateway.xendit.name
                                      ? cardDecorationScreen(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")
                                      : cardDecorationScreen(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png"),
                                  SizedBox(width: 22),
                                  Text(
                                    controller.selectedPaymentMethod.value.tr,
                                    textAlign: TextAlign.start,
                                    style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      RoundedButtonFill(
                        title: isBidMode ? "Send Offer to Drivers".tr : "Confirm Booking".tr,
                        onPress: () async {
                          if (isBidMode) {
                            controller.placeBiddingOrder();
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
        },
      ),
    );
  }

  Widget waitingDialog(BuildContext context, CabBookingController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.4,
        maxChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.grey400), height: 4, width: 33),
                  SizedBox(height: 30),
                  Text("Waiting for driver....".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                  Image.asset('assets/loader.gif', width: 250),
                  RoundedButtonFill(
                    title: "Cancel Ride".tr,
                    color: AppThemeData.danger300,
                    textColor: AppThemeData.surface,
                    onPress: () async {
                      try {
                        controller.currentOrder.update((order) {
                          if (order != null) {
                            order.status = Constant.orderRejected;
                          }
                        });

                        if (controller.currentOrder.value.id != null) {
                          await FireStoreUtils.updateCabOrder(controller.currentOrder.value);
                        }

                        controller.bottomSheetType.value = "";
                        controller.polyLines.clear();
                        controller.markers.clear();
                        controller.osmMarker.clear();
                        controller.routePoints.clear();
                        controller.sourceTextEditController.value.clear();
                        controller.destinationTextEditController.value.clear();
                        controller.departureLatLong.value = const LatLng(0.0, 0.0);
                        controller.destinationLatLong.value = const LatLng(0.0, 0.0);
                        controller.departureLatLongOsm.value = latlong.LatLng(0.0, 0.0);
                        controller.destinationLatLongOsm.value = latlong.LatLng(0.0, 0.0);

                        // 4. Reset user’s in-progress order
                        if (Constant.userModel != null) {
                          Constant.userModel?.inProgressOrderID = null;
                          await FireStoreUtils.updateUser(Constant.userModel!);
                        }
                        ShowToastDialog.showToast("Ride cancelled successfully".tr);
                        // Get.offAll(const CabDashboardScreen());
                        Get.back();
                        CabDashboardController cabDashboardController = Get.put(CabDashboardController());
                        cabDashboardController.selectedIndex.value = 0;
                      } catch (e) {
                        ShowToastDialog.showToast("Failed to cancel ride".tr);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget driverDialog(BuildContext context, CabBookingController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(color: isDark ? AppThemeData.grey700 : Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.grey400), height: 4, width: 33),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 10),
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(color: isDark ? Colors.transparent : Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      // if (Constant.selectedMapType == 'osm') {
                                      //   final result = await Get.to(() => MapPickerPage());
                                      //   if (result != null) {
                                      //     controller.sourceTextEditController.value.text = '';
                                      //     final firstPlace = result;
                                      //     final lat = firstPlace.coordinates.latitude;
                                      //     final lng = firstPlace.coordinates.longitude;
                                      //     final address = firstPlace.address;
                                      //     controller.sourceTextEditController.value.text = address.toString();
                                      //     controller.setDepartureMarker(lat, lng);
                                      //   }
                                      // } else {
                                      //   Get.to(LocationPickerScreen())!.then((value) async {
                                      //     if (value != null) {
                                      //       SelectedLocationModel selectedLocationModel = value;
                                      //
                                      //       controller.sourceTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      //       controller.setDepartureMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                      //     }
                                      //   });
                                      // }
                                    },
                                    child: TextFieldWidget(
                                      controller: controller.sourceTextEditController.value,
                                      hintText: "Pickup Location".tr,
                                      enable: false,
                                      readOnly: true,
                                      prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Icon(Icons.stop_circle_outlined, color: Colors.green)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () async {
                                      // if (Constant.selectedMapType == 'osm') {
                                      //   final result = await Get.to(() => MapPickerPage());
                                      //   if (result != null) {
                                      //     controller.destinationTextEditController.value.text = '';
                                      //     final firstPlace = result;
                                      //     final lat = firstPlace.coordinates.latitude;
                                      //     final lng = firstPlace.coordinates.longitude;
                                      //     final address = firstPlace.address;
                                      //     controller.destinationTextEditController.value.text = address.toString();
                                      //     controller.setDestinationMarker(lat, lng);
                                      //   }
                                      // } else {
                                      //   Get.to(LocationPickerScreen())!.then((value) async {
                                      //     if (value != null) {
                                      //       SelectedLocationModel selectedLocationModel = value;
                                      //
                                      //       controller.destinationTextEditController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                      //       controller.setDestinationMarker(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                      //     }
                                      //   });
                                      // }
                                    },
                                    child: TextFieldWidget(
                                      controller: controller.destinationTextEditController.value,
                                      // backgroundColor: AppThemeData.grey50,
                                      // borderColor: AppThemeData.grey50,
                                      hintText: "Destination Location".tr,
                                      enable: false,
                                      readOnly: true,
                                      prefix: const Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Icon(Icons.radio_button_checked, color: Colors.red)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 10,
                              top: 33,
                              child: DottedBorder(
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
                                child: const SizedBox(width: 20, height: 40),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Constant.isEnableOTPTripStart == true
                            ? Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Otp :".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                  Text(
                                    controller.currentOrder.value.otpCode ?? '',
                                    style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                  ),
                                ],
                              ),
                            )
                            : SizedBox.shrink(),
                        if (Constant.isEnableOTPTripStart == true) SizedBox(height: 14),
                        controller.currentOrder.value.driver != null
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadiusGeometry.circular(10),
                                  child: NetworkImageWidget(imageUrl: controller.currentOrder.value.driver?.profilePictureURL ?? '', height: 70, width: 70, borderRadius: 35),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        controller.currentOrder.value.driver?.fullName() ?? '',
                                        style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18),
                                      ),
                                      // The number itself, not only a button
                                      // that dials it. "Both need to see each
                                      // others phone numbers" was the report,
                                      // and a call icon is not seeing it.
                                      Builder(
                                        builder: (_) {
                                          final driver = controller.currentOrder.value.driver;
                                          final phone = '${driver?.countryCode ?? ''}${driver?.phoneNumber ?? ''}'.trim();
                                          if (phone.isEmpty) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                                            child: Text(
                                              phone,
                                              style: AppThemeData.mediumTextStyle(
                                                color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Builder(
                                        builder: (_) {
                                          final sid = controller.currentOrder.value.sectionId ?? '';
                                          final vehicle = controller.currentOrder.value.driver?.vehicleDetails?[sid];
                                          if (vehicle == null) return const SizedBox.shrink();
                                          final vType = vehicle['vehicleType']?.toString() ?? '';
                                          final brand = vehicle['carBrand']?.toString() ?? '';
                                          final carModel = vehicle['carModel']?.toString() ?? '';
                                          final plate = vehicle['carPlateNumber']?.toString() ?? '';
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (vType.isNotEmpty)
                                                Text(vType, style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14)),
                                              if (brand.isNotEmpty || carModel.isNotEmpty)
                                                Text(
                                                  "$brand $carModel".trim(),
                                                  style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                                ),
                                              if (plate.isNotEmpty)
                                                Text(plate.toUpperCase(), style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 16)),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    RoundedButtonBorder(
                                      title: controller.driverModel.value.averageRating.toStringAsFixed(1),
                                      width: 20,
                                      height: 3.5,
                                      radius: 10,
                                      isRight: false,
                                      isCenter: true,
                                      textColor: AppThemeData.warning400,
                                      borderColor: AppThemeData.warning400,
                                      color: AppThemeData.warning50,
                                      icon: SvgPicture.asset("assets/icons/ic_start.svg"),
                                      onPress: () {},
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Constant.makePhoneCall(controller.currentOrder.value.driver!.phoneNumber.toString());
                                          },
                                          child: Container(
                                            width: 38,
                                            height: 38,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey200 : AppThemeData.grey200),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(padding: const EdgeInsets.all(8.0), child: SvgPicture.asset("assets/icons/ic_phone_call.svg")),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        InkWell(
                                          onTap: () async {
                                            ShowToastDialog.showLoader("Please wait...".tr);

                                            UserModel? customer = await FireStoreUtils.getUserProfile(controller.currentOrder.value.authorID ?? '');
                                            UserModel? driverUser = await FireStoreUtils.getUserProfile(controller.currentOrder.value.driverId ?? '');

                                            ShowToastDialog.closeLoader();

                                            Get.to(
                                              const ChatScreen(),
                                              arguments: {
                                                "senderName": customer?.fullName(),
                                                "receivedName": driverUser?.fullName(),
                                                "orderId": controller.currentOrder.value.id,
                                                "receivedId": driverUser?.id,
                                                "senderId": customer?.id,
                                                "senderProfileUrl": customer?.profilePictureURL,
                                                "receivedProfileUrl": driverUser?.profilePictureURL,
                                                "token": driverUser?.fcmToken,
                                                "chatType": Constant.userRoleDriver,
                                              },
                                            );
                                          },
                                          child: Container(
                                            width: 42,
                                            height: 42,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, color: isDark ? AppThemeData.grey200 : AppThemeData.grey200),
                                                borderRadius: BorderRadius.circular(120),
                                              ),
                                            ),
                                            child: Padding(padding: const EdgeInsets.all(8.0), child: SvgPicture.asset("assets/icons/ic_wechat.svg")),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            )
                            : SizedBox(),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: InkWell(
                            onTap: () {
                              controller.bottomSheetType.value = 'payment';
                            },
                            child: Row(
                              children: [
                                controller.selectedPaymentMethod.value == PaymentGateway.wallet.name
                                    ? cardDecorationScreen(controller, PaymentGateway.wallet, isDark, "assets/images/ic_wallet.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.cod.name
                                    ? cardDecorationScreen(controller, PaymentGateway.cod, isDark, "assets/images/ic_cash.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.stripe.name
                                    ? cardDecorationScreen(controller, PaymentGateway.stripe, isDark, "assets/images/stripe.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.paypal.name
                                    ? cardDecorationScreen(controller, PaymentGateway.paypal, isDark, "assets/images/paypal.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.payStack.name
                                    ? cardDecorationScreen(controller, PaymentGateway.payStack, isDark, "assets/images/paystack.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.mercadoPago.name
                                    ? cardDecorationScreen(controller, PaymentGateway.mercadoPago, isDark, "assets/images/mercado-pago.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.flutterWave.name
                                    ? cardDecorationScreen(controller, PaymentGateway.flutterWave, isDark, "assets/images/flutterwave_logo.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.payFast.name
                                    ? cardDecorationScreen(controller, PaymentGateway.payFast, isDark, "assets/images/payfast.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name
                                    ? cardDecorationScreen(controller, PaymentGateway.midTrans, isDark, "assets/images/midtrans.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.orangeMoney.name
                                    ? cardDecorationScreen(controller, PaymentGateway.orangeMoney, isDark, "assets/images/orange_money.png")
                                    : controller.selectedPaymentMethod.value == PaymentGateway.xendit.name
                                    ? cardDecorationScreen(controller, PaymentGateway.xendit, isDark, "assets/images/xendit.png")
                                    : cardDecorationScreen(controller, PaymentGateway.razorpay, isDark, "assets/images/razorpay.png"),
                                SizedBox(width: 22),
                                Expanded(
                                  child: Text(
                                    controller.selectedPaymentMethod.value.tr,
                                    textAlign: TextAlign.start,
                                    style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                  ),
                                ),
                                Text("Change".tr, textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                              Text("Order Summary".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                              const SizedBox(height: 8),

                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Subtotal".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                    Text(
                                      Constant.amountShow(amount: controller.subTotal.value.toString()),
                                      style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Discount".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                    Text(Constant.amountShow(amount: controller.discount.value.toString()), style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.danger300)),
                                  ],
                                ),
                              ),

                              if (Constant.platformFeeModel?.enable == true)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Platform fee".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                      Text(
                                        Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                    ],
                                  ),
                                ),

                              InkWell(
                                onTap: () {
                                  showBillBifurcationDialog(context, isDark, controller);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Tax amount".tr,
                                        style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, decoration: TextDecoration.underline),
                                      ),
                                      Text(
                                        Constant.amountShow(amount: controller.taxAmount.value.toString()),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(),

                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Order Total".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                    Text(
                                      Constant.amountShow(amount: controller.totalAmount.value.toString()),
                                      style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  Obx(() {
                    if (controller.currentOrder.value.status == Constant.orderInTransit) {
                      return Column(
                        children: [
                          RoundedButtonFill(
                            title: "SOS".tr,
                            color: Colors.red.withOpacity(0.50),
                            textColor: AppThemeData.grey50,
                            isCenter: true,
                            icon: const Icon(Icons.call, color: Colors.white),
                            onPress: () async {
                              ShowToastDialog.showLoader("Please wait...".tr);

                              LocationData location = await controller.currentLocation.value.getLocation();

                              await FireStoreUtils.getSOS(controller.currentOrder.value.id ?? '').then((value) async {
                                if (value == false) {
                                  await FireStoreUtils.setSos(controller.currentOrder.value.id ?? '', UserLocation(latitude: location.latitude!, longitude: location.longitude!)).then((_) {
                                    ShowToastDialog.closeLoader();
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(SnackBar(content: Text("Your SOS request has been submitted to admin".tr), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
                                  });
                                } else {
                                  ShowToastDialog.closeLoader();
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text("Your SOS request is already submitted".tr), backgroundColor: Colors.red, duration: Duration(seconds: 3)));
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                  Obx(() {
                    if (controller.currentOrder.value.status == Constant.orderInTransit && controller.currentOrder.value.paymentStatus == false) {
                      return RoundedButtonFill(
                        title: "Pay Now".tr,
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
                            controller.completeOrder();
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.wallet.name) {
                            if (Constant.userModel!.walletAmount == null || Constant.userModel!.walletAmount! < controller.totalAmount.value) {
                              ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                            } else {
                              controller.completeOrder();
                            }
                          } else if (controller.selectedPaymentMethod.value == PaymentGateway.midTrans.name) {
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
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey900,
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Padding cardDecorationScreen(CabBookingController controller, PaymentGateway value, isDark, String image) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        width: 40,
        height: 40,
        decoration: ShapeDecoration(shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8))),
        child: Padding(padding: EdgeInsets.all(value.name == "payFast" ? 0 : 8.0), child: image == '' ? Container(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100) : Image.asset(image)),
      ),
    );
  }

  Obx cardDecoration(CabBookingController controller, PaymentGateway value, isDark, String image) {
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
                              Constant.amountShow(amount: controller.userModel.value.walletAmount == null ? '0.0' : controller.userModel.value.walletAmount.toString()),
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

  void showBillBifurcationDialog(BuildContext context, bool isDark, CabBookingController controller) {
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
                  const SizedBox(height: 10),
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


  // =====================================================================
  // Bidding / counter-offer UI.
  //
  // Both widgets below are only ever built in bid mode - that is, when the
  // customer came in through the Bid section *and* the admin's global bidding
  // switch is on. A ride started from Ride on the home screen has no fare box
  // and never reaches the offer list, whatever that switch says, so the normal
  // booking flow looks exactly as it always did.
  // Every control here is one of the project's existing components -
  // TextFieldWidget, RoundedButtonFill, RoundedButtonBorder,
  // NetworkImageWidget, MySeparator - and the same AppThemeData typography,
  // colours and spacing as the sheets around it.
  // =====================================================================

  /// "Your offer" box, with the minimum-fare hint.
  ///
  /// Shown twice: on the vehicle sheet in [compact] form, right after the
  /// destination is chosen, and again on the confirm sheet. Both read and write
  /// the same controller, so it is one number the customer can revise, not two
  /// fields that can disagree.
  Widget offeredFareField(CabBookingController controller, bool isDark, {bool compact = false}) {
    final double minimum = controller.minimumAllowedFare;
    return Padding(
      padding: EdgeInsets.only(top: compact ? 4 : 20, bottom: compact ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // On the vehicle sheet this is the customer being *asked* for a
            // price, so it is phrased as the question the client wanted:
            // "use heading for bid or select or chose ur price". On the confirm
            // sheet it is a review of the number they already gave.
            compact ? "Choose your price".tr : "Your offer".tr,
            style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
          ),
          const SizedBox(height: 8),
          TextFieldWidget(
            controller: controller.offeredFareTextEditController.value,
            hintText: "Enter the fare you want to offer".tr,
            textInputType: const TextInputType.numberWithOptions(decimal: true),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Text(
                Constant.currencyModel?.symbol ?? '',
                style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
              ),
            ),
          ),
          if (minimum > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "${'The minimum fare for this trip is'.tr} ${Constant.amountShow(amount: minimum.toString())}",
                style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.warning400),
              ),
            ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "Nearby drivers will accept your fare or send you a counter offer.".tr,
                style: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
              ),
            ),
        ],
      ),
    );
  }

  /// The live list of driver offers. Updates from the Firestore subscription
  /// in the controller - there is no refresh control because there is nothing
  /// to refresh.
  Widget bidOffersDialog(BuildContext context, CabBookingController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppThemeData.grey700 : Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
              child: Obx(() {
                final List<RideBidModel> offers = controller.liveOffers;
                final bool expired = controller.biddingEndedWithoutDriver;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.grey400), height: 4, width: 33),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Driver offers".tr,
                            style: AppThemeData.boldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                          ),
                        ),
                        Text(
                          "${'Your offer'.tr}: ${Constant.amountShow(amount: (controller.biddingState.value.offeredFare ?? 0).toString())}",
                          style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.primary300),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: offers.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!expired) Image.asset('assets/loader.gif', width: 200),
                                Text(
                                  expired
                                      ? (controller.biddingState.value.status == RideBiddingStatus.noDrivers
                                          ? "No driver is available nearby right now".tr
                                          : "No driver responded in time".tr)
                                      : "Waiting for driver offers....".tr,
                                  textAlign: TextAlign.center,
                                  style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                                ),
                              ],
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: offers.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => bidOfferCard(controller, offers[index], isDark),
                            ),
                    ),
                    const SizedBox(height: 10),
                    if (expired)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RoundedButtonFill(
                          title: "Send Offer to Drivers".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey900,
                          onPress: () => controller.resendBiddingRequest(),
                        ),
                      ),
                    RoundedButtonFill(
                      title: "Cancel Ride".tr,
                      color: AppThemeData.danger300,
                      textColor: AppThemeData.surface,
                      onPress: () => controller.cancelBiddingRequest(),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }),
            ),
          );
        },
      ),
    );
  }

  /// One driver's offer: photo, name, rating, completed trips, vehicle,
  /// AC / Non-AC and the amount, with Accept and Reject.
  Widget bidOfferCard(CabBookingController controller, RideBidModel bid, bool isDark) {
    final bool busy = controller.bidActionInFlight.value.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: NetworkImageWidget(imageUrl: bid.driverPhoto ?? '', height: 56, width: 56, borderRadius: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bid.driverName ?? '',
                      style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                    if ((bid.vehicleType ?? '').isNotEmpty)
                      Text(
                        bid.vehicleType!,
                        style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                    if (bid.vehicleDescription.isNotEmpty)
                      Text(
                        bid.vehicleDescription,
                        style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                    if ((bid.vehiclePlate ?? '').isNotEmpty)
                      Text(
                        bid.vehiclePlate!.toUpperCase(),
                        style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Constant.amountShow(amount: (bid.amount ?? 0).toString()),
                    style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.primary300),
                  ),
                  const SizedBox(height: 6),
                  RoundedButtonBorder(
                    title: (bid.driverRating ?? 0).toStringAsFixed(1),
                    width: 18,
                    height: 3.2,
                    radius: 10,
                    isRight: false,
                    isCenter: true,
                    textColor: AppThemeData.warning400,
                    borderColor: AppThemeData.warning400,
                    color: AppThemeData.warning50,
                    icon: SvgPicture.asset("assets/icons/ic_start.svg"),
                    onPress: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              bidChip("${bid.driverCompletedTrips ?? 0} ${'trips'.tr}", isDark),
              if (bid.airConditioning != null) bidChip(bid.airConditioning! ? "AC".tr : "Non-AC".tr, isDark),
              if (bid.type == RideBidType.counter) bidChip("Counter offer".tr, isDark),
              if (bid.type == RideBidType.accept) bidChip("Accepted your fare".tr, isDark),
            ],
          ),
          if ((bid.note ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                bid.note!.tr,
                style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
          ),
          Row(
            children: [
              Expanded(
                child: RoundedButtonFill(
                  title: "Reject".tr,
                  height: 5,
                  color: AppThemeData.danger300,
                  textColor: AppThemeData.grey50,
                  onPress: () {
                    if (busy) return;
                    controller.rejectOffer(bid);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RoundedButtonFill(
                  title: "Accept".tr,
                  height: 5,
                  color: AppThemeData.success400,
                  textColor: AppThemeData.grey50,
                  onPress: () {
                    if (busy) return;
                    controller.acceptOffer(bid);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget bidChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? AppThemeData.grey700 : AppThemeData.grey100,
      ),
      child: Text(
        label,
        style: AppThemeData.mediumTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
      ),
    );
  }
}
