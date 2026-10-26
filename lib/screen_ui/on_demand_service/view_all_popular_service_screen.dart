import 'package:customer/screen_ui/on_demand_service/on_demand_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/view_all_popular_service_controller.dart';
import '../../models/provider_serivce_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/text_field_widget.dart';

class ViewAllPopularServiceScreen extends StatelessWidget {
  const ViewAllPopularServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX<ViewAllPopularServiceController>(
      init: ViewAllPopularServiceController(),
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
                  Text("All Services".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                    child: Column(
                      children: [
                        TextFieldWidget(hintText: "Search Service".tr, controller: controller.searchTextFiledController.value, onchange: (value) => controller.getFilterData(value.toString())),
                        const SizedBox(height: 15),
                        controller.providerList.isEmpty
                            ? Expanded(child: Center(child: Constant.showEmptyView(message: "No service Found".tr)))
                            : Expanded(
                              child: ListView.builder(
                                itemCount: controller.providerList.length,
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                scrollDirection: Axis.vertical,
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
}
