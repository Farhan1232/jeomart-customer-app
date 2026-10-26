import 'package:customer/constant/constant.dart';
import 'package:customer/models/category_model.dart';
import 'package:customer/models/favorite_ondemand_service_model.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

class FavouriteOndemmandController extends GetxController {
  // Add your controller logic here

  Rx<bool> isLoading = false.obs;
  RxList<FavouriteOndemandServiceModel> lstFav = <FavouriteOndemandServiceModel>[].obs;
  RxList<CategoryModel> categories = <CategoryModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    isLoading.value = true;
    await FireStoreUtils.getOnDemandCategory().then((catValue) {
      categories.value = catValue;
    });
    await FireStoreUtils.getFavouritesServiceList(FireStoreUtils.getCurrentUid()).then((favList) {
      lstFav.value = favList;
    });
    isLoading.value = false;
  }

  void toggleFavourite(ProviderServiceModel provider) {
    if (Constant.userModel == null) {
      Get.to(LoginScreen());
    } else {
      var contain = lstFav.where((element) => element.service_id == provider.id);
      if (contain.isNotEmpty) {
        FavouriteOndemandServiceModel favouriteModel = FavouriteOndemandServiceModel(
          section_id: provider.sectionId,
          service_id: provider.id,
          user_id: FireStoreUtils.getCurrentUid(),
          serviceAuthorId: provider.author,
        );
        FireStoreUtils.removeFavouriteOndemandService(favouriteModel);
        lstFav.removeWhere((item) => item.service_id == provider.id);
      } else {
        FavouriteOndemandServiceModel favouriteModel = FavouriteOndemandServiceModel(
          section_id: provider.sectionId,
          service_id: provider.id,
          user_id: FireStoreUtils.getCurrentUid(),
          serviceAuthorId: provider.author,
        );
        FireStoreUtils.setFavouriteOndemandSection(favouriteModel);
        lstFav.add(favouriteModel);
      }
    }
  }

  /// Get category by id safely from cached categories
  Future<CategoryModel?> getCategory(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return null;

    // Try to find category from cached list
    CategoryModel? cat = categories.firstWhereOrNull((element) => element.id == categoryId);

    // If not found, fetch from Firestore
    cat ??= await FireStoreUtils.getCategoryById(categoryId);

    return cat;
  }
}
