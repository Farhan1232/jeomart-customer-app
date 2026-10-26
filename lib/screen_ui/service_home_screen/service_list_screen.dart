import 'package:customer/constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/service_list_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../utils/network_image_widget.dart';

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return GetX(
      init: ServiceListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            centerTitle: false,
            title: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("JEOM".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 22, color: themeController.isDark.value ? AppThemeData.grey50 : AppThemeData.grey900)),
                Text("All Your Needs in One App!".tr, style: AppThemeData.regularTextStyle(fontSize: 14, color: themeController.isDark.value ? AppThemeData.grey100 : AppThemeData.grey700)),
              ],
            ),
          ),
          body:
              controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        controller.serviceListBanner.isEmpty ? SizedBox() : BannerView(bannerList: controller.serviceListBanner),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Explore Our Services".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 20, color: themeController.isDark.value ? AppThemeData.grey50 : AppThemeData.grey900)),
                              const SizedBox(height: 12),
                              GridView.builder(
                                itemCount: controller.sectionList.length,
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 130),
                                itemBuilder: (context, index) {
                                  final section = controller.sectionList[index];
                                  return GestureDetector(
                                    onTap: () => controller.onServiceTap(context, section),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: Constant.sectionColor[index % Constant.sectionColor.length], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
                                            child: Text(
                                              section.name ?? '',
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.grey900),
                                            ),
                                          ),
                                          const Spacer(),
                                          NetworkImageWidget(imageUrl: section.sectionImage ?? '', width: 80, height: 60, fit: BoxFit.contain, showShimmer: false),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }
}

class BannerView extends StatelessWidget {
  final List<dynamic> bannerList;
  final RxInt currentPage = 0.obs;
  final ScrollController scrollController = ScrollController();

  BannerView({super.key, required this.bannerList});

  void onScroll(BuildContext context) {
    if (scrollController.hasClients && bannerList.isNotEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = screenWidth * 0.8 + 10; // 80% width + spacing
      final offset = scrollController.offset;
      final index = (offset / itemWidth).round();

      if (index != currentPage.value && index < bannerList.length) {
        currentPage.value = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    scrollController.addListener(() => onScroll(context));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: bannerList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: MediaQuery.of(context).size.width * 0.8, child: NetworkImageWidget(imageUrl: bannerList[index].toString(), fit: BoxFit.fill, showShimmer: false)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            return Row(
              children: List.generate(bannerList.length, (index) {
                final isSelected = currentPage.value == index;
                return Expanded(child: Container(height: 4, decoration: BoxDecoration(color: isSelected ? AppThemeData.grey300 : AppThemeData.grey100, borderRadius: BorderRadius.circular(5))));
              }),
            );
          }),
        ],
      ),
    );
  }
}
