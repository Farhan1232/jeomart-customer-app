import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/on_demand_service/provider_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/theme_controller.dart';
import '../../models/provider_serivce_model.dart';
import '../../controllers/on_demand_details_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import 'on_demand_booking_screen.dart';
import 'package:customer/utils/app_image_cache.dart';

class OnDemandDetailsScreen extends StatelessWidget {
  const OnDemandDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX<OnDemandDetailsController>(
      init: OnDemandDetailsController(),
      builder: (controller) {
        return Scaffold(
          body: buildSliverScrollView(context, controller, controller.provider, controller.userModel, isDark),
          bottomNavigationBar:
              controller.isOpen.value == false
                  ? SizedBox()
                  : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RoundedButtonFill(
                          title: "Book Now".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            if (!Constant.requireLogin()) return;
                            Get.to(() => OnDemandBookingScreen(), arguments: {'providerModel': controller.provider, 'categoryTitle': controller.categoryTitle.value});
                          },
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  SingleChildScrollView buildSliverScrollView(BuildContext context, OnDemandDetailsController controller, ProviderServiceModel provider, user, isDark) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CachedNetworkImage(cacheManager: AppImageCache.manager, 
                imageUrl: provider.photos.isNotEmpty ? provider.photos.first : "",
                placeholder: (context, url) => Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.fitWidth),
                fit: BoxFit.fitWidth,
                width: width,
                height: height * 0.45,
              ),
              Positioned(top: height * 0.05, left: width * 0.03, child: _circleButton(context, icon: Icons.arrow_back, onTap: () => Get.back())),
              Positioned(
                top: height * 0.05,
                right: width * 0.03,
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), color: controller.isOpen.value ? Colors.green : Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(controller.isOpen.value ? "Open".tr : "Close".tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: GetBuilder<OnDemandDetailsController>(
              builder: (controller) {
                final provider = controller.provider;
                final categoryTitle = controller.categoryTitle.value;
                final subCategoryTitle = controller.subCategoryTitle.value;
                // final tabString = controller.tabString.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.title.toString(),
                            style: TextStyle(fontSize: 20, fontFamily: AppThemeData.regular, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                        Row(
                          children: [
                            provider.disPrice == "" || provider.disPrice == "0"
                                ? Text(
                                  provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price ?? '0') : '${Constant.amountShow(amount: provider.price ?? '0')}/${'hr'.tr}',
                                  style: TextStyle(fontSize: 18, fontFamily: AppThemeData.regular, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppThemeData.primary300),
                                )
                                : Row(
                                  children: [
                                    Text(
                                      provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.disPrice ?? '0') : '${Constant.amountShow(amount: provider.disPrice ?? '0')}/${'hr'.tr}',
                                      style: TextStyle(fontSize: 18, fontFamily: AppThemeData.regular, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppThemeData.primary300),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price ?? '0') : '${Constant.amountShow(amount: provider.price ?? '0')}/${'hr'.tr}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                      ),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(categoryTitle, style: TextStyle(fontSize: 14, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? Colors.white : Colors.black)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: AppThemeData.warning400),
                              const SizedBox(width: 3),
                              Text(
                                provider.reviewsCount != 0 ? ((provider.reviewsSum ?? 0.0) / (provider.reviewsCount ?? 0.0)).toStringAsFixed(1) : '0',
                                style: const TextStyle(letterSpacing: 0.5, fontSize: 16, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, color: AppThemeData.warning400),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "(${provider.reviewsCount} ${'Reviews'.tr})",
                                style: TextStyle(letterSpacing: 0.5, fontSize: 16, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          subCategoryTitle.isNotEmpty
                              ? Container(
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppThemeData.primary300.withOpacity(0.20)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Text(subCategoryTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: AppThemeData.regular, color: AppThemeData.primary300)),
                                ),
                              )
                              : Container(),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.green.withOpacity(0.20)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: InkWell(
                                onTap: () {
                                  showModalBottomSheet(
                                    isScrollControlled: true,
                                    isDismissible: true,
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    enableDrag: true,
                                    builder: (context) => showTiming(context, controller, isDark),
                                  );
                                },
                                child: Text("View Timing".tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 0.5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, color: isDark ? Colors.white : Colors.black, size: 20),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            provider.address.toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(),
                    _tabBar(controller),
                    Obx(() {
                      if (controller.tabString.value == "About") {
                        return aboutTabViewWidget(controller, controller.provider, isDark);
                      } else if (controller.tabString.value == "Gallery") {
                        return galleryTabViewWidget(controller);
                      } else {
                        return reviewTabViewWidget(controller, isDark);
                      }
                    }),
                    const SizedBox(height: 15),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
    return ClipOval(
      child: Container(color: Colors.black.withOpacity(0.7), child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 30, color: Colors.white)))),
    );
  }

  Widget _tabBar(OnDemandDetailsController controller) {
    return Obx(() => Row(children: [_tabItem("About", controller), _tabItem("Gallery", controller), _tabItem("Review", controller)]));
  }

  Widget _tabItem(String title, OnDemandDetailsController controller) {
    return GestureDetector(
      onTap: () => controller.changeTab(title),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: controller.tabString.value == title ? AppThemeData.primary300 : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
        child: Text(title.tr, style: TextStyle(fontWeight: FontWeight.bold, color: controller.tabString.value == title ? Colors.white : Colors.black)),
      ),
    );
  }

  Widget aboutTabViewWidget(OnDemandDetailsController controller, ProviderServiceModel providerModel, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((providerModel.description ?? '').tr, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Obx(() {
            final user = controller.userModel.value;
            if (user == null) return const SizedBox();
            return InkWell(
              onTap: () {
                Get.to(() => ProviderScreen(), arguments: {'providerId': user.id});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppThemeData.grey500 : Colors.grey.shade100, width: 1),
                    color: isDark ? AppThemeData.grey500 : Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(radius: 30, backgroundImage: CachedNetworkImageProvider(user.profilePictureURL?.isNotEmpty == true ? user.profilePictureURL! : Constant.placeHolderImage, cacheManager: AppImageCache.manager)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.fullName(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 5),
                                    Text(user.email ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14)),
                                    const SizedBox(height: 10),
                                    // Rating Box
                                    Container(
                                      decoration: BoxDecoration(color: AppThemeData.warning400, borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, size: 16, color: Colors.white),
                                          const SizedBox(width: 3),
                                          Text(
                                            double.parse(user.reviewsCount.toString()) != 0
                                                ? (double.parse(user.reviewsSum.toString()) / double.parse(user.reviewsCount.toString())).toStringAsFixed(1)
                                                : '0',
                                            style: const TextStyle(letterSpacing: 0.5, fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget galleryTabViewWidget(OnDemandDetailsController controller) {
    final photos = controller.provider.photos;

    if (photos.isEmpty) {
      return Center(child: Text("No Image Found".tr));
    }

    return GridView.builder(
      itemCount: photos.length,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 0, crossAxisSpacing: 8, mainAxisExtent: 180),
      itemBuilder: (context, index) {
        final imageUrl = photos[index];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
              imageUrl: imageUrl,
              height: 60,
              width: 60,
              imageBuilder: (context, imageProvider) => Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: imageProvider, fit: BoxFit.cover))),
              placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
              errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Widget reviewTabViewWidget(OnDemandDetailsController controller, bool isDark) {
    final reviews = controller.ratingService;

    if (reviews.isEmpty) {
      return SizedBox(height: 200, child: Center(child: Text("No review Found".tr, style: AppThemeData.mediumTextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900))));
    }

    return ListView.builder(
      itemCount: reviews.length,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: isDark ? AppThemeData.grey700 : AppThemeData.grey50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              shadows: const [BoxShadow(color: Color(0x0A000000), blurRadius: 32, offset: Offset(0, 0), spreadRadius: 0)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(review.uname ?? '', style: TextStyle(fontSize: 16, letterSpacing: 1, fontWeight: FontWeight.w600, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                      Text(
                        review.createdAt != null ? DateFormat('dd MMM').format(review.createdAt!.toDate()) : '',
                        style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RatingBar.builder(
                    initialRating: double.tryParse(review.rating.toString()) ?? 0,
                    direction: Axis.horizontal,
                    itemSize: 20,
                    ignoreGestures: true,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => Icon(Icons.star, color: AppThemeData.primary300),
                    onRatingUpdate: (rate) {},
                  ),
                  const Divider(),
                  const SizedBox(height: 5),
                  Text(review.comment ?? '', style: TextStyle(color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget showTiming(BuildContext context, OnDemandDetailsController controller, bool isDark) {
    final provider = controller.provider;
    return Container(
      decoration: BoxDecoration(color: isDark ? AppThemeData.grey300 : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text("Service Timing".tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppThemeData.regular, color: AppThemeData.primary300)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _timeCard(context, "Start Time : ".tr, provider.startTime.toString(), isDark)),
                const SizedBox(width: 10),
                Expanded(child: _timeCard(context, "End Time : ".tr, provider.endTime.toString(), isDark)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text("Service Days".tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppThemeData.regular, color: AppThemeData.primary300)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children:
                  provider.days
                      .map(
                        (day) => Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: isDark ? const Color(0XFF3c3a2e) : const Color(0XFFC3C5D1), width: 1)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
                            child: Text(day, style: TextStyle(color: isDark ? const Color(0XFFa5a292) : const Color(0XFF5A5D6D))),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _timeCard(BuildContext context, String title, String value, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: isDark ? const Color(0XFF3c3a2e) : const Color(0XFFC3C5D1), width: 1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
        child: Row(
          children: [
            Text(title, style: TextStyle(color: isDark ? const Color(0XFFa5a292) : const Color(0XFF5A5D6D))),
            Text(value, style: TextStyle(color: isDark ? const Color(0XFFa5a292) : const Color(0XFF5A5D6D))),
          ],
        ),
      ),
    );
  }
}
