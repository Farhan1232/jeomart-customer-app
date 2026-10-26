import 'dart:developer';

import 'package:customer/constant/constant.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// What happens when a customer taps an advertising banner.
///
/// The six banner carousels in this app - the two on the food home screen, the
/// one on the second food theme, the dine-in one and the two e-commerce ones -
/// had six identical copies of this, and every copy could strand the app:
///
/// ```dart
/// ShowToastDialog.showLoader("Please wait...".tr);
/// VendorModel? vendorModel = await FireStoreUtils.getVendorById(...);
/// if (vendorModel!.zoneId == Constant.selectedZone!.id) {   // <- two throws
/// ```
///
/// A banner pointing at a store that has since been deleted, or one saved with
/// no redirect id, makes `getVendorById` return null, and `vendorModel!` then
/// throws on the line straight after the blocking loader went up and before any
/// `closeLoader()`. The overlay swallows every tap from then on, which is the
/// "click on banner image ... it stuck and u need to restart your app" the
/// client recorded, in "every section" - because every section had the same
/// copy.
///
/// The routing rules here are unchanged: a store banner opens the store, a
/// product banner opens the store that sells it, both only inside the
/// customer's own zone, and a link banner opens the link. What is new is that
/// none of the ways it can fail leave the loader up, and each of them says what
/// went wrong instead of freezing.
Future<void> openBanner(BannerModel bannerModel) async {
  switch (bannerModel.redirect_type) {
    case 'store':
      await _openStore(bannerModel.redirect_id?.toString() ?? '');
      break;
    case 'product':
      await _openProduct(bannerModel.redirect_id?.toString() ?? '');
      break;
    case 'external_link':
      await _openLink(bannerModel.redirect_id?.toString() ?? '');
      break;
  }
}

Future<void> _openStore(String vendorId) async {
  if (vendorId.trim().isEmpty) {
    ShowToastDialog.showToast("This banner has no link yet.".tr);
    return;
  }

  ShowToastDialog.showLoader("Please wait...".tr);
  VendorModel? vendorModel;
  try {
    vendorModel = await FireStoreUtils.getVendorById(vendorId);
  } catch (error) {
    log('openBanner: store $vendorId could not be read :: $error');
  } finally {
    // In a `finally`, so the read that fails takes the overlay down with it.
    ShowToastDialog.closeLoader();
  }

  _openVendor(vendorModel);
}

Future<void> _openProduct(String productId) async {
  if (productId.trim().isEmpty) {
    ShowToastDialog.showToast("This banner has no link yet.".tr);
    return;
  }

  ShowToastDialog.showLoader("Please wait...".tr);
  VendorModel? vendorModel;
  try {
    final ProductModel? productModel = await FireStoreUtils.getProductById(productId);
    final String vendorId = productModel?.vendorID?.toString() ?? '';
    if (vendorId.isNotEmpty) {
      vendorModel = await FireStoreUtils.getVendorById(vendorId);
    }
  } catch (error) {
    log('openBanner: product $productId could not be read :: $error');
  } finally {
    ShowToastDialog.closeLoader();
  }

  _openVendor(vendorModel);
}

/// The zone check both banner kinds end in.
///
/// A missing zone is treated the same way a mismatched one always was - the
/// store is not shown - rather than throwing on `Constant.selectedZone!`.
void _openVendor(VendorModel? vendorModel) {
  if (vendorModel == null) {
    ShowToastDialog.showToast("This store is no longer available.".tr);
    return;
  }

  final String? myZoneId = Constant.selectedZone?.id;
  if (myZoneId != null && vendorModel.zoneId == myZoneId) {
    Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
  } else {
    ShowToastDialog.showToast("The store is not available in your area. Change other location first.".tr);
  }
}

Future<void> _openLink(String link) async {
  final String trimmed = link.trim();
  if (trimmed.isEmpty) {
    ShowToastDialog.showToast("This banner has no link yet.".tr);
    return;
  }

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
    // "jeomart.com" is what somebody types into an admin panel field labelled
    // link, and `canLaunchUrl` rejects a URI with no scheme outright. Assume
    // https rather than refusing the banner.
    if (!uri.hasScheme) uri = Uri.parse('https://$trimmed');
  } catch (error) {
    log('openBanner: link "$trimmed" is not a URL :: $error');
    ShowToastDialog.showToast("Could not launch".tr);
    return;
  }

  // `canLaunchUrl` is asked, but it is not allowed to be the last word.
  //
  // On Android 11 and later it answers by querying the package manager, and it
  // can only see the apps this one declares in `<queries>`. The manifest now
  // declares http, https and tel - but a device with an unusual browser, or a
  // manufacturer build that filters differently, can still answer "no" for a
  // link that opens perfectly well. Every live banner on this project is a
  // https://wa.me/... link, so a false "no" here is the whole feature.
  //
  // So the launch is attempted whatever the answer, and the toast is shown only
  // when the attempt itself fails.
  if (await _launch(uri, LaunchMode.externalApplication)) return;
  if (await _launch(uri, LaunchMode.platformDefault)) return;
  ShowToastDialog.showToast("Could not launch".tr);
}

Future<bool> _launch(Uri uri, LaunchMode mode) async {
  try {
    return await launchUrl(uri, mode: mode);
  } catch (error) {
    log('openBanner: launching $uri as $mode failed :: $error');
    return false;
  }
}
