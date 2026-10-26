import 'package:customer/constant/constant.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/screen_ui/on_demand_service/on_demand_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../controllers/provider_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/provider_serivce_model.dart';
import '../../themes/app_them_data.dart';
import 'package:customer/utils/app_image_cache.dart';

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<ProviderController>(
      init: ProviderController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(automaticallyImplyLeading: true),
          body:
              controller.isLoading.value
                  ? Center(child: Constant.loader())
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child:
                              (controller.userModel.value?.profilePictureURL ?? "").isNotEmpty
                                  ? CircleAvatar(backgroundImage: CachedNetworkImageProvider(controller.userModel.value?.profilePictureURL ?? '', cacheManager: AppImageCache.manager), radius: 50.0)
                                  : CircleAvatar(backgroundImage: CachedNetworkImageProvider(Constant.placeHolderImage, cacheManager: AppImageCache.manager), radius: 50.0),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          controller.userModel.value?.fullName() ?? '',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset("assets/icons/ic_mail.svg", color: isDark ? Colors.white : Colors.black),
                            const SizedBox(width: 6),
                            Text(
                              controller.userModel.value?.email ?? '',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset("assets/icons/ic_mobile.svg", color: isDark ? Colors.white : Colors.black),
                            const SizedBox(width: 6),
                            Text(
                              controller.userModel.value?.phoneNumber ?? '',
                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontFamily: AppThemeData.regular, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: const BoxDecoration(color: AppThemeData.warning400, borderRadius: BorderRadius.all(Radius.circular(16))),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  _getRating(controller),
                                  style: const TextStyle(letterSpacing: 0.5, fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        const SizedBox(height: 10),
                        controller.providerList.isEmpty
                            ? Center(child: Text("No Services Found".tr))
                            : Expanded(
                              child: ListView.builder(
                                itemCount: controller.providerList.length,
                                padding: EdgeInsets.zero,
                                itemBuilder: (context, index) {
                                  ProviderServiceModel data = controller.providerList[index];
                                  return ServiceView(provider: data, isDark: isDark, controller: controller.onDemandHomeController.value);
                                },
                              ),
                            ),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  String _getRating(ProviderController controller) {
    final reviewsCount = double.tryParse(controller.userModel.value?.reviewsCount?.toString() ?? "0") ?? 0;
    final reviewsSum = double.tryParse(controller.userModel.value?.reviewsSum?.toString() ?? "0") ?? 0;

    if (reviewsCount == 0) return "0";
    final avg = reviewsSum / reviewsCount;
    return avg.toStringAsFixed(1);
  }
}
