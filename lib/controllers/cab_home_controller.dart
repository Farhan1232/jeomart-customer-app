import 'package:customer/models/banner_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

class CabHomeController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<BannerModel> bannerTopHome = <BannerModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    await FireStoreUtils.getHomeTopBanner().then((value) {
      bannerTopHome.value = value;
    });
    isLoading.value = false;
  }
}
