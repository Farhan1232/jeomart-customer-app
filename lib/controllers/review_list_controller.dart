import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/rating_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../service/fire_store_utils.dart';
import '../utils/firestore_paginator.dart';
import 'package:get/get.dart';

class ReviewListController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<VendorModel> vendorModel = VendorModel().obs;
  RxList<RatingModel> ratingList = <RatingModel>[].obs;

  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, RatingModel>? reviewsPaginator;
  Worker? _paginatorWorker;

  bool get hasMoreReviews => reviewsPaginator?.hasMore.value ?? false;

  bool get isLoadingMore => reviewsPaginator?.isLoadingMore.value ?? false;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      vendorModel.value = argumentData['vendorModel'];
      getAllReview();
    }
    isLoading.value = false;
  }

  Future<void> getAllReview() async {
    reviewsPaginator?.dispose();
    final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, RatingModel>(
      source: FirestorePageSource(FireStoreUtils.vendorReviewsQuery(vendorModel.value.id.toString())),
      mapper: (doc) {
        final data = doc.data();
        if (data == null) return null;
        try {
          return RatingModel.fromJson(data);
        } catch (_) {
          return null;
        }
      },
      pageSize: 20,
    );
    reviewsPaginator = paginator;
    _paginatorWorker?.dispose();
    _paginatorWorker = ever<List<RatingModel>>(paginator.items, (items) {
      ratingList.value = items;
    });
    await paginator.refresh();
    update();
  }

  Future<void> loadMoreReviews() async {
    await reviewsPaginator?.loadMore();
  }

  Future<void> refreshReviews() async {
    await reviewsPaginator?.refresh();
  }

  @override
  void onClose() {
    _paginatorWorker?.dispose();
    _paginatorWorker = null;
    reviewsPaginator?.dispose();
    reviewsPaginator = null;
    super.onClose();
  }
}
