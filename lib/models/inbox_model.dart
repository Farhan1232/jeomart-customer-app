import 'package:cloud_firestore/cloud_firestore.dart';

class InboxModel {
  String? senderId;
  String? receiverId;
  String? lastMessage;
  String? lastSenderId;
  String? orderId;
  Timestamp? createdAt;
  String? chatType;
  String? lastMessageType;
  String? type;
  List<String>? senderReceiverId;

  InboxModel({this.senderId, this.lastMessage, this.orderId, this.receiverId, this.lastSenderId, this.createdAt, this.chatType, this.lastMessageType, this.type, this.senderReceiverId});

  factory InboxModel.fromJson(Map<String, dynamic> parsedJson) {
    return InboxModel(
      senderId: parsedJson['senderId'] ?? '',
      lastMessage: parsedJson['lastMessage'],
      orderId: parsedJson['orderId'],
      receiverId: parsedJson['receiverId'] ?? '',
      lastSenderId: parsedJson['lastSenderId'] ?? '',
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      chatType: parsedJson['chatType'] ?? '',
      lastMessageType: parsedJson['lastMessageType'],
      senderReceiverId: List<String>.from(parsedJson['sender_receiver_id'] ?? []),
      type: parsedJson['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'lastMessage': lastMessage,
      'orderId': orderId,
      'receiverId': receiverId,
      'lastSenderId': lastSenderId,
      'createdAt': createdAt,
      if (chatType != null) 'chatType': chatType,
      'lastMessageType': lastMessageType,
      'sender_receiver_id': senderReceiverId,
      'type': type,
    };
  }
}
