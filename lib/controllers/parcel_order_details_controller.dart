import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/rating_model.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../constant/constant.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';

class ParcelOrderDetailsController extends GetxController {
  Rx<ParcelOrderModel> parcelOrder = ParcelOrderModel().obs;
  RxList<ParcelCategory> parcelCategory = <ParcelCategory>[].obs;
  RxBool isLoading = false.obs;

  Rx<UserModel?> driverUser = Rx<UserModel?>(null);
  Rx<RatingModel> ratingModel = RatingModel().obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is ParcelOrderModel) {
      parcelOrder.value = args;
      setStatusHistoryFromString(parcelOrder.value);
    }
    loadParcelCategories();
    calculateTotalAmount();
    fetchDriverDetails();
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;

  void calculateTotalAmount() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    orderTaxAmount.value = 0;
    platformTaxAmount.value = 0;
    subTotal.value = double.parse(parcelOrder.value.subTotal.toString());
    discount.value = double.parse(parcelOrder.value.discount ?? '0.0');

    /// ---------------- ORDER TAX ----------------
    for (var taxElement in parcelOrder.value.taxSetting ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

    /// ---------------- PLATFORM TAX ----------------
    if (double.parse(parcelOrder.value.platformFee ?? '0.0') > 0) {
      for (var taxElement in parcelOrder.value.platformTax ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: parcelOrder.value.platformFee ?? '0.0', taxModel: taxElement);
      }
    }

    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;

    totalAmount.value = (subTotal.value - discount.value) + double.parse(parcelOrder.value.platformFee ?? '0.0') + taxAmount.value;
    update();
  }

  Future<void> fetchDriverDetails() async {
    if (parcelOrder.value.driverId != null) {
      await FireStoreUtils.getUserProfile(parcelOrder.value.driverId ?? '').then((value) {
        if (value != null) {
          driverUser.value = value;
        }
      });

      await FireStoreUtils.getReviewsbyID(parcelOrder.value.id.toString()).then((value) {
        if (value != null) {
          ratingModel.value = value;
        }
      });
    }
  }

  void setStatusHistoryFromString(ParcelOrderModel order) {
    final steps = ["Order Placed", "Driver Accepted", "Pickup Done", "In Transit", "Delivered"];

    final history = <ParcelStatus>[];

    DateTime baseTime = order.createdAt?.toDate() ?? DateTime.now();
    int minutesGap = 30;

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];

      history.add(ParcelStatus(status: step, time: baseTime.add(Duration(minutes: i * minutesGap))));

      if (step == order.status) break;
    }

    order.statusHistory = history;
  }

  Future<void> cancelParcelOrder() async {
    ShowToastDialog.showLoader("Cancelling order...".tr);
    parcelOrder.value.status = Constant.orderCancelled;
    if (parcelOrder.value.paymentMethod?.toLowerCase() != "cod") {
      WalletTransactionModel walletTransaction = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: totalAmount.value,
        date: Timestamp.now(),
        paymentMethod: PaymentGateway.wallet.name,
        transactionUser: "customer",
        userId: FireStoreUtils.getCurrentUid(),
        isTopup: true,
        orderId: parcelOrder.value.id,
        note: "Refund for cancelled parcel order",
        paymentStatus: "success",
        serviceType: Constant.parcelServiceType,
      );

      // Save wallet transaction
      await FireStoreUtils.setWalletTransaction(walletTransaction);

      // Update wallet balance
      await FireStoreUtils.updateUserWallet(amount: totalAmount.value.toString(), userId: FireStoreUtils.getCurrentUid());
    }

    await FireStoreUtils.parcelOrderPlace(parcelOrder.value);
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Order cancelled successfully".tr);
    Get.back(result: true);
  }

  void loadParcelCategories() async {
    isLoading.value = true;
    final categories = await FireStoreUtils.getParcelServiceCategory();
    parcelCategory.value = categories;
    isLoading.value = false;
  }

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  ParcelCategory? getSelectedCategory() {
    try {
      return parcelCategory.firstWhere((cat) => cat.title?.toLowerCase().trim() == parcelOrder.value.parcelType?.toLowerCase().trim(), orElse: () => ParcelCategory());
    } catch (e) {
      return null;
    }
  }
}
