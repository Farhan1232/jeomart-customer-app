import 'dart:async';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/conversation_model.dart';
import 'package:customer/models/inbox_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HelpSupportController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;
  Rx<UserModel> userModel = UserModel().obs;
  Rx<ScrollController> scrollController = ScrollController().obs;

  @override
  void onInit() {
    setSeen();
    setPref();
    super.onInit();
  }

  @override
  void onClose() {
    FireStoreUtils.stopSeenListener();
    _scrollTimer?.cancel();
    scrollController.value.dispose();
    messageController.value.dispose();
    super.onClose();
  }

  /// Scrolls the thread back to the newest message after one is sent.
  ///
  /// Same guard, and for the same reason, as the chat screen's: `position`
  /// throws once the list is gone, and the half-second wait outlives a back
  /// press. This controller now owns its scroll controller outright, because
  /// `FirestorePagination` no longer disposes one it was handed.
  Timer? _scrollTimer;

  void scrollToLatest() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 500), () {
      if (isClosed) return;
      final ScrollController scroll = scrollController.value;
      if (!scroll.hasClients) return;
      scroll.jumpTo(scroll.position.minScrollExtent);
    });
  }

  Future<void> setPref() async {
    await Preferences.setBoolean(Preferences.isClickOnNotification, false);
  }

  Future<void> setSeen() async {
    FireStoreUtils.setSeen();
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value?.id != null) {
        userModel.value = value!;
      }
    });
  }

  Future<void> sendMessage({required String message, Url? url, required String videoThumbnail, required String messageType}) async {
    List<String> senderReceiverId = [userModel.value.id!, 'admin'];
    InboxModel inboxModel = InboxModel(
      senderReceiverId: senderReceiverId,
      chatType: Constant.userRoleCustomer,
      lastSenderId: userModel.value.id,
      senderId: userModel.value.id,
      receiverId: 'admin',
      createdAt: Timestamp.now(),
      orderId: null,
      lastMessage: messageController.value.text,
      lastMessageType: messageType,
      type: 'adminchat',
    );

    await FireStoreUtils.addInbox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: FireStoreUtils.getCurrentUid(),
      receiverId: Constant.adminType,
      createdAt: Timestamp.now(),
      url: url,
      orderId: null,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
    );

    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent an image";
      } else if (url.mime.contains('video')) {
        conversationModel.message = "sent an Video";
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a voice message";
      }
    }

    await FireStoreUtils.addChat(conversationModel);
    scrollToLatest();
  }
}
