import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/screen_ui/parcel_service/home_parcel_screen.dart';
import 'package:get/get.dart';
import '../screen_ui/parcel_service/my_booking_screen.dart';

class ParcelDashboardController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    if (Constant.walletSetting == false) {
      pageList.value = [const HomeParcelScreen(), const MyBookingScreen(), const ProfileScreen()];
    } else {
      pageList.value = [const HomeParcelScreen(), const MyBookingScreen(), const WalletScreen(), const ProfileScreen()];
    }
    super.onInit();
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}
