import 'package:customer/controllers/scan_qr_code_controller.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_code_dart_scan/qr_code_dart_scan.dart';

import '../../../controllers/theme_controller.dart';
import '../../../themes/show_toast_dialog.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

class ScanQrCodeScreen extends StatelessWidget {
  const ScanQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetBuilder(
      init: ScanQrCodeController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            title: Text("Scan QR Code".tr, style: TextStyle(fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500)),
          ),
          body: QRCodeDartScanView(
            // enable scan invert qr code ( default = false)
            typeScan: TypeScan.live,
            // if TypeScan.takePicture will try decode when click to take a picture(default TypeScan.live)
            onCapture: (Result result) {
              Get.back();
              ShowToastDialog.showLoader("Please wait...".tr);
              if (controller.allNearestRestaurant.isNotEmpty) {
                if (controller.allNearestRestaurant.where((vendor) => vendor.id == result.text).isEmpty) {
                  ShowToastDialog.closeLoader();
                  ShowToastDialog.showToast("Store is not available".tr);
                  return;
                }
                VendorModel storeModel = controller.allNearestRestaurant.firstWhere((vendor) => vendor.id == result.text);
                ShowToastDialog.closeLoader();
                Get.back();
                Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": storeModel});
              } else {
                Get.back();
                ShowToastDialog.showToast("Store is not available".tr);
              }
            },
          ),
        );
      },
    );
  }
}
