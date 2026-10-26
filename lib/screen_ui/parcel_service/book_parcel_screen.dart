import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/utils.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/book_parcel_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/user_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';

class BookParcelScreen extends StatelessWidget {
  const BookParcelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: BookParcelController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Book Your Document Delivery".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                        Text(
                          "Schedule a secure and timely pickup & delivery".tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppThemeData.mediumTextStyle(fontSize: 12, color: AppThemeData.grey900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                selectDeliveryTypeView(controller, isDark, context),
                const SizedBox(height: 16),
                buildUploadBoxView(isDark, controller),
                const SizedBox(height: 16),
                buildInfoSectionView(
                  title: "Sender Information".tr,
                  locationController: controller.senderLocationController.value,
                  nameController: controller.senderNameController.value,
                  mobileController: controller.senderMobileController.value,
                  noteController: controller.senderNoteController.value,
                  countryCodeController: controller.senderCountryCodeController.value,
                  countryISOCodeController: controller.senderCountryISOCodeController.value,
                  showWeight: true,
                  isDark: isDark,
                  context: context,
                  controller: controller,
                  onTap: () async {
                    if (Constant.selectedMapType == 'osm') {
                      final result = await Get.to(() => MapPickerPage());
                      if (result != null) {
                        final firstPlace = result;

                        if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                          final address = firstPlace.address;
                          final lat = firstPlace.coordinates.latitude;
                          final lng = firstPlace.coordinates.longitude;
                          controller.senderLocationController.value.text = address; // ✅
                          controller.senderLocation.value = UserLocation(latitude: lat, longitude: lng); // ✅ <-- Add this
                        } else {
                          ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                        }
                      }
                    } else {
                      Get.to(LocationPickerScreen())!.then((value) async {
                        if (value != null) {
                          SelectedLocationModel selectedLocationModel = value;

                          if (Constant.checkZoneCheck(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude) == true) {
                            controller.senderLocationController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                            controller.senderLocation.value = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                          } else {
                            ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                          }
                          // ✅ <-- Add this
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                buildInfoSectionView(
                  title: "Receiver Information".tr,
                  locationController: controller.receiverLocationController.value,
                  nameController: controller.receiverNameController.value,
                  mobileController: controller.receiverMobileController.value,
                  noteController: controller.receiverNoteController.value,
                  countryCodeController: controller.receiverCountryCodeController.value,
                  countryISOCodeController: controller.receiverISOCountryCodeController.value,
                  showWeight: false,
                  isDark: isDark,
                  context: context,
                  controller: controller,
                  onTap: () async {
                    if (Constant.selectedMapType == 'osm') {
                      final result = await Get.to(() => MapPickerPage());
                      if (result != null) {
                        final firstPlace = result;

                        if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                          final lat = firstPlace.coordinates.latitude;
                          final lng = firstPlace.coordinates.longitude;
                          final address = firstPlace.address;

                          controller.receiverLocationController.value.text = address; // ✅
                          controller.receiverLocation.value = UserLocation(latitude: lat, longitude: lng);
                        } else {
                          ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                        }
                      }
                    } else {
                      Get.to(LocationPickerScreen())!.then((value) async {
                        if (value != null) {
                          SelectedLocationModel selectedLocationModel = value;

                          if (Constant.checkZoneCheck(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude) == true) {
                            controller.receiverLocationController.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                            controller.receiverLocation.value = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude); // ✅ <-- Add this
                          } else {
                            ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                          }
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 15),
                RoundedButtonFill(
                  title: "Continue".tr,
                  onPress: () {
                    controller.bookNow();
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.grey900,
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget selectDeliveryTypeView(BookParcelController controller, bool isDark, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select delivery type".tr, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13)),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              controller.selectedDeliveryType.value = 'now';
              controller.isScheduled.value = false;
            },
            child: Row(
              children: [
                Image.asset("assets/images/image_parcel.png", height: 38, width: 38),
                const SizedBox(width: 20),
                Expanded(child: Text("As soon as possible".tr, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16))),
                Icon(
                  controller.selectedDeliveryType.value == 'now' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: controller.selectedDeliveryType.value == 'now' ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              controller.selectedDeliveryType.value = 'later';
              controller.isScheduled.value = true;
            },
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset("assets/images/image_parcel_scheduled.png", height: 38, width: 38),
                    const SizedBox(width: 20),
                    Expanded(child: Text("Scheduled".tr, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16))),
                    Icon(
                      controller.selectedDeliveryType.value == 'later' ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: controller.selectedDeliveryType.value == 'later' ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                      size: 20,
                    ),
                  ],
                ),
                if (controller.selectedDeliveryType.value == 'later') ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => controller.pickScheduledDate(context),
                    child: TextFieldWidget(
                      hintText: "When to pickup at this address".tr,
                      controller: controller.scheduledDateController.value,
                      enable: false,
                      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                      borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                      suffix: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.calendar_month_outlined)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => controller.pickScheduledTime(context),
                    child: TextFieldWidget(
                      hintText: "When to pickup at this address".tr,
                      controller: controller.scheduledTimeController.value,
                      enable: false,
                      // onchange: (v) => controller.pickScheduledTime(context),
                      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                      borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                      suffix: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.access_time)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUploadBoxView(bool isDark, BookParcelController controller) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Upload parcel image".tr, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13)),
          const SizedBox(height: 10),
          DottedBorder(
            options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(10), color: isDark ? AppThemeData.greyDark300 : AppThemeData.grey300),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset("assets/icons/ic_upload_parcel.svg", height: 40, width: 40),
                  const SizedBox(height: 10),
                  Text("Upload Parcel Image".tr, style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                  const SizedBox(height: 4),
                  Text("Supported: .jpg, .jpeg, .png".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                  Text("Max size 1MB".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                  const SizedBox(height: 8),
                  RoundedButtonFill(
                    title: "Browse Image".tr,
                    onPress: () {
                      controller.onCameraClick(Get.context!);
                    },
                    color: AppThemeData.primary300,
                    textColor: AppThemeData.grey900,
                    width: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (controller.images.isEmpty) const SizedBox(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                controller.images.map((image) {
                  return Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(top: 20, right: 20),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(image.path), width: 70, height: 70, fit: BoxFit.cover)),
                      ),
                      Positioned.fill(
                        top: 0,
                        right: 0,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: AppThemeData.danger300, size: 20),
                            onPressed: () {
                              controller.images.remove(image);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildInfoSectionView({
    required String title,
    required TextEditingController locationController,
    required TextEditingController nameController,
    required TextEditingController mobileController,
    required TextEditingController noteController,
    required TextEditingController countryCodeController,
    required TextEditingController countryISOCodeController,
    bool showWeight = false,
    GestureTapCallback? onTap,
    required bool isDark,
    required BookParcelController controller,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500, fontSize: 13)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onTap,
            child: TextFieldWidget(
              hintText: "Your Location".tr,
              controller: locationController,
              suffix: const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.location_on_outlined)),
              backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
              borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
              enable: false,
            ),
          ),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Name".tr,
            controller: nameController,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
          ),
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Enter Mobile number".tr,
            controller: mobileController,
            textInputType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]')), LengthLimitingTextInputFormatter(10)],
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
            prefix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountryCodePicker(
                  onInit: (value) {
                    countryCodeController.text = value?.dialCode ?? Constant.defaultCountryCode;
                    countryISOCodeController.text = value?.code ?? Constant.defaultCountryCode;
                  },
                  onChanged: (value) {
                    countryCodeController.text = value.dialCode ?? Constant.defaultCountryCode;
                    countryISOCodeController.text = value.code ?? Constant.defaultCountryCode;
                  },
                  initialSelection: countryISOCodeController.text.isNotEmpty ? countryISOCodeController.text : Constant.defaultCountryCode,
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  textStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : Colors.black),
                  dialogTextStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                  searchStyle: TextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                  dialogBackgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                  padding: EdgeInsets.zero,
                ),
                // const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: AppThemeData.grey400),
                Container(height: 24, width: 1, color: AppThemeData.grey400),
                const SizedBox(width: 4),
              ],
            ),
          ),
          if (showWeight) ...[
            const SizedBox(height: 10),
            DropDownTextField(
              controller: controller.senderWeightController.value,
              clearOption: false,
              enableSearch: false,
              textFieldDecoration: InputDecoration(
                hintText: "Select parcel Weight".tr,
                hintStyle: AppThemeData.regularTextStyle(fontSize: 14, color: isDark ? AppThemeData.grey400 : AppThemeData.greyDark400),
                filled: true,
                fillColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppThemeData.grey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppThemeData.grey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppThemeData.grey200)),
              ),
              dropDownList:
                  controller.parcelWeight.map((e) {
                    return DropDownValueModel(
                      name: e.title ?? 'Normal'.tr,
                      value: e.title ?? 'Normal'.tr, // safer to use title string
                    );
                  }).toList(),
              onChanged: (val) {
                if (val is DropDownValueModel) {
                  controller.senderWeightController.value.setDropDown(val);

                  // Link it to the selectedWeight object
                  controller.selectedWeight = controller.parcelWeight.firstWhereOrNull((e) => e.title == val.value);
                }
              },
            ),
          ],
          const SizedBox(height: 10),
          TextFieldWidget(
            hintText: "Notes (Optional)".tr,
            controller: noteController,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
          ),
        ],
      ),
    );
  }
}
