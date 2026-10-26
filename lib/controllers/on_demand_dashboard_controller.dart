import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/on_demand_service/favourite_ondemand_screen.dart';
import 'package:get/get.dart';

import '../screen_ui/on_demand_service/my_booking_on_demand_screen.dart';
import '../screen_ui/on_demand_service/on_demand_home_screen.dart';

class OnDemandDashboardController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    if (Constant.walletSetting == false) {
      pageList.value = [OnDemandHomeScreen(), FavouriteOndemandScreen(), const MyBookingOnDemandScreen(), const ProfileScreen()];
    } else {
      pageList.value = [OnDemandHomeScreen(), FavouriteOndemandScreen(), const MyBookingOnDemandScreen(), const WalletScreen(), const ProfileScreen()];
    }
    super.onInit();
  }
}
