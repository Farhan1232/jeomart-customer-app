import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/controllers/intercity_home_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/utils/vehicle_display.dart';
import 'package:customer/payment/create_razor_pay_order_model.dart';
import 'package:customer/payment/rozorpay_conroller.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_coupon_code_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_border.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:customer/utils/safe_geocoding.dart' as get_cord_address;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart';
import '../../constant/constant.dart';
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
import 'package:customer/utils/app_image_cache.dart';

class IntercityHomeScreen extends StatelessWidget {
  const IntercityHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: IntercityHomeController(),
      builder: (controller) {
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
                              // Resolved before `isLoading` went false, so this is
                              // already the customer's own location on the very
                              // first frame. An in-progress ride still wins,
                              // because the map should open on the ride.
                              //
                              // The old last resort here was
                              // `41.4219057, -102.0840772` - a field in Nebraska -
                              // and nothing ever moved the map off it.
                              initialCenter:
                                  controller.currentOrder.value.id != null && controller.currentOrder.value.sourceLocation != null
                                      ? latlong.LatLng(
                                        double.parse(controller.currentOrder.value.sourceLocation!.latitude.toString()),
                                        double.parse(controller.currentOrder.value.sourceLocation!.longitude.toString()),
                                      )
                                      : controller.mapStart.value,
                              initialZoom: 14,
                            ),
                            children: [
                              flutterMap.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.jeo.customer'),
                              flutterMap.MarkerLayer(markers: controller.osmMarker),
                              if (controller.routePoints.isNotEmpty) flutterMap.PolylineLayer(polylines: [flutterMap.Polyline(points: controller.routePoints, strokeWidth: 5.0, color: Colors.blue)]),
                            ],
                          )
                          : GoogleMap(
                            // Goes through the controller so a camera move issued
                            // before Google's controller exists is skipped rather
                            // than throwing, and so the map is recentred the
                            // moment a real fix lands.
                            onMapCreated: (googleMapController) {
                              controller.onGoogleMapCreated(googleMapController);

                              if (Constant.currentLocation != null) {
                                controller.setDepartureMarker(Constant.currentLocation!.latitude, Constant.currentLocation!.longitude);
                                controller.searchPlaceNameGoogle();
                              }
                            },
                            initialCameraPosition: CameraPosition(target: controller.currentPosition.value, zoom: 14),
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
                            } else if (Navigator.canPop(context)) {
                              // Go back one screen - to the cab service screen
                              // this was opened from.
                              //
                              // This used to be `Get.offAll(ServiceListScreen())`,
                              // which throws the **whole** navigation stack away
                              // and drops the customer on the service grid. So
                              // choosing Intercity, looking at the map and
                              // pressing back did not take you back to where you
                              // came from - it took you out of the cab section
                              // altogether, and destroyed the dashboard on the
                              // way. The cab booking screen's identical control
                              // has always been a plain `Get.back()`; this is the
                              // same fix the Pay Now branch needed, in the same
                              // screen, for the same reason: intercity was left
                              // behind when the cab flow was corrected.
                              Get.back();
                            } else {
                              // Nothing to pop - this screen is the root, which
                              // happens when it is opened from a notification.
                              // The service list is the right place to land.
                              Get.offAll(const ServiceListScreen());
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50, borderRadius: BorderRadius.circular(30)),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Center(child: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? AppThemeData.grey50 : AppThemeData.greyDark50)),
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
                          : SizedBox(),
                    ],
                  ),
        );
      },
    );
  }

  Widget searchLocationBottomSheet(BuildContext context, IntercityHomeController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.48,
        minChildSize: 0.48,
        maxChildSize: 0.8,
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
                                controller.sourceTextEditController.value.text = '';
                                final firstPlace = result;
                                if (result != null) {
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
                Align(alignment: Alignment.centerLeft, child: Text("Popular Destinations".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: AppThemeData.grey900))),
                SizedBox(
                  height: 120,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: controller.popularDestination.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () async {
                            if (controller.popularDestination[index].latitude != null || controller.popularDestination[index].longitude != null) {
                              List<get_cord_address.Placemark> placeMarks = await get_cord_address.placemarkFromCoordinates(
                                controller.popularDestination[index].latitude ?? 0.0,
                                controller.popularDestination[index].longitude ?? 0.0,
                              );

                              final address =
                                  (placeMarks.first.subLocality!.isEmpty ? '' : "${placeMarks.first.subLocality}, ") +
                                  (placeMarks.first.street!.isEmpty ? '' : "${placeMarks.first.street}, ") +
                                  (placeMarks.first.name!.isEmpty ? '' : "${placeMarks.first.name}, ") +
                                  (placeMarks.first.subAdministrativeArea!.isEmpty ? '' : "${placeMarks.first.subAdministrativeArea}, ") +
                                  (placeMarks.first.administrativeArea!.isEmpty ? '' : "${placeMarks.first.administrativeArea}, ") +
                                  (placeMarks.first.country!.isEmpty ? '' : "${placeMarks.first.country}, ") +
                                  (placeMarks.first.postalCode!.isEmpty ? '' : "${placeMarks.first.postalCode}, ");
                              controller.destinationTextEditController.value.text = address;
                              controller.setDestinationMarker(controller.popularDestination[index].latitude ?? 0.0, controller.popularDestination[index].longitude ?? 0.0);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                  imageUrl:
                                      (controller.popularDestination[index].image != null && controller.popularDestination[index].image!.isNotEmpty)
                                          ? controller.popularDestination[index].image!
                                          : Constant.placeHolderImage,
                                  height: 160,
                                  width: 120,
                                  imageBuilder:
                                      (context, imageProvider) =>
                                          Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: imageProvider, fit: BoxFit.cover))),
                                  placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                  errorWidget:
                                      (context, url, error) => ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover, memCacheHeight: 80, memCacheWidth: 80),
                                      ),
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  left: 5,
                                  top: 80,
                                  child: Text(controller.popularDestination[index].title.toString(), style: AppThemeData.boldTextStyle(fontSize: 15, color: AppThemeData.surface)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 10),
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

  Widget vehicleSelection(BuildContext context, IntercityHomeController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.40,
        minChildSize: 0.40,
        maxChildSize: 0.8,
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
                                                  ClipRRect(borderRadius: BorderRadius.circular(20), child: CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.userPlaceHolder, fit: BoxFit.cover)),
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
                                                "${vehicleType.name} | ${controller.distance.toStringAsFixed(2)}km",
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
                  Obx(
                    () => RoundedButtonFill(
                      title: 'pay_amount'.trParams({
                        'amount':
                            controller.selectedVehicleType.value.id == null
                                ? Constant.amountShow(amount: "0.0")
                                : Constant.amountShow(amount: controller.getAmount(controller.selectedVehicleType.value).toString()),
                      }),
                      // title:
                      // "Pay ${controller.selectedVehicleType.value.id == null ? Constant.amountShow(amount: "0.0") : Constant.amountShow(amount: controller.getAmount(controller.selectedVehicleType.value).toString())}",
                      onPress: () async {
                        if (controller.selectedVehicleType.value.id != null) {
                          controller.calculateTotalAmount();
                          controller.bottomSheetType.value = "payment";
                        } else {
                          ShowToastDialog.showToast("Please select a vehicle type first.".tr);
                        }
                      },
                      color: AppThemeData.primary300,
                      textColor: AppThemeData.grey900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget paymentBottomSheet(BuildContext context, IntercityHomeController controller, bool isDark) {
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
                      controller.bottomSheetType.value = "conformRide";
                    }
                  },
                ),
                // RoundedButtonFill(
                //   title: "Continue".tr,
                //   color: AppThemeData.primary300,
                //   textColor: AppThemeData.grey900,
                //   onPress: () async {
                //     if (controller.selectedPaymentMethod.value.isEmpty) {
                //       ShowToastDialog.showToast("Please select a payment method");
                //     } else {
                //       if (controller.currentOrder.value.id != null) {
                //         controller.bottomSheetType.value = "driverDetails";
                //       } else {
                //         controller.bottomSheetType.value = "conformRide";
                //       }
                //     }
                //   },
                // ),
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
          return GetX<IntercityHomeController>(
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
                                            if (controller.cabCouponList
                                                .where((element) => element.code!.toLowerCase() == controller.couponCodeTextEditController.value.text.toLowerCase())
                                                .isNotEmpty) {
                                              CouponModel couponModel = controller.cabCouponList.firstWhere(
                                                (p0) => p0.code!.toLowerCase() == controller.couponCodeTextEditController.value.text.toLowerCase(),
                                              );
                                              if (couponModel.expiresAt!.toDate().isAfter(DateTime.now())) {
                                                double couponAmount = Constant.calculateDiscount(amount: controller.subTotal.value.toString(), offerModel: couponModel);
                                                if (couponAmount < controller.subTotal.value) {
                                                  controller.selectedCouponModel.value = couponModel;
                                                  controller.calculateTotalAmount();
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
                                        Text("Subtotal".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
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
                        title: "Confirm Booking".tr,
                        onPress: () async {
                          controller.placeOrder();
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

  Widget waitingDialog(BuildContext context, IntercityHomeController controller, bool isDark) {
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
                    onPress: () async {
                      try {
                        // 1. Update current order status
                        controller.currentOrder.update((order) {
                          if (order != null) {
                            order.status = Constant.orderRejected;
                          }
                        });

                        // 2. Save to Firestore
                        if (controller.currentOrder.value.id != null) {
                          await FireStoreUtils.updateCabOrder(controller.currentOrder.value);
                        }

                        // 3. Reset controller states
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
                          Constant.userModel!.inProgressOrderID = null;
                          await FireStoreUtils.updateUser(Constant.userModel!);
                        }

                        // 5. Optional feedback
                        ShowToastDialog.showToast("Ride cancelled successfully".tr);
                        Get.back();
                        CabDashboardController cabDashboardController = Get.put(CabDashboardController());
                        cabDashboardController.selectedIndex.value = 0;
                      } catch (e) {
                        ShowToastDialog.showToast("Failed to cancel ride".tr);
                      }
                    },
                    color: AppThemeData.danger300,
                    textColor: AppThemeData.surface,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget driverDialog(BuildContext context, IntercityHomeController controller, bool isDark) {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        // Was 0.7, which locked the sheet over the map; 0.3 as on the cab screen.
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
                                  // Pickup Location
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
                                  // Destination Location
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
                        Row(
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
                                  // The driver's number, as the normal cab screen shows it.
                                  if (_intercityDriverPhone(controller).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                                      child: Text(
                                        _intercityDriverPhone(controller),
                                        style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                      ),
                                    ),
                                  Builder(builder: (_) {
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
                                          Text(
                                            vType,
                                            style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                          ),
                                        if (brand.isNotEmpty || carModel.isNotEmpty)
                                          Text(
                                            "$brand $carModel".trim(),
                                            style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                          ),
                                        if (plate.isNotEmpty)
                                          Text(
                                            plate.toUpperCase(),
                                            style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 16),
                                          ),
                                      ],
                                    );
                                  }),
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
                                if (_intercityDriverPhone(controller).isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => Constant.makePhoneCall(_intercityDriverPhone(controller)),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: ShapeDecoration(
                                        shape: RoundedRectangleBorder(
                                          side: const BorderSide(width: 1, color: AppThemeData.grey200),
                                          borderRadius: BorderRadius.circular(120),
                                        ),
                                      ),
                                      child: Padding(padding: const EdgeInsets.all(8.0), child: SvgPicture.asset("assets/icons/ic_phone_call.svg")),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
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
                                    Text("Subtotal".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
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
                        const SizedBox(height: 20),
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
                                Text(
                                  controller.selectedPaymentMethod.value.tr,
                                  textAlign: TextAlign.start,
                                  style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Obx(() {
                          if (controller.currentOrder.value.status == Constant.orderInTransit) {
                            return Column(
                              children: [
                                RoundedButtonFill(
                                  title: "SOS".tr,
                                  color: Colors.red.withOpacity(0.50),
                                  textColor: AppThemeData.grey50,
                                  isCenter: true,
                                  icon: Icon(Icons.call, color: Colors.white),
                                  onPress: () async {
                                    ShowToastDialog.showLoader("Please wait...".tr);

                                    LocationData location = await controller.currentLocation.value.getLocation();

                                    await FireStoreUtils.getSOS(controller.currentOrder.value.id ?? '').then((value) async {
                                      if (value == false) {
                                        await FireStoreUtils.setSos(controller.currentOrder.value.id ?? '', UserLocation(latitude: location.latitude!, longitude: location.longitude!)).then((value) {
                                          ShowToastDialog.closeLoader();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Builder(
                                                builder: (context) {
                                                  return Text("Your SOS request has been submitted to admin".tr);
                                                },
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        });
                                      } else {
                                        ShowToastDialog.closeLoader();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Builder(
                                              builder: (context) {
                                                return Text("Your SOS request is already submitted".tr);
                                              },
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          } else {
                            return const SizedBox.shrink();
                          }
                        }),
                      ],
                    ),
                  ),
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
                            controller.completeOrder();
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

  Padding cardDecorationScreen(IntercityHomeController controller, PaymentGateway value, isDark, String image) {
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

  Obx cardDecoration(IntercityHomeController controller, PaymentGateway value, isDark, String image) {
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

  void showBillBifurcationDialog(BuildContext context, bool isDark, IntercityHomeController controller) {
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
}

/// The accepted driver's phone number, with country code, or '' if unknown.
///
/// Taken from the driver block on the ride first, as the normal cab screen
/// does, and from the driver's live profile (`driverModel`, read once the ride
/// is accepted) when the ride's copy has no number.
String _intercityDriverPhone(IntercityHomeController controller) {
  final driver = controller.currentOrder.value.driver;
  final String fromRide = '${driver?.countryCode ?? ''}${driver?.phoneNumber ?? ''}'.trim();
  if ((driver?.phoneNumber ?? '').trim().isNotEmpty) return fromRide;
  final live = controller.driverModel.value;
  if (live.id == null || live.id != controller.currentOrder.value.driverId) return '';
  if ((live.phoneNumber ?? '').trim().isEmpty) return '';
  return '${live.countryCode ?? ''}${live.phoneNumber ?? ''}'.trim();
}
