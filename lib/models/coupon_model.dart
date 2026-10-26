import 'package:cloud_firestore/cloud_firestore.dart';

class CouponModel {
  String? discountType;
  String? id;
  String? code;
  String? discount;
  String? image;
  Timestamp? expiresAt;
  Timestamp? createdAt;
  String? description;
  String? sectionId;
  bool? isPublic;
  String? vendorID;
  bool? isEnabled;

  CouponModel({this.discountType, this.id, this.code, this.discount, this.image, this.expiresAt, this.description, this.isPublic, this.vendorID, this.isEnabled,this.createdAt,this.sectionId});

  CouponModel.fromJson(Map<String, dynamic> json) {
    discountType = json['discountType'];
    id = json['id'];
    code = json['code'];
    discount = json['discount'];
    image = json['image'];
    expiresAt = json['expiresAt'];
    description = json['description'];
    isPublic = json['isPublic'];
    vendorID = json['vendorID'];
    isEnabled = json['isEnabled'];
    createdAt = json['createdAt'];
    sectionId = json['section_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['discountType'] = discountType;
    data['id'] = id;
    data['code'] = code;
    data['discount'] = discount;
    data['image'] = image;
    data['expiresAt'] = expiresAt;
    data['description'] = description;
    data['isPublic'] = isPublic;
    data['vendorID'] = vendorID;
    data['isEnabled'] = isEnabled;
    data['createdAt'] = createdAt;
    data['section_id'] = sectionId;
    return data;
  }
}
