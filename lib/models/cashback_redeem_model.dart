import 'package:cloud_firestore/cloud_firestore.dart';

class CashbackRedeemModel {
  final String? id;
  final String? cashbackId;
  final String? userId;
  final String? orderId;
  final Timestamp? createdAt;

  CashbackRedeemModel({
    this.id,
    this.cashbackId,
    this.userId,
    this.orderId,
    this.createdAt,
  });

  factory CashbackRedeemModel.fromJson(Map<String, dynamic> json) {
    return CashbackRedeemModel(
      id: json['id'],
      cashbackId: json['cashbackId'],
      userId: json['userId'],
      orderId: json['orderId'],
      createdAt: json['createdAt'] == null ? null : json['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cashbackId': cashbackId,
      'userId': userId,
      'orderId': orderId,
      'createdAt': createdAt,
    };
  }
}
