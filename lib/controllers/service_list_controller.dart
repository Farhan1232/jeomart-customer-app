import 'dart:async';

import 'package:customer/models/section_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/screen_ui/cab_service_screens/cab_dashboard_screen.dart';
import 'package:customer/screen_ui/ecommarce/dash_board_e_commerce_screen.dart';
import 'package:customer/screen_ui/parcel_service/parcel_dashboard_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_dashboard_screen.dart';
import 'package:customer/service/cart_provider.dart';
import 'package:customer/service/database_helper.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:customer/utils/preferences.dart';
import 'package:customer/utils/city_filter.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screen_ui/auth_screens/login_screen.dart';
import '../screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart';
import '../screen_ui/on_demand_service/on_demand_dashboard_screen.dart';

class ServiceListController extends GetxController {
  var isLoading = false.obs;
  var serviceListBanner = <dynamic>[].obs;
  var sectionList = <SectionModel>[].obs;
  var currencyData = CurrencyModel().obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;

    // This is the first screen the customer sees after the splash, and it used
    // to reach it through four network round trips laid end to end: the
    // currency, then the sections, then the section banners, then the zones.
    //
    // Not one of them reads anything another one writes. They are sequential
    // only because each was written as its own `await` on the line after the
    // last. Started together, the screen waits for the slowest single read
    // instead of the sum of all four.
    final Future<CurrencyModel?> currencyReq = FireStoreUtils.getCurrency();
    final Future<List<SectionModel>> sectionsReq = FireStoreUtils.getSections();
    final Future<List<dynamic>> bannersReq = FireStoreUtils.getSectionBannerList();
    final Future<void> zoneReq = getZone();
    // The zones of the customer's area, for the sections offered per city.
    final Future<Set<String>?> hereReq = CityFilter.customerZones();

    // Read back in the original order, so anything downstream that depends on
    // the order these values were assigned in still sees it.
    final CurrencyModel? currency = await currencyReq;
    currencyData.value = currency ?? CurrencyModel(id: "", code: "USD", decimal: 2, isactive: true, name: "US Dollar", symbol: "\$", symbolatright: false);

    sectionList.assignAll(CityFilter.keep(await sectionsReq, (SectionModel s) => s.zoneIds, await hereReq));
    serviceListBanner.assignAll(await bannersReq);
    await zoneReq;

    isLoading.value = false;
  }

  Future<void> getZone() async {
    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        Constant.zoneList = value;
      }
    });
  }

  Future<void> onServiceTap(BuildContext context, SectionModel sectionModel) async {
    try {
      ShowToastDialog.showLoader("Please wait...".tr);
      Constant.sectionConstantModel = sectionModel;
      // Started here rather than in [_navigate]. The profile read, the push
      // token and the profile write below all came first, and only then the
      // geocoder and the tax query - five round trips in series behind the
      // loader. The tax lookup reads only the section and the selected
      // location, neither of which anything below changes, and its result is
      // still applied in [_navigate], at the same point as before.
      final Future<List<TaxModel>?> taxReq = FireStoreUtils.getTaxList(sectionModel.id);
      // The sign-in redirect below never uses it.
      unawaited(taxReq.then<void>((_) {}, onError: (Object _) {}));
      AppThemeData.primary300 = Color(int.tryParse(sectionModel.color?.replaceFirst("#", "0xff") ?? '') ?? 0xff2196F3);
      if (auth.FirebaseAuth.instance.currentUser != null) {
        String uid = auth.FirebaseAuth.instance.currentUser!.uid;
        UserModel? user = await FireStoreUtils.getUserProfile(uid);
        if (user != null && user.role == Constant.userRoleCustomer) {
          user.fcmToken = await NotificationService.getToken();
          await FireStoreUtils.updateUser(user);
          ShowToastDialog.closeLoader();
          if (sectionModel.serviceType == 'Ecommerce Service') {
            await Preferences.setString(Preferences.foodDeliveryType, 'Delivery');
          }
          await _navigate(sectionModel, taxReq);
        } else {
          ShowToastDialog.closeLoader();
          Get.offAll(() => const LoginScreen());
        }
      } else {
        ShowToastDialog.closeLoader();
        await _navigate(sectionModel, taxReq);
      }
    } catch (e) {
      print("Error during service tap: $e");
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> _navigate(SectionModel sectionModel, Future<List<TaxModel>?> taxReq) async {
    await taxReq.then((value) {
      if (value != null) {
        Constant.taxProductList = value.where((TaxModel taxModel) => taxModel.scope == "product").toList();
        Constant.orderProductTaxList = value.where((TaxModel taxModel) => taxModel.scope == "order").toList();
        Constant.driverDeliveryTaxList = value.where((TaxModel taxModel) => taxModel.scope == "delivery").toList();

        if (sectionModel.packagingChargeEnable == true) {
          Constant.packagingTaxList = value.where((TaxModel taxModel) => taxModel.scope == "packaging").toList();
        }
        if (sectionModel.platformFee?.enable == true) {
          Constant.platformFeeModel = sectionModel.platformFee;
          Constant.platformTaxList = value.where((TaxModel taxModel) => taxModel.scope == "platform").toList();
        }
      }
    });

    if (sectionModel.serviceTypeFlag == "ecommerce-service" || sectionModel.serviceTypeFlag == "delivery-service") {
      if (cartItem.isNotEmpty) {
        showAlertDialog(Get.context!, UserModel(), sectionModel);
      } else {
        if (sectionModel.serviceTypeFlag == "ecommerce-service") {
          Get.to(DashBoardEcommerceScreen());
        } else if (sectionModel.serviceTypeFlag == "cab-service") {
          Get.to(CabDashboardScreen());
        } else if (sectionModel.serviceTypeFlag == "rental-service") {
          Get.to(RentalDashboardScreen());
        } else if (sectionModel.serviceTypeFlag == "parcel_delivery") {
          Get.to(ParcelDashboardScreen());
        } else if (sectionModel.serviceTypeFlag == "ondemand-service") {
          Get.to(OnDemandDashboardScreen());
        } else {
          Get.to(() => DashBoardScreen());
        }
      }
    } else {
      if (sectionModel.serviceTypeFlag == "ecommerce-service") {
        Get.to(DashBoardEcommerceScreen());
      } else if (sectionModel.serviceTypeFlag == "cab-service") {
        Get.to(CabDashboardScreen());
      } else if (sectionModel.serviceTypeFlag == "rental-service") {
        Get.to(RentalDashboardScreen());
      } else if (sectionModel.serviceTypeFlag == "parcel_delivery") {
        Get.to(ParcelDashboardScreen());
      } else if (sectionModel.serviceTypeFlag == "ondemand-service") {
        Get.to(OnDemandDashboardScreen());
      } else {
        Get.to(() => DashBoardScreen());
      }
    }
  }

  final CartProvider cartProvider = CartProvider();

  void showAlertDialog(BuildContext context, UserModel user, SectionModel sectionModel) {
    Get.defaultDialog(
      title: "Alert!".tr,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("If you select this Section/Service, your previously added items will be removed from the cart.".tr, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: RoundedButtonFill(
                  height: 5.5,
                  title: "Cancel".tr,
                  onPress: () {
                    Get.back();
                  },
                  color: AppThemeData.grey900,
                  textColor: AppThemeData.surface,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RoundedButtonFill(
                  title: "OK".tr,
                  height: 5.5,
                  onPress: () async {
                    DatabaseHelper.instance.deleteAllCartProducts();
                    cartProvider.clearDatabase();
                    Get.back();
                    if (sectionModel.serviceTypeFlag == "ecommerce-service") {
                      Get.off(() => DashBoardEcommerceScreen());
                    } else {
                      Get.to(() => DashBoardScreen());
                    }
                  },
                  color: AppThemeData.primary300,
                  textColor: AppThemeData.surface,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [], // 👈 keep this empty since we put buttons in content
    );
  }
}
