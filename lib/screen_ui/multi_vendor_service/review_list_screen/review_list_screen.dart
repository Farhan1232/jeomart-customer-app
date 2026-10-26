import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/review_list_controller.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/rating_model.dart';
import 'package:customer/models/review_attribute_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/responsive.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../controllers/theme_controller.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/widget/load_more_listener.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../service/fire_store_utils.dart';
import '../chat_screens/full_screen_image_viewer.dart';

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ReviewListController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text("Reviews".tr, textAlign: TextAlign.start, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : controller.ratingList.isEmpty
                  ? Constant.showEmptyView(message: "No Review found".tr)
                  : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: LoadMoreListener(
                      onLoadMore: controller.loadMoreReviews,
                      child: RefreshIndicator(
                        onRefresh: controller.refreshReviews,
                        child: ListView.builder(
                          itemCount: controller.ratingList.length + (controller.hasMoreReviews ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= controller.ratingList.length) {
                              return const LoadMoreIndicator();
                            }
                            RatingModel ratingModel = controller.ratingList[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Container(
                                decoration: ShapeDecoration(
                                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                  shape: RoundedRectangleBorder(side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200), borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ratingModel.uname.toString(), style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 18, fontFamily: AppThemeData.semiBold)),
                                      Visibility(
                                        visible: ratingModel.productId != null,
                                        child: FutureBuilder(
                                          future: FireStoreUtils.fireStore.collection(CollectionName.vendorProducts).doc(ratingModel.productId?.split('~').first).get(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return const Text('');
                                            } else {
                                              if (snapshot.hasError) {
                                                return const Text('');
                                              } else if (snapshot.data == null) {
                                                return const Text('');
                                              } else if (snapshot.data != null) {
                                                ProductModel model = ProductModel.fromJson(snapshot.data!.data()!);
                                                return Text(
                                                  '${'Rate for'.tr} - ${model.name ?? ''}',
                                                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold),
                                                );
                                              } else {
                                                return const Text('');
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      RatingBar.builder(
                                        ignoreGestures: true,
                                        initialRating: ratingModel.rating ?? 0.0,
                                        minRating: 1,
                                        direction: Axis.horizontal,
                                        itemCount: 5,
                                        itemSize: 18,
                                        itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        itemBuilder: (context, _) => const Icon(Icons.star, color: AppThemeData.warning300),
                                        unratedColor: AppThemeData.grey400,
                                        onRatingUpdate: (double rate) {},
                                      ),
                                      const SizedBox(height: 5),
                                      Visibility(
                                        visible: ratingModel.comment != '' && ratingModel.comment != null,
                                        child: Text(
                                          ratingModel.comment.toString(),
                                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.medium),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Visibility(
                                        visible: ratingModel.reviewAttributes != null,
                                        child: ListView.builder(
                                          itemCount: ratingModel.reviewAttributes!.length,
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemBuilder: (context, index) {
                                            String key = ratingModel.reviewAttributes!.keys.elementAt(index);
                                            dynamic value = ratingModel.reviewAttributes![key];
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                              child: Row(
                                                children: [
                                                  FutureBuilder(
                                                    future: FireStoreUtils.fireStore.collection(CollectionName.reviewAttributes).doc(key).get(),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                                        return const Text('');
                                                      } else {
                                                        if (snapshot.hasError) {
                                                          return const Text('');
                                                        } else if (snapshot.data == null) {
                                                          return const Text('');
                                                        } else {
                                                          ReviewAttributeModel model = ReviewAttributeModel.fromJson(snapshot.data!.data()!);
                                                          return Expanded(
                                                            child: Text(
                                                              model.title.toString(),
                                                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.semiBold),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                  ),
                                                  RatingBar.builder(
                                                    ignoreGestures: true,
                                                    initialRating: value == null ? 0.0 : value ?? 0.0,
                                                    minRating: 1,
                                                    direction: Axis.horizontal,
                                                    itemCount: 5,
                                                    itemSize: 15,
                                                    unratedColor: AppThemeData.grey400,
                                                    itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                                                    itemBuilder: (context, _) => const Icon(Icons.star, color: AppThemeData.warning300),
                                                    onRatingUpdate: (double rate) {},
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      if (ratingModel.photos?.isNotEmpty == true)
                                        SizedBox(
                                          height: Responsive.height(9, context),
                                          child: ListView.builder(
                                            itemCount: ratingModel.photos?.length,
                                            scrollDirection: Axis.horizontal,
                                            padding: EdgeInsets.zero,
                                            itemBuilder: (context, index) {
                                              return InkWell(
                                                onTap: () {
                                                  Get.to(FullScreenImageViewer(imageUrl: ratingModel.photos?[index]));
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(6.0),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: NetworkImageWidget(
                                                      imageUrl: ratingModel.photos?[index],
                                                      height: Responsive.height(9, context),
                                                      width: Responsive.height(8, context),
                                                      fit: BoxFit.fill,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      const SizedBox(height: 5),
                                      Text(
                                        Constant.timestampToDateTime(ratingModel.createdAt!),
                                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 14, fontFamily: AppThemeData.medium),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
        );
      },
    );
  }
}
