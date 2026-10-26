import 'package:cloud_firestore/cloud_firestore.dart';

class GiftCardsOrderModel {
  String? price;
  Timestamp? expireDate;
  Timestamp? createdDate;
  String? message;
  String? id;
  String? giftId;
  String? giftTitle;
  String? giftCode;
  String? giftPin;
  bool? redeem;
  String? paymentType;
  String? userid;
  bool? isPasswordShow;

  GiftCardsOrderModel(
      {this.price, this.id, this.expireDate, this.createdDate, this.giftTitle, this.message, this.giftId, this.giftCode, this.giftPin, this.redeem, this.paymentType, this.userid});

  GiftCardsOrderModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    price = json['price'];
    expireDate = json['expireDate'];
    createdDate = json['createdDate'];
    giftTitle = json['giftTitle'];
    message = json['message'];
    giftId = json['giftId'];
    giftCode = json['giftCode'];
    giftPin = json['giftPin'];
    redeem = json['redeem'];
    paymentType = json['paymentType'];
    userid = json['userid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['price'] = price;
    data['expireDate'] = expireDate;
    data['createdDate'] = createdDate;
    data['message'] = message;
    data['giftId'] = giftId;
    data['giftTitle'] = giftTitle;
    data['giftCode'] = giftCode;
    data['giftPin'] = giftPin;
    data['redeem'] = redeem;
    data['paymentType'] = paymentType;
    data['userid'] = userid;
    return data;
  }
}
