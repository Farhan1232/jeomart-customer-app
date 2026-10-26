import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

class AllCategoryProductController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<VendorCategoryModel> categoryModel = VendorCategoryModel().obs;
  RxList<ProductModel> productList = <ProductModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArguments();
    super.onInit();
  }

  Future<void> getArguments() async {
    final arguments = Get.arguments;
    if (arguments != null) {
      categoryModel.value = arguments['categoryModel'];
      await getProductByCategoryId();
    }
    isLoading.value = false;
  }

  Future<void> getProductByCategoryId() async {
    productList.value = await FireStoreUtils.getProductListByCategoryId(categoryModel.value.id.toString());
  }
}
