import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';

class DineInBookingModel {
  String? discount;
  String? id;
  String? guestPhone;
  String? guestFirstName;
  String? status;
  UserModel? author;
  String? guestEmail;
  String? vendorID;
  String? occasion;
  String? authorID;
  String? specialRequest;
  Timestamp? date;
  String? totalGuest;
  VendorModel? vendor;
  bool? firstVisit;
  Timestamp? createdAt;
  String? guestLastName;
  String? discountType;

  DineInBookingModel(
      {this.discount,
      this.id,
      this.guestPhone,
      this.guestFirstName,
      this.status,
      this.author,
      this.guestEmail,
      this.vendorID,
      this.occasion,
      this.authorID,
      this.specialRequest,
      this.date,
      this.totalGuest,
      this.vendor,
      this.firstVisit,
      this.createdAt,
      this.guestLastName,
      this.discountType});

  DineInBookingModel.fromJson(Map<String, dynamic> json) {
    print(json['id']);
    discount = json['discount'];
    id = json['id'];
    guestPhone = json['guestPhone'];
    guestFirstName = json['guestFirstName'];
    status = json['status'];
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    guestEmail = json['guestEmail'];
    vendorID = json['vendorID'];
    occasion = json['occasion'];
    authorID = json['authorID'];
    specialRequest = json['specialRequest'];
    date = json['date'];
    totalGuest = json['totalGuest'].toString();
    vendor = json['vendor'] != null ? VendorModel.fromJson(json['vendor']) : null;
    firstVisit = json['firstVisit'];
    createdAt = json['createdAt'];
    guestLastName = json['guestLastName'];
    discountType = json['discountType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['discount'] = discount;
    data['id'] = id;
    data['guestPhone'] = guestPhone;
    data['guestFirstName'] = guestFirstName;
    data['status'] = status;
    if (author != null) {
      data['author'] = author!.toJson();
    }
    data['guestEmail'] = guestEmail;
    data['vendorID'] = vendorID;
    data['occasion'] = occasion;
    data['authorID'] = authorID;
    data['specialRequest'] = specialRequest;
    data['date'] = date;
    data['totalGuest'] = totalGuest;
    if (vendor != null) {
      data['vendor'] = vendor!.toJson();
    }
    data['firstVisit'] = firstVisit;
    data['createdAt'] = createdAt;
    data['guestLastName'] = guestLastName;
    data['discountType'] = discountType;
    return data;
  }
}
