import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/ecommarce/home_e_commerce_screen.dart';
import '../screen_ui/multi_vendor_service/favourite_screens/favourite_screen.dart';
import '../screen_ui/multi_vendor_service/order_list_screen/order_screen.dart';
import '../screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:get/get.dart';

class DashBoardEcommerceController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    if (Constant.walletSetting == false) {
      pageList.value = [const HomeECommerceScreen(), const FavouriteScreen(), const OrderScreen(), const ProfileScreen()];
    } else {
      pageList.value = [const HomeECommerceScreen(), const FavouriteScreen(), const WalletScreen(), const OrderScreen(), const ProfileScreen()];
    }
    super.onInit();
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}
