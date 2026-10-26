import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import '../models/conversation_model.dart';
import '../models/inbox_model.dart';
import '../service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../service/send_notification.dart';
import '../utils/shared_order_chat.dart';

class ChatController extends GetxController {
  Rx<TextEditingController> messageController = TextEditingController().obs;

  Rx<ScrollController> scrollController = ScrollController().obs;

  @override
  void onInit() {
    // TODO: implement onInit

    getArgument();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxString orderId = "".obs;
  RxString senderId = "".obs;
  RxString senderName = "".obs;
  RxString senderProfileUrl = "".obs;
  RxString receivedId = "".obs;
  RxString receivedName = "".obs;
  RxString receivedProfileUrl = "".obs;
  RxString token = "".obs;
  RxString chatType = "".obs;

  /// What the chat header prints under the name. Empty means `Order #<id>`,
  /// which is what every existing caller gets; a driver-posted trip passes its
  /// own line instead.
  RxString subtitle = "".obs;
  UserModel? receiverUser;

  /// Set when this chat belongs to a store order: one conversation for the
  /// customer, the store and the driver. Null for every other chat.
  Rxn<SharedOrderChat> sharedChat = Rxn<SharedOrderChat>();
  Future<SharedOrderChat?>? _sharedChatLoad;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderId.value = argumentData['orderId'] ?? '';
      senderId.value = argumentData['senderId'] ?? '';
      senderName.value = argumentData['senderName'] ?? '';
      senderProfileUrl.value = argumentData['senderProfileUrl'] ?? "";
      receivedId.value = argumentData['receivedId'] ?? '';
      receivedName.value = argumentData['receivedName'] ?? '';
      receivedProfileUrl.value = argumentData['receivedProfileUrl'] ?? "";
      token.value = argumentData['token'] ?? '';
      chatType.value = argumentData['chatType'] ?? "";
      subtitle.value = argumentData['chatSubtitle']?.toString() ?? "";
      // Only a store or driver chat can be an order's; the lookup runs beside
      // the rest of the opening, not in front of it.
      if (chatType.value == Constant.userRoleVendor || chatType.value == Constant.userRoleDriver) {
        _sharedChatLoad = _loadSharedChat();
      }
      if (receivedId.value.isNotEmpty) {
        receiverUser = await FireStoreUtils.getUserForChat(receivedId.value);
      }
    }
    log("senderId :: ${senderId.value} :: receivedId :: ${receivedId.value}");

    setSeen();
    isLoading.value = false;
  }

  Future<SharedOrderChat?> _loadSharedChat() async {
    final SharedOrderChat? chat = await SharedOrderChat.load(orderId.value);
    if (!isClosed) sharedChat.value = chat;
    return chat;
  }

  Future<void> setSeen() async {
    FireStoreUtils.setSeenChatForOrder(orderId: orderId.value);
  }

  /// Scrolls the thread back to the newest message after one is sent.
  ///
  /// The list is `reverse: true`, so newest is `minScrollExtent`.
  ///
  /// The half second is the round trip the message needs before it exists in
  /// the list. It was a bare `Timer` at each of the four send sites, reading
  /// `scrollController.position` unconditionally when it fired - and `position`
  /// throws once the list it was attached to is gone, which is what a back
  /// press within that half second does. Asking `hasClients` first is the whole
  /// fix, and having it in one place is why it is here rather than in the four
  /// call sites.
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

  /// The controllers this screen owns are closed with it.
  ///
  /// They were never disposed here: `FirestorePagination` used to dispose the
  /// scroll controller it was handed, which is not its to dispose, and the text
  /// field's controller was simply leaked. Both belong to this controller and
  /// die with it.
  @override
  void onClose() {
    // `setSeen()` opens a live listener over this thread that marks every
    // incoming message read. Nothing ever stopped it: `stopSeenForOrderListener`
    // existed and had no callers, so each chat opened left one running against a
    // thread the customer had walked away from, marking messages read that they
    // never saw. Help & Support already stops its own in the same place.
    FireStoreUtils.stopSeenForOrderListener();
    _scrollTimer?.cancel();
    scrollController.value.dispose();
    messageController.value.dispose();
    super.onClose();
  }

  Future<void> sendMessage(String message, Url? url, String videoThumbnail, String messageType, ChatController controller) async {
    // Read before anything is awaited: the send button clears the field right
    // after calling this.
    final String typedText = messageController.value.text;
    SharedOrderChat? shared = sharedChat.value;
    if (shared == null && _sharedChatLoad != null) shared = await _sharedChatLoad;
    if (shared != null) {
      await shared.send(
        _orderMessage(message, url, videoThumbnail, messageType),
        senderRole: SharedOrderChat.customer,
        fallbackName: senderName.value,
        lastMessage: typedText,
        lastMessageType: messageType,
      );
      return;
    }

    List<String> senderReceiverId = [controller.senderId.value, controller.receivedId.value];
    InboxModel inboxModel = InboxModel(
      chatType: controller.chatType.value,
      senderReceiverId: senderReceiverId,
      lastSenderId: senderId.value,
      senderId: senderId.value,
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      orderId: orderId.value,
      lastMessage: typedText,
      lastMessageType: messageType,
      type: 'orderChat',
    );

    await FireStoreUtils.addInbox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: FireStoreUtils.getCurrentUid(),
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      url: url,
      orderId: orderId.value,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
    );

    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent a message".tr;
      } else if (url.mime.contains('video')) {
        conversationModel.message = "Sent a video".tr;
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a audio".tr;
      }
    }

    await FireStoreUtils.addChat(conversationModel);
    print("sendChatFcmMessage ::11:: ${receivedName.value} :: ${conversationModel.message} :: ${receiverUser?.fcmToken}");
    print("sendChatFcmMessage ::22:: ${inboxModel.type} :: ${inboxModel.chatType} :: $orderId :: ${conversationModel.senderId}");
    await SendNotification.sendChatFcmMessage(receivedName.value, conversationModel.message.toString(), receiverUser?.fcmToken ?? '', {
      'type': inboxModel.type,
      'chatType': inboxModel.chatType,
      'orderId': orderId,
      'senderId': conversationModel.senderId,
    });
  }

  /// A message for an order's shared chat, built the way [sendMessage] builds
  /// every other message.
  ConversationModel _orderMessage(String message, Url? url, String videoThumbnail, String messageType) {
    final ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: FireStoreUtils.getCurrentUid(),
      receiverId: receivedId.value,
      createdAt: Timestamp.now(),
      url: url,
      orderId: orderId.value,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      seen: false,
    );
    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "sent a message".tr;
      } else if (url.mime.contains('video')) {
        conversationModel.message = "Sent a video".tr;
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "Sent a audio".tr;
      }
    }
    return conversationModel;
  }

  final ImagePicker imagePicker = ImagePicker();

  // Future pickFile({required ImageSource source}) async {
  //   try {
  //     XFile? image = await imagePicker.pickImage(source: source);
  //     if (image == null) return;
  //     Url url = await FireStoreUtils.uploadChatImageToFireStorage(File(image.path), Get.context!);
  //     sendMessage('', url, '', 'image');
  //     Get.back();
  //   } on PlatformException catch (e) {
  //     ShowToastDialog.showToast("${"failed_to_pick".tr} : \n $e");
  //   }
  // }
}
