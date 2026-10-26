import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/search_controller.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/text_field_widget.dart';
import '../../../controllers/theme_controller.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../../../widget/restaurant_image_view.dart';
import '../restaurant_details_screen/restaurant_details_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: SearchScreenController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              Constant.sectionConstantModel?.name?.toLowerCase().contains('restaurants') == true ? "Find your favorite products and nearby stores" : "Search Item & Store".tr,
              textAlign: TextAlign.start,
              style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(55),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFieldWidget(
                  hintText: Constant.sectionConstantModel?.name?.toLowerCase().contains('restaurants') == true ? 'Find your favorite products and nearby stores'.tr : 'Search the store and item'.tr,
                  prefix: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SvgPicture.asset("assets/icons/ic_search.svg")),
                  controller: null,
                  onchange: (value) {
                    controller.onSearchTextChanged(value);
                  },
                ),
              ),
            ),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          controller.vendorSearchList.isEmpty
                              ? const SizedBox()
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Store".tr,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                  ),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                                ],
                              ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.vendorSearchList.length,
                            itemBuilder: (context, index) {
                              VendorModel vendorModel = controller.vendorSearchList[index];
                              return InkWell(
                                onTap: () {
                                  Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": vendorModel});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Container(
                                    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                              child: Stack(
                                                children: [
                                                  RestaurantImageView(vendorModel: vendorModel),
                                                  Container(
                                                    height: Responsive.height(20, context),
                                                    width: Responsive.width(100, context),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: const Alignment(-0.00, -1.00),
                                                        end: const Alignment(0, 1),
                                                        colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Transform.translate(
                                              offset: Offset(Responsive.width(-3, context), Responsive.height(17.5, context)),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Visibility(
                                                    visible: (vendorModel.isSelfDelivery == true && Constant.isSelfDeliveryFeature == true),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                          decoration: BoxDecoration(
                                                            color: AppThemeData.success300,
                                                            borderRadius: BorderRadius.circular(120), // Optional
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              SvgPicture.asset("assets/icons/ic_free_delivery.svg"),
                                                              const SizedBox(width: 5),
                                                              Text(
                                                                "Free Delivery".tr,
                                                                style: TextStyle(fontSize: 14, color: AppThemeData.success300, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                    decoration: ShapeDecoration(
                                                      color: isDark ? AppThemeData.primary600 : AppThemeData.primary50,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: ColorFilter.mode(AppThemeData.primary300, BlendMode.srcIn)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          "${Constant.calculateReview(reviewCount: vendorModel.reviewsCount!.toStringAsFixed(0), reviewSum: vendorModel.reviewsSum.toString())} (${vendorModel.reviewsCount!.toStringAsFixed(0)})",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                                            fontFamily: AppThemeData.semiBold,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                    decoration: ShapeDecoration(
                                                      color: isDark ? AppThemeData.ecommerce600 : AppThemeData.ecommerce50,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        SvgPicture.asset("assets/icons/ic_map_distance.svg", colorFilter: ColorFilter.mode(AppThemeData.ecommerce300, BlendMode.srcIn)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          "${Constant.getDistance(lat1: vendorModel.latitude.toString(), lng1: vendorModel.longitude.toString(), lat2: Constant.selectedLocation.location!.latitude.toString(), lng2: Constant.selectedLocation.location!.longitude.toString())} ${Constant.distanceType}",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: isDark ? AppThemeData.ecommerce300 : AppThemeData.ecommerce300,
                                                            fontFamily: AppThemeData.semiBold,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                vendorModel.title.toString(),
                                                textAlign: TextAlign.start,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  overflow: TextOverflow.ellipsis,
                                                  fontFamily: AppThemeData.semiBold,
                                                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                ),
                                              ),
                                              Text(
                                                vendorModel.location.toString(),
                                                textAlign: TextAlign.start,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  overflow: TextOverflow.ellipsis,
                                                  fontFamily: AppThemeData.medium,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? AppThemeData.grey400 : AppThemeData.grey400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          controller.productSearchList.isEmpty
                              ? const SizedBox()
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Items".tr,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                  ),
                                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                                ],
                              ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.productSearchList.length,
                            itemBuilder: (context, index) {
                              ProductModel productModel = controller.productSearchList[index];
                              return FutureBuilder(
                                future: getPrice(productModel),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Constant.loader();
                                  } else {
                                    if (snapshot.hasError) {
                                      return Center(child: Text('Error: ${snapshot.error}'));
                                    } else if (snapshot.data == null) {
                                      return const SizedBox();
                                    } else {
                                      Map<String, dynamic> map = snapshot.data!;
                                      String price = map['price'];
                                      String disPrice = map['disPrice'];
                                      return InkWell(
                                        onTap: () async {
                                          await FireStoreUtils.getVendorById(productModel.vendorID.toString()).then((value) {
                                            if (value != null) {
                                              Get.to(const RestaurantDetailsScreen(), arguments: {"vendorModel": value});
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 20),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Constant.sectionConstantModel!.isProductDetails == false
                                                        ? SizedBox()
                                                        : productModel.nonveg == true || productModel.veg == true
                                                        ? Row(
                                                          children: [
                                                            productModel.nonveg == true ? SvgPicture.asset("assets/icons/ic_nonveg.svg") : SvgPicture.asset("assets/icons/ic_veg.svg"),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              productModel.nonveg == true ? "Non Veg.".tr : "Pure veg.".tr,
                                                              style: TextStyle(
                                                                color: productModel.nonveg == true ? AppThemeData.danger300 : AppThemeData.success400,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                        : SizedBox(),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      productModel.name.toString(),
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                        fontFamily: AppThemeData.semiBold,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    double.parse(disPrice) <= 0
                                                        ? Text(
                                                          Constant.amountShow(amount: price),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                            fontFamily: AppThemeData.semiBold,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        )
                                                        : Row(
                                                          children: [
                                                            Text(
                                                              Constant.amountShow(amount: disPrice),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              Constant.amountShow(amount: price),
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                decoration: TextDecoration.lineThrough,
                                                                decorationColor: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                                color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                    Row(
                                                      children: [
                                                        SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: const ColorFilter.mode(AppThemeData.warning300, BlendMode.srcIn)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          "${Constant.calculateReview(reviewCount: productModel.reviewsCount!.toStringAsFixed(0), reviewSum: productModel.reviewsSum.toString())} (${productModel.reviewsCount!.toStringAsFixed(0)})",
                                                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      "${productModel.description}",
                                                      maxLines: 2,
                                                      style: TextStyle(
                                                        overflow: TextOverflow.ellipsis,
                                                        color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                        fontFamily: AppThemeData.regular,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ClipRRect(
                                                borderRadius: const BorderRadius.all(Radius.circular(16)),
                                                child: Stack(
                                                  children: [
                                                    NetworkImageWidget(
                                                      imageUrl: productModel.photo.toString(),
                                                      fit: BoxFit.cover,
                                                      height: Responsive.height(16, context),
                                                      width: Responsive.width(34, context),
                                                    ),
                                                    Container(
                                                      height: Responsive.height(16, context),
                                                      width: Responsive.width(34, context),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin: const Alignment(-0.00, -1.00),
                                                          end: const Alignment(0, 1),
                                                          colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> getPrice(ProductModel productModel) async {
    String price = "0.0";
    String disPrice = "0.0";
    List<String> selectedVariants = [];
    List<String> selectedIndexVariants = [];
    List<String> selectedIndexArray = [];

    print("=======>");
    print(productModel.price);
    print(productModel.disPrice);

    VendorModel? vendorModel = await FireStoreUtils.getVendorById(productModel.vendorID.toString());
    if (productModel.itemAttribute != null) {
      if (productModel.itemAttribute!.attributes!.isNotEmpty) {
        for (var element in productModel.itemAttribute!.attributes!) {
          if (element.attributeOptions!.isNotEmpty) {
            selectedVariants.add(productModel.itemAttribute!.attributes![productModel.itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString());
            selectedIndexVariants.add('${productModel.itemAttribute!.attributes!.indexOf(element)} _${productModel.itemAttribute!.attributes![0].attributeOptions![0].toString()}');
            selectedIndexArray.add('${productModel.itemAttribute!.attributes!.indexOf(element)}_0');
          }
        }
      }
      if (productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
        price = Constant.productCommissionPrice(vendorModel!, productModel.itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0');
        disPrice = Constant.productCommissionPrice(vendorModel, '0');
      }
    } else {
      price = Constant.productCommissionPrice(vendorModel!, productModel.price.toString());
      disPrice = Constant.productCommissionPrice(vendorModel, productModel.disPrice.toString());
    }

    return {'price': price, 'disPrice': disPrice};
  }
}
