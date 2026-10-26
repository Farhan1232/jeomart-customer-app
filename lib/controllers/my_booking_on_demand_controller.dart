import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/onprovider_order_model.dart';
import '../models/worker_model.dart';
import '../service/fire_store_utils.dart';
import '../utils/firestore_paginator.dart';

class MyBookingOnDemandController extends GetxController {
  RxBool isLoading = true.obs;

  RxString selectedTab = "Placed".obs;
  RxMap<String, WorkerModel> workers = <String, WorkerModel>{}.obs;

  RxList<String> tabTitles = ["Placed", "Completed", "Cancelled"].obs;

  /// Booking history is paged instead of streaming the whole collection. The
  /// first page stays live so status changes still arrive immediately.
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, OnProviderOrderModel>? ordersPaginator;

  /// Keeps the derived lists in sync with the loaded pages.
  Worker? _paginatorWorker;

  List<OnProviderOrderModel> get orders => ordersPaginator?.items ?? <OnProviderOrderModel>[];

  bool get hasMoreOrders => ordersPaginator?.hasMore.value ?? false;

  /// Statuses per tab. Filtering stays client-side so the Firestore query, and
  /// the index behind it, is unchanged.
  static const Map<String, List<String>> tabStatuses = {
    "Placed": ["Order Placed", "Order Accepted", "Order Assigned", "Order Ongoing", "In Transit"],
    "Completed": ["Order Completed"],
    "Cancelled": ["Order Rejected", "Order Cancelled", "Driver Rejected"],
  };

  bool Function(OnProviderOrderModel) _filterFor(String tab) {
    final statuses = tabStatuses[tab] ?? const <String>[];
    return (order) => statuses.contains(order.status);
  }

  /// Worker ids already requested, so a rebuild or a live update never asks
  /// Firestore for the same worker twice.
  final Set<String> _requestedWorkerIds = <String>{};

  @override
  void onInit() {
    super.onInit();
    listenOrders();
  }

  Future<void> selectTab(String tab) async {
    selectedTab.value = tab;
    await ordersPaginator?.applyFilter(_filterFor(tab));
  }

  Future<void> loadMoreOrders() async {
    await ordersPaginator?.loadMore();
  }

  Future<void> refreshOrders() async {
    _requestedWorkerIds.clear();
    await ordersPaginator?.refresh();
  }

  /// Loads the first page and keeps it live; older pages arrive on scroll.
  Future<void> listenOrders() async {
    isLoading.value = true;
    ordersPaginator?.dispose();

    final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, OnProviderOrderModel>(
      source: FirestorePageSource(FireStoreUtils.providerOrdersQuery(), live: true),
      mapper: (doc) {
        final data = doc.data();
        if (data == null) return null;
        try {
          return OnProviderOrderModel.fromJson(data);
        } catch (_) {
          return null;
        }
      },
      pageSize: 20,
      autoFillTarget: 10,
      filter: _filterFor(selectedTab.value),
    );
    ordersPaginator = paginator;

    // Fetch each referenced worker at most once, no matter how often the live
    // first page re-delivers or the list rebuilds.
    _paginatorWorker?.dispose();
    _paginatorWorker = ever<List<OnProviderOrderModel>>(paginator.items, _loadMissingWorkers);

    await paginator.refresh();
    isLoading.value = false;
  }

  void _loadMissingWorkers(List<OnProviderOrderModel> loadedOrders) {
    for (final order in loadedOrders) {
      final workerId = order.workerId;
      if (workerId == null || workerId.isEmpty) continue;
      if (!_requestedWorkerIds.add(workerId)) continue;
      FireStoreUtils.getWorker(workerId).then((worker) {
        if (worker != null) workers[workerId] = worker;
      });
    }
  }

  List<OnProviderOrderModel> get filteredParcelOrders => getOrdersForTab(selectedTab.value);

  List<OnProviderOrderModel> getOrdersForTab(String tab) {
    return orders.where(_filterFor(tab)).toList();
  }

  WorkerModel? getWorker(String? workerId) {
    if (workerId == null || workerId.isEmpty) return null;
    return workers[workerId];
  }

  @override
  void onClose() {
    _paginatorWorker?.dispose();
    _paginatorWorker = null;
    ordersPaginator?.dispose();
    ordersPaginator = null;
    super.onClose();
  }
}
