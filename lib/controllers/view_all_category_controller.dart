import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_category_model.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class ViewAllCategoryController extends GetxController {
  RxBool isLoading = true.obs;

  RxList<VendorCategoryModel> vendorCategoryModel = <VendorCategoryModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getCategoryData();
    super.onInit();
  }

  Future<void> getCategoryData() async {
    await FireStoreUtils.getVendorCategory().then((value) {
      vendorCategoryModel.value = value;

    });

    if (Constant.restaurantList != null) {
      List<String> usedCategoryIds = Constant.restaurantList!.expand((vendor) => vendor.categoryID ?? []).whereType<String>().toSet().toList();
      vendorCategoryModel.value = vendorCategoryModel.where((category) => usedCategoryIds.contains(category.id)).toList();
    }

    isLoading.value = false;
  }
}
