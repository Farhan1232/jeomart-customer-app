import 'package:bottom_picker/bottom_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/widget/my_separator.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/on_demand_booking_controller.dart';
import '../../models/user_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/show_toast_dialog.dart';
import '../../themes/text_field_widget.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../location_enable_screens/address_list_screen.dart';
import 'package:customer/utils/app_image_cache.dart';

class OnDemandBookingScreen extends StatelessWidget {
  const OnDemandBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: OnDemandBookingController(),
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
                  Text("Book Service".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Services Section
                Text("Services".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(controller.provider.value?.title ?? '', style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                            const SizedBox(height: 5),
                            Text(controller.categoryTitle.value, style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                            if (controller.provider.value?.priceUnit == "Fixed") ...[
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  GestureDetector(onTap: controller.decrementQuantity, child: Icon(Icons.remove_circle_outline, color: AppThemeData.primary300, size: 30)),
                                  const SizedBox(width: 10),
                                  Text('${controller.quantity.value}', style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                  const SizedBox(width: 10),
                                  GestureDetector(onTap: controller.incrementQuantity, child: Icon(Icons.add_circle_outline, color: AppThemeData.primary300, size: 30)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey.shade300,
                          image: controller.provider.value!.photos.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(controller.provider.value?.photos.first, cacheManager: AppImageCache.manager), fit: BoxFit.cover) : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Address".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                            SizedBox(height: 5),
                            InkWell(
                              onTap: () async {
                                if (Constant.userModel != null) {
                                  Get.to(AddressListScreen())!.then((value) {
                                    if (value != null) {
                                      ShippingAddress shippingAddress = value;
                                      if (Constant.checkZoneCheck(shippingAddress.location!.latitude ?? 0.0, shippingAddress.location!.longitude ?? 0.0)) {
                                        controller.selectedAddress.value = shippingAddress;
                                        controller.calculatePrice();
                                      } else {
                                        ShowToastDialog.showToast("Service not available in this area".tr);
                                      }
                                    }
                                  });
                                } else {
                                  Constant.checkPermission(
                                    onTap: () async {
                                      ShowToastDialog.showLoader("Please wait...".tr);

                                      ShippingAddress shippingAddress = ShippingAddress();

                                      try {
                                        await Geolocator.requestPermission();
                                        await Geolocator.getCurrentPosition();
                                        ShowToastDialog.closeLoader();

                                        if (Constant.selectedMapType == 'osm') {
                                          final result = await Get.to(() => MapPickerPage());
                                          if (result != null) {
                                            final firstPlace = result;
                                            final lat = firstPlace.coordinates.latitude;
                                            final lng = firstPlace.coordinates.longitude;
                                            final address = firstPlace.address;

                                            shippingAddress.addressAs = "Home";
                                            shippingAddress.locality = address.toString();
                                            shippingAddress.location = UserLocation(latitude: lat, longitude: lng);

                                            controller.selectedAddress.value = shippingAddress;
                                            Get.back();
                                          }
                                        } else {
                                          Get.to(LocationPickerScreen())!.then((value) async {
                                            if (value != null) {
                                              SelectedLocationModel selectedLocationModel = value;

                                              shippingAddress.addressAs = "Home";
                                              shippingAddress.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                                              shippingAddress.locality = "Picked from Map";

                                              controller.selectedAddress.value = shippingAddress;
                                            }
                                          });
                                        }
                                      } catch (e) {
                                        await placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) {
                                          Placemark placeMark = valuePlaceMaker[0];
                                          shippingAddress.location = UserLocation(latitude: 19.228825, longitude: 72.854118);
                                          String currentLocation =
                                              "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
                                          shippingAddress.locality = currentLocation;
                                        });

                                        controller.selectedAddress.value = shippingAddress;
                                        ShowToastDialog.closeLoader();
                                      }
                                    },
                                    context: context,
                                  );
                                }
                              },
                              child: Text(
                                controller.selectedAddress.value.getFullAddress(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                TextFieldWidget(title: "Description".tr, hintText: "Enter Description".tr, controller: controller.descriptionController.value, maxLine: 5),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    BottomPicker.dateTime(
                      onSubmit: (value) {
                        if (value is DateTime) {
                          controller.setDateTime(value);
                        }
                      },
                      minDateTime: DateTime.now(),
                      buttonAlignment: MainAxisAlignment.center,
                      displaySubmitButton: true,
                      buttonSingleColor: AppThemeData.primary300,
                      buttonPadding: 10,
                      buttonWidth: 70,
                      backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                      pickerTextStyle: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900,),
                    ).show(context);
                  },
                  child: TextFieldWidget(title: "Booking Date & Slot".tr, hintText: "Choose Date and Time".tr, controller: controller.dateTimeController.value, enable: false),
                ),
                const SizedBox(height: 15),
                controller.provider.value?.priceUnit == "Fixed"
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        controller.couponList.isNotEmpty
                            ? SizedBox(
                              height: 85,
                              child: ListView.builder(
                                itemCount: controller.couponList.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  final coupon = controller.couponList[index];
                                  return GestureDetector(onTap: () => controller.applyCoupon(coupon), child: buildOfferItem(controller, index, isDark));
                                },
                              ),
                            )
                            : Container(),
                        buildPromoCode(controller, isDark),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text("Price Detail".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                        ),
                        priceTotalRow(context, controller, isDark),
                      ],
                    )
                    : SizedBox(),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(20.0),
            child: RoundedButtonFill(title: "Confirm".tr, color: AppThemeData.primary300, textColor: AppThemeData.grey50, onPress: () => controller.confirmBooking(context)),
          ),
        );
      },
    );
  }

  Widget buildOfferItem(OnDemandBookingController controller, int index, bool isDark) {
    return Obx(() {
      final coupon = controller.couponList[index];

      return Container(
        margin: const EdgeInsets.fromLTRB(7, 10, 7, 10),
        height: 85,
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(10), color: AppThemeData.primary300),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Image(image: AssetImage('assets/images/offer_icon.png'), height: 25, width: 25),
                    const SizedBox(width: 10),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      child: Text(
                        coupon.discountType == "Fix Price" ? "${Constant.amountShow(amount: coupon.discount.toString())} ${'OFF'.tr}" : "${coupon.discount} ${'% Off'.tr}",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.7, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coupon.code ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5, color: Colors.orange)),
                    Container(margin: const EdgeInsets.only(left: 15, right: 15, top: 3), width: 1, color: AppThemeData.grey50),
                    Text(
                      "valid till ".tr + controller.getDate(coupon.expiresAt!.toDate().toString()),
                      style: TextStyle(letterSpacing: 0.5, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget buildPromoCode(OnDemandBookingController controller, bool isDark) {
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.asset("assets/images/reedem.png", height: 50, width: 50),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Promo Code".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Text(
                            "Apply promo code".tr,
                            style: AppThemeData.mediumTextStyle(fontSize: 15, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FloatingActionButton(
                onPressed: () {
                  Get.bottomSheet(promoCodeSheet(controller, isDark), isScrollControlled: true, isDismissible: true, backgroundColor: Colors.transparent, enableDrag: true);
                },
                mini: true,
                backgroundColor: Colors.blueGrey.shade50,
                elevation: 0,
                child: const Icon(Icons.add, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget promoCodeSheet(OnDemandBookingController controller, bool isDark) {
    return Container(
      padding: EdgeInsets.only(bottom: Get.height / 4.3, left: 25, right: 25),
      height: Get.height * 0.88,
      decoration: BoxDecoration(color: Colors.transparent, border: Border.all(style: BorderStyle.none)),
      child: Column(
        children: [
          InkWell(
            onTap: () => Get.back(),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100, width: 0.3),
                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.close,
                  color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, // ✅ visible color
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(padding: const EdgeInsets.only(top: 30), child: const Image(image: AssetImage('assets/images/redeem_coupon.png'), width: 100)),
                    Container(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text('Redeem Your Coupons'.tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16)),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.only(top: 10, left: 22, right: 22),
                        child: Text("Voucher or Coupon code".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                      child: DottedBorder(
                        options: RoundedRectDottedBorderOptions(strokeWidth: 1, radius: const Radius.circular(12), color: AppThemeData.primary300),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            alignment: Alignment.center,
                            child: TextFormField(
                              textAlign: TextAlign.center,
                              style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                              controller: controller.couponTextController.value,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Write Coupon Code".tr,
                                hintStyle: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 30, bottom: 30, left: 15, right: 15),
                      child: RoundedButtonFill(
                        title: "REDEEM NOW".tr,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () {
                          final inputCode = controller.couponTextController.value.text.trim().toLowerCase();

                          final matchingCoupon = controller.couponList.firstWhereOrNull((c) => c.code?.toLowerCase() == inputCode);

                          if (matchingCoupon != null) {
                            controller.applyCoupon(matchingCoupon);
                            Get.back();
                          } else {
                            ShowToastDialog.showToast("Applied coupon not valid.".tr);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget priceTotalRow(BuildContext context, OnDemandBookingController controller, bool isDark) {
    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey100),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        ),
        child: Column(
          children: [
            const SizedBox(height: 5),
            rowText("Price".tr, Constant.amountShow(amount: controller.price.value.toString()), isDark),
            controller.discountAmount.value != 0 ? const Divider() : const SizedBox(),
            controller.discountAmount.value != 0
                ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${"Discount".tr} ${controller.discountType.value == 'Percentage' || controller.discountType.value == 'Percent' ? "(${controller.discountLabel.value}%)" : "(${Constant.amountShow(amount: controller.discountLabel.value)})"}",
                              style: TextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                            ),
                            Text(controller.offerCode.value, style: TextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                          ],
                        ),
                      ),
                      Text("(-${Constant.amountShow(amount: controller.discountAmount.value.toString())})", style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                )
                : const SizedBox(),
            const Divider(),
            if (Constant.platformFeeModel?.enable == true) rowText("Platform fee".tr, Constant.amountShow(amount: Constant.platformFeeModel?.fee.toString()), isDark),
            if (Constant.platformFeeModel?.enable == true) const Divider(),
            InkWell(
              onTap: () {
                showBillBifurcationDialog(context, isDark, controller);
              },
              child: rowText("Tax amount".tr, Constant.amountShow(amount: (controller.taxAmount.value).toString()), isDark, underline: true),
            ),
            const Divider(),
            rowText("Total Amount".tr, Constant.amountShow(amount: controller.totalAmount.value.toString()), isDark),
            const SizedBox(height: 5),
          ],
        ),
      );
    });
  }

  Widget rowText(String title, String value, bool isDark, {bool? underline}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.tr,
            style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, decoration: underline == true ? TextDecoration.underline : TextDecoration.none),
          ),
          Text(value.tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
        ],
      ),
    );
  }

  void showBillBifurcationDialog(BuildContext context, bool isDark, OnDemandBookingController controller) {
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
                  const SizedBox(height: 20),
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
