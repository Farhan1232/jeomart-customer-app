import 'package:customer/models/banner_model.dart';
import 'package:customer/utils/zone_selection.dart';
import 'package:customer/models/category_model.dart';
import 'package:customer/models/favorite_ondemand_service_model.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';
import '../constant/constant.dart';

class OnDemandHomeController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<BannerModel> bannerTopHome = <BannerModel>[].obs;
  RxList<CategoryModel> categories = <CategoryModel>[].obs;
  RxList<ProviderServiceModel> providerList = <ProviderServiceModel>[].obs;

  /// Store last fetched category
  Rx<CategoryModel?> categoryModel = Rx<CategoryModel?>(null);

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    isLoading.value = true;
    await getZone();

    // Fetch banners
    FireStoreUtils.getHomeTopBanner().then((value) {
      bannerTopHome.value = value;
    });

    // Fetch categories
    FireStoreUtils.getOnDemandCategory().then((catValue) {
      categories.value = catValue;
    });

    // Fetch provider services
    FireStoreUtils.getProviderFuture()
        .then((providerServiceList) {
          Set<String?> uniqueAuthorIds = providerServiceList.map((service) => service.author).toSet();
          List<String?> listOfUniqueProviders = uniqueAuthorIds.toList();

          List<ProviderServiceModel> filteredProviders = [];

          for (var provider in listOfUniqueProviders) {
            List<ProviderServiceModel> filteredList = providerServiceList.where((service) => service.author == provider).toList();

            filteredList.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

            for (int index = 0; index < filteredList.length; index++) {
              final service = filteredList[index];

              if (Constant.isSubscriptionModelApplied == true || Constant.sectionConstantModel?.adminCommision?.isEnabled == true) {
                if (service.subscriptionPlan?.itemLimit == "-1") {
                  filteredProviders.add(service);
                } else {
                  if (index < int.parse(service.subscriptionPlan?.itemLimit ?? '0')) {
                    filteredProviders.add(service);
                  }
                }
              } else {
                filteredProviders.add(service);
              }
            }
          }

          providerList.value = filteredProviders;
          isLoading.value = false;
        })
        .catchError((e) {
          print("Provider error: $e");
          isLoading.value = false;
        });

    FireStoreUtils.getFavouritesServiceList(FireStoreUtils.getCurrentUid()).then((favList) {
      lstFav.value = favList;
    });
  }

  /// Get category by id safely from cached categories
  Future<CategoryModel?> getCategory(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return null;

    // Try to find category from cached list
    CategoryModel? cat = categories.firstWhereOrNull((element) => element.id == categoryId);

    // If not found, fetch from Firestore
    cat ??= await FireStoreUtils.getCategoryById(categoryId);

    categoryModel.value = cat;
    return cat;
  }

  RxList<FavouriteOndemandServiceModel> lstFav = <FavouriteOndemandServiceModel>[].obs;

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

  Future<void> getZone() async {
    await FireStoreUtils.getZone().then((value) {
      // One shared rule - see [ZoneSelection]. A point that is inside no zone
      // used to leave the customer holding whichever zone came last in the list.
      ZoneSelection.apply(
        value,
        latitude: Constant.selectedLocation.location?.latitude,
        longitude: Constant.selectedLocation.location?.longitude,
      );
    });
  }
}
