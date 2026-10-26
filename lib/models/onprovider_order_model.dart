import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/provider_serivce_model.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';

class OnProviderOrderModel {
  String authorID, payment_method;
  UserModel author;
  Timestamp createdAt;
  String? sectionId;
  ProviderServiceModel provider;
  String status;
  ShippingAddress? address;
  String id;
  List<TaxModel>? taxModel;
  Timestamp? scheduleDateTime;
  Timestamp? newScheduleDateTime;
  Timestamp? startTime;
  Timestamp? endTime;
  String? notes;
  String? discount;
  String? discountType;
  String? discountLabel;
  String? couponCode;
  double quantity;
  String? reason;
  String? otp;
  String? adminCommission;
  String? adminCommissionType;
  String? extraCharges;
  String? extraChargesDescription;
  bool? paymentStatus;
  bool? extraPaymentStatus;
  String? workerId;
  String? platformFee;
  List<TaxModel>? platformTax;

  OnProviderOrderModel({
    this.sectionId = '',
    this.authorID = '',
    this.payment_method = '',
    author,
    createdAt,
    provider,
    this.status = '',
    this.address,
    this.id = '',
    this.taxModel,
    scheduleDateTime,
    this.newScheduleDateTime,
    this.startTime,
    this.endTime,
    this.notes = '',
    this.discount,
    this.discountType,
    this.discountLabel,
    this.couponCode,
    this.quantity = 0.0,
    this.reason,
    this.otp,
    this.adminCommission,
    this.adminCommissionType,
    this.extraCharges = '',
    this.extraChargesDescription = '',
    this.paymentStatus,
    this.extraPaymentStatus,
    this.workerId,
    this.platformFee,
    this.platformTax,
  }) : author = author ?? UserModel(),
       createdAt = createdAt ?? Timestamp.now(),
       provider = provider ?? ProviderServiceModel(),
       scheduleDateTime = scheduleDateTime ?? Timestamp.now();

  factory OnProviderOrderModel.fromJson(Map<String, dynamic> parsedJson) {
    List<TaxModel>? taxList;
    if (parsedJson['taxSetting'] != null) {
      taxList = <TaxModel>[];
      parsedJson['taxSetting'].forEach((v) {
        taxList!.add(TaxModel.fromJson(v));
      });
    }
    List<TaxModel>? platformTax;
    if (parsedJson['platformTax'] != null) {
      platformTax = <TaxModel>[];
      parsedJson['platformTax'].forEach((v) {
        platformTax!.add(TaxModel.fromJson(v));
      });
    }
    return OnProviderOrderModel(
      author: parsedJson.containsKey('author') ? UserModel.fromJson(parsedJson['author']) : UserModel(),
      authorID: parsedJson['authorID'] ?? '',
      address: parsedJson.containsKey('address') ? ShippingAddress.fromJson(parsedJson['address']) : ShippingAddress(),
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      id: parsedJson['id'] ?? '',
      payment_method: parsedJson['payment_method'] ?? '',
      taxModel: taxList,
      sectionId: parsedJson['sectionId'] ?? '',
      status: parsedJson['status'] ?? '',
      provider: parsedJson.containsKey('provider') ? ProviderServiceModel.fromJson(parsedJson['provider']) : ProviderServiceModel(),
      notes: parsedJson['notes'] ?? "",
      scheduleDateTime: parsedJson['scheduleDateTime'] ?? Timestamp.now(),
      newScheduleDateTime: parsedJson['newScheduleDateTime'],
      startTime: parsedJson['startTime'],
      endTime: parsedJson['endTime'],
      discount: parsedJson['discount'] ?? "0.0",
      discountLabel: parsedJson['discountLabel'] ?? "0.0",
      discountType: parsedJson['discountType'] ?? "",
      couponCode: parsedJson['couponCode'] ?? "",
      quantity: double.parse("${parsedJson['quantity'] ?? 0.0}"),
      reason: parsedJson['reason'] ?? '',
      otp: parsedJson['otp'] ?? '',
      adminCommission: parsedJson['adminCommission'] ?? "",
      adminCommissionType: parsedJson['adminCommissionType'] ?? "",
      extraCharges: parsedJson["extraCharges"] ?? "0.0",
      paymentStatus: parsedJson['paymentStatus'],
      extraPaymentStatus: parsedJson['extraPaymentStatus'],
      workerId: parsedJson['workerId'] ?? "",
      extraChargesDescription: parsedJson['extraChargesDescription'] ?? "",
      platformFee: parsedJson['platformFee'],
      platformTax: platformTax,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address?.toJson(),
      'author': author.toJson(),
      'authorID': authorID,
      'payment_method': payment_method,
      'createdAt': createdAt,
      'id': id,
      'status': status,
      'provider': provider.toJson(),
      'sectionId': sectionId,
      "taxSetting": taxModel?.map((v) => v.toJson()).toList(),
      "scheduleDateTime": scheduleDateTime,
      "newScheduleDateTime": newScheduleDateTime,
      "startTime": startTime,
      "endTime": endTime,
      "notes": notes,
      'discount': discount,
      "discountLabel": discountLabel,
      "discountType": discountType,
      "couponCode": couponCode,
      'quantity': quantity,
      'reason': reason,
      'otp': otp,
      "adminCommission": adminCommission,
      "adminCommissionType": adminCommissionType,
      'extraCharges': extraCharges,
      'paymentStatus': paymentStatus,
      'extraPaymentStatus': extraPaymentStatus,
      'workerId': workerId,
      'extraChargesDescription': extraChargesDescription,
      'platformFee': platformFee,
      'platformTax': platformTax?.map((v) => v.toJson()).toList(),
    };
  }
}
