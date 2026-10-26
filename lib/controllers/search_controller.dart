import 'package:customer/constant/constant.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../service/fire_store_utils.dart';
import '../utils/parallel.dart';
import 'package:get/get.dart';

class SearchScreenController extends GetxController {
  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxList<VendorModel> vendorList = <VendorModel>[].obs;
  RxList<VendorModel> vendorSearchList = <VendorModel>[].obs;

  RxList<ProductModel> productList = <ProductModel>[].obs;
  RxList<ProductModel> productSearchList = <ProductModel>[].obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      vendorList.value = argumentData['vendorList'];
      productList.clear();
    }
    isLoading.value = false;

    // One query per vendor, but no longer one *after* the other.
    //
    // This screen searches product names on the device, so it does have to hold
    // every vendor's products - that part is unchanged. What it used to do was
    // `await` each vendor's query inside a `for` loop, which on the live
    // project is 45 round trips in series before the product half of the search
    // works at all. The reads are independent, so they now overlap.
    //
    // `Parallel.map` keeps the results in vendor order, so the products are
    // appended in exactly the order the sequential loop appended them and the
    // subscription item-limit rule below is applied to precisely the same list.
    final List<List<ProductModel>?> perVendor = await Parallel.map<VendorModel, List<ProductModel>>(
      vendorList,
      (VendorModel vendor) => FireStoreUtils.getProductByVendorId(vendor.id.toString()),
    );

    for (int i = 0; i < vendorList.length; i++) {
      final VendorModel element = vendorList[i];
      final List<ProductModel> value = perVendor[i] ?? <ProductModel>[];
      if ((Constant.isSubscriptionModelApplied == true || element.adminCommission?.isEnabled == true) && element.subscriptionPlan != null) {
        if (element.subscriptionPlan?.itemLimit == '-1') {
          productList.addAll(value);
        } else {
          int selectedProduct = value.length < int.parse(element.subscriptionPlan?.itemLimit ?? '0') ? (value.isEmpty ? 0 : (value.length)) : int.parse(element.subscriptionPlan?.itemLimit ?? '0');
          productList.addAll(value.sublist(0, selectedProduct));
        }
      } else {
        productList.addAll(value);
      }
    }
  }

  void onSearchTextChanged(String text) {
    if (text.isEmpty) {
      return;
    }
    vendorSearchList.clear();
    productSearchList.clear();
    for (var element in vendorList) {
      if (element.title!.toLowerCase().contains(text.toLowerCase())) {
        vendorSearchList.add(element);
      }
    }

    for (var element in productList) {
      if (element.name!.toLowerCase().contains(text.toLowerCase())) {
        productSearchList.add(element);
      }
    }
  }

  @override
  void dispose() {
    vendorSearchList.clear();
    productSearchList.clear();
    super.dispose();
  }
}
