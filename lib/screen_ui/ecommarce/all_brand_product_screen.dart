import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/all_brand_product_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AllBrandProductScreen extends StatelessWidget {
  const AllBrandProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AllBrandProductController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface, centerTitle: false, titleSpacing: 0),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 20),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 3.5 / 6, crossAxisSpacing: 10),
                      padding: EdgeInsets.zero,
                      itemCount:  controller.productList.length,
                      itemBuilder: (context, index) {
                        ProductModel productModel = controller.productList[index];
                        return FutureBuilder(
                          future: FireStoreUtils.getVendorById(productModel.vendorID.toString()),
                          builder: (context, vendorSnapshot) {
                            if (!vendorSnapshot.hasData || vendorSnapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(); // Show placeholder or loader
                            }
                            VendorModel? vendorModel = vendorSnapshot.data;
                            String price = "0.0";
                            String disPrice = "0.0";
                            List<String> selectedVariants = [];
                            List<String> selectedIndexVariants = [];
                            List<String> selectedIndexArray = [];
                            if (productModel.itemAttribute != null) {
                              if (productModel.itemAttribute!.attributes!.isNotEmpty) {
                                for (var element in productModel.itemAttribute!.attributes!) {
                                  if (element.attributeOptions!.isNotEmpty) {
                                    selectedVariants.add(
                                      productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString(),
                                    );
                                    selectedIndexVariants.add(
                                      '${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}',
                                    );
                                    selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
                                  }
                                }
                              }

                              if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
                                price = Constant.productCommissionPrice(
                                  vendorModel!,
                                  productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0',
                                );
                                disPrice = "0";
                              }
                            } else {
                              price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
                              disPrice = double.parse(productModel.disPrice.toString()) <= 0 ? "0" : Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
                            }
                            return GestureDetector(
                              onTap: () async {
                                Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      height: 90,
                                      width: Responsive.width(100, context),
                                      child: NetworkImageWidget(imageUrl: productModel.photo.toString(), fit: BoxFit.cover),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productModel.name!.capitalizeString(),
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: AppThemeData.semiBoldTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark600 : AppThemeData.grey600),
                                      ),
                                      disPrice == "" || disPrice == "0"
                                          ? Text(Constant.amountShow(amount: price), style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: AppThemeData.primary300))
                                          : Row(
                                            children: [
                                              Text(
                                                Constant.amountShow(amount: price),
                                                style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                Constant.amountShow(amount: disPrice),
                                                style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                              ),
                                            ],
                                          ),
                                      Container(
                                        decoration: BoxDecoration(color: isDark ? AppThemeData.warning50 : AppThemeData.warning50, borderRadius: BorderRadius.circular(30)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.star, size: 18, color: AppThemeData.warning400),
                                              Text(
                                                "${Constant.calculateReview(reviewCount: productModel.reviewsCount.toString(), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsSum})",
                                                style: AppThemeData.semiBoldTextStyle(fontSize: 12, color: AppThemeData.warning400),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
        );
      },
    );
  }
}
