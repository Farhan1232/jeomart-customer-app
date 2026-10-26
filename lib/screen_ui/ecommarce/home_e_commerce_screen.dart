import 'package:customer/utils/banner_tap.dart';
import 'package:badges/badges.dart' as badges;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/home_e_commerce_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/ecommarce/all_brand_product_screen.dart';
import 'package:customer/screen_ui/ecommarce/all_category_product_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/advertisement_screens/all_advertisement_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/cart_screen/cart_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/category_restaurant_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/home_screen/restaurant_list_screen.dart' show RestaurantListScreen;
import 'package:customer/screen_ui/multi_vendor_service/home_screen/view_all_category_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/search_screen/search_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_border.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:customer/widget/video_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class HomeECommerceScreen extends StatelessWidget {
  const HomeECommerceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: HomeECommerceController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
            titleSpacing: 0,
            leading: InkWell(
              onTap: () {
                Get.offAll(const ServiceListScreen());
              },
              child: Icon(Icons.arrow_back, color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, size: 20),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Constant.userModel == null
                    ? InkWell(
                      onTap: () {
                        Get.offAll(const LoginScreen());
                      },
                      child: Text("Login".tr, textAlign: TextAlign.center, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 12)),
                    )
                    : Text(Constant.userModel!.fullName(), textAlign: TextAlign.center, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 12)),
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
                                  shippingAddress.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
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
                        TextSpan(text: Constant.selectedLocation.getFullAddress(), style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey50, fontSize: 14)),
                        WidgetSpan(child: SvgPicture.asset("assets/icons/ic_down.svg", colorFilter: ColorFilter.mode(AppThemeData.grey50, BlendMode.srcIn))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Obx(
                () => Padding(
                  padding: const EdgeInsets.only(right: 15.0, left: 10),
                  child: badges.Badge(
                    showBadge: true,
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
                    badgeStyle: badges.BadgeStyle(shape: badges.BadgeShape.circle, badgeColor: AppThemeData.info300),
                    child: InkWell(
                      onTap: () async {
                        (await Get.to(const CartScreen()));
                        controller.getCartData();
                      },
                      child: ClipOval(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200), borderRadius: BorderRadius.circular(120)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SvgPicture.asset("assets/icons/ic_shoping_cart.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey50 : AppThemeData.grey50, BlendMode.srcIn)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(50.0), // height of the bottom widget
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                  onTap: () {
                    Get.to(const SearchScreen(), arguments: {"vendorList": controller.allNearestRestaurant});
                  },
                  child: TextFieldWidget(
                    hintText: 'Search the store, item and more...'.tr,
                    controller: null,
                    enable: false,
                    backgroundColor: AppThemeData.grey50,
                    hintColor: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                    prefix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SvgPicture.asset("assets/icons/ic_search.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey400 : AppThemeData.grey400, BlendMode.srcIn)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? _buildHomeECommerceShimmer(isDark)
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Category".tr,
                                    textAlign: TextAlign.start,
                                    style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Get.to(const ViewAllCategoryScreen());
                                  },
                                  child: Text(
                                    "View all".tr,
                                    textAlign: TextAlign.start,
                                    style: AppThemeData.semiBoldTextStyle(
                                      decoration: TextDecoration.underline,
                                      color: isDark ? AppThemeData.multiVendorDark300 : AppThemeData.multiVendor300,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              height: 100,
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: controller.vendorCategoryModel.length,
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (context, index) {
                                  VendorCategoryModel vendorCategoryModel = controller.vendorCategoryModel[index];
                                  return InkWell(
                                    onTap: () {
                                      Get.to(const CategoryRestaurantScreen(), arguments: {"vendorCategoryModel": vendorCategoryModel, "dineIn": false, "ecommerce": true});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 18),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          NetworkImageWidget(imageUrl: vendorCategoryModel.photo.toString(), height: 60, width: 60, fit: BoxFit.cover),
                                          const SizedBox(height: 5),
                                          Text(
                                            vendorCategoryModel.title.toString(),
                                            textAlign: TextAlign.center,
                                            style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800, fontSize: 14),
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
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: controller.bannerModel.isEmpty ? const SizedBox() : BannerView(controller: controller)),
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
                            child: Text(
                              "New Arrivals".tr,
                              textAlign: TextAlign.start,
                              style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              height: 380,
                              child: GridView.count(
                                crossAxisCount: 2,
                                // 2 columns
                                mainAxisSpacing: 0,
                                crossAxisSpacing: 20,
                                childAspectRatio: 1 / 1.1,
                                padding: EdgeInsets.zero,
                                physics: NeverScrollableScrollPhysics(),
                                children: controller.newArrivalRestaurantList.take(4).map((item) => NewArrivalCard(item: item)).toList(),
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: RoundedButtonBorder(
                              radius: 10,
                              color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                              borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                              title: 'View All Arrivals'.tr,
                              onPress: () {
                                Get.to(RestaurantListScreen(), arguments: {"vendorList": controller.newArrivalRestaurantList, "title": "New Arrivals".tr});
                              },
                            ),
                          ),
                          SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Top Brands".tr, textAlign: TextAlign.start, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16)),
                                SizedBox(height: 10),
                                GridView.builder(
                                  padding: EdgeInsets.zero,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 4.5 / 6, crossAxisSpacing: 2),
                                  itemCount: controller.brandList.length,
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    BrandsModel brandModel = controller.brandList[index];
                                    return InkWell(
                                      onTap: () {
                                        Get.to(AllBrandProductScreen(), arguments: {"brandModel": brandModel});
                                      },
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: ShapeDecoration(
                                              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(width: 1, strokeAlign: BorderSide.strokeAlignOutside, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: Padding(padding: const EdgeInsets.all(10), child: ClipOval(child: NetworkImageWidget(imageUrl: brandModel.photo.toString(), fit: BoxFit.cover))),
                                          ),
                                          SizedBox(height: 5),
                                          Text(
                                            '${brandModel.title}',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: controller.categoryWiseProductList.length,
                            itemBuilder: (context, index) {
                              VendorCategoryModel item = controller.categoryWiseProductList[index];
                              String imagePath = ["assets/images/ic_product_bg_1.png", "assets/images/ic_product_bg_2.png", "assets/images/ic_product_bg_3.png"][index % ["", "", ""].length];
                              return Container(
                                width: Responsive.width(100, context),
                                decoration: BoxDecoration(image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.fill)),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 20),
                                  child: FutureBuilder<List<ProductModel>>(
                                    future: controller.productsForCategory(item.id.toString()),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300)));
                                      } else if ((snapshot.hasData || (snapshot.data?.isNotEmpty ?? false))) {
                                        List<ProductModel> productList = snapshot.data!;
                                        return snapshot.data!.isEmpty
                                            ? Container()
                                            : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: [
                                                Text(item.title.toString(), textAlign: TextAlign.start, style: AppThemeData.boldTextStyle(color: AppThemeData.grey900, fontSize: 18)),
                                                Text(
                                                  "Style up with the latest fits, now at unbeatable prices.".tr,
                                                  textAlign: TextAlign.start,
                                                  style: AppThemeData.regularTextStyle(color: AppThemeData.grey900, fontSize: 12),
                                                ),
                                                SizedBox(height: 20),
                                                GridView.builder(
                                                  shrinkWrap: true,
                                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 3.5 / 6, crossAxisSpacing: 10),
                                                  padding: EdgeInsets.zero,
                                                  physics: NeverScrollableScrollPhysics(),
                                                  itemCount: productList.length > 6 ? 6 : productList.length,
                                                  itemBuilder: (context, index) {
                                                    ProductModel productModel = productList[index];
                                                    return FutureBuilder(
                                                      future: FireStoreUtils.getVendorById(productModel.vendorID.toString()),
                                                      builder: (context, vendorSnapshot) {
                                                        if (!vendorSnapshot.hasData || vendorSnapshot.connectionState == ConnectionState.waiting) {
                                                          return const SizedBox(); // Show placeholder or loader
                                                        }
                                                        VendorModel? vendorModel = vendorSnapshot.data;
                                                        String price = "0.0";
                                                        String disPrice = "0.0";
                                                        List<String> selectedVariants = [];
                                                        List<String> selectedIndexVariants = [];
                                                        List<String> selectedIndexArray = [];
                                                        if (productModel.itemAttribute != null) {
                                                          if (productModel.itemAttribute!.attributes!.isNotEmpty) {
                                                            for (var element in productModel.itemAttribute!.attributes!) {
                                                              if (element.attributeOptions!.isNotEmpty) {
                                                                selectedVariants.add(
                                                                  productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString(),
                                                                );
                                                                selectedIndexVariants.add(
                                                                  '${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}',
                                                                );
                                                                selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
                                                              }
                                                            }
                                                          }

                                                          if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
                                                            price = Constant.productCommissionPrice(
                                                              vendorModel!,
                                                              productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0',
                                                            );
                                                            disPrice = "0";
                                                          }
                                                        } else {
                                                          price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
                                                          disPrice =
                                                              double.parse(productModel.disPrice.toString()) <= 0
                                                                  ? "0"
                                                                  : Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
                                                        }
                                                        return GestureDetector(
                                                          onTap: () async {
                                                            Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                                                          },
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              ClipRRect(
                                                                borderRadius: BorderRadius.circular(10),
                                                                child: SizedBox(
                                                                  height: 90,
                                                                  width: Responsive.width(100, context),
                                                                  child: NetworkImageWidget(imageUrl: productModel.photo.toString(), fit: BoxFit.cover),
                                                                ),
                                                              ),
                                                              Column(
                                                                mainAxisAlignment: MainAxisAlignment.start,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    productModel.name!.capitalizeString(),
                                                                    textAlign: TextAlign.start,
                                                                    maxLines: 1,
                                                                    style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                                  ),
                                                                  disPrice == "" || disPrice == "0"
                                                                      ? Text(Constant.amountShow(amount: price), style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.primary300))
                                                                      : Column(
                                                                        children: [
                                                                          Text(
                                                                            Constant.amountShow(amount: price),
                                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                                                          ),
                                                                          const SizedBox(width: 5),
                                                                          Text(
                                                                            Constant.amountShow(amount: disPrice),
                                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                  Container(
                                                                    decoration: BoxDecoration(color: isDark ? AppThemeData.warning50 : AppThemeData.warning50, borderRadius: BorderRadius.circular(30)),
                                                                    child: Padding(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          Icon(Icons.star, size: 18, color: AppThemeData.warning400),
                                                                          Text(
                                                                            "${Constant.calculateReview(reviewCount: productModel.reviewsCount.toString(), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsSum})",
                                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: AppThemeData.warning400),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                                RoundedButtonBorder(
                                                  radius: 10,
                                                  color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                                                  borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                                                  title: 'View All Products'.tr,
                                                  onPress: () {
                                                    Get.to(AllCategoryProductScreen(), arguments: {"categoryModel": item});
                                                  },
                                                ),
                                              ],
                                            );
                                      } else {
                                        return SizedBox();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 10),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: controller.bannerModel.isEmpty ? const SizedBox() : BannerBottomView(controller: controller)),
                          // Visibility(
                          //   visible: (Constant.isEnableAdsFeature == true && controller.advertisementList.isNotEmpty),
                          //   child: const SizedBox(height: 20),
                          // ),
                          // Visibility(
                          //   visible: Constant.isEnableAdsFeature == true,
                          //   child:
                          //   controller.advertisementList.isEmpty
                          //       ? const SizedBox()
                          //       : Container(
                          //     color: AppThemeData.primary300.withAlpha(40),
                          //     child: Padding(
                          //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          //       child: Column(
                          //         mainAxisAlignment: MainAxisAlignment.start,
                          //         crossAxisAlignment: CrossAxisAlignment.start,
                          //         children: [
                          //           Row(
                          //             children: [
                          //               Expanded(
                          //                 child: Text(
                          //                   "Highlights for you".tr,
                          //                   textAlign: TextAlign.start,
                          //                   style: TextStyle(
                          //                     fontFamily: AppThemeData.semiBold,
                          //                     fontSize: 16,
                          //                     color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                          //                   ),
                          //                 ),
                          //               ),
                          //               InkWell(
                          //                 onTap: () {
                          //                   Get.to(AllAdvertisementScreen())?.then((value) {
                          //                     controller.getFavouriteRestaurant();
                          //                   });
                          //                 },
                          //                 child: Text(
                          //                   "View all".tr,
                          //                   textAlign: TextAlign.center,
                          //                   style: TextStyle(
                          //                     fontFamily: AppThemeData.regular,
                          //                     color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                          //                   ),
                          //                 ),
                          //               ),
                          //             ],
                          //           ),
                          //           const SizedBox(height: 16),
                          //           SizedBox(
                          //             height: 220,
                          //             child: ListView.builder(
                          //               physics: const BouncingScrollPhysics(),
                          //               scrollDirection: Axis.horizontal,
                          //               itemCount:
                          //               controller.advertisementList.length >= 10
                          //                   ? 10
                          //                   : controller.advertisementList.length,
                          //               padding: EdgeInsets.all(0),
                          //               itemBuilder: (BuildContext context, int index) {
                          //                 return AdvertisementHomeCard(
                          //                   controller: controller,
                          //                   model: controller.advertisementList[index],
                          //                 );
                          //               },
                          //             ),
                          //           ),
                          //         ],
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("All Store".tr, textAlign: TextAlign.start, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16)),
                                SizedBox(height: 10),
                                ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: controller.allNearestRestaurant.length > 8 ? 8 : controller.allNearestRestaurant.length,
                                  itemBuilder: (context, index) {
                                    VendorModel item = controller.allNearestRestaurant[index];
                                    return InkWell(
                                      onTap: () {
                                        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": item});
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 20),
                                        child: Row(
                                          children: [
                                            ClipRRect(borderRadius: BorderRadius.circular(10), child: NetworkImageWidget(imageUrl: item.photo.toString(), height: 80, width: 130, fit: BoxFit.cover)),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.title.toString(), style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16)),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                      SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          item.location.toString(),
                                                          style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Container(
                                                    decoration: BoxDecoration(color: isDark ? AppThemeData.warning50 : AppThemeData.warning50, borderRadius: BorderRadius.circular(30)),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.star, size: 18, color: AppThemeData.warning400),
                                                          Text(
                                                            "${Constant.calculateReview(reviewCount: item.reviewsCount.toString(), reviewSum: item.reviewsSum.toString())} (${item.reviewsSum})",
                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: AppThemeData.warning400),
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
                                      ),
                                    );
                                  },
                                ),
                                RoundedButtonBorder(
                                  radius: 10,
                                  color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100,
                                  borderColor: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
                                  title: 'View All Stores'.tr,
                                  onPress: () {
                                    Get.to(const RestaurantListScreen(), arguments: {"vendorList": controller.allNearestRestaurant});
                                  },
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
    );
  }
}

class NewArrivalCard extends StatelessWidget {
  final VendorModel item;

  const NewArrivalCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return InkWell(
      onTap: () {
        Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": item});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: NetworkImageWidget(
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              imageUrl: item.photo != null && item.photo!.isNotEmpty ? item.photo.toString() : Constant.placeHolderImage.toString(),
            ),
          ),
          SizedBox(height: 5),
          Text(item.title.toString(), style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 14)),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.location.toString(),
                  style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(color: isDark ? AppThemeData.warning50 : AppThemeData.warning50, borderRadius: BorderRadius.circular(30)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 18, color: AppThemeData.warning400),
                  Text(
                    "${Constant.calculateReview(reviewCount: item.reviewsCount.toString(), reviewSum: item.reviewsSum.toString())} (${item.reviewsSum})",
                    style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: AppThemeData.warning400),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BannerView extends StatelessWidget {
  final HomeECommerceController controller;

  const BannerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
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
  final HomeECommerceController controller;

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

class AdvertisementHomeCard extends StatelessWidget {
  final AdvertisementModel model;
  final HomeECommerceController controller;

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

Widget _buildHomeECommerceShimmer(bool isDark) {
  final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

  Widget box({double w = double.infinity, double h = 14, double radius = 8}) =>
      Container(width: w, height: h, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(radius)));

  return Shimmer.fromColors(
    baseColor: baseColor,
    highlightColor: highlightColor,
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category title row
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Expanded(child: box(w: 100, h: 16)), box(w: 50, h: 12)])),
          const SizedBox(height: 10),
          // Category horizontal list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (_, __) => Column(mainAxisAlignment: MainAxisAlignment.start, children: [box(w: 60, h: 60, radius: 30), const SizedBox(height: 5), box(w: 50, h: 12)]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Banner
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: box(h: 160, radius: 16)),
          const SizedBox(height: 20),
          // Highlights section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: box(w: 140, h: 16)), box(w: 50, h: 12)]),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => box(w: 160, h: 220, radius: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // New Arrivals title
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: box(w: 120, h: 16)),
          const SizedBox(height: 20),
          // New Arrivals 2-column grid (4 items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 16,
              childAspectRatio: 1 / 1.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: List.generate(4, (_) => box(radius: 12)),
            ),
          ),
          const SizedBox(height: 10),
          // View All Arrivals button placeholder
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: box(h: 44, radius: 10)),
          const SizedBox(height: 20),
          // Top Brands title
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: box(w: 100, h: 16)),
          const SizedBox(height: 10),
          // Brands 4-column grid (8 items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              childAspectRatio: 4.5 / 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: List.generate(8, (_) => Column(children: [box(w: 80, h: 80, radius: 10), const SizedBox(height: 5), box(w: 50, h: 10)])),
            ),
          ),
          const SizedBox(height: 10),
          // Category-wise product sections (2 sections)
          ...List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box(w: 140, h: 18), const SizedBox(height: 6), box(w: 220, h: 12), const SizedBox(height: 12)]),
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, __) => box(w: 150, h: 200, radius: 12),
                    ),
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
