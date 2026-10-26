import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import '../../constant/constant.dart';
import '../../controllers/on_demand_review_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/app_them_data.dart';
import '../../themes/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../utils/network_image_widget.dart';

class OnDemandReviewScreen extends StatelessWidget {
  const OnDemandReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetBuilder<OnDemandReviewController>(
      init: OnDemandReviewController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppThemeData.primary300,
            title: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppThemeData.grey50),
                      child: Center(child: Padding(padding: const EdgeInsets.only(left: 5), child: Icon(Icons.arrow_back_ios, color: AppThemeData.grey900, size: 20))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900)),
                ],
              ),
            ),
          ),
          body: Obx(
            () =>
                (controller.reviewFor.value == "Worker" && controller.workerModel.value == null) || (controller.reviewFor.value == "Provider" && controller.provider.value == null)
                    ? Constant.loader()
                    : Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20, top: 42, bottom: 20),
                            child: Card(
                              elevation: 2,
                              color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 65),
                                  child: Column(
                                    children: [
                                      Text('Rate for'.tr, style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900)),
                                      Text(
                                        controller.reviewFor.value == "Provider" ? controller.order.value!.provider.authorName ?? "" : controller.workerModel.value!.fullName(),
                                        style: AppThemeData.mediumTextStyle(fontSize: 18, color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey900),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: RatingBar.builder(
                                          initialRating: controller.ratings.value,
                                          minRating: 1,
                                          direction: Axis.horizontal,
                                          allowHalfRating: true,
                                          itemCount: 5,
                                          itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                                          unratedColor: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400,
                                          onRatingUpdate: (rating) {
                                            controller.ratings.value = rating;
                                          },
                                        ),
                                      ),
                                      Padding(padding: EdgeInsets.all(20.0), child: TextFieldWidget(hintText: "Type comment....".tr, controller: controller.comment, maxLine: 5)),
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: RoundedButtonFill(
                                          title: controller.ratingModel.value != null ? "Update Review".tr : "Add Review".tr,
                                          color: AppThemeData.primary300,
                                          textColor: AppThemeData.grey50,
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: NetworkImageWidget(
                                imageUrl: controller.reviewFor.value == "Provider" ? controller.order.value?.provider.authorProfilePic ?? '' : controller.workerModel.value?.profilePictureURL ?? '',
                                fit: BoxFit.cover,
                                height: 100,
                                width: 100,
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
