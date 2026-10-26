import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../constant/assets.dart';
import '../../utils/utils.dart';

class LocationPermissionScreen extends StatefulWidget {
  // autoDetect: true (onboarding) fetches current location automatically.
  // false (e.g. "Change Zone") lets the user pick current or manual location.
  final bool autoDetect;

  const LocationPermissionScreen({super.key, this.autoDetect = true});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoDetect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestCurrentLocation();
      });
    }
  }

  Future<void> _requestCurrentLocation() async {
    if (_isLocating) return;
    await Constant.checkPermission(context: context, onTap: _detectAndSaveCurrentLocation);
  }

  Future<void> _detectAndSaveCurrentLocation() async {
    if (_isLocating) return;
    _isLocating = true;
    ShowToastDialog.showLoader("Getting your location...".tr);

    try {
      final position = await Utils.getCurrentLocation();
      if (position == null) {
        ShowToastDialog.showToast("Please enable location services and try again.".tr);
        return;
      }

      final locality = await Utils.getAddressFromCoordinates(position.latitude, position.longitude);
      final addressModel = ShippingAddress(
        id: 'current_location',
        addressAs: 'Current Location',
        locality: locality == 'Unknown location' ? '${position.latitude}, ${position.longitude}' : locality,
        location: UserLocation(latitude: position.latitude, longitude: position.longitude),
        isDefault: true,
      );

      await _persistLocation(addressModel);
      Constant.selectedLocation = addressModel;
      Constant.currentLocation = position;
      if (mounted) Get.offAll(const ServiceListScreen());
    } catch (error) {
      ShowToastDialog.showToast(
        error.toString().contains('permanently denied')
            ? "Location permission is disabled. Enable it in app settings.".tr
            : "Unable to get your current location. Please try again or set it from the map.".tr,
      );
    } finally {
      _isLocating = false;
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> _persistLocation(ShippingAddress addressModel) async {
    // Guests have no account/profile to persist to — keep it in-memory only.
    if (auth.FirebaseAuth.instance.currentUser == null) return;

    final user = Constant.userModel ?? await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
    if (user == null) return;
    // Whoever had to read it, everything after this point should be able to
    // find the signed-in customer in memory.
    Constant.userModel = user;

    final addresses = List<ShippingAddress>.from(user.shippingAddress ?? []);
    for (final address in addresses) {
      address.isDefault = false;
    }
    addresses.removeWhere((address) => address.id == addressModel.id);
    addresses.insert(0, addressModel);
    user.shippingAddress = addresses;
    await FireStoreUtils.updateUser(user);
  }

  // Keeps the app usable when Location Services are disabled or denied:
  // proceed with the existing/default location instead of blocking the user.
  void _continueWithoutLocation() {
    if (Constant.selectedLocation.location == null) {
      Constant.selectedLocation = Constant.defaultGuestLocation;
    }
    Get.offAll(const ServiceListScreen());
  }

  Future<void> _saveAndContinue(ShippingAddress addressModel) async {
    addressModel.id ??= Constant.getUuid();
    addressModel.isDefault = true;
    await _persistLocation(addressModel);
    Constant.selectedLocation = addressModel;
    if (mounted) Get.offAll(const ServiceListScreen());
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Image.asset(AppAssets.icLocation),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Enable Location for a Personalized Experience".tr,
                    style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    "Allow location access to discover beauty stores and services near you.".tr,
                    style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 30),
                RoundedButtonFill(
                  title: "Use current location".tr,
                  onPress: _requestCurrentLocation,
                  color: AppThemeData.grey900,
                  textColor: AppThemeData.grey50,
                ),
                const SizedBox(height: 10),
                RoundedButtonFill(
                  title: "Set from map".tr,
                  onPress: () async {
                    Constant.checkPermission(
                      context: context,
                      onTap: () async {
                        ShowToastDialog.showLoader("Please wait...".tr);
                        ShippingAddress addressModel = ShippingAddress();
                        try {
                          await Geolocator.requestPermission();
                          await Geolocator.getCurrentPosition(
                            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
                          );
                          ShowToastDialog.closeLoader();
                          if (Constant.selectedMapType == 'osm') {
                            final result = await Get.to(() => MapPickerPage());
                            if (result != null) {
                              final firstPlace = result;
                              final lat = firstPlace.coordinates.latitude;
                              final lng = firstPlace.coordinates.longitude;
                              final address = firstPlace.address;

                              addressModel.addressAs = "Home";
                              addressModel.locality = address.toString();
                              addressModel.location = UserLocation(latitude: lat, longitude: lng);
                              await _saveAndContinue(addressModel);
                            }
                          } else {
                            Get.to(LocationPickerScreen())!.then((value) async {
                              if (value != null) {
                                SelectedLocationModel selectedLocationModel = value;

                                addressModel.addressAs = "Home";
                                addressModel.locality = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                addressModel.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                                await _saveAndContinue(addressModel);
                              }
                            });
                          }
                        } catch (e) {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Unable to open the map. Please try again.".tr);
                        }
                      },
                    );
                  },
                  color: AppThemeData.grey50,
                  textColor: AppThemeData.grey900,
                ),
                const SizedBox(height: 20),
                Constant.userModel == null
                    ? const SizedBox()
                    : GestureDetector(
                      onTap: () async {
                        Get.to(AddressListScreen())!.then((value) {
                          if (value != null) {
                            ShippingAddress addressModel = value;
                            Constant.selectedLocation = addressModel;
                            Get.offAll(const ServiceListScreen());
                          }
                        });
                      },
                      child: Text("Enter Manually location".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                    ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _continueWithoutLocation,
                  child: Text("Continue without location".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
