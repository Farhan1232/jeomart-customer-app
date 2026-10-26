import 'package:customer/controllers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/complain_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../constant/constant.dart';
import '../../themes/text_field_widget.dart';

class ComplainScreen extends StatelessWidget {
  const ComplainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetBuilder<ComplainController>(
      init: ComplainController(),
      builder: (controller) {
        return Obx(
          () => Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppThemeData.taxiBooking300,
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
                        child: const Center(child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text("Complain".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                  ],
                ),
              ),
            ),
            body:
                controller.isLoading.value
                    ? Constant.loader()
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Obx(
                            () =>
                                controller.status.value != '' && controller.status.value.isNotEmpty == true
                                    ? Row(
                                      children: [
                                        Text("Status".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                        Text(" : ${controller.status.value}".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800)),
                                      ],
                                    )
                                    : SizedBox(),
                          ),
                          if (controller.status.value != '' && controller.status.value.isNotEmpty == true) const SizedBox(height: 10),
                          Obx(() => TextFieldWidget(title: "Title".tr, hintText: "Title".tr, controller: controller.title.value)),
                          const SizedBox(height: 10),
                          Obx(() => TextFieldWidget(title: "Complain".tr, hintText: 'Type Description....'.tr, controller: controller.comment.value, maxLine: 8)),
                          const SizedBox(height: 20),
                          RoundedButtonFill(title: "Save".tr, color: AppThemeData.primary300, textColor: AppThemeData.grey50, onPress: () => controller.submitComplain()),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }
}
