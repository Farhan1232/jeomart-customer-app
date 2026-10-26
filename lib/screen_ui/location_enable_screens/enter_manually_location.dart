import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/enter_manually_location_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';

class EnterManuallyLocationScreen extends StatelessWidget {
  const EnterManuallyLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX<EnterManuallyLocationController>(
      init: EnterManuallyLocationController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            leading: InkWell(
              onTap: () {
                Get.back();
              },
              child: Icon(Icons.arrow_back, size: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.mode == "Edit" ? "Edit Address".tr : "Add a New Address".tr,
                            style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter your location details so we can deliver your orders quickly and accurately.".tr,
                            style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey600),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: Text("Set as Default Address".tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))),
                              Transform.scale(
                                scale: 0.7, // Decrease the size (try 0.5, 0.6, etc.)
                                child: Switch(
                                  value: controller.isDefault.value,
                                  onChanged: (value) {
                                    controller.isDefault.value = value;
                                  },
                                  activeThumbColor: Colors.green,
                                  inactiveThumbColor: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Constant.checkPermission(
                                context: context,
                                onTap: () async {
                                  if (Constant.selectedMapType == 'osm') {
                                    final result = await Get.to(() => MapPickerPage());
                                    if (result != null) {
                                      final firstPlace = result;
                                      final lat = firstPlace.coordinates.latitude;
                                      final lng = firstPlace.coordinates.longitude;
                                      final address = firstPlace.address;

                                      controller.localityEditingController.value.text = address.toString();
                                      controller.location.value = UserLocation(latitude: lat, longitude: lng);
                                    }
                                  } else {
                                    Get.to(LocationPickerScreen())!.then((value) async {
                                      if (value != null) {
                                        SelectedLocationModel selectedLocationModel = value;

                                        controller.localityEditingController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                        controller.location.value = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                                      }
                                    });
                                  }
                                },
                              );
                            },
                            child: TextFieldWidget(
                              title: "Choose Location".tr,
                              hintText: "Choose Location".tr,
                              readOnly: true,
                              enable: false,
                              controller: null,
                              suffix: GestureDetector(
                                onTap: () {
                                  Constant.checkPermission(
                                    context: context,
                                    onTap: () async {
                                      if (Constant.selectedMapType == 'osm') {
                                        final result = await Get.to(() => MapPickerPage());
                                        if (result != null) {
                                          final firstPlace = result;
                                          final lat = firstPlace.coordinates.latitude;
                                          final lng = firstPlace.coordinates.longitude;
                                          final address = firstPlace.address;

                                          controller.localityEditingController.value.text = address.toString();
                                          controller.location.value = UserLocation(latitude: lat, longitude: lng);
                                        }
                                      } else {
                                        Get.to(LocationPickerScreen())!.then((value) async {
                                          if (value != null) {
                                            SelectedLocationModel selectedLocationModel = value;

                                            controller.localityEditingController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                                            controller.location.value = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                                            Get.back();
                                          }
                                        });
                                      }
                                    },
                                  );
                                },
                                child: Padding(padding: const EdgeInsets.only(right: 10), child: Icon(Icons.gps_fixed, size: 24, color: AppThemeData.ecommerce300)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextFieldWidget(title: "Flat/House/Floor/Building*".tr, hintText: "Enter address details".tr, controller: controller.houseBuildingTextEditingController.value),
                          const SizedBox(height: 15),
                          TextFieldWidget(title: "Area/Sector/Locality*".tr, hintText: "Enter area/locality".tr, controller: controller.localityEditingController.value),
                          const SizedBox(height: 15),
                          TextFieldWidget(title: "Nearby Landmark".tr, hintText: "Add a landmark".tr, controller: controller.landmarkEditingController.value),
                          const SizedBox(height: 30),
                          Container(height: 1, color: AppThemeData.grey200),
                          const SizedBox(height: 25),
                          Text("Save Address As".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey900)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children:
                                controller.saveAsList
                                    .map(
                                      (item) => GestureDetector(
                                        onTap: () {
                                          controller.selectedSaveAs.value = item;
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: controller.selectedSaveAs.value == item ? AppThemeData.primary300 : AppThemeData.grey100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          child: Text(
                                            controller.getLocalizedSaveAs(item),
                                            style: AppThemeData.mediumTextStyle(color: controller.selectedSaveAs.value == item ? AppThemeData.grey50 : AppThemeData.grey600),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: 30),
                          RoundedButtonFill(
                            title: "Save Address".tr,
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey50,
                            onPress: () async {
                              if (controller.location.value.latitude == null || controller.location.value.longitude == null) {
                                ShowToastDialog.showToast("Please select Location".tr);
                              } else if (controller.houseBuildingTextEditingController.value.text.isEmpty) {
                                ShowToastDialog.showToast("Please Enter Flat / House / Floor / Building".tr);
                              } else if (controller.localityEditingController.value.text.isEmpty) {
                                ShowToastDialog.showToast("Please Enter Area / Sector / Locality".tr);
                              } else {
                                ShowToastDialog.showLoader("Please wait...".tr);

                                //Common values
                                controller.shippingModel.value.location = controller.location.value;
                                controller.shippingModel.value.addressAs = controller.selectedSaveAs.value;
                                controller.shippingModel.value.address = controller.houseBuildingTextEditingController.value.text;
                                controller.shippingModel.value.locality = controller.localityEditingController.value.text;
                                controller.shippingModel.value.landmark = controller.landmarkEditingController.value.text;

                                if (controller.mode.value == "Edit") {
                                  //Edit Mode
                                  controller.shippingAddressList.value =
                                      controller.shippingAddressList.map((address) {
                                        if (address.id == controller.shippingModel.value.id) {
                                          return controller.shippingModel.value; // replace existing one
                                        }
                                        return address;
                                      }).toList();
                                  Constant.selectedLocation = controller.shippingModel.value;
                                } else {
                                  //Add Mode
                                  controller.shippingModel.value.id = Constant.getUuid();
                                  controller.shippingModel.value.isDefault = controller.shippingAddressList.isEmpty ? true : false;
                                  controller.shippingAddressList.add(controller.shippingModel.value);
                                }

                                //Handle default address switch
                                if (controller.isDefault.value) {
                                  controller.shippingAddressList.value =
                                      controller.shippingAddressList.map((address) {
                                        address.isDefault = address.id == controller.shippingModel.value.id ? true : false;
                                        return address;
                                      }).toList();
                                }

                                controller.userModel.value.shippingAddress = controller.shippingAddressList;
                                await FireStoreUtils.updateUser(controller.userModel.value);

                                ShowToastDialog.closeLoader();
                                Get.back(result: true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
        );
      },
    );
  }
}
