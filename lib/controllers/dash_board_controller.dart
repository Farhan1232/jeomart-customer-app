import 'package:customer/constant/constant.dart';
import '../screen_ui/multi_vendor_service/favourite_screens/favourite_screen.dart';
import '../screen_ui/multi_vendor_service/home_screen/home_screen.dart';
import '../screen_ui/multi_vendor_service/home_screen/home_screen_two.dart';
import '../screen_ui/multi_vendor_service/order_list_screen/order_screen.dart';
import '../screen_ui/multi_vendor_service/profile_screen/profile_screen.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxInt selectedIndex = 0.obs;

  RxList pageList = [].obs;

  @override
  void onInit() {
    // `?.` rather than `!`: this controller is also created from a notification
    // tap, which can arrive before a section has been chosen. A throw here left
    // `pageList` empty and the dashboard with nothing to draw.
    if (Constant.sectionConstantModel?.theme == "theme_2") {
      if (Constant.walletSetting == false) {
        pageList.value = [const HomeScreen(), const FavouriteScreen(), const OrderScreen(), const ProfileScreen()];
      } else {
        pageList.value = [const HomeScreen(), const FavouriteScreen(), const WalletScreen(), const OrderScreen(), const ProfileScreen()];
      }
    } else {
      if (Constant.walletSetting == false) {
        pageList.value = [const HomeScreenTwo(), const FavouriteScreen(), const OrderScreen(), const ProfileScreen()];
      } else {
        pageList.value = [const HomeScreenTwo(), const FavouriteScreen(), const WalletScreen(), const OrderScreen(), const ProfileScreen()];
      }
    }
    super.onInit();
  }

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;
}
