import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/location_enable_screens/location_permission_screen.dart';
import 'package:customer/screen_ui/on_demand_service/view_all_popular_service_screen.dart';
import 'package:customer/screen_ui/on_demand_service/view_category_service_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../controllers/on_demand_home_controller.dart';
import '../../models/category_model.dart';
import '../../models/provider_serivce_model.dart';
import 'on_demand_category_screen.dart';
import 'on_demand_details_screen.dart';
import 'package:customer/utils/app_image_cache.dart';

class OnDemandHomeScreen extends StatelessWidget {
  const OnDemandHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<OnDemandHomeController>(
      init: OnDemandHomeController(),
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
                    onTap: () => Get.offAll(const ServiceListScreen()),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: const Center(child: Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Constant.userModel == null
                            ? InkWell(onTap: () => Get.offAll(const LoginScreen()), child: Text("Login".tr, style: AppThemeData.boldTextStyle(color: AppThemeData.grey900, fontSize: 12)))
                            : Text(Constant.userModel!.fullName(), style: AppThemeData.boldTextStyle(color: AppThemeData.grey900, fontSize: 12)),
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
                                TextSpan(
                                  text: Constant.selectedLocation.getFullAddress(),
                                  style: TextStyle(fontFamily: AppThemeData.medium, overflow: TextOverflow.ellipsis, color: AppThemeData.grey900, fontSize: 14),
                                ),
                                WidgetSpan(child: SvgPicture.asset("assets/icons/ic_down.svg")),
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
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Constant.isZoneAvailable == false || controller.providerList.isEmpty
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
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BannerView(bannerList: controller.bannerTopHome),
                          const SizedBox(height: 20),
                          Container(
                            height: MediaQuery.of(context).size.height * 0.12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? AppThemeData.greyDark600 : AppThemeData.greyDark600, width: 1),
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                            ),
                            child:
                                controller.categories.isEmpty
                                    ? Constant.showEmptyView(message: "No Categories".tr)
                                    : Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: controller.categories.length > 3 ? 3 : controller.categories.length,
                                              scrollDirection: Axis.horizontal,
                                              itemBuilder: (context, index) {
                                                final category = controller.categories[index];
                                                return InkWell(
                                                  onTap: () {
                                                    Get.to(() => ViewCategoryServiceListScreen(), arguments: {'categoryId': category.id, 'categoryTitle': category.title});
                                                  },
                                                  child: CategoryView(category: category, index: index, isDark: isDark),
                                                );
                                              },
                                            ),
                                          ),
                                          if (controller.categories.length > 3)
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      Get.to(() => const OnDemandCategoryScreen());
                                                    },
                                                    child: ClipOval(child: Container(width: 50, height: 50, color: AppThemeData.grey200, child: const Center(child: Icon(Icons.chevron_right)))),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  SizedBox(
                                                    width: 70,
                                                    child: Center(
                                                      child: Text(
                                                        "View All".tr,
                                                        textAlign: TextAlign.center,
                                                        maxLines: 1,
                                                        style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Most Popular services".tr,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Get.to(() => ViewAllPopularServiceScreen());
                                  },
                                  child: Text("View all".tr, style: TextStyle(color: AppThemeData.primary300, fontSize: 14, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          controller.providerList.isEmpty
                              ? Center(child: Text("No Services Found".tr))
                              : ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: controller.providerList.length >= 6 ? 6 : controller.providerList.length,
                                itemBuilder: (_, index) {
                                  return ServiceView(provider: controller.providerList[index], controller: controller, isDark: isDark);
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

class BannerView extends StatelessWidget {
  final List<BannerModel> bannerList;
  final RxInt currentPage = 0.obs;
  final ScrollController scrollController = ScrollController();

  BannerView({super.key, required this.bannerList});

  void onScroll(BuildContext context) {
    if (scrollController.hasClients && bannerList.isNotEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = screenWidth * 0.8 + 10; // banner width + spacing
      final offset = scrollController.offset;
      final index = (offset / itemWidth).round();

      if (index != currentPage.value && index < bannerList.length) {
        currentPage.value = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    scrollController.addListener(() {
      onScroll(context);
    });

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: bannerList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 15),
            itemBuilder: (context, index) {
              final banner = bannerList[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(width: MediaQuery.of(context).size.width * 0.8, child: NetworkImageWidget(imageUrl: banner.photo ?? '', fit: BoxFit.cover)),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Obx(() {
          return Row(
            children: List.generate(bannerList.length, (index) {
              bool isSelected = currentPage.value == index;
              return Expanded(child: Container(height: 4, decoration: BoxDecoration(color: isSelected ? AppThemeData.grey300 : AppThemeData.grey100, borderRadius: BorderRadius.circular(5))));
            }),
          );
        }),
      ],
    );
  }
}

class CategoryView extends StatelessWidget {
  final CategoryModel category;
  final int index;
  final bool isDark;

  const CategoryView({super.key, required this.category, required this.index, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 55,
            width: 55,
            decoration: BoxDecoration(color: Constant.colorList[index % Constant.colorList.length], borderRadius: BorderRadius.circular(50)),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: category.image.toString(), errorWidget: (_, __, ___) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover)),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 70,
            child: Center(
              child: Text(category.title ?? "", textAlign: TextAlign.center, maxLines: 1, style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceView extends StatelessWidget {
  final ProviderServiceModel provider;
  final bool isDark;
  final OnDemandHomeController? controller;

  const ServiceView({super.key, required this.provider, this.isDark = false, this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.to(() => OnDemandDetailsScreen(), arguments: {'providerModel': provider});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppThemeData.grey500 : Colors.grey.shade200),
          color: isDark ? AppThemeData.grey900 : Colors.white,
        ),
        child: Row(
          children: [
            // --- Left Image ---
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
              child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                imageUrl: provider.photos.isNotEmpty ? provider.photos[0] : Constant.placeHolderImage,
                width: 110,
                height: MediaQuery.of(context).size.height * 0.16,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover),
              ),
            ),

            // --- Right Content ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Favourite icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            provider.title ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        if (controller != null)
                          Obx(
                            () => GestureDetector(
                              onTap: () => controller!.toggleFavourite(provider),
                              child: Icon(
                                controller!.lstFav.where((element) => element.service_id == provider.id).isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                size: 24,
                                color: controller!.lstFav.where((element) => element.service_id == provider.id).isNotEmpty ? AppThemeData.primary300 : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Category
                    if (controller != null)
                      FutureBuilder<CategoryModel?>(
                        future: controller!.getCategory(provider.categoryId ?? ""),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          return Text(snap.data?.title ?? "", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54));
                        },
                      ),

                    const SizedBox(height: 4),

                    // Price
                    _buildPrice(),

                    const SizedBox(height: 6),

                    // Rating
                    _buildRating(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrice() {
    if (provider.disPrice == "" || provider.disPrice == "0") {
      return Text(
        provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price) : '${Constant.amountShow(amount: provider.price ?? "0")}/${'hr'.tr}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppThemeData.primary300),
      );
    } else {
      return Row(
        children: [
          Text(
            provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.disPrice ?? '0') : '${Constant.amountShow(amount: provider.disPrice)}/${'hr'.tr}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppThemeData.primary300),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price) : '${Constant.amountShow(amount: provider.price ?? "0")}/hr',
              style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildRating() {
    double rating = 0;
    if (provider.reviewsCount != null && provider.reviewsCount != 0) {
      rating = (provider.reviewsSum ?? 0) / (provider.reviewsCount ?? 1);
    }
    return Container(
      decoration: BoxDecoration(color: AppThemeData.warning400, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [const Icon(Icons.star, size: 14, color: Colors.white), const SizedBox(width: 3), Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Colors.white))],
      ),
    );
  }
}
