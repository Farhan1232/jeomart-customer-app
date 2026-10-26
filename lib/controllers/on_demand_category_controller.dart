import 'package:get/get.dart';

import '../models/category_model.dart';
import '../service/fire_store_utils.dart';

class OnDemandCategoryController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<CategoryModel> categories = <CategoryModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchCategories();
  }

  void fetchCategories() async {
    try {
      isLoading.value = true;
      // Fetch categories
      FireStoreUtils.getOnDemandCategory().then((catValue) {
        categories.value = catValue;
      });
    } catch (e) {
      print("Error fetching categories: $e");
    } finally {
      isLoading.value = false;
    }
  }
}
