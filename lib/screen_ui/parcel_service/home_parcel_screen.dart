import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:customer/utils/safe_geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../controllers/home_parcel_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/banner_model.dart';
import '../../models/parcel_category.dart';
import '../../models/user_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/show_toast_dialog.dart';
import '../../utils/network_image_widget.dart';
import '../../widget/osm_map/map_picker_page.dart';
import '../../widget/place_picker/location_picker_screen.dart';
import '../../widget/place_picker/selected_location_model.dart';
import '../auth_screens/login_screen.dart';
import '../location_enable_screens/address_list_screen.dart';
import 'book_parcel_screen.dart';

class HomeParcelScreen extends StatelessWidget {
  const HomeParcelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<HomeParcelController>(
      init: HomeParcelController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
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
                        InkWell(
                          onTap: () async {
                            if (Constant.userModel != null) {
                              Get.to(AddressListScreen())!.then((value) {
                                if (value != null) {
                                  ShippingAddress shippingAddress = value;
                                  Constant.selectedLocation = shippingAddress;
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

                                        Constant.selectedLocation = shippingAddress;
                                        Get.back();
                                      }
                                    } else {
                                      Get.to(LocationPickerScreen())!.then((value) async {
                                        if (value != null) {
                                          SelectedLocationModel selectedLocationModel = value;

                                          shippingAddress.addressAs = "Home";
                                          shippingAddress.location = UserLocation(latitude: selectedLocationModel.latLng!.latitude, longitude: selectedLocationModel.latLng!.longitude);
                                          shippingAddress.locality = "Picked from Map";

                                          Constant.selectedLocation = shippingAddress;
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
                                  }
                                },
                                context: context,
                              );
                            }
                          },
                          child: Text(
                            Constant.selectedLocation.getFullAddress(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900),
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
                  ? Center(child: Constant.loader())
                  : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          BannerView(bannerList: controller.bannerTopHome),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("What are you sending?".tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                                    border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: ListView.builder(
                                    itemCount: controller.parcelCategory.length,
                                    shrinkWrap: true,
                                    physics: const ScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    itemBuilder: (context, index) {
                                      return buildItems(item: controller.parcelCategory[index], isDark: isDark);
                                    },
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
    );
  }

  Widget buildItems({required ParcelCategory item, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: InkWell(
        onTap: () {
          if (!Constant.requireLogin()) return;
          Get.to(const BookParcelScreen(), arguments: {'parcelCategory': item});
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NetworkImageWidget(imageUrl: item.image ?? '', height: 38, width: 38),
            const SizedBox(width: 20),
            Expanded(child: Text(item.title ?? '', style: AppThemeData.semiBoldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 16))),
            Icon(Icons.arrow_forward_ios, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800, size: 20),
          ],
        ),
      ),
    );
  }
}

class BannerView extends StatelessWidget {
  final List<BannerModel> bannerList;
  final RxInt currentPage = 0.obs;
  final ScrollController scrollController = ScrollController();

  BannerView({super.key, required this.bannerList});

  /// Computes the visible item index from scroll offset
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
