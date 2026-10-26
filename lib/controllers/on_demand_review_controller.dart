import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant/collection_name.dart';
import '../models/onprovider_order_model.dart';
import '../models/provider_serivce_model.dart';
import '../models/rating_model.dart';
import '../models/worker_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';
import '../constant/constant.dart';
import '../themes/show_toast_dialog.dart';

class OnDemandReviewController extends GetxController {
  final Rxn<OnProviderOrderModel> order = Rxn<OnProviderOrderModel>();
  final RxString reviewFor = "".obs;
  final Rxn<RatingModel> ratingModel = Rxn<RatingModel>();
  final RxDouble ratings = 0.0.obs;
  final TextEditingController comment = TextEditingController();

  final Rxn<UserModel> provider = Rxn<UserModel>();
  final Rxn<ProviderServiceModel> providerServiceModel = Rxn<ProviderServiceModel>();
  final Rxn<WorkerModel> workerModel = Rxn<WorkerModel>();

  final RxInt providerReviewCount = 0.obs;
  final RxDouble providerReviewSum = 0.0.obs;
  final RxInt serviceReviewCount = 0.obs;
  final RxDouble serviceReviewSum = 0.0.obs;
  final RxInt workerReviewCount = 0.obs;
  final RxDouble workerReviewSum = 0.0.obs;

  final FirebaseFirestore firestore = FireStoreUtils.fireStore;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null) {
      order.value = args['order'];
      reviewFor.value = args['reviewFor'];
      getReview();
    }
  }

  void getReview() async {
    // Get existing rating
    if (reviewFor.value == "Provider") {
      RatingModel? value = await FireStoreUtils.getReviewsByProviderID(order.value!.id, order.value!.provider.author.toString());
      if (value != null) {
        ratingModel.value = value;
        ratings.value = value.rating ?? 0.0;
        comment.text = value.comment ?? '';
      }
    } else {
      RatingModel? value = await FireStoreUtils.getReviewsByWorkerID(order.value!.id, order.value!.workerId.toString());
      if (value != null) {
        ratingModel.value = value;
        ratings.value = value.rating ?? 0.0;
        comment.text = value.comment ?? '';
      }
    }

    // Worker review logic
    if (reviewFor.value == "Worker") {
      WorkerModel? value = await FireStoreUtils.getWorker(order.value!.workerId.toString());
      if (value != null) {
        workerModel.value = value;

        final int existingCount = (value.reviewsCount ?? 0).toInt();
        final double existingSum = (value.reviewsSum ?? 0.0).toDouble();
        final double oldRating = ratingModel.value?.rating ?? 0.0;

        workerReviewCount.value = ratingModel.value != null ? (existingCount - 1) : existingCount;
        workerReviewSum.value = ratingModel.value != null ? (existingSum - oldRating) : existingSum;
      }
    }
    // Provider & service review logic
    else {
      UserModel? user = await FireStoreUtils.getUserProfile(order.value!.provider.author.toString());
      if (user != null) {
        provider.value = user;

        final int existingCount = int.tryParse(user.reviewsCount?.toString() ?? '0') ?? 0;
        final double existingSum = double.tryParse(user.reviewsSum?.toString() ?? '0.0') ?? 0.0;
        final double oldRating = ratingModel.value?.rating ?? 0.0;

        providerReviewCount.value = ratingModel.value != null ? (existingCount - 1) : existingCount;
        providerReviewSum.value = ratingModel.value != null ? (existingSum - oldRating) : existingSum;
      }

      ProviderServiceModel? service = await FireStoreUtils.getCurrentProvider(order.value!.provider.id.toString());
      if (service != null) {
        providerServiceModel.value = service;

        final int existingCount = (service.reviewsCount ?? 0).toInt();
        final double existingSum = (service.reviewsSum ?? 0.0).toDouble();
        final double oldRating = ratingModel.value?.rating ?? 0.0;

        serviceReviewCount.value = ratingModel.value != null ? (existingCount - 1) : existingCount;
        serviceReviewSum.value = ratingModel.value != null ? (existingSum - oldRating) : existingSum;
      }
    }
  }

  void submitReview() async {
    if (reviewFor.value == "Provider") {
      await _providerReviewSubmit();
    } else {
      await _workerReviewSubmit();
    }
  }

  Future<void> _providerReviewSubmit() async {
    ShowToastDialog.showLoader("Submit in...".tr);
    providerServiceModel.value!.reviewsCount = serviceReviewCount.value + 1;
    providerServiceModel.value!.reviewsSum = serviceReviewSum.value + ratings.value;

    // Convert to string only if your model field is String
    provider.value!.reviewsCount = (providerReviewCount.value + 1).toString();
    provider.value!.reviewsSum = (providerReviewSum.value + ratings.value).toString();

    RatingModel rate = RatingModel(
      id: ratingModel.value?.id ?? firestore.collection(CollectionName.itemsReview).doc().id,
      productId: ratingModel.value?.productId ?? order.value!.provider.id,
      comment: comment.text,
      photos: ratingModel.value?.photos ?? [],
      rating: ratings.value,
      orderId: ratingModel.value?.orderId ?? order.value!.id,
      vendorId: ratingModel.value?.vendorId ?? order.value!.provider.author.toString(),
      customerId: Constant.userModel?.id,
      uname: '${Constant.userModel?.firstName ?? ''} ${Constant.userModel?.lastName ?? ''}',
      profile: Constant.userModel?.profilePictureURL,
      createdAt: Timestamp.now(),
    );

    await FireStoreUtils.updateReviewById(rate);
    await FireStoreUtils.updateUser(provider.value!);
    await FireStoreUtils.updateProvider(providerServiceModel.value!);

    ShowToastDialog.closeLoader();
    Get.back(result: true);
  }

  Future<void> _workerReviewSubmit() async {
    ShowToastDialog.showLoader("Submit in...".tr);
    workerModel.value!.reviewsCount = workerReviewCount.value + 1;
    workerModel.value!.reviewsSum = workerReviewSum.value + ratings.value;

    RatingModel rate = RatingModel(
      id: ratingModel.value?.id ?? firestore.collection(CollectionName.itemsReview).doc().id,
      productId: ratingModel.value?.productId ?? order.value!.provider.id,
      comment: comment.text,
      photos: ratingModel.value?.photos ?? [],
      rating: ratings.value,
      orderId: ratingModel.value?.orderId ?? order.value!.id,
      driverId: ratingModel.value?.driverId ?? order.value!.workerId.toString(),
      customerId: Constant.userModel?.id,
      uname: '${Constant.userModel?.firstName ?? ''} ${Constant.userModel?.lastName ?? ''}',
      profile: Constant.userModel?.profilePictureURL,
      createdAt: Timestamp.now(),
    );

    await FireStoreUtils.updateReviewById(rate);
    await FireStoreUtils.updateWorker(workerModel.value!);

    ShowToastDialog.closeLoader();
    Get.back(result: true);
  }
}
