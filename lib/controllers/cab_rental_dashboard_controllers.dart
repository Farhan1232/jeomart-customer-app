import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/rental_service/rental_home_screen.dart';
import 'package:get/get.dart';
import '../screen_ui/rental_service/my_rental_booking_screen.dart';

class CabRentalDashboardControllers extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    // TODO: implement onInit

    if (Constant.walletSetting == false) {
      pageList.value = [RentalHomeScreen(), MyRentalBookingScreen(), const ProfileScreen()];
    } else {
      pageList.value = [RentalHomeScreen(), MyRentalBookingScreen(), const WalletScreen(), const ProfileScreen()];
    }
    super.onInit();
  }
}
