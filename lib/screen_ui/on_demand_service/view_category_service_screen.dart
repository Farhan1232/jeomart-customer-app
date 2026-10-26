import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/view_category_service_controller.dart';
import '../../models/provider_serivce_model.dart';
import '../../screen_ui/on_demand_service/on_demand_home_screen.dart';
import '../../themes/app_them_data.dart';

class ViewCategoryServiceListScreen extends StatelessWidget {
  const ViewCategoryServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<ViewCategoryServiceController>(
      init: ViewCategoryServiceController(),
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
                  Text(controller.categoryTitle.value, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : controller.providerList.isEmpty
                  ? Constant.showEmptyView(message: "No Service Found".tr)
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: ListView.builder(
                      itemCount: controller.providerList.length,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        ProviderServiceModel providerModel = controller.providerList[index];
                        return ServiceView(isDark: isDark, provider: providerModel, controller: controller.onDemandHomeController.value);
                      },
                    ),
                  ),
        );
      },
    );
  }
}
