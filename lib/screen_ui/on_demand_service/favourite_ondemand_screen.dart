import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/favourite_ondemmand_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/category_model.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/screen_ui/on_demand_service/on_demand_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:customer/utils/app_image_cache.dart';

class FavouriteOndemandScreen extends StatelessWidget {
  const FavouriteOndemandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: FavouriteOndemmandController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.onDemand300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Text("Favourite Services".tr, style: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey900 : AppThemeData.grey900, fontSize: 20)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Constant.userModel == null
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset("assets/images/login.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round()),
                        const SizedBox(height: 12),
                        Text("Please Log In to Continue".tr, style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold)),
                        const SizedBox(height: 5),
                        Text(
                          "You’re not logged in. Please sign in to access your account and explore all features.".tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                        ),
                        const SizedBox(height: 20),
                        RoundedButtonFill(
                          title: "Log in".tr,
                          width: 55,
                          height: 5.5,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
                            Get.offAll(const LoginScreen());
                          },
                        ),
                      ],
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child:
                        controller.lstFav.isEmpty
                            ? Constant.showEmptyView(message: "Favourite Service not found.".tr)
                            : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              scrollDirection: Axis.vertical,
                              physics: const BouncingScrollPhysics(),
                              itemCount: controller.lstFav.length,
                              itemBuilder: (context, index) {
                                return FutureBuilder<List<ProviderServiceModel>>(
                                  future: FireStoreUtils.getCurrentProviderService(controller.lstFav[index]),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                                      return const SizedBox(); // or a placeholder widget
                                    }

                                    final provider = snapshot.data!.first; // safer way than [0]

                                    return GestureDetector(
                                      onTap: () {
                                        Get.to(() => OnDemandDetailsScreen(), arguments: {'providerModel': provider});
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 5),
                                        child: Container(
                                          height: MediaQuery.of(context).size.height * 0.16,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: isDark ? AppThemeData.grey500 : Colors.grey.shade100, width: 1),
                                            color: isDark ? AppThemeData.grey900 : Colors.white,
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), topLeft: Radius.circular(10)),
                                                child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                                  imageUrl: provider.photos.isNotEmpty ? provider.photos.first : Constant.placeHolderImage,
                                                  height: MediaQuery.of(context).size.height * 0.16,
                                                  width: 110,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                                  errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              provider.title ?? "",
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                                                            ),
                                                          ),
                                                          Obx(
                                                            () => GestureDetector(
                                                              onTap: () => controller.toggleFavourite(provider),
                                                              child: Icon(
                                                                controller.lstFav.where((element) => element.service_id == provider.id).isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                                                size: 24,
                                                                color:
                                                                    controller.lstFav.where((element) => element.service_id == provider.id).isNotEmpty
                                                                        ? AppThemeData.primary300
                                                                        : (isDark ? Colors.white38 : Colors.black38),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      FutureBuilder<CategoryModel?>(
                                                        future: controller.getCategory(provider.categoryId ?? ""),
                                                        builder: (ctx, snap) {
                                                          if (!snap.hasData) return const SizedBox();
                                                          return Text(snap.data?.title ?? "", style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black));
                                                        },
                                                      ),
                                                      _buildPrice(provider, isDark: isDark),
                                                      _buildRating(provider),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                // ignore: dead_code
                                FutureBuilder<List<ProviderServiceModel>>(
                                  future: FireStoreUtils.getCurrentProviderService(controller.lstFav[index]),
                                  builder: (context, snapshot) {
                                    return snapshot.data != null
                                        ? GestureDetector(
                                          onTap: () {
                                            Get.to(() => OnDemandDetailsScreen(), arguments: {'providerModel': snapshot.data![0]});
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 5),
                                            child: Container(
                                              height: MediaQuery.of(context).size.height * 0.16,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: isDark ? AppThemeData.grey500 : Colors.grey.shade100, width: 1),
                                                color: isDark ? AppThemeData.grey900 : Colors.white,
                                              ),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), topLeft: Radius.circular(10)),
                                                    child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                                                      imageUrl: snapshot.data![0].photos.isNotEmpty ? snapshot.data![0].photos[0] : Constant.placeHolderImage,
                                                      height: MediaQuery.of(context).size.height * 0.16,
                                                      width: 110,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => Center(child: CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation(AppThemeData.primary300))),
                                                      errorWidget: (context, url, error) => CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: Constant.placeHolderImage, fit: BoxFit.cover),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  snapshot.data![0].title ?? "",
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                                                                ),
                                                              ),
                                                              Obx(
                                                                () => GestureDetector(
                                                                  onTap: () => controller.toggleFavourite(snapshot.data![0]),
                                                                  child: Icon(
                                                                    controller.lstFav.where((element) => element.service_id == snapshot.data![0].id).isNotEmpty
                                                                        ? Icons.favorite
                                                                        : Icons.favorite_border,
                                                                    size: 24,
                                                                    color:
                                                                        controller.lstFav.where((element) => element.service_id == snapshot.data![0].id).isNotEmpty
                                                                            ? AppThemeData.primary300
                                                                            : (isDark ? Colors.white38 : Colors.black38),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          FutureBuilder<CategoryModel?>(
                                                            future: controller.getCategory(snapshot.data![0].categoryId ?? ""),
                                                            builder: (ctx, snap) {
                                                              if (!snap.hasData) return const SizedBox();
                                                              return Text(snap.data?.title ?? "", style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black));
                                                            },
                                                          ),
                                                          _buildPrice(snapshot.data![0], isDark: isDark),
                                                          _buildRating(snapshot.data![0]),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                        : Container();
                                  },
                                );
                              },
                            ),
                  ),
        );
      },
    );
  }

  Widget _buildPrice(ProviderServiceModel provider, {bool isDark = false}) {
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
          const SizedBox(width: 5),
          Text(
            provider.priceUnit == 'Fixed' ? Constant.amountShow(amount: provider.price) : '${Constant.amountShow(amount: provider.price ?? "0")}/${'hr'.tr}',
            style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
          ),
        ],
      );
    }
  }

  Widget _buildRating(ProviderServiceModel provider) {
    double rating = 0;
    if (provider.reviewsCount != null && provider.reviewsCount != 0) {
      rating = (provider.reviewsSum ?? 0) / (provider.reviewsCount ?? 1);
    }
    return Container(
      decoration: BoxDecoration(color: AppThemeData.warning400, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: Colors.white),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1), style: const TextStyle(letterSpacing: 0.5, fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }
}
