import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/favorite_ondemand_service_model.dart';
import '../models/provider_serivce_model.dart';
import '../models/rating_model.dart';
import '../service/fire_store_utils.dart';

class OnDemandDetailsController extends GetxController {
  late ProviderServiceModel provider;

  final Rxn<UserModel> userModel = Rxn<UserModel>();
  final RxString subCategoryTitle = ''.obs;
  final RxString categoryTitle = ''.obs;
  final RxList<RatingModel> ratingService = <RatingModel>[].obs;
  final RxList<FavouriteOndemandServiceModel> lstFav = <FavouriteOndemandServiceModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isOpen = false.obs;
  final RxString tabString = "About".obs;

  @override
  void onInit() {
    super.onInit();
    provider = Get.arguments['providerModel'];
    timeCheck();
    getData();
  }


  Future<void> getData() async {
    await getReviewList();
    await getAuthor(); //fetch and set provider author here
    if (Constant.userModel != null) {
      lstFav.value = await FireStoreUtils.getFavouritesServiceList(FireStoreUtils.getCurrentUid());
    }
    isLoading.value = false;
  }

  Future<void> getReviewList() async {
    await FireStoreUtils.getCategoryById(provider.categoryId.toString()).then((value) {
      if (value != null) {
        categoryTitle.value = value.title.toString();
      }
    });

    await FireStoreUtils.getSubCategoryById(provider.subCategoryId.toString()).then((value) {
      if (value != null) {
        subCategoryTitle.value = value.title.toString();
      }
    });

    await FireStoreUtils.getReviewByProviderServiceId(provider.id.toString()).then((value) {
      ratingService.value = value;
    });

    if (Constant.userModel != null) {
      await FireStoreUtils.getFavouritesServiceList(FireStoreUtils.getCurrentUid()).then((value) {
        lstFav.value = value;
      });
    }
  }

  Future<void> getAuthor() async {
    final authorId = provider.author?.toString();
    if (authorId != null && authorId.isNotEmpty) {
      final user = await FireStoreUtils.getUserProfile(authorId);
      if (user != null) {
        userModel.value = user;
      }
    }
  }

  void timeCheck() {
    final now = DateTime.now();
    final day = DateFormat('EEEE', 'en_US').format(now);
    final date = DateFormat('dd-MM-yyyy').format(now);

    for (var element in provider.days) {
      if (day == element.toString()) {
        final start = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${provider.startTime}");
        final end = DateFormat("dd-MM-yyyy HH:mm").parse("$date ${provider.endTime}");
        if (isCurrentDateInRange(start, end)) {
          isOpen.value = true;
        }
      }
    }
  }

  bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    final currentDate = DateTime.now();
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  void changeTab(String tab) {
    tabString.value = tab;
  }
}


