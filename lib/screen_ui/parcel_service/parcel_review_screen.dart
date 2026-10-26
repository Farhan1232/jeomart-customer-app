import 'package:customer/controllers/parcel_review_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../utils/network_image_widget.dart';

class ParcelReviewScreen extends StatelessWidget {
  const ParcelReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX<ParcelReviewController>(
      init: ParcelReviewController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            elevation: 0,
            backgroundColor: AppThemeData.primary300,
            leading: GestureDetector(onTap: () => Get.back(), child: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black)),
            title: Text(
              controller.ratingModel.value != null && controller.ratingModel.value!.id!.isNotEmpty ? "Update Review".tr : "Add Review".tr,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
            ),
          ),
          body: Obx(
            () =>
                controller.isLoading.value
                    ? Constant.loader()
                    : Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 20),
                            child: Card(
                              elevation: 2,
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 65),
                                  child: Column(
                                    children: [
                                      // Driver Name
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          controller.order.value!.driver?.fullName() ?? "",
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: AppThemeData.medium, fontSize: 18),
                                        ),
                                      ),
                                      // Car info
                                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.grey)),

                                      // Title
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Text('How is your trip?'.tr, style: TextStyle(fontSize: 18, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Your feedback will help us improve \n driving experience better'.tr,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: isDark ? Colors.white : Colors.black.withOpacity(0.60), letterSpacing: 0.8),
                                        ),
                                      ),

                                      // Rating
                                      Padding(
                                        padding: const EdgeInsets.only(top: 20),
                                        child: Text('Rate for'.tr, style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black.withOpacity(0.60), letterSpacing: 0.8)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          controller.order.value!.driver?.fullName() ?? "",
                                          style: TextStyle(fontSize: 18, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: RatingBar.builder(
                                          initialRating: controller.ratings.value,
                                          minRating: 1,
                                          direction: Axis.horizontal,
                                          allowHalfRating: true,
                                          itemCount: 5,
                                          itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                          unratedColor: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400,
                                          onRatingUpdate: (rating) => controller.ratings.value = rating,
                                        ),
                                      ),

                                      // Comment
                                      Padding(padding: const EdgeInsets.all(20.0), child: TextFieldWidget(hintText: "Type comment....".tr, controller: controller.comment.value, maxLine: 5)),

                                      // Submit Button
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: RoundedButtonFill(
                                          title: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
                                          color: AppThemeData.primary300,
                                          textColor: isDark ? Colors.white : Colors.black,
                                          onPress: controller.submitReview,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(60),
                                color: Colors.white,
                                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, spreadRadius: 6)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: NetworkImageWidget(imageUrl: controller.order.value?.driver?.profilePictureURL ?? '', fit: BoxFit.cover, height: 110, width: 110),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        );
      },
    );
  }
}
