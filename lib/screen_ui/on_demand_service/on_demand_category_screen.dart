import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/screen_ui/on_demand_service/view_category_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/on_demand_category_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../models/category_model.dart';
import '../../themes/app_them_data.dart';
import 'package:customer/utils/app_image_cache.dart';

class OnDemandCategoryScreen extends StatelessWidget {
  const OnDemandCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX(
      init: OnDemandCategoryController(),
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
                    onTap: () => Get.back(),
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
                        Text("Explore services".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                        Text(
                          "Explore services tailored for you—quick, easy, and personalized.".tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppThemeData.boldTextStyle(fontSize: 14, color: AppThemeData.grey900),
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
                  : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          controller.categories.isEmpty
                              ? Center(child: Text("No Categories".tr))
                              : GridView.builder(
                                padding: const EdgeInsets.all(5),
                                itemCount: controller.categories.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                                itemBuilder: (context, index) {
                                  return categoriesCell(context, controller.categories[index], index, isDark);
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

  Widget categoriesCell(BuildContext context, CategoryModel category, int index, bool isDark) {
    return GestureDetector(
      onTap: () {
        Get.to(() => ViewCategoryServiceListScreen(), arguments: {'categoryId': category.id, 'categoryTitle': category.title});
      },
      child: Column(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(cacheManager: AppImageCache.manager, imageUrl: category.image ?? "", height: 60, width: 60, fit: BoxFit.cover)),
          const SizedBox(height: 5),
          Text(category.title ?? "", style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
