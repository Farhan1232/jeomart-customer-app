import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/order_model.dart';
import '../service/cart_provider.dart';
import '../service/fire_store_utils.dart';
import '../utils/firestore_paginator.dart';
import 'package:get/get.dart';

class OrderController extends GetxController {
  /// Store order history is paged instead of fetching every order the customer
  /// has ever placed. The per-status lists below are still derived
  /// client-side, so no query - and no Firestore index - changes.
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, OrderModel>? ordersPaginator;

  /// Keeps the derived lists in sync with the loaded pages.
  Worker? _paginatorWorker;

  RxList<OrderModel> allList = <OrderModel>[].obs;
  RxList<OrderModel> inProgressList = <OrderModel>[].obs;
  RxList<OrderModel> deliveredList = <OrderModel>[].obs;
  RxList<OrderModel> rejectedList = <OrderModel>[].obs;
  RxList<OrderModel> cancelledList = <OrderModel>[].obs;

  RxBool isLoading = true.obs;

  /// Which tab the order screen is showing. Drives how far the paginator loads,
  /// so a tab is never left empty just because its orders are further down the
  /// history.
  RxInt selectedTabIndex = 0.obs;

  static const List<String> tabKeys = ["all", "inProgress", "delivered", "cancelled", "rejected"];

  bool get hasMoreOrders => ordersPaginator?.hasMore.value ?? false;

  bool _matchesTab(OrderModel order, String tab) {
    switch (tab) {
      case "all":
        return true;
      case "inProgress":
        return order.status == Constant.orderAccepted || order.status == Constant.driverPending || order.status == Constant.orderShipped || order.status == Constant.orderInTransit;
      case "delivered":
        return order.status == Constant.orderCompleted;
      case "cancelled":
        return order.status == Constant.orderCancelled;
      case "rejected":
        return order.status == Constant.orderRejected;
      default:
        return false;
    }
  }

  Future<void> onTabChanged(int index) async {
    selectedTabIndex.value = index;
    await ordersPaginator?.applyFilter((order) => _matchesTab(order, tabKeys[index]));
  }

  @override
  void onInit() {
    getOrder();
    super.onInit();
  }

  Future<void> getOrder() async {
    if (Constant.userModel != null) {
      ordersPaginator?.dispose();
      final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, OrderModel>(
        source: FirestorePageSource(FireStoreUtils.vendorOrdersQuery(), live: true),
        mapper: (doc) {
          final data = doc.data();
          if (data == null) return null;
          try {
            return OrderModel.fromJson(data);
          } catch (_) {
            return null;
          }
        },
        pageSize: 20,
        autoFillTarget: 10,
        filter: (order) => _matchesTab(order, tabKeys[selectedTabIndex.value]),
      );
      ordersPaginator = paginator;
      _paginatorWorker?.dispose();
      _paginatorWorker = ever<List<OrderModel>>(paginator.items, _splitByStatus);
      await paginator.refresh();
    }

    isLoading.value = false;
  }

  Future<void> loadMoreOrders() async {
    await ordersPaginator?.loadMore();
  }

  Future<void> refreshOrders() async {
    await ordersPaginator?.refresh();
  }

  void _splitByStatus(List<OrderModel> orders) {
    allList.value = orders;
    inProgressList.value = orders.where((p0) => _matchesTab(p0, "inProgress")).toList();
    deliveredList.value = orders.where((p0) => _matchesTab(p0, "delivered")).toList();
    cancelledList.value = orders.where((p0) => _matchesTab(p0, "cancelled")).toList();
    rejectedList.value = orders.where((p0) => _matchesTab(p0, "rejected")).toList();
  }

  final CartProvider cartProvider = CartProvider();

  void addToCart({required CartProductModel cartProductModel}) {
    cartProvider.addToCart(Get.context!, cartProductModel, cartProductModel.quantity!);
    update();
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
