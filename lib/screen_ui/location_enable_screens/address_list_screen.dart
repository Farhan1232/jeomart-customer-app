import 'package:customer/constant/assets.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/address_list_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/screen_ui/location_enable_screens/enter_manually_location.dart';
import 'package:customer/themes/app_them_data.dart' show AppThemeData;
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class AddressListScreen extends StatelessWidget {
  const AddressListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddressListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            leading: InkWell(
              onTap: () {
                Get.back();
              },
              child: Icon(Icons.arrow_back, size: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("My Addresses".tr, style: AppThemeData.boldTextStyle(fontSize: 24, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                        const SizedBox(height: 5),
                        Text(
                          "Allows users to view, manage, add, or edit delivery addresses.".tr,
                          style: AppThemeData.mediumTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark500 : AppThemeData.grey600),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child:
                              controller.shippingAddressList.isEmpty
                                  ? Constant.showEmptyView(message: "Address not found".tr)
                                  : ListView.separated(
                                    itemCount: controller.shippingAddressList.length,
                                    itemBuilder: (context, index) {
                                      ShippingAddress address = controller.shippingAddressList[index];
                                      return InkWell(
                                        onTap: () {
                                          Get.back(result: address);
                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        decoration: BoxDecoration(color: isDark ? AppThemeData.greyDark100 : AppThemeData.grey100, borderRadius: BorderRadius.circular(8)),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                          child: Text(
                                                            address.addressAs.toString(),
                                                            style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 10),
                                                      address.isDefault == true
                                                          ? Container(
                                                            decoration: BoxDecoration(color: isDark ? AppThemeData.success100 : AppThemeData.success100, borderRadius: BorderRadius.circular(8)),
                                                            child: Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                              child: Text("Default".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: AppThemeData.grey900)),
                                                            ),
                                                          )
                                                          : SizedBox(),
                                                    ],
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    address.getFullAddress().toString(),
                                                    style: AppThemeData.mediumTextStyle(fontSize: 16, color: isDark ? AppThemeData.greyDark800 : AppThemeData.grey800),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                await controller.deleteAddress(index);
                                              },
                                              child: SvgPicture.asset("assets/icons/ic_delete_address.svg"),
                                            ),
                                            SizedBox(width: 10),
                                            InkWell(
                                              onTap: () {
                                                Get.to(EnterManuallyLocationScreen(), arguments: {"address": address, "mode": "Edit"})!.then((value) {
                                                  if (value == true) {
                                                    controller.getUser();
                                                  }
                                                });
                                              },
                                              child: SvgPicture.asset("assets/icons/ic_edit_address.svg"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    separatorBuilder: (BuildContext context, int index) {
                                      return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200, height: 1));
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 16, right: 16, top: 20),
            child: RoundedButtonFill(
              title: "Add New Address".tr,
              onPress: () {
                Get.to(EnterManuallyLocationScreen())!.then((value) {
                  if (value == true) {
                    controller.getUser();
                  }
                });
              },
              isRight: false,
              isCenter: true,
              icon: SvgPicture.asset(AppAssets.icPlus, width: 20, height: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.greyDark900),
              color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
              textColor: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
            ),
          ),
        );
      },
    );
  }
}
