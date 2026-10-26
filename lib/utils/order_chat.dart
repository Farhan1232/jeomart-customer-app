import 'dart:developer';

import 'package:customer/constant/constant.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:get/get.dart';

/// Opening the chat on an order, from the customer's side.
///
/// The three buttons that did this - two for the restaurant, one for the driver
/// - each opened a blocking loader and then dereferenced the reads that
/// followed with `!`:
///
/// ```dart
/// ShowToastDialog.showLoader("Please wait...".tr);
/// UserModel? restaurantUser = await FireStoreUtils.getUserProfile(order.vendor!.author.toString());
/// VendorModel? vendorModel  = await FireStoreUtils.getVendorById(restaurantUser!.vendorID.toString());
/// ShowToastDialog.closeLoader();
/// ```
///
/// An order whose vendor has since been removed, or whose driver profile cannot
/// be read, throws on one of those bangs - two lines above the `closeLoader()`
/// that would have taken the overlay down. The overlay then swallows every tap
/// for the rest of the session, which is the same freeze the advertising
/// banners caused. Same shape, same fix: the loader comes down in a `finally`,
/// and a missing piece says so rather than throwing.
class OrderChat {
  /// Chat with the restaurant that took the order.
  static Future<void> openWithVendor(OrderModel order) async {
    ShowToastDialog.showLoader("Please wait...".tr);

    UserModel? customer;
    UserModel? restaurantUser;
    VendorModel? vendorModel;
    try {
      customer = await FireStoreUtils.getUserProfile(order.authorID.toString());
      final String vendorAuthor = order.vendor?.author?.toString() ?? '';
      if (vendorAuthor.isNotEmpty) {
        restaurantUser = await FireStoreUtils.getUserProfile(vendorAuthor);
      }
      final String vendorId = restaurantUser?.vendorID?.toString() ?? '';
      if (vendorId.isNotEmpty) {
        vendorModel = await FireStoreUtils.getVendorById(vendorId);
      }
    } catch (error) {
      log('OrderChat.openWithVendor failed :: $error');
    } finally {
      ShowToastDialog.closeLoader();
    }

    if (customer == null || restaurantUser == null || vendorModel == null) {
      ShowToastDialog.showToast("This chat is not available right now.".tr);
      return;
    }

    Get.to(
      const ChatScreen(),
      arguments: <String, dynamic>{
        "senderName": customer.fullName(),
        "receivedName": vendorModel.title,
        "orderId": order.id,
        "receivedId": restaurantUser.id,
        "senderId": customer.id,
        "senderProfileUrl": customer.profilePictureURL,
        "receivedProfileUrl": vendorModel.photo,
        "token": restaurantUser.fcmToken,
        "chatType": Constant.userRoleVendor,
      },
    );
  }

  /// Chat with the driver delivering the order.
  static Future<void> openWithDriver(OrderModel order) async {
    ShowToastDialog.showLoader("Please wait...".tr);

    UserModel? customer;
    UserModel? driver;
    try {
      customer = await FireStoreUtils.getUserProfile(order.authorID.toString());
      final String driverId = order.driverID?.toString() ?? '';
      if (driverId.isNotEmpty) {
        driver = await FireStoreUtils.getUserProfile(driverId);
      }
    } catch (error) {
      log('OrderChat.openWithDriver failed :: $error');
    } finally {
      ShowToastDialog.closeLoader();
    }

    if (customer == null) {
      ShowToastDialog.showToast("This chat is not available right now.".tr);
      return;
    }

    Get.to(
      const ChatScreen(),
      arguments: <String, dynamic>{
        "senderName": customer.fullName(),
        "receivedName": driver?.fullName(),
        "orderId": order.id,
        "receivedId": driver?.id,
        "senderId": customer.id,
        "senderProfileUrl": customer.profilePictureURL,
        "receivedProfileUrl": driver?.profilePictureURL,
        "token": driver?.fcmToken,
        "chatType": Constant.userRoleDriver,
      },
    );
  }
}
