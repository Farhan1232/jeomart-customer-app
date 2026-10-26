import 'package:customer/utils/parallel.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:get/get.dart';

class AllBrandProductController extends GetxController {
  RxList<ProductModel> productList = <ProductModel>[].obs;
  Rx<BrandsModel> brandModel = BrandsModel().obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArguments();
    super.onInit();
  }

  Future<void> getArguments() async {
    final arguments = Get.arguments;
    if (arguments != null) {
      brandModel.value = arguments['brandModel'];
      await getProductByCategoryId();
    }
    isLoading.value = false;
  }

  Future<void> getProductByCategoryId() async {
    List<ProductModel> productDataList = await FireStoreUtils.getProductListByBrandId(brandModel.value.id.toString());

    List<VendorModel> vendorList = await FireStoreUtils.getAllStoresFuture(ecommarce: true);
    List<ProductModel> allProduct = <ProductModel>[];

    // One product query per store, fetched together rather than one after
    // another. On the live project that is 45 stores, so this loop used to be
    // 45 network round trips laid end to end before a single brand product
    // could be shown.
    //
    // The loop below is untouched - it just reads the answers out of this map
    // instead of awaiting each one in turn, so the subscription item-limit rule
    // is applied to exactly the same lists in exactly the same order.
    final Map<String, List<ProductModel>> productsByVendor = <String, List<ProductModel>>{};
    await Parallel.map<VendorModel, void>(vendorList, (VendorModel vendor) async {
      productsByVendor[vendor.id.toString()] = await FireStoreUtils.getAllProducts(vendor.id.toString());
      return null;
    });

    for (var vendor in vendorList) {
      await Future<List<ProductModel>>.value(productsByVendor[vendor.id.toString()] ?? <ProductModel>[]).then((value) {
        if (Constant.isSubscriptionModelApplied == true || vendor.adminCommission?.isEnabled == true) {
          if (vendor.subscriptionPlan != null && Constant.isExpire(vendor) == false) {
            if (vendor.subscriptionPlan?.itemLimit == '-1') {
              allProduct.addAll(value);
            } else {
              int selectedProduct = value.length < int.parse(vendor.subscriptionPlan?.itemLimit ?? '0') ? (value.isEmpty ? 0 : (value.length)) : int.parse(vendor.subscriptionPlan?.itemLimit ?? '0');
              allProduct.addAll(value.sublist(0, selectedProduct));
            }
          }
        } else {
          allProduct.addAll(value);
        }
      });
    }
    for (var element in productDataList) {
      final bool productIsInList = allProduct.any((product) => product.id == element.id);
      if (productIsInList) {
        productList.add(element);
      }
    }
  }
}
