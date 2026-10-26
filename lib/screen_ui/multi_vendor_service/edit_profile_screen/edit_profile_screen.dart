import 'dart:io';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/edit_profile_controller.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/theme_controller.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: EditProfileController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(centerTitle: false, titleSpacing: 0, backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Profile Information".tr,
                    style: TextStyle(fontSize: 24, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "View and update your personal details, contact information, and preferences.".tr,
                    style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        controller.profileImage.isEmpty
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.asset(Constant.userPlaceHolder, height: Responsive.width(24, context), width: Responsive.width(24, context), fit: BoxFit.cover),
                            )
                            : Constant().hasValidUrl(controller.profileImage.value) == false
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.file(File(controller.profileImage.value), height: Responsive.width(24, context), width: Responsive.width(24, context), fit: BoxFit.cover),
                            )
                            : ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: NetworkImageWidget(
                                fit: BoxFit.cover,
                                imageUrl: controller.profileImage.value,
                                height: Responsive.width(24, context),
                                width: Responsive.width(24, context),
                                errorWidget: Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover, height: Responsive.width(24, context), width: Responsive.width(24, context)),
                              ),
                            ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              buildBottomSheet(context, controller);
                            },
                            child: SvgPicture.asset("assets/icons/ic_edit.svg"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: TextFieldWidget(title: 'First Name'.tr, controller: controller.firstNameController.value, hintText: 'First Name'.tr)),
                      const SizedBox(width: 10),
                      Expanded(child: TextFieldWidget(title: 'Last Name'.tr, controller: controller.lastNameController.value, hintText: 'Last Name'.tr)),
                    ],
                  ),
                  TextFieldWidget(title: 'Email'.tr, textInputType: TextInputType.emailAddress, controller: controller.emailController.value, hintText: 'Email'.tr, enable: false),
                  TextFieldWidget(title: 'Phone Number'.tr, textInputType: TextInputType.emailAddress, controller: controller.phoneNumberController.value, hintText: 'Phone Number'.tr, enable: false),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: RoundedButtonFill(
                title: "Save Details".tr,
                height: 5.5,
                color: AppThemeData.primary300,
                textColor: AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  controller.saveData();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, EditProfileController controller) {
    return showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: Responsive.height(22, context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 15), child: Text("please select".tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(onPressed: () => controller.pickFile(source: ImageSource.camera), icon: const Icon(Icons.camera_alt, size: 32)),
                            Padding(padding: const EdgeInsets.only(top: 3), child: Text("camera".tr, style: const TextStyle())),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(onPressed: () => controller.pickFile(source: ImageSource.gallery), icon: const Icon(Icons.photo_library_sharp, size: 32)),
                            Padding(padding: const EdgeInsets.only(top: 3), child: Text("gallery".tr, style: const TextStyle())),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
