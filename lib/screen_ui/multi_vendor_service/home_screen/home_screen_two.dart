import 'package:customer/utils/banner_tap.dart';
import 'dart:math';

import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/food_home_controller.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/story_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/restaurant_list_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/story_view.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/view_all_category_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/custom_dialog_box.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/preferences.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../../controllers/theme_controller.dart';
import '../../../models/banner_model.dart';
import '../../../service/database_helper.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../widget/gradiant_text.dart';
import '../../auth_screens/login_screen.dart';
import '../advertisement_screens/all_advertisement_screen.dart';
import '../cart_screen/cart_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import '../scan_qrcode_screen/scan_qr_code_screen.dart';
import '../search_screen/search_screen.dart';
import 'category_restaurant_screen.dart';
import 'discount_restaurant_list_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'home_screen.dart';

class HomeScreenTwo extends StatelessWidget {
  const HomeScreenTwo({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: FoodHomeController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          body:
              controller.isLoading.value
                  ? _buildHomeScreenTwoShimmer(isDark)
                  : Constant.isZoneAvailable == false || controller.allNearestRestaurant.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/location.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round()),
                        const SizedBox(height: 12),
                        Text("No Store Found in Your Area".tr, style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold)),
                        const SizedBox(height: 5),
                        Text(
                          "Currently, there are no available store in your zone. Try changing your location to find nearby options.".tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                        ),
                        const SizedBox(height: 20),
                        RoundedButtonFill(
                          title: "Change Zone".tr,
                          width: 55,
                          height: 5.5,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            Get.offAll(const LocationPermissionScreen(autoDetect: false));
                          },
                        ),
                      ],
                    ),
                  )
                  : Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
                    child:
                        controller.isListView.value == false
                            ? const MapView()
                            : Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              Get.offAll(const ServiceListScreen());
                                            },
                                            child: Icon(Icons.arrow_back, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Constant.userModel == null
                                                    ? InkWell(
                                                      onTap: () {
                                                        Get.offAll(const LoginScreen());
                                                      },
                                                      child: Text(
                                                        "Login".tr,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 12),
                                                      ),
                                                    )
                                                    : Text(
                                                      Constant.userModel!.fullName(),
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 12),
                                                    ),
                                                InkWell(
                                                  onTap: () async {
                                                    if (Constant.userModel != null) {
                                                      Get.to(AddressListScreen())!.then((value) {
                                                        if (value != null) {
                                                          ShippingAddress shippingAddress = value;
                                                          Constant.selectedLocation = shippingAddress;
                                                          controller.getData();
                                                        }
                                                      });
                                                    } else {
                                                      Constant.checkPermission(
                                                        onTap: () async {
                                                          ShowToastDialog.showLoader("Please wait...".tr);

                                                          // ✅ declare once for whole method
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
                                                                Constant.selectedLocation = shippingAddress;
                                                                controller.getData();
                                                                Get.back();
                                                              }
                                                            } else {
                                                              Get.to(LocationPickerScreen())!.then((value) async {
                                                                if (value != null) {
                                                                  SelectedLocationModel selectedLocationModel = value;

                                                                  shippingAddress.addressAs = "Home";
                                                                  shippingAddress.location = UserLocation(
                                                                    latitude: selectedLocationModel.latLng!.latitude,
                                                                    longitude: selectedLocationModel.latLng!.longitude,
                                                                  );
                                                                  shippingAddress.locality = "Picked from Map"; // You can reverse-geocode

                                                                  Constant.selectedLocation = shippingAddress;
                                                                  controller.getData();
                                                                }
                                                              });
                                                            }
                                                          } catch (e) {
                                                            await placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) {
                                                              Placemark placeMark = valuePlaceMaker[0];
                                                              shippingAddress.addressAs = "Home";
                                                              shippingAddress.location = UserLocation(latitude: 19.228825, longitude: 72.854118);
                                                              String currentLocation =
                                                                  "${placeMark.name}, ${placeMark.subLocality}, ${placeMark.locality}, ${placeMark.administrativeArea}, ${placeMark.postalCode}, ${placeMark.country}";
                                                              shippingAddress.locality = currentLocation;
                                                            });

                                                            Constant.selectedLocation = shippingAddress;
                                                            ShowToastDialog.closeLoader();
                                                            controller.getData();
                                                          }
                                                        },
                                                        context: context,
                                                      );
                                                    }
                                                  },
                                                  child: Text.rich(
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: Constant.selectedLocation.getFullAddress(),
                                                          style: TextStyle(
                                                            fontFamily: AppThemeData.medium,
                                                            overflow: TextOverflow.ellipsis,
                                                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        WidgetSpan(child: SvgPicture.asset("assets/icons/ic_down.svg")),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          InkWell(
                                            onTap: () async {
                                              (await Get.to(const CartScreen()));
                                              controller.getCartData();
                                            },
                                            child: ClipOval(
                                              child: Container(
                                                padding: const EdgeInsets.all(8.0),
                                                color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                                child: SvgPicture.asset(
                                                  "assets/icons/ic_shoping_cart.svg",
                                                  colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey50 : AppThemeData.grey900, BlendMode.srcIn),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () {
                                          Get.to(const SearchScreen(), arguments: {"vendorList": controller.allNearestRestaurant});
                                        },
                                        child: TextFieldWidget(
                                          hintText:
                                              Constant.sectionConstantModel?.name?.toLowerCase().contains('restaurants') == true
                                                  ? 'Search the dish, food and more...'.tr
                                                  : 'Search the store, item and more...'.tr,
                                          controller: null,
                                          enable: false,
                                          prefix: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SvgPicture.asset("assets/icons/ic_search.svg")),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        controller.bannerModel.isEmpty ? const SizedBox() : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerView(controller: controller)),
                                        const SizedBox(height: 20),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: CategoryView(controller: controller)),
                                        controller.couponRestaurantList.isEmpty
                                            ? const SizedBox()
                                            : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [const SizedBox(height: 20), OfferView(controller: controller)])),
                                        controller.storyList.isEmpty || Constant.storyEnable == false
                                            ? const SizedBox()
                                            : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [const SizedBox(height: 20), StoryView(controller: controller)])),
                                        Visibility(
                                          visible: Constant.isEnableAdsFeature == true,
                                          child:
                                              controller.advertisementList.isEmpty
                                                  ? const SizedBox()
                                                  : Column(
                                                    children: [
                                                      const SizedBox(height: 20),
                                                      Container(
                                                        margin: const EdgeInsets.symmetric(horizontal: 16),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppThemeData.primary300.withAlpha(40)),
                                                        child: Column(
                                                          mainAxisAlignment: MainAxisAlignment.start,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    "Highlights for you".tr,
                                                                    textAlign: TextAlign.start,
                                                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                                                  ),
                                                                ),
                                                                InkWell(
                                                                  onTap: () {
                                                                    Get.to(AllAdvertisementScreen())?.then((value) {
                                                                      controller.getFavouriteRestaurant();
                                                                    });
                                                                  },
                                                                  child: Text(
                                                                    "See all".tr,
                                                                    textAlign: TextAlign.center,
                                                                    style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 16),
                                                            SizedBox(
                                                              height: 220,
                                                              child: ListView.builder(
                                                                physics: const BouncingScrollPhysics(),
                                                                scrollDirection: Axis.horizontal,
                                                                itemCount: controller.advertisementList.length >= 10 ? 10 : controller.advertisementList.length,
                                                                padding: EdgeInsets.all(0),
                                                                itemBuilder: (BuildContext context, int index) {
                                                                  return AdvertisementHomeCard(controller: controller, model: controller.advertisementList[index]);
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                        controller.allNearestRestaurant.isEmpty ? const SizedBox() : Column(children: [const SizedBox(height: 20), RestaurantView(controller: controller)]),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                  ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Container(
            decoration: BoxDecoration(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, borderRadius: const BorderRadius.all(Radius.circular(30))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: const BorderRadius.all(Radius.circular(30))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              controller.isListView.value = true;
                            },
                            child: ClipOval(
                              child: Container(
                                decoration: BoxDecoration(color: controller.isListView.value ? AppThemeData.primary300 : null),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SvgPicture.asset(
                                    "assets/icons/ic_view_grid_list.svg",
                                    colorFilter: ColorFilter.mode(controller.isListView.value ? AppThemeData.grey50 : AppThemeData.grey500, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              controller.isListView.value = false;
                            },
                            child: ClipOval(
                              child: Container(
                                decoration: BoxDecoration(color: controller.isListView.value == false ? AppThemeData.primary300 : null),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SvgPicture.asset(
                                    "assets/icons/ic_map_draw.svg",
                                    colorFilter: ColorFilter.mode(controller.isListView.value == false ? AppThemeData.grey50 : AppThemeData.grey500, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      Get.to(const ScanQrCodeScreen());
                    },
                    child: ClipOval(
                      child: Container(
                        decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: SvgPicture.asset("assets/icons/ic_scan_code.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey400 : AppThemeData.grey500, BlendMode.srcIn)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  DropdownButton<String>(
                    isDense: false,
                    underline: const SizedBox(),
                    value: controller.selectedOrderTypeValue.value.tr,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items:
                        <String>['Delivery'.tr, 'TakeAway'.tr].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value.tr, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                          );
                        }).toList(),
                    onChanged: (value) async {
                      if (cartItem.isEmpty) {
                        await Preferences.setString(Preferences.foodDeliveryType, value!);
                        controller.selectedOrderTypeValue.value = value;
                        controller.getData();
                      } else {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return CustomDialogBox(
                              title: "Alert".tr,
                              descriptions: "Do you really want to change the delivery option? Your cart will be empty.".tr,
                              positiveString: "Ok".tr,
                              negativeString: "Cancel".tr,
                              positiveClick: () async {
                                await Preferences.setString(Preferences.foodDeliveryType, value!);
                                controller.selectedOrderTypeValue.value = value;
                                controller.getData();
                                DatabaseHelper.instance.deleteAllCartProducts();
                                controller.cartProvider.clearDatabase();
                                controller.getCartData();
                                Get.back();
                              },
                              negativeClick: () {
                                Get.back();
                              },
                              img: null,
                            );
                          },
                        );
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

class CategoryView extends StatelessWidget {
  final FoodHomeController controller;

  const CategoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text("Our Categories".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18))),
                      InkWell(
                        onTap: () {
                          Get.to(const ViewAllCategoryScreen());
                        },
                        child: Text(
                          "See all".tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  GradientText(
                    'Best Servings Items'.tr,
                    style: TextStyle(fontSize: 24, fontFamily: 'Inter Tight', fontWeight: FontWeight.w800),
                    gradient: LinearGradient(colors: [Color(0xFF3961F1), Color(0xFF11D0EA)]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 5 / 6),
              itemCount: controller.vendorCategoryModel.length >= 8 ? 8 : controller.vendorCategoryModel.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                VendorCategoryModel vendorCategoryModel = controller.vendorCategoryModel[index];
                return InkWell(
                  onTap: () {
                    Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": false});
                  },
                  child: Column(
                    children: [
                      ClipOval(child: SizedBox(width: 60, height: 60, child: NetworkImageWidget(imageUrl: vendorCategoryModel.photo.toString(), fit: BoxFit.cover))),
                      Text(
                        "${vendorCategoryModel.title}",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class OfferView extends StatelessWidget {
  final FoodHomeController controller;

  const OfferView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text("Large Discounts".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18))),
                      InkWell(
                        onTap: () {
                          Get.to(const DiscountRestaurantListScreen(), arguments: {"vendorList": controller.couponRestaurantList, "couponList": controller.couponList, "title": "Discounts Stores"});
                        },
                        child: Text(
                          "See all".tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  GradientText(
                    'Save Upto 50% Off'.tr,
                    style: TextStyle(fontSize: 24, fontFamily: 'Inter Tight', fontWeight: FontWeight.w800),
                    gradient: LinearGradient(colors: [Color(0xFF39F1C5), Color(0xFF97EA11)]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * 0.32,
              child: ListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: controller.couponRestaurantList.length >= 15 ? 15 : controller.couponRestaurantList.length,
                itemBuilder: (context, index) {
                  VendorModel vendorModel = controller.couponRestaurantList[index];
                  CouponModel offerModel = controller.couponList[index];
                  return InkWell(
                    onTap: () {
                      Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: Responsive.width(34, context),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          child: Stack(
                            children: [
                              NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, height: Responsive.height(100, context), width: Responsive.width(100, context)),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), AppThemeData.grey900]),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        vendorModel.title.toString(),
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(fontSize: 18, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                                      ),
                                      const SizedBox(height: 5),
                                      RoundedButtonFill(
                                        title:
                                            "${offerModel.discountType == "Fix Price" ? Constant.currencyModel!.symbol : ""}${offerModel.discount}${offerModel.discountType == "Percentage" ? "% off".tr : "off".tr}",
                                        color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
                                        textColor: AppThemeData.grey50,
                                        width: 20,
                                        height: 3.5,
                                        onPress: () async {},
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
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class BannerView extends StatelessWidget {
  final FoodHomeController controller;

  const BannerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: PageView.builder(
        physics: const BouncingScrollPhysics(),
        controller: controller.pageController.value,
        scrollDirection: Axis.horizontal,
        itemCount: controller.bannerModel.length,
        padEnds: false,
        pageSnapping: true,
        onPageChanged: (value) {
          controller.currentPage.value = value;
        },
        itemBuilder: (BuildContext context, int index) {
          BannerModel bannerModel = controller.bannerModel[index];
          return InkWell(
            onTap: () async {
              await openBanner(bannerModel);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(12)), child: NetworkImageWidget(imageUrl: bannerModel.photo.toString(), fit: BoxFit.cover)),
            ),
          );
        },
      ),
    );
  }
}

class StoryView extends StatelessWidget {
  final FoodHomeController controller;

  const StoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      height: Responsive.height(32, context),
      decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(20)), image: DecorationImage(image: AssetImage("assets/images/story_bg.png"), fit: BoxFit.cover)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text("Stories".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 18)))]),
                GradientText(
                  'Best Items Stories Ever'.tr,
                  style: TextStyle(fontSize: 24, fontFamily: 'Inter Tight', fontWeight: FontWeight.w800),
                  gradient: LinearGradient(colors: [Color(0xFFF1C839), Color(0xFFEA1111)]),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: controller.storyList.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  StoryModel storyModel = controller.storyList[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => MoreStories(storyList: controller.storyList, index: index)));
                      },
                      child: SizedBox(
                        width: 134,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          child: Stack(
                            children: [
                              NetworkImageWidget(imageUrl: storyModel.videoThumbnail.toString(), fit: BoxFit.cover, height: Responsive.height(100, context), width: Responsive.width(100, context)),
                              Container(color: Colors.black.withOpacity(0.30)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                                child: FutureBuilder(
                                  future: FireStoreUtils.getVendorById(storyModel.vendorID.toString()),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return Constant.loader();
                                    } else {
                                      if (snapshot.hasError) {
                                        return Center(child: Text('${"Error".tr}: ${snapshot.error}'));
                                      } else if (snapshot.data == null) {
                                        return const SizedBox();
                                      } else {
                                        VendorModel vendorModel = snapshot.data!;
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipOval(child: NetworkImageWidget(imageUrl: vendorModel.photo.toString(), width: 30, height: 30, fit: BoxFit.cover)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    vendorModel.title.toString(),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    style: const TextStyle(color: Colors.white, fontSize: 12, overflow: TextOverflow.ellipsis, fontWeight: FontWeight.w700),
                                                  ),
                                                  Row(
                                                    children: [
                                                      SvgPicture.asset("assets/icons/ic_star.svg"),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum!.toStringAsFixed(0))} ${'reviews'.tr}",
                                                        textAlign: TextAlign.center,
                                                        maxLines: 1,
                                                        style: const TextStyle(color: AppThemeData.warning300, fontSize: 10, overflow: TextOverflow.ellipsis, fontWeight: FontWeight.w700),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    }
                                  },
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
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class RestaurantView extends StatelessWidget {
  final FoodHomeController controller;

  const RestaurantView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text("Best Stores".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18))),
                  InkWell(
                    onTap: () {
                      Get.to(const RestaurantListScreen(), arguments: {"vendorList": controller.allNearestRestaurant, "title": "Best Stores"});
                    },
                    child: Text(
                      "See all".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.vertical,
                itemCount: controller.allNearestRestaurant.length,
                itemBuilder: (BuildContext context, int index) {
                  VendorModel vendorModel = controller.allNearestRestaurant[index];
                  List<CouponModel> tempList = [];
                  List<double> discountAmountTempList = [];
                  for (var element in controller.couponList) {
                    if (vendorModel.id == element.vendorID && element.expiresAt!.toDate().isAfter(DateTime.now())) {
                      tempList.add(element);
                      discountAmountTempList.add(double.parse(element.discount.toString()));
                    }
                  }
                  return InkWell(
                    onTap: () {
                      Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(16)),
                              child: Stack(
                                children: [
                                  NetworkImageWidget(height: Responsive.height(14, context), width: Responsive.width(30, context), imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover),
                                  Container(
                                    height: Responsive.height(14, context),
                                    width: Responsive.width(30, context),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                                    ),
                                  ),
                                  discountAmountTempList.isEmpty
                                      ? const SizedBox()
                                      : Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Upto".tr,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  overflow: TextOverflow.ellipsis,
                                                  fontFamily: AppThemeData.regular,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                ),
                                              ),
                                              Text(
                                                discountAmountTempList.reduce(min).toString() + "% OFF".tr,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  overflow: TextOverflow.ellipsis,
                                                  fontFamily: AppThemeData.semiBold,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendorModel.title.toString(),
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 18, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                  ),
                                  Text(
                                    vendorModel.location.toString(),
                                    textAlign: TextAlign.start,
                                    maxLines: 2,
                                    style: TextStyle(
                                      overflow: TextOverflow.ellipsis,
                                      fontFamily: AppThemeData.medium,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        Visibility(
                                          visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                                          child: Row(
                                            children: [
                                              SvgPicture.asset("assets/icons/ic_free_delivery.svg", width: 18),
                                              const SizedBox(width: 5),
                                              Text(
                                                "Free Delivery".tr,
                                                style: TextStyle(
                                                  overflow: TextOverflow.ellipsis,
                                                  fontFamily: AppThemeData.medium,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: SvgPicture.asset("assets/icons/ic_star.svg", width: 18, colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                            ),
                                            Text(
                                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                              textAlign: TextAlign.start,
                                              maxLines: 1,
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.medium,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Icon(Icons.circle, size: 5, color: isDark ? AppThemeData.grey400 : AppThemeData.grey500),
                                            ),
                                            Text(
                                              "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                              textAlign: TextAlign.start,
                                              maxLines: 1,
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.medium,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                              ),
                                            ),
                                          ],
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildHomeScreenTwoShimmer(bool isDark) {
  final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

  Widget box({double w = double.infinity, double h = 14, double radius = 8}) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(radius)));

  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // Header row: back icon + location block + cart icon
          Row(
            children: [
              box(w: 24, h: 24, radius: 4),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box(w: 100, h: 12), const SizedBox(height: 6), box(w: 180, h: 14)])),
              box(w: 42, h: 42, radius: 21),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
          box(h: 48, radius: 12),
          const SizedBox(height: 20),
          // Banner (comes before categories in HomeScreenTwo)
          box(h: 160, radius: 16),
          const SizedBox(height: 20),
          // Category row title
          box(w: 140, h: 16),
          const SizedBox(height: 12),
          // Category row
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => Column(children: [box(w: 56, h: 56, radius: 28), const SizedBox(height: 6), box(w: 44, h: 10)]),
            ),
          ),
          const SizedBox(height: 20),
          // Coupon/offer row title
          box(w: 120, h: 16),
          const SizedBox(height: 12),
          // Coupon/offer cards row
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => box(w: 140, h: 160, radius: 12),
            ),
          ),
          const SizedBox(height: 20),
          // Restaurant cards title
          box(w: 120, h: 16),
          const SizedBox(height: 12),
          // Restaurant cards
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  box(w: 80, h: 80, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box(h: 14), const SizedBox(height: 8), box(w: 120, h: 12), const SizedBox(height: 8), box(w: 80, h: 10)]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
