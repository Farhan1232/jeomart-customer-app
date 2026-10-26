import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/rental_home_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/rental_vehicle_type.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../../themes/text_field_widget.dart';
import '../../utils/utils.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../auth_screens/login_screen.dart';
import '../multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;
import 'package:customer/utils/app_image_cache.dart';

class RentalHomeScreen extends StatelessWidget {
  const RentalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX(
      init: RentalHomeController(),
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
                    onTap: () {
                      log(":: Login  :: 22");
                      Get.offAll(const ServiceListScreen());
                    },
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
                        Constant.userModel == null
                            ? InkWell(
                              onTap: () {
                                Get.offAll(const LoginScreen());
                              },
                              child: Text("Login".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey900)),
                            )
                            : Text(Constant.userModel!.fullName(), style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              controller.isLoading.value
                  ? Center(child: Constant.loader())
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () async {
                              if (Constant.selectedMapType == 'osm') {
                                final result = await Get.to(() => MapPickerPage());
                                if (result != null) {
                                  final firstPlace = result;

                                  if (Constant.checkZoneCheck(firstPlace.coordinates.latitude, firstPlace.coordinates.longitude) == true) {
                                    final address = firstPlace.address;
                                    final lat = firstPlace.coordinates.latitude;
                                    final lng = firstPlace.coordinates.longitude;
                                    controller.sourceTextEditController.value.text = address;
                                    controller.departureLatLongOsm.value = latlong.LatLng(lat, lng);
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
                                      controller.departureLatLong.value = latlong.LatLng(selectedLocationModel.latLng!.latitude, selectedLocationModel.latLng!.longitude);
                                    } else {
                                      ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
                                    }
                                  }
                                });
                              }
                            },
                            hoverColor: Colors.transparent,
                            child: TextFieldWidget(
                              controller: controller.sourceTextEditController.value,
                              hintText: "Your current location".tr,
                              title: "Pickup Location".tr,
                              enable: false,
                              prefix: Padding(padding: EdgeInsets.only(left: 10, right: 10), child: Icon(Icons.stop_circle_outlined, color: Colors.green)),
                            ),
                          ),
                          const SizedBox(height: 25),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text("Select Your Vehicle Type".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => controller.pickDateTime(context),
                                  child: Row(
                                    children: [
                                      Text(
                                        Constant.formatTimestamp(Timestamp.fromDate(controller.selectedDate.value)),
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.date_range, size: 20),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          ListView.builder(
                            itemCount: controller.vehicleTypes.length,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.vertical,
                            itemBuilder: (context, index) {
                              RentalVehicleType vehicleType = controller.vehicleTypes[index];
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
                                                  ? controller.selectedVehicleType.value?.id == vehicleType.id
                                                      ? AppThemeData.carRentDark300
                                                      : Colors.transparent
                                                  : controller.selectedVehicleType.value?.id == vehicleType.id
                                                  ? AppThemeData.carRent300
                                                  : Colors.transparent,
                                          width: 1,
                                        ),
                                        color:
                                            controller.selectedVehicleType.value?.id == vehicleType.id
                                                ? AppThemeData.carRent50
                                                : isDark
                                                ? AppThemeData.carRentDark50
                                                : Colors.white,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              //borderRadius: BorderRadius.circular(10),
                                              child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                                imageUrl: vehicleType.rentalVehicleIcon.toString(),
                                                height: 60,
                                                width: 60,
                                                imageBuilder:
                                                    (context, imageProvider) =>
                                                        Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: imageProvider, fit: BoxFit.cover))),
                                                placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                                errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover),
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
                                                      "${vehicleType.name}",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 1,
                                                        color:
                                                            isDark
                                                                ? controller.selectedVehicleType.value?.id == vehicleType.id
                                                                    ? AppThemeData.greyDark50
                                                                    : AppThemeData.grey50
                                                                : AppThemeData.greyDark50,
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2.0),
                                                      child: Text(
                                                        "${vehicleType.description}",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w400,
                                                          letterSpacing: 1,
                                                          color:
                                                              isDark
                                                                  ? controller.selectedVehicleType.value?.id == vehicleType.id
                                                                      ? AppThemeData.greyDark50
                                                                      : AppThemeData.grey50
                                                                  : AppThemeData.greyDark50,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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
                          const SizedBox(height: 25),
                          RoundedButtonFill(
                            title: "Continue".tr,
                            onPress: () async {
                              final sourceText = controller.sourceTextEditController.value.text.trim();
                              if (!Constant.requireLogin()) return;
                              if (sourceText.isEmpty) {
                                ShowToastDialog.showToast("Please select source location".tr);
                                return;
                              }

                              if (controller.selectedVehicleType.value == null) {
                                ShowToastDialog.showToast("Please select a vehicle type".tr);
                                return;
                              }

                              await controller.getRentalPackage();

                              if (controller.rentalPackages.isEmpty) {
                                ShowToastDialog.showToast("No preference available for the selected vehicle type".tr);
                                return;
                              }

                              // Open bottom sheet if packages exist
                              Get.bottomSheet(selectPreferences(context, controller, isDark), isScrollControlled: true, backgroundColor: Colors.transparent);
                            },
                            color: AppThemeData.primary300,
                            textColor: AppThemeData.grey900,
                          ),
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

  Widget selectPreferences(BuildContext context, RentalHomeController controller, bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.40,
      minChildSize: 0.40,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
            child: Column(
              children: [
                // handle bar
                Container(height: 4, width: 33, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey.shade400)),

                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text("Select Preferences".tr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: controller.rentalPackages.length,
                    itemBuilder: (context, index) {
                      final package = controller.rentalPackages[index];
                      return Obx(
                        () => InkWell(
                          onTap: () => controller.selectedPackage.value = package,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: controller.selectedPackage.value?.id == package.id ? (isDark ? AppThemeData.carRentDark300 : AppThemeData.carRent300) : Colors.transparent,
                                width: 1,
                              ),
                              color:
                                  controller.selectedPackage.value?.id == package.id
                                      ? AppThemeData.carRent50
                                      : isDark
                                      ? AppThemeData.carRentDark50
                                      : Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          package.name ?? "",
                                          style: AppThemeData.semiBoldTextStyle(
                                            fontSize: 18,
                                            color:
                                                isDark
                                                    ? controller.selectedPackage.value?.id == package.id
                                                        ? AppThemeData.greyDark50
                                                        : AppThemeData.grey50
                                                    : AppThemeData.greyDark50,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          package.description ?? "",
                                          style: AppThemeData.mediumTextStyle(
                                            fontSize: 14,
                                            color:
                                                isDark
                                                    ? controller.selectedPackage.value?.id == package.id
                                                        ? AppThemeData.greyDark50
                                                        : AppThemeData.grey50
                                                    : AppThemeData.greyDark50,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    Constant.amountShow(amount: package.baseFare.toString()),
                                    style: AppThemeData.boldTextStyle(
                                      fontSize: 18,
                                      color:
                                          isDark
                                              ? controller.selectedPackage.value?.id == package.id
                                                  ? AppThemeData.greyDark50
                                                  : AppThemeData.grey50
                                              : AppThemeData.greyDark50,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                RoundedButtonFill(
                  title: "Continue".tr,
                  onPress: () {
                    Get.bottomSheet(paymentBottomSheet(context, controller, isDark), isScrollControlled: true, backgroundColor: Colors.transparent);
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
  }

  Widget paymentBottomSheet(BuildContext context, RentalHomeController controller, bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      // Start height
      minChildSize: 0.30,
      // Minimum height
      maxChildSize: 0.8,
      // Maximum height
      expand: false,
      // Prevents full-screen takeover
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: isDark ? AppThemeData.grey500 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Select Payment Method".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                  GestureDetector(onTap: () => Get.back(), child: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),

              // Payment options list
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  controller: scrollController,
                  children: [
                    Text("Preferred Payment".tr, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                    const SizedBox(height: 10),

                    if (controller.walletSettingModel.value.isEnabled == true || controller.cashOnDeliverySettingModel.value.isEnabled == true)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
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
                          Text("Other Payment Options".tr, style: AppThemeData.boldTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500)),
                          const SizedBox(height: 10),
                        ],
                      ),

                    // Other gateways
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Continue button
              RoundedButtonFill(
                title: "Continue".tr,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey900,
                onPress: () async {
                  if (controller.selectedPaymentMethod.value.isEmpty) {
                    ShowToastDialog.showToast("Please select a payment method".tr);
                    return;
                  }

                  // Only check wallet if payment method is wallet
                  if (controller.selectedPaymentMethod.value == "wallet") {
                    num walletAmount = controller.userModel.value.walletAmount ?? 0;
                    num baseFare = double.tryParse(controller.selectedPackage.value?.baseFare.toString() ?? "0") ?? 0;

                    if (walletAmount < baseFare) {
                      ShowToastDialog.showToast("You do not have sufficient wallet balance".tr);
                      return;
                    }
                  }
                  // Complete the order
                  controller.completeOrder();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Obx cardDecoration(RentalHomeController controller, PaymentGateway value, isDark, String image) {
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
}
