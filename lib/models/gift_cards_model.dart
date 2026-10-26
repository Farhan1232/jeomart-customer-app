
import 'package:cloud_firestore/cloud_firestore.dart';

class GiftCardsModel {
  Timestamp? createdAt;
  String? image;
  String? expiryDay;
  String? id;
  String? message;
  String? title;
  bool? isEnable;

  GiftCardsModel({this.createdAt, this.image, this.expiryDay, this.id, this.message, this.title, this.isEnable});

  GiftCardsModel.fromJson(Map<String, dynamic> json) {
    createdAt = json['createdAt'];
    image = json['image'];
    expiryDay = json['expiryDay'];
    id = json['id'];
    message = json['message'];
    title = json['title'];
    isEnable = json['isEnable'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['createdAt'] = createdAt;
    data['image'] = image;
    data['expiryDay'] = expiryDay;
    data['id'] = id;
    data['message'] = message;
    data['title'] = title;
    data['isEnable'] = isEnable;
    return data;
  }
}
