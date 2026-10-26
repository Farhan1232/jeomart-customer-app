import 'package:customer/utils/banner_tap.dart';
import 'dart:developer';

import 'package:badges/badges.dart' as badges;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/map_view_controller.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/favourite_model.dart';
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
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/preferences.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;

import '../../../controllers/food_home_controller.dart';
import '../../../controllers/theme_controller.dart';
import '../../../models/banner_model.dart';
import '../../../models/story_model.dart';
import '../../../service/database_helper.dart';
import '../../../service/fire_store_utils.dart';
import '../../../themes/show_toast_dialog.dart';
import '../../../themes/text_field_widget.dart';
import '../../../widget/restaurant_image_view.dart';
import '../../../widget/video_widget.dart';
import '../../auth_screens/login_screen.dart';
import '../advertisement_screens/all_advertisement_screen.dart';
import '../cart_screen/cart_screen.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';
import '../scan_qrcode_screen/scan_qr_code_screen.dart';
import '../search_screen/search_screen.dart';
import 'category_restaurant_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'discount_restaurant_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: FoodHomeController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(0.00, -3),
                colors: [isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce50, isDark ? AppThemeData.surfaceDark : AppThemeData.surface],
                end: const Alignment(0, 1),
              ),
            ),
            child:
                controller.isLoading.value
                    ? _buildHomeShimmer(isDark)
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
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                log(":: Login  :: 11");
                                                Get.offAll(const ServiceListScreen());
                                              },
                                              icon: Icon(Icons.arrow_back, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, size: 20),
                                            ),

                                            SizedBox(width: 10),
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

                                                            // ✅ declare it once here!
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
                                            Obx(
                                              () => badges.Badge(
                                                showBadge: cartItem.isEmpty ? false : true,
                                                badgeContent: Text(
                                                  "${cartItem.length}",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    overflow: TextOverflow.ellipsis,
                                                    fontFamily: AppThemeData.semiBold,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                                  ),
                                                ),
                                                badgeStyle: badges.BadgeStyle(shape: badges.BadgeShape.circle, badgeColor: AppThemeData.ecommerce300),
                                                child: InkWell(
                                                  onTap: () async {
                                                    (await Get.to(const CartScreen()));
                                                    controller.getCartData();
                                                  },
                                                  child: ClipOval(
                                                    child: Container(
                                                      width: 42,
                                                      height: 42,
                                                      decoration: ShapeDecoration(
                                                        shape: RoundedRectangleBorder(
                                                          side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                                                          borderRadius: BorderRadius.circular(120),
                                                        ),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: SvgPicture.asset(
                                                          "assets/icons/ic_shoping_cart.svg",
                                                          colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey50 : AppThemeData.grey900, BlendMode.srcIn),
                                                        ),
                                                      ),
                                                    ),
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
                                                    ? 'Search the restaurant, food and more...'.tr
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
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          controller.storyList.isEmpty || Constant.storyEnable == false
                                              ? const SizedBox()
                                              : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: StoryView(controller: controller)),
                                          SizedBox(height: controller.storyList.isEmpty ? 0 : 20),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                titleView(isDark, "Explore the Categories", () {
                                                  Get.to(const ViewAllCategoryScreen());
                                                }),
                                                const SizedBox(height: 10),
                                                CategoryView(controller: controller),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          controller.bannerModel.isEmpty ? const SizedBox() : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerView(controller: controller)),
                                          controller.couponRestaurantList.isEmpty
                                              ? const SizedBox()
                                              : Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    titleView(isDark, "Largest Discounts", () {
                                                      Get.to(
                                                        const DiscountRestaurantListScreen(),
                                                        arguments: {"vendorList": controller.couponRestaurantList, "couponList": controller.couponList, "title": "Discounts Stores"},
                                                      );
                                                    }),
                                                    const SizedBox(height: 16),
                                                    OfferView(controller: controller),
                                                  ],
                                                ),
                                              ),
                                          const SizedBox(height: 28),
                                          controller.newArrivalRestaurantList.isEmpty
                                              ? const SizedBox()
                                              : Container(
                                                decoration: const BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/ic_new_arrival_bg.png"), fit: BoxFit.cover)),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              "New Arrivals".tr,
                                                              textAlign: TextAlign.start,
                                                              style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () {
                                                              Get.to(const RestaurantListScreen(), arguments: {"vendorList": controller.newArrivalRestaurantList, "title": "New Arrival"})?.then((v) {
                                                                controller.getFavouriteRestaurant();
                                                              });
                                                            },
                                                            child: Text(
                                                              "View all".tr,
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 16),
                                                      NewArrival(controller: controller),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          const SizedBox(height: 20),
                                          controller.bannerBottomModel.isEmpty
                                              ? const SizedBox()
                                              : Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: BannerBottomView(controller: controller)),
                                          Visibility(visible: (Constant.isEnableAdsFeature == true && controller.advertisementList.isNotEmpty), child: const SizedBox(height: 20)),
                                          Visibility(
                                            visible: Constant.isEnableAdsFeature == true,
                                            child:
                                                controller.advertisementList.isEmpty
                                                    ? const SizedBox()
                                                    : Container(
                                                      color: AppThemeData.primary300.withAlpha(40),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                                                    "View all".tr,
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
                                                    ),
                                          ),
                                          const SizedBox(height: 20),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Container(
                                              decoration: ShapeDecoration(
                                                color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: InkWell(
                                                        onTap: () {
                                                          controller.isPopular.value = true;
                                                        },
                                                        child: Container(
                                                          decoration:
                                                              controller.isPopular.value == false
                                                                  ? null
                                                                  : ShapeDecoration(color: AppThemeData.grey900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                            child: Text(
                                                              "Popular Stores".tr,
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: InkWell(
                                                        onTap: () {
                                                          controller.isPopular.value = false;
                                                        },
                                                        child: Container(
                                                          decoration:
                                                              controller.isPopular.value == true
                                                                  ? null
                                                                  : ShapeDecoration(color: AppThemeData.grey900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                            child: Text(
                                                              "All Stores".tr,
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                fontFamily: AppThemeData.semiBold,
                                                                color:
                                                                    controller.isPopular.value == true
                                                                        ? isDark
                                                                            ? AppThemeData.grey400
                                                                            : AppThemeData.grey500
                                                                        : isDark
                                                                        ? AppThemeData.primary300
                                                                        : AppThemeData.primary300,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                            child: controller.isPopular.value ? PopularRestaurant(controller: controller) : AllRestaurant(controller: controller),
                                          ),
                                          // controller.isPopular.value
                                          //     ? PopularRestaurant(
                                          //   controller: controller,
                                          // )
                                          //     : PopularRestaurant(
                                          //   controller: controller,
                                          // ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                              controller.update();
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
                  Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100, // background when dropdown opens
                    ),
                    child: DropdownButton<String>(
                      isDense: false,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Row titleView(isDark, String name, Function()? onPress) {
    return Row(
      children: [
        Expanded(child: Text(name.tr, textAlign: TextAlign.start, style: TextStyle(fontFamily: AppThemeData.bold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900))),
        InkWell(
          onTap: () {
            onPress!();
          },
          child: Text("View all".tr, textAlign: TextAlign.center, style: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300)),
        ),
      ],
    );
  }
}

class PopularRestaurant extends StatelessWidget {
  final FoodHomeController controller;

  const PopularRestaurant({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: controller.popularRestaurantList.length,
      itemBuilder: (BuildContext context, int index) {
        VendorModel vendorModel = controller.popularRestaurantList[index];
        return InkWell(
          onTap: () {
            Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
              controller.getFavouriteRestaurant();
            });
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: controller.popularRestaurantList.length - 1 == index ? 60 : 20),
            child: Container(
              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        child: Stack(
                          children: [
                            RestaurantImageView(vendorModel: vendorModel),
                            Container(
                              height: Responsive.height(20, context),
                              width: Responsive.width(100, context),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                              ),
                            ),

                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () async {
                                  if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                    await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                  } else {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.add(favouriteModel);
                                    await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                  }
                                },
                                child: Obx(
                                  () =>
                                      controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                          ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                          : SvgPicture.asset("assets/icons/ic_like.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(Responsive.width(-3, context), Responsive.height(17.5, context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Visibility(
                              visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppThemeData.success300,
                                      borderRadius: BorderRadius.circular(120), // Optional
                                    ),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                        const SizedBox(width: 5),
                                        Text("Free Delivery".tr, style: TextStyle(fontSize: 14, color: AppThemeData.carRent600, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.primary600 : AppThemeData.primary50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                    style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/icons/ic_map_distance.svg", colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn)),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                      fontFamily: AppThemeData.semiBold,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
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
                          maxLines: 1,
                          style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
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
    );
  }
}

class AllRestaurant extends StatelessWidget {
  final FoodHomeController controller;

  const AllRestaurant({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      itemCount: controller.allNearestRestaurant.length,
      itemBuilder: (BuildContext context, int index) {
        VendorModel vendorModel = controller.allNearestRestaurant[index];
        return InkWell(
          onTap: () {
            Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
              controller.getFavouriteRestaurant();
            });
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: controller.allNearestRestaurant.length - 1 == index ? 60 : 20),
            child: Container(
              decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        child: Stack(
                          children: [
                            RestaurantImageView(vendorModel: vendorModel),
                            Container(
                              height: Responsive.height(20, context),
                              width: Responsive.width(100, context),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () async {
                                  if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                    await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                  } else {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.add(favouriteModel);
                                    await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                  }
                                },
                                child: Obx(
                                  () =>
                                      controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                          ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                          : SvgPicture.asset("assets/icons/ic_like.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(Responsive.width(-3, context), Responsive.height(17.5, context)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Visibility(
                              visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppThemeData.carRent300,
                                      borderRadius: BorderRadius.circular(120), // Optional
                                    ),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                        const SizedBox(width: 5),
                                        Text("Free Delivery".tr, style: TextStyle(fontSize: 14, color: AppThemeData.carRent600, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.primary600 : AppThemeData.primary50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                    style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: ShapeDecoration(
                                color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                              ),
                              child: Row(
                                children: [
                                  SvgPicture.asset("assets/icons/ic_map_distance.svg", colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn)),
                                  const SizedBox(width: 5),
                                  Text(
                                    "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                      fontFamily: AppThemeData.semiBold,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
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
                          maxLines: 1,
                          style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
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
    );
  }
}

class NewArrival extends StatelessWidget {
  final FoodHomeController controller;

  const NewArrival({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return SizedBox(
      height: Responsive.height(24, context),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: controller.newArrivalRestaurantList.length >= 10 ? 10 : controller.newArrivalRestaurantList.length,
        itemBuilder: (BuildContext context, int index) {
          VendorModel vendorModel = controller.newArrivalRestaurantList[index];
          return InkWell(
            onTap: () {
              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                controller.getFavouriteRestaurant();
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: Responsive.width(55, context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        child: Stack(
                          children: [
                            NetworkImageWidget(imageUrl: vendorModel.photo.toString(), fit: BoxFit.cover, height: Responsive.height(100, context), width: Responsive.width(100, context)),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: const Alignment(0.00, 1.00), end: const Alignment(0, -1), colors: [Colors.black.withOpacity(0), AppThemeData.grey900]),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: InkWell(
                                onTap: () async {
                                  if (controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                    await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                  } else {
                                    FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                    controller.favouriteList.add(favouriteModel);
                                    await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                  }
                                },
                                child: Obx(
                                  () =>
                                      controller.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                          ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                          : SvgPicture.asset("assets/icons/ic_like.svg"),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      vendorModel.title.toString(),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: TextStyle(fontSize: 16, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Visibility(
                            visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                            child: Row(
                              children: [
                                SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                const SizedBox(width: 4),
                                Text(
                                  "Free Delivery".tr,
                                  textAlign: TextAlign.start,
                                  maxLines: 1,
                                  style: TextStyle(
                                    overflow: TextOverflow.ellipsis,
                                    fontFamily: AppThemeData.medium,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                              const SizedBox(width: 4),
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
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              SvgPicture.asset("assets/icons/ic_map_distance.svg"),
                              const SizedBox(width: 4),
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
                    Text(
                      vendorModel.location.toString(),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500, color: isDark ? AppThemeData.grey400 : AppThemeData.grey400),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AdvertisementHomeCard extends StatelessWidget {
  final AdvertisementModel model;
  final FoodHomeController controller;

  const AdvertisementHomeCard({super.key, required this.controller, required this.model});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return InkWell(
      onTap: () async {
        ShowToastDialog.showLoader("Please wait...".tr);
        VendorModel? vendorModel = await FireStoreUtils.getVendorById(model.vendorId!);
        ShowToastDialog.closeLoader();
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
      },
      child: Container(
        margin: EdgeInsets.only(right: 16),
        width: Responsive.width(70, context),
        decoration: BoxDecoration(
          color: isDark ? AppThemeData.info600 : AppThemeData.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: isDark ? 6 : 2, spreadRadius: 0, offset: Offset(0, isDark ? 3 : 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                model.type == 'restaurant_promotion'
                    ? ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      child: NetworkImageWidget(imageUrl: model.coverImage ?? '', height: 135, width: double.infinity, fit: BoxFit.cover),
                    )
                    : VideoAdvWidget(url: model.video ?? '', height: 135, width: double.infinity),
                if (model.type != 'video_promotion' && model.vendorId != null && (model.showRating == true || model.showReview == true))
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FutureBuilder(
                      future: FireStoreUtils.getVendorById(model.vendorId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox();
                        } else {
                          if (snapshot.hasError) {
                            return const SizedBox();
                          } else if (snapshot.data == null) {
                            return const SizedBox();
                          } else {
                            VendorModel vendorModel = snapshot.data!;
                            return Container(
                              decoration: ShapeDecoration(color: isDark ? AppThemeData.primary600 : AppThemeData.primary50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    if (model.showRating == true) SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                    if (model.showRating == true) const SizedBox(width: 5),
                                    Text(
                                      "${model.showRating == true ? Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString()) : ''} ${model.showReview == true ? '(${vendorModel.reviewsCount!.toStringAsFixed(0)})' : ''}",
                                      style: TextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (model.type == 'restaurant_promotion')
                    ClipRRect(borderRadius: BorderRadius.circular(30), child: NetworkImageWidget(imageUrl: model.profileImage ?? '', height: 50, width: 50, fit: BoxFit.cover)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.title ?? '',
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          model.description ?? '',
                          style: TextStyle(fontSize: 12, fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey400 : AppThemeData.grey600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  model.type == 'restaurant_promotion'
                      ? IconButton(
                        icon: Obx(
                          () =>
                              controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty
                                  ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                  : SvgPicture.asset("assets/icons/ic_like.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey400 : AppThemeData.grey600, BlendMode.srcIn)),
                        ),
                        onPressed: () async {
                          if (controller.favouriteList.where((p0) => p0.restaurantId == model.vendorId).isNotEmpty) {
                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: model.vendorId, userId: FireStoreUtils.getCurrentUid());
                            controller.favouriteList.removeWhere((item) => item.restaurantId == model.vendorId);
                            await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                          } else {
                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: model.vendorId, userId: FireStoreUtils.getCurrentUid());
                            controller.favouriteList.add(favouriteModel);
                            await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                          }
                          controller.update();
                        },
                      )
                      : Container(
                        decoration: ShapeDecoration(color: isDark ? AppThemeData.primary600 : AppThemeData.primary50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Icon(Icons.arrow_forward, size: 20, color: AppThemeData.primary300)),
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

class OfferView extends StatelessWidget {
  final FoodHomeController controller;

  const OfferView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return SizedBox(
      height: Responsive.height(17, context),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: controller.couponRestaurantList.length >= 15 ? 15 : controller.couponRestaurantList.length,
        itemBuilder: (BuildContext context, int index) {
          VendorModel vendorModel = controller.couponRestaurantList[index];
          CouponModel offerModel = controller.couponList[index];
          return InkWell(
            onTap: () {
              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: Responsive.width(38, context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                            Positioned(
                              bottom: 5,
                              left: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Upto".tr,
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 18,
                                      overflow: TextOverflow.ellipsis,
                                      fontFamily: AppThemeData.regular,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                                    ),
                                  ),
                                  Text(
                                    "${offerModel.discountType == "Fix Price" ? Constant.currencyModel!.symbol : ""}${offerModel.discount}${offerModel.discountType == "Percentage" ? "% off".tr : "off".tr}",
                                    textAlign: TextAlign.start,
                                    maxLines: 1,
                                    style: TextStyle(overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      vendorModel.title.toString(),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      style: TextStyle(fontSize: 16, overflow: TextOverflow.ellipsis, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Visibility(
                            visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                            child: Row(
                              children: [
                                Row(
                                  children: [
                                    SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                    const SizedBox(width: 5),
                                    Text(
                                      "Free Delivery".tr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        overflow: TextOverflow.ellipsis,
                                        fontFamily: AppThemeData.medium,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                              const SizedBox(width: 10),
                              Text(
                                "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                textAlign: TextAlign.start,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  overflow: TextOverflow.ellipsis,
                                  fontFamily: AppThemeData.medium,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
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
            ),
          );
        },
      ),
    );
  }
}

class BannerView extends StatelessWidget {
  final FoodHomeController controller;

  const BannerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: controller.pageController.value,
            scrollDirection: Axis.horizontal,
            itemCount: controller.bannerModel.length,
            padEnds: false,
            pageSnapping: true,
            allowImplicitScrolling: true,
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(controller.bannerModel.length, (index) {
              return Obx(
                () => Container(
                  margin: const EdgeInsets.only(right: 5),
                  alignment: Alignment.centerLeft,
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: controller.currentPage.value == index ? AppThemeData.primary300 : Colors.black12),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class BannerBottomView extends StatelessWidget {
  final FoodHomeController controller;

  const BannerBottomView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            physics: const BouncingScrollPhysics(),
            controller: controller.pageBottomController.value,
            scrollDirection: Axis.horizontal,
            itemCount: controller.bannerBottomModel.length,
            padEnds: false,
            pageSnapping: true,
            allowImplicitScrolling: true,
            onPageChanged: (value) {
              controller.currentBottomPage.value = value;
            },
            itemBuilder: (BuildContext context, int index) {
              BannerModel bannerModel = controller.bannerBottomModel[index];
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(controller.bannerBottomModel.length, (index) {
              return Obx(
                () => Container(
                  margin: const EdgeInsets.only(right: 5),
                  alignment: Alignment.centerLeft,
                  height: 9,
                  width: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: controller.currentBottomPage.value == index ? AppThemeData.primary300 : Colors.black12),
                ),
              );
            }),
          ),
        ),
      ],
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
    return SizedBox(
      height: 124,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: controller.vendorCategoryModel.length,
        itemBuilder: (context, index) {
          VendorCategoryModel vendorCategoryModel = controller.vendorCategoryModel[index];
          return InkWell(
            onTap: () {
              Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": false});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: SizedBox(
                width: 78,
                child: Container(
                  decoration: ShapeDecoration(
                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(width: 1, strokeAlign: BorderSide.strokeAlignOutside, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 60, height: 60, child: ClipOval(child: NetworkImageWidget(imageUrl: vendorCategoryModel.photo.toString(), fit: BoxFit.cover))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(
                          '${vendorCategoryModel.title}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium),
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
    );
  }
}

class StoryView extends StatelessWidget {
  final FoodHomeController controller;

  const StoryView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
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
                                                "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum!.toStringAsFixed(0))} reviews",
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
    );
  }
}

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: MapViewController(),
      builder: (controller) {
        return Stack(
          children: [
            Constant.selectedMapType == "osm"
                ? flutterMap.FlutterMap(
                  mapController: controller.osmMapController,
                  options: flutterMap.MapOptions(
                    initialCenter: location.LatLng(Constant.selectedLocation.location!.latitude ?? 0.0, Constant.selectedLocation.location!.longitude ?? 0.0),
                    initialZoom: 10,
                  ),
                  children: [
                    flutterMap.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.jeo.customer'),
                    flutterMap.MarkerLayer(markers: controller.osmMarker),
                  ],
                )
                : GoogleMap(
                  mapType: MapType.terrain,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: Set<Marker>.of(controller.markers.values),
                  onMapCreated: (GoogleMapController mapController) {
                    controller.mapController = mapController;
                  },
                  mapToolbarEnabled: true,
                  initialCameraPosition: CameraPosition(
                    zoom: 18,
                    target:
                        controller.homeController.allNearestRestaurant.isEmpty
                            ? LatLng(Constant.selectedLocation.location!.latitude ?? 45.521563, Constant.selectedLocation.location!.longitude ?? -122.677433)
                            : LatLng(controller.homeController.allNearestRestaurant.first.latitude ?? 45.521563, controller.homeController.allNearestRestaurant.first.longitude ?? -122.677433),
                  ),
                ),
            controller.homeController.allNearestRestaurant.isEmpty
                ? Container()
                : Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: SizedBox(
                      height: Responsive.height(25, context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: PageView.builder(
                              pageSnapping: true,
                              controller: PageController(viewportFraction: 0.88),
                              onPageChanged: (value) async {
                                if (Constant.selectedMapType == "osm") {
                                  controller.osmMapController.move(
                                    location.LatLng(controller.homeController.allNearestRestaurant[value].latitude!, controller.homeController.allNearestRestaurant[value].longitude!),
                                    16,
                                  );
                                } else {
                                  CameraUpdate cameraUpdate = CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      zoom: 18,
                                      target: LatLng(controller.homeController.allNearestRestaurant[value].latitude!, controller.homeController.allNearestRestaurant[value].longitude!),
                                    ),
                                  );
                                  controller.mapController!.animateCamera(cameraUpdate);
                                }
                              },
                              itemCount: controller.homeController.allNearestRestaurant.length,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                VendorModel vendorModel = controller.homeController.allNearestRestaurant[index];
                                return InkWell(
                                  onTap: () {
                                    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel})?.then((v) {
                                      controller.homeController.getFavouriteRestaurant();
                                    });
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: index == 0 ? 0 : 10),
                                    child: Container(
                                      decoration: BoxDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, borderRadius: const BorderRadius.all(Radius.circular(16))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                                child: Stack(
                                                  children: [
                                                    NetworkImageWidget(
                                                      imageUrl: vendorModel.photo.toString(),
                                                      fit: BoxFit.cover,
                                                      height: Responsive.height(14, context),
                                                      width: Responsive.width(100, context),
                                                    ),
                                                    Container(
                                                      height: Responsive.height(14, context),
                                                      width: Responsive.width(100, context),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: const Alignment(-0.00, -1.00),
                                                          end: const Alignment(0, 1),
                                                          colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: 10,
                                                      top: 10,
                                                      child: InkWell(
                                                        onTap: () async {
                                                          if (controller.homeController.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty) {
                                                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                                            controller.homeController.favouriteList.removeWhere((item) => item.restaurantId == vendorModel.id);
                                                            await FireStoreUtils.removeFavouriteRestaurant(favouriteModel);
                                                          } else {
                                                            FavouriteModel favouriteModel = FavouriteModel(restaurantId: vendorModel.id, userId: FireStoreUtils.getCurrentUid());
                                                            controller.homeController.favouriteList.add(favouriteModel);
                                                            await FireStoreUtils.setFavouriteRestaurant(favouriteModel);
                                                          }
                                                        },
                                                        child: Obx(
                                                          () =>
                                                              controller.homeController.favouriteList.where((p0) => p0.restaurantId == vendorModel.id).isNotEmpty
                                                                  ? SvgPicture.asset("assets/icons/ic_like_fill.svg")
                                                                  : SvgPicture.asset("assets/icons/ic_like.svg"),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Transform.translate(
                                                offset: Offset(Responsive.width(-3, context), Responsive.height(11, context)),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Visibility(
                                                      visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                            decoration: BoxDecoration(
                                                              color: AppThemeData.carRent300,
                                                              borderRadius: BorderRadius.circular(120), // Optional
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                                                const SizedBox(width: 5),
                                                                Text(
                                                                  "Free Delivery".tr,
                                                                  style: TextStyle(fontSize: 14, color: AppThemeData.success600, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      decoration: ShapeDecoration(
                                                        color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        child: Row(
                                                          children: [
                                                            SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount.toString(), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                                              style: TextStyle(
                                                                color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      decoration: ShapeDecoration(
                                                        color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                      ),
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        child: Row(
                                                          children: [
                                                            SvgPicture.asset("assets/icons/ic_map_distance.svg", colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn)),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                                              style: TextStyle(
                                                                color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 15),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vendorModel.title.toString(),
                                                  textAlign: TextAlign.start,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    overflow: TextOverflow.ellipsis,
                                                    fontFamily: AppThemeData.semiBold,
                                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                  ),
                                                ),
                                                Text(
                                                  vendorModel.location.toString(),
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
                                          ),
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
                  ),
                ),
          ],
        );
      },
    );
  }
}

Widget _buildHomeShimmer(bool isDark) {
  final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

  Widget box({double w = double.infinity, double h = 14, double radius = 8}) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(radius)));

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Shimmer.fromColors(
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
            // Stories row
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => Column(children: [box(w: 64, h: 64, radius: 32), const SizedBox(height: 6), box(w: 50, h: 10)]),
              ),
            ),
            const SizedBox(height: 20),
            // "Explore the Categories" title
            box(w: 140, h: 16),
            const SizedBox(height: 12),
            // Categories row
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
            // Banner
            box(h: 160, radius: 16),
            const SizedBox(height: 20),
            // "Largest Discounts" title
            box(w: 120, h: 16),
            const SizedBox(height: 12),
            // Offer cards row
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
            // "Popular Stores" title
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
    ),
  );
}
