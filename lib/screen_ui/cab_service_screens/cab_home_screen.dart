import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_home_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/service_home_screen/service_list_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'intercity_home_screen.dart';
import 'cab_booking_screen.dart';

class CabHomeScreen extends StatelessWidget {
  const CabHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CabHomeController(),
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
                              child: Text("Login".tr, textAlign: TextAlign.center, style: AppThemeData.boldTextStyle(color: AppThemeData.grey900, fontSize: 12)),
                            )
                            : Text(Constant.userModel!.fullName(), textAlign: TextAlign.center, style: AppThemeData.boldTextStyle(color: AppThemeData.grey900, fontSize: 12)),
                        Text(Constant.selectedLocation.getFullAddress(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
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
                  // Scrollable because this page now carries three photographs
                  // it did not before. The body was a bare Column, so on a short
                  // phone the extra height would have been a RenderFlex overflow
                  // rather than something the customer could scroll to.
                  : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // An admin-uploaded banner still wins. The bundled one is
                        // the fallback: with no banner configured this strip
                        // collapsed to nothing and the page opened on a bare
                        // heading, which is what the client was looking at.
                        controller.bannerTopHome.isEmpty
                            ? const CabDefaultBanner()
                            : BannerView(bannerList: controller.bannerTopHome),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20),
                            Text("Where are you going for?".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 18)),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Constant.sectionConstantModel!.rideType == "both" || Constant.sectionConstantModel!.rideType == "ride"
                                    ? GestureDetector(
                                      onTap: () {
                                        if (!Constant.requireLogin()) return;
                                        // The normal metered booking, always:
                                        // choose a vehicle, see the fare, pay
                                        // it. Bidding is its own section in the
                                        // bar and never appears here.
                                        Get.to(() => const CabBookingScreen());
                                      },
                                      child: Container(
                                        width: Responsive.width(40, context),
                                        decoration: BoxDecoration(color: AppThemeData.warning50, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppThemeData.warning200)),
                                        // The photograph has to be clipped to the
                                        // card's own radius, so the padding moves
                                        // off the Container and on to the text.
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const _CardPhoto(asset: "assets/images/img_ride_car.png"),
                                            Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Ride".tr, style: AppThemeData.semiBoldTextStyle(color: AppThemeData.taxiBooking500, fontSize: 16)),
                                                  Text("City rides, 24x7 availability".tr, style: AppThemeData.mediumTextStyle(color: AppThemeData.taxiBooking600, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : SizedBox(),
                                SizedBox(width: 20),
                                Constant.sectionConstantModel!.rideType == "both" || Constant.sectionConstantModel!.rideType == "intercity"
                                    ? GestureDetector(
                                      onTap: () {
                                        if (!Constant.requireLogin()) return;
                                        Get.to(() => IntercityHomeScreen());
                                      },
                                      child: Container(
                                        width: Responsive.width(44, context),
                                        decoration: BoxDecoration(color: AppThemeData.carRent50, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppThemeData.carRent200)),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const _CardPhoto(asset: "assets/images/img_intercity_car.png"),
                                            Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Intercity/Outstation".tr, style: AppThemeData.semiBoldTextStyle(color: AppThemeData.carRent500, fontSize: 16)),
                                                  Text("Long trips, prepaid options".tr, style: AppThemeData.mediumTextStyle(color: AppThemeData.parcelService600, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    : SizedBox(),
                              ],
                            ),
                            SizedBox(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Every Ride. Every Driver. Verified.".tr, style: AppThemeData.boldTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900, fontSize: 22)),
                                      Text(
                                        "All drivers go through ID checks and background verification for your safety.".tr,
                                        style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark700 : AppThemeData.grey700, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(child: Image.asset("assets/images/img_ride_driver.png", height: 118, width: 68)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }
}

/// The bundled JEOM banner, shown when no admin banner is configured.
///
/// Deliberately a fallback rather than a replacement: the moment an admin
/// uploads a banner for this section, theirs is what the customer sees. The
/// bundled one only exists so the cab page never opens on a bare heading, which
/// is what it did on a project with an empty `bannerTopHome`.
///
/// Same 15 px radius and the same 150 px strip height the admin banner carousel
/// uses, so switching from one to the other does not move the page.
class CabDefaultBanner extends StatelessWidget {
  const CabDefaultBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            "assets/images/img_cab_banner.png",
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}

/// The photograph across the top of a service card.
///
/// `BoxFit.cover` on a fixed height, so the card keeps its shape whatever the
/// screen width and the car stays the subject rather than being letterboxed.
class _CardPhoto extends StatelessWidget {
  const _CardPhoto({required this.asset});

  final String asset;

  /// The strip the photograph is cropped into.
  ///
  /// 64 rather than the 80 it was: blocks 1 and 2 grew by the height of a
  /// photograph when these were added, which pushed block 3's text off the
  /// bottom of a short phone. `BoxFit.cover` means the shorter box crops the
  /// picture rather than squashing it, so nothing is distorted.
  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, height: height, width: double.infinity, fit: BoxFit.cover);
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

    return bannerList.isEmpty
        ? SizedBox()
        : Column(
          children: [
            SizedBox(height: 20),
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
