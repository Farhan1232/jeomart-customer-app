
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPlanModel {
  Timestamp? createdAt;
  String? description;
  String? expiryDay;
  Features? features;
  String? id;
  bool? isEnable;
  bool? isCommissionPlan;
  String? itemLimit;
  String? orderLimit;
  String? name;
  String? price;
  String? place;
  String? image;
  String? type;
  String? sectionId;
  List<String>? planPoints;

  SubscriptionPlanModel(
      {this.createdAt,
      this.description,
      this.expiryDay,
      this.features,
      this.id,
      this.isEnable,
      this.isCommissionPlan,
      this.itemLimit,
      this.orderLimit,
      this.name,
      this.price,
      this.place,
      this.image,
      this.type,
      this.sectionId,
      this.planPoints});

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      createdAt: json['createdAt'],
      description: json['description'],
      expiryDay: json['expiryDay'],
      features: json['features'] == null ? null : Features.fromJson(json['features']),
      id: json['id'],
      isEnable: json['isEnable'],
      isCommissionPlan: json['isCommissionPlan'],
      itemLimit: json['itemLimit'],
      orderLimit: json['orderLimit'],
      name: json['name'],
      price: json['price'],
      // place: json['place'],
      sectionId: json['sectionId'],
      image: json['image'],
      type: json['type'],
      planPoints: json['plan_points'] == null ? [] : List<String>.from(json['plan_points']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt,
      'description': description,
      'expiryDay': expiryDay.toString(),
      'features': features?.toJson(),
      'id': id,
      'isEnable': isEnable,
      'itemLimit': itemLimit.toString(),
      'orderLimit': orderLimit.toString(),
      'name': name,
      'price': price.toString(),
      'place': place.toString(),
      'image': image.toString(),
      'type': type,
      'sectionId': sectionId,
      'plan_points': planPoints
    };
  }
}

class Features {
  bool? chat;
  bool? qrCodeGenerate;
  bool? ownerMobileApp;
  bool? demo;

  Features({
    this.chat,
    this.qrCodeGenerate,
    this.ownerMobileApp,
    this.demo,
  });

  // Factory constructor to create an instance from JSON
  factory Features.fromJson(Map<String, dynamic> json) {
    return Features(
      chat: json['chat'] ?? false,
      qrCodeGenerate: json['qrCodeGenerate'] ?? false,
      ownerMobileApp: json['ownerMobileApp'] ?? false,
    );
  }

  // Method to convert an instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'chat': chat,
      'qrCodeGenerate': qrCodeGenerate,
      'ownerMobileApp': ownerMobileApp,
    };
  }
}
