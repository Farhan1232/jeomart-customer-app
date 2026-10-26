import 'package:get/get.dart';
import '../models/banner_model.dart';
import '../models/parcel_category.dart';
import '../service/fire_store_utils.dart';

class HomeParcelController extends GetxController {
  RxBool isLoading = true.obs;

  RxList<BannerModel> bannerTopHome = <BannerModel>[].obs;
  RxList<ParcelCategory> parcelCategory = <ParcelCategory>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  void loadData() async {
    try {
      isLoading.value = true;

      // The banners and the parcel categories are independent reads that used
      // to be awaited one after the other. Started together, the first screen
      // waits for the slower of the two. A failure in either still lands in the
      // `catch` below once both have finished, which clears both lists exactly
      // as before.
      await Future.wait(<Future<void>>[
        // Load banners
        FireStoreUtils.getHomeTopBanner().then((value) {
          bannerTopHome.value = value;
        }),
        // Load parcel categories
        FireStoreUtils.getParcelServiceCategory().then((value) {
          parcelCategory.value = value;
        }),
      ]);
    } catch (e) {
      bannerTopHome.clear();
      parcelCategory.clear();
    } finally {
      isLoading.value = false;
    }
  }
}
