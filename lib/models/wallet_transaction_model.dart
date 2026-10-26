import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransactionModel {
  String? userId;
  String? paymentMethod;
  double? amount;
  bool? isTopup;
  String? orderId;
  String? paymentStatus;
  Timestamp? date;
  String? id;
  String? transactionUser;
  String? note;
  String? serviceType;

  WalletTransactionModel({
    this.userId,
    this.paymentMethod,
    this.amount,
    this.isTopup,
    this.orderId,
    this.paymentStatus,
    this.date,
    this.id,
    this.transactionUser,
    this.note,
    this.serviceType,
  });

  WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    paymentMethod = json['payment_method'];
    amount = double.parse("${json['amount'] ?? 0.0}");
    isTopup = json['isTopUp'];
    orderId = json['order_id'];
    paymentStatus = json['payment_status'];
    date = json['date'];
    transactionUser = json['transactionUser'] ?? 'customer';
    note = json['note'] ?? 'Wallet Top-up';
    serviceType = json['serviceType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['payment_method'] = paymentMethod;
    data['amount'] = amount;
    data['isTopUp'] = isTopup;
    data['order_id'] = orderId;
    data['payment_status'] = paymentStatus;
    data['date'] = date;
    data['transactionUser'] = transactionUser;
    data['note'] = note;
    return data;
  }
}
