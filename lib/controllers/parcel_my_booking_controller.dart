import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constant/constant.dart';
import '../models/parcel_order_model.dart';
import '../models/wallet_transaction_model.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../service/fire_store_utils.dart';
import '../utils/firestore_paginator.dart';
import '../themes/show_toast_dialog.dart';

class ParcelMyBookingController extends GetxController {
  RxBool isLoading = true.obs;

  RxString selectedTab = "New".obs;
  RxList<String> tabTitles = ["New", "In Transit", "Delivered", "Cancelled"].obs;

  /// Parcel history is paged instead of streaming the whole collection. The
  /// first page stays live so status changes still arrive immediately.
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, ParcelOrderModel>? ordersPaginator;

  List<ParcelOrderModel> get parcelOrder => ordersPaginator?.items ?? <ParcelOrderModel>[];

  bool get hasMoreOrders => ordersPaginator?.hasMore.value ?? false;

  /// Statuses per tab. Filtering stays client-side, so the Firestore query -
  /// and the index behind it - is unchanged.
  static const Map<String, List<String>> tabStatuses = {
    "New": ["Order Placed"],
    "In Transit": ["Order Accepted", "Driver Accepted", "Driver Pending", "Order Shipped", "In Transit"],
    "Delivered": ["Order Completed"],
    "Cancelled": ["Order Rejected", "Order Cancelled", "Driver Rejected"],
  };

  bool Function(ParcelOrderModel) _filterFor(String tab) {
    final statuses = tabStatuses[tab] ?? const <String>[];
    return (order) => statuses.contains(order.status);
  }

  @override
  void onInit() {
    super.onInit();
    listenParcelOrders();
  }

  Future<void> selectTab(String tab) async {
    selectedTab.value = tab;
    await ordersPaginator?.applyFilter(_filterFor(tab));
  }

  Future<void> loadMoreOrders() async {
    await ordersPaginator?.loadMore();
  }

  Future<void> refreshOrders() async {
    await ordersPaginator?.refresh();
  }

  /// Loads the first page and keeps it live; older pages arrive on scroll.
  Future<void> listenParcelOrders() async {
    isLoading.value = true;
    if (Constant.userModel == null) {
      isLoading.value = false;
      return;
    }
    ordersPaginator?.dispose();
    final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, ParcelOrderModel>(
      source: FirestorePageSource(FireStoreUtils.parcelOrdersQuery(), live: true),
      mapper: (doc) {
        final data = doc.data();
        if (data == null) return null;
        try {
          return ParcelOrderModel.fromJson(data);
        } catch (_) {
          return null;
        }
      },
      pageSize: 20,
      autoFillTarget: 10,
      filter: _filterFor(selectedTab.value),
    );
    ordersPaginator = paginator;
    await paginator.refresh();
    isLoading.value = false;
  }

  /// Return filtered list for a specific tab title
  List<ParcelOrderModel> getOrdersForTab(String tab) {
    return parcelOrder.where(_filterFor(tab)).toList();
  }

  /// Old helper (optional)
  List<ParcelOrderModel> get filteredParcelOrders => getOrdersForTab(selectedTab.value);

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  Future<void> cancelParcelOrder(ParcelOrderModel order) async {
    try {
      isLoading.value = true;

      if (order.status != Constant.orderPlaced) {
        ShowToastDialog.showToast("You can only cancel before pickup.".tr);
        return;
      }

      order.status = Constant.orderCancelled;
      await FireStoreUtils.parcelOrderPlace(order);

      listenParcelOrders();

      if (order.paymentMethod?.toLowerCase() != "cod") {
        double totalTax = 0.0;

        final taxSettings = order.taxSetting ?? [];

        for (var element in taxSettings) {
          totalTax += Constant.calculateTax(amount: (double.parse(order.subTotal.toString()) - double.parse(order.discount.toString())).toString(), taxModel: element);
        }

        double subTotal = double.parse(order.subTotal.toString()) - double.parse(order.discount.toString());
        double refundAmount = subTotal + totalTax;

        WalletTransactionModel walletTransaction = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: refundAmount,
          date: Timestamp.now(),
          paymentMethod: PaymentGateway.wallet.name,
          transactionUser: "customer",
          userId: FireStoreUtils.getCurrentUid(),
          isTopup: true,
          // refund
          orderId: order.id,
          note: "Refund for cancelled parcel order",
          paymentStatus: "success",
          serviceType: Constant.parcelServiceType,
        );

        // Save wallet transaction
        await FireStoreUtils.setWalletTransaction(walletTransaction);

        // Update wallet balance
        await FireStoreUtils.updateUserWallet(amount: refundAmount.toString(), userId: FireStoreUtils.getCurrentUid());
      }

      ShowToastDialog.showToast("Order cancelled successfully".tr);
    } catch (e) {
      ShowToastDialog.showToast("${'Failed to cancel order:'.tr} $e".tr);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    ordersPaginator?.dispose();
    ordersPaginator = null;
    super.onClose();
  }
}
