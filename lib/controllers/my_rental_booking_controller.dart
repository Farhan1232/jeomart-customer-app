import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:get/get.dart';
import '../models/rental_order_model.dart';
import '../models/tax_model.dart';
import '../service/fire_store_utils.dart';
import '../utils/firestore_paginator.dart';

class MyRentalBookingController extends GetxController {
  RxBool isLoading = true.obs;

  RxString selectedTab = "New".obs;
  RxList<String> tabTitles = ["New", "On Going", "Completed", "Cancelled"].obs;

  /// Rental history is paged; the first page stays live so status changes
  /// still arrive immediately.
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, RentalOrderModel>? ordersPaginator;

  List<RentalOrderModel> get rentalOrders => ordersPaginator?.items ?? <RentalOrderModel>[];

  bool get hasMoreOrders => ordersPaginator?.hasMore.value ?? false;

  final RxString selectedPaymentMethod = ''.obs;

  /// Statuses per tab. Filtering stays client-side so the Firestore query, and
  /// the index behind it, is unchanged.
  static const Map<String, List<String>> tabStatuses = {
    "New": ["Order Placed", "Order Accepted", "Driver Pending"],
    "On Going": ["Driver Accepted", "Order Shipped", "In Transit"],
    "Completed": ["Order Completed"],
    "Cancelled": ["Order Rejected", "Order Cancelled", "Driver Rejected"],
  };

  bool Function(RentalOrderModel) _filterFor(String tab) {
    final statuses = tabStatuses[tab] ?? const <String>[];
    return (order) => statuses.contains(order.status);
  }

  @override
  void onInit() {
    super.onInit();
    listenRentalOrders();
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
  Future<void> listenRentalOrders() async {
    isLoading.value = true;
    ordersPaginator?.dispose();
    if (Constant.userModel != null) {
      final paginator = FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, RentalOrderModel>(
        source: FirestorePageSource(FireStoreUtils.rentalOrdersQuery(), live: true),
        mapper: (doc) {
          final data = doc.data();
          if (data == null) return null;
          try {
            return RentalOrderModel.fromJson(data);
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
    }
    isLoading.value = false;
  }

  Rx<RentalOrderModel> selectedOrder = RentalOrderModel().obs;
  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble extraKilometerCharge = 0.0.obs;
  RxDouble extraMinutesCharge = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;

  void calculateTotalAmount(RentalOrderModel order) {
    subTotal.value = 0.0;
    discount.value = 0.0;
    taxAmount.value = 0.0;
    totalAmount.value = 0.0;
    extraKilometerCharge.value = 0.0;
    extraMinutesCharge.value = 0.0;
    orderTaxAmount.value = 0;
    platformTaxAmount.value = 0;

    selectedOrder.value = order;
    try {
      subTotal.value = double.tryParse(selectedOrder.value.subTotal?.toString() ?? "0") ?? 0.0;
      discount.value = double.tryParse(selectedOrder.value.discount?.toString() ?? "0") ?? 0.0;
      taxAmount.value = 0.0;

      if (selectedOrder.value.endTime != null) {
        DateTime start = selectedOrder.value.startTime!.toDate();
        DateTime end = selectedOrder.value.endTime!.toDate();
        int hours = end.difference(start).inHours;
        if (hours >= int.parse(selectedOrder.value.rentalPackageModel!.includedHours.toString())) {
          hours = hours - int.parse(selectedOrder.value.rentalPackageModel!.includedHours.toString());
          double hourlyRate = double.tryParse(selectedOrder.value.rentalPackageModel?.extraMinuteFare?.toString() ?? "0") ?? 0.0;
          extraMinutesCharge.value = (hours * 60) * hourlyRate;
        }
      }

      if (selectedOrder.value.startKitoMetersReading != null && selectedOrder.value.endKitoMetersReading != null) {
        double startKm = double.tryParse(selectedOrder.value.startKitoMetersReading?.toString() ?? "0") ?? 0.0;
        double endKm = double.tryParse(selectedOrder.value.endKitoMetersReading?.toString() ?? "0") ?? 0.0;
        if (endKm > startKm) {
          double totalKm = endKm - startKm;
          if (totalKm > double.parse(selectedOrder.value.rentalPackageModel!.includedDistance!)) {
            totalKm = totalKm - double.parse(selectedOrder.value.rentalPackageModel!.includedDistance!);
            double extraKmRate = double.tryParse(selectedOrder.value.rentalPackageModel?.extraKmFare?.toString() ?? "0") ?? 0.0;
            extraKilometerCharge.value = totalKm * extraKmRate;
          }
        }
      }
      subTotal.value = subTotal.value + extraKilometerCharge.value + extraMinutesCharge.value;

      for (var taxElement in selectedOrder.value.taxSetting ?? []) {
        orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
      }

      /// ---------------- PLATFORM TAX ----------------
      if (double.parse(selectedOrder.value.platformFee ?? '0.0') > 0) {
        for (var taxElement in selectedOrder.value.platformTax ?? []) {
          platformTaxAmount.value += Constant.calculateTax(amount: selectedOrder.value.platformFee ?? '0.0', taxModel: taxElement);
        }
      }
      taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;
      totalAmount.value = (subTotal.value - discount.value) + double.parse(selectedOrder.value.platformFee!) + taxAmount.value;
    } catch (e) {
      ShowToastDialog.showToast("Failed to calculate total: $e");
    }
  }

  Future<void> completeOrder() async {
    if (selectedPaymentMethod.value == PaymentGateway.cod.name) {
      selectedOrder.value.paymentMethod = selectedPaymentMethod.value;
      await FireStoreUtils.rentalOrderPlace(selectedOrder.value).then((value) {
        ShowToastDialog.showToast("Payment method changed".tr);
        Get.back();
        Get.back();
      });
    } else {
      selectedOrder.value.paymentStatus = true;
      selectedOrder.value.paymentMethod = selectedPaymentMethod.value;
      if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
        WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: double.parse(totalAmount.toString()),
          date: Timestamp.now(),
          paymentMethod: PaymentGateway.wallet.name,
          transactionUser: "customer",
          userId: FireStoreUtils.getCurrentUid(),
          isTopup: false,
          orderId: selectedOrder.value.id,
          note: "Rental Amount debited".tr,
          paymentStatus: "success".tr,
          serviceType: Constant.parcelServiceType,
        );

        await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
          if (value == true) {
            await FireStoreUtils.updateUserWallet(amount: "-${totalAmount.value.toString()}", userId: FireStoreUtils.getCurrentUid());
          }
        });
      }

      await FireStoreUtils.rentalOrderPlace(selectedOrder.value).then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        Get.back();
        Get.back();
      });
    }
  }

  /// Return filtered list for a specific tab title
  List<RentalOrderModel> getOrdersForTab(String tab) {
    return rentalOrders.where(_filterFor(tab)).toList();
  }

  /// Old helper (optional)
  List<RentalOrderModel> get filteredRentalOrders => getOrdersForTab(selectedTab.value);

  Future<void> cancelRentalRequest(RentalOrderModel order, {List<TaxModel>? taxList}) async {
    try {
      isLoading.value = true;
      order.status = Constant.orderCancelled;
      await FireStoreUtils.rentalOrderPlace(order);

      listenRentalOrders();

      if (order.paymentMethod?.toLowerCase() != "cod") {
        double refundAmount = totalAmount.value;

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
          note: "Refund for cancelled booking".tr,
          paymentStatus: "success".tr,
          serviceType: Constant.parcelServiceType,
        );

        await FireStoreUtils.setWalletTransaction(walletTransaction);
        await FireStoreUtils.updateUserWallet(amount: refundAmount.toString(), userId: FireStoreUtils.getCurrentUid());
      }
      ShowToastDialog.showToast("Booking cancelled successfully".tr);
    } catch (e) {
      ShowToastDialog.showToast("Failed to cancel booking: $e".tr);
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
