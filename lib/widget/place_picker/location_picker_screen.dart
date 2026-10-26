import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/widget/place_picker/location_controller.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: Constant.mapAPIKey);

class LocationPickerScreen extends StatelessWidget {
  const LocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX<LocationController>(
      init: LocationController(),
      builder: (controller) {
        return Scaffold(
          body: Stack(
            children: [
              controller.selectedLocation.value == null
                  ? const Center(child: CircularProgressIndicator())
                  : GoogleMap(
                    onMapCreated: (controllers) {
                      controller.mapController = controllers;
                    },
                    initialCameraPosition: CameraPosition(target: controller.selectedLocation.value!, zoom: 15),
                    onTap: (LatLng tappedPosition) {
                      controller.selectedLocation.value = tappedPosition;
                      controller.getAddressFromLatLng(tappedPosition);
                    },
                    markers:
                        controller.selectedLocation.value == null
                            ? {}
                            : {
                              Marker(
                                markerId: const MarkerId("selected-location"),
                                position: controller.selectedLocation.value!,
                                onTap: () {
                                  controller.getAddressFromLatLng(controller.selectedLocation.value!);
                                },
                              ),
                            },
                    onCameraMove: controller.onMapMoved,
                    onCameraIdle: () {
                      if (controller.selectedLocation.value != null) {
                        controller.getAddressFromLatLng(controller.selectedLocation.value!);
                      }
                    },
                  ),
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Get.back();
                      },
                      child: Container(
                        decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50, borderRadius: BorderRadius.circular(30)),
                        child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.arrow_back_ios_new_outlined, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                      ),
                    ),
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        Prediction? p = await PlacesAutocomplete.show(context: context, apiKey: Constant.mapAPIKey, mode: Mode.overlay, language: "en");
                        if (p != null) {
                          final detail = await _places.getDetailsByPlaceId(p.placeId!);
                          final lat = detail.result.geometry!.location.lat;
                          final lng = detail.result.geometry!.location.lng;
                          final LatLng pos = LatLng(lat, lng);
                          controller.selectedLocation.value = pos;
                          controller.mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
                          controller.getAddressFromLatLng(pos);
                        }
                      },
                      child: Container(
                        width: Responsive.width(100, context),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(60)),
                        child: Row(children: [Icon(Icons.search), SizedBox(width: 8), Text("Search place...".tr)]),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() => Text(controller.address.value, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                      const SizedBox(height: 10),
                      RoundedButtonFill(title: "Confirm Location".tr, height: 5.5, color: AppThemeData.primary300, textColor: AppThemeData.grey50, onPress: () => controller.confirmLocation()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
