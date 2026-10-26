import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant/collection_name.dart';
import '../models/rating_model.dart';
import '../models/rental_order_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';
import '../constant/constant.dart';
import '../themes/show_toast_dialog.dart';

class RentalReviewController extends GetxController {
  RxBool isLoading = true.obs;

  /// Order from arguments
  final Rx<RentalOrderModel?> order = Rx<RentalOrderModel?>(null);

  /// Rating data
  final Rx<RatingModel?> ratingModel = Rx<RatingModel?>(null);
  final RxDouble ratings = 0.0.obs;
  final Rx<TextEditingController> comment = TextEditingController().obs;

  /// Driver (to be reviewed)
  final Rx<UserModel?> driverUser = Rx<UserModel?>(null);

  /// Review stats
  final RxInt futureCount = 0.obs;
  final RxInt futureSum = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args['order'] != null) {
      order.value = args['order'] as RentalOrderModel;
      getReview();
    }
  }

  /// Fetch old review + driver stats
  Future<void> getReview() async {
    await FireStoreUtils.getReviewsbyID(order.value?.id ?? "").then((value) {
      if (value != null) {
        ratingModel.value = value;
        ratings.value = value.rating ?? 0;
        comment.value.text = value.comment ?? "";
      }
    });

    await FireStoreUtils.getUserProfile(order.value?.driverId ?? '').then((value) {
      if (value != null) {
        driverUser.value = value;

        final int userReviewsCount = int.tryParse(driverUser.value!.reviewsCount?.toString() ?? "0") ?? 0;
        final int userReviewsSum = int.tryParse(driverUser.value!.reviewsSum?.toString() ?? "0") ?? 0;

        if (ratingModel.value != null) {
          final int oldRating = ratingModel.value?.rating?.toInt() ?? 0;
          futureCount.value = userReviewsCount - 1;
          futureSum.value = userReviewsSum - oldRating;
        } else {
          futureCount.value = userReviewsCount;
          futureSum.value = userReviewsSum;
        }
      }
    });

    isLoading.value = false;
  }

  /// Save / update review
  Future<void> submitReview() async {
    if (comment.value.text.trim().isEmpty || ratings.value == 0) {
      ShowToastDialog.showToast("Please provide rating and comment".tr);
      return;
    }

    ShowToastDialog.showLoader("Submit in...".tr);

    final user = await FireStoreUtils.getUserProfile(order.value?.driverId ?? '');

    if (user != null) {
      user.reviewsCount = (futureCount.value + 1).toString();
      user.reviewsSum = (futureSum.value + ratings.value.toInt()).toString();
    }
    if (ratingModel.value != null) {
      /// Update existing review
      final updatedRating = RatingModel(
        id: ratingModel.value!.id,
        comment: comment.value.text,
        photos: ratingModel.value?.photos ?? [],
        rating: ratings.value,
        orderId: ratingModel.value!.orderId,
        driverId: ratingModel.value!.driverId,
        customerId: ratingModel.value!.customerId,
        vendorId: ratingModel.value?.vendorId,
        uname: "${Constant.userModel?.firstName ?? ''} ${Constant.userModel?.lastName ?? ''}",
        profile: Constant.userModel?.profilePictureURL,
        createdAt: Timestamp.now(),
      );

      await FireStoreUtils.updateReviewById(updatedRating);
      if (user != null) {
        await FireStoreUtils.updateUser(user);
      }
    } else {
      /// New review
      final docRef = FireStoreUtils.fireStore.collection(CollectionName.itemsReview).doc();
      final newRating = RatingModel(
        id: docRef.id,
        comment: comment.value.text,
        photos: [],
        rating: ratings.value,
        orderId: order.value?.id,
        driverId: order.value?.driverId.toString(),
        customerId: Constant.userModel?.id,
        uname: "${Constant.userModel?.firstName ?? ''} ${Constant.userModel?.lastName ?? ''}",
        profile: Constant.userModel?.profilePictureURL,
        createdAt: Timestamp.now(),
      );

      await FireStoreUtils.updateReviewById(newRating);
      if (user != null) {
        await FireStoreUtils.updateUser(user);
      }
    }

    ShowToastDialog.closeLoader();
    Get.back(result: true);
  }

  @override
  void onClose() {
    comment.value.dispose();
    super.onClose();
  }
}
