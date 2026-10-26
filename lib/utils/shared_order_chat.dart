import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/models/conversation_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/send_notification.dart';
import 'package:get/get.dart';

/// Someone taking part in an order's chat.
class OrderChatMember {
  OrderChatMember({required this.role, required this.id, this.name = '', this.token = ''});

  /// [SharedOrderChat.customer], [SharedOrderChat.store] or
  /// [SharedOrderChat.driver] - the same words `chatType` already uses.
  final String role;
  final String id;
  String name;
  String token;
}

/// One conversation per store order, shared by the customer, the store and the
/// driver.
///
/// The messages of an order were always kept in one place,
/// `chat/{orderId}/thread`: the customer's "chat with store" and "chat with
/// driver" buttons, the store's chat and the driver's chat all read and write
/// that same thread. What made it three separate chats was everything around
/// the thread - each message was pushed to one person only, the inbox entry
/// named two people and was rewritten by whoever wrote last (so the order left
/// the store's inbox as soon as the driver wrote), and nothing said who a
/// message came from.
///
/// This class supplies those pieces, for orders in `vendor_orders` only. A
/// ride, parcel, rental, service booking, trip or support chat is not an order
/// there, so [load] returns null for it and that chat works as it always did.
class SharedOrderChat {
  SharedOrderChat({required this.orderId, required this.members});

  static const String customer = 'customer';
  static const String store = 'vendor';
  static const String driver = 'driver';

  /// The second inbox entry of an order, the one the driver inboxes list.
  static const String driverInboxSuffix = '_driver';

  final String orderId;
  final List<OrderChatMember> members;

  /// Who takes part, read from the order document.
  ///
  /// Null - "not a shared chat, carry on as before" - when there is no order or
  /// fewer than two people are known. The driver joins once one has accepted:
  /// the dispatcher only offers an order (`Driver Pending`) and never writes
  /// `driverID`; accepting it does.
  static SharedOrderChat? fromOrder(String orderId, Map<String, dynamic>? order) {
    if (orderId.isEmpty || order == null) return null;
    final Map<String, dynamic>? author = _map(order['author']);
    final Map<String, dynamic>? vendor = _map(order['vendor']);
    final Map<String, dynamic>? driverData = _map(order['driver']);
    final String driverId = _text(order['driverID']);
    // The driver copied into the order is only trusted if it is the one on it.
    final bool driverMatches = _text(driverData?['id']) == driverId;

    final List<OrderChatMember> members = <OrderChatMember>[];
    void add(String role, String id, String name, String token) {
      if (id.isEmpty) return;
      members.add(OrderChatMember(role: role, id: id, name: name.trim(), token: token));
    }

    add(customer, _text(order['authorID']), _personName(author), _text(author?['fcmToken']));
    add(store, _text(vendor?['author']), _text(vendor?['title']), _text(vendor?['fcmToken']));
    add(driver, driverId, driverMatches ? _personName(driverData) : '', driverMatches ? _text(driverData?['fcmToken']) : '');

    if (members.length < 2) return null;
    return SharedOrderChat(orderId: orderId, members: members);
  }

  /// Reads the order and everyone's current device token.
  ///
  /// Null for anything that is not a store order, and on any failure - the
  /// chat then works exactly as it did before.
  static Future<SharedOrderChat?> load(String orderId) async {
    if (orderId.isEmpty) return null;
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderId).get();
      final SharedOrderChat? chat = fromOrder(orderId, doc.data());
      if (chat == null) return null;
      // A token copied into the order goes stale when someone signs in again;
      // the profile holds the live one.
      await Future.wait(
        chat.members.map((OrderChatMember member) async {
          final UserModel? user = await FireStoreUtils.getUserProfile(member.id);
          if (user == null) return;
          final String token = user.fcmToken ?? '';
          if (token.isNotEmpty) member.token = token;
          if (member.name.isEmpty) member.name = user.fullName().trim();
        }),
      );
      return chat;
    } catch (error) {
      log('SharedOrderChat.load($orderId) failed :: $error');
      return null;
    }
  }

  OrderChatMember? memberWithRole(String role) => members.firstWhereOrNull((OrderChatMember m) => m.role == role);

  OrderChatMember? memberWithId(String id) => id.isEmpty ? null : members.firstWhereOrNull((OrderChatMember m) => m.id == id);

  static String roleLabel(String role) {
    switch (role) {
      case customer:
        return 'Customer'.tr;
      case store:
        return 'Store'.tr;
      case driver:
        return 'Driver'.tr;
    }
    return '';
  }

  static String _displayName(OrderChatMember member) => member.name.isNotEmpty ? member.name : roleLabel(member.role);

  /// The chat header seen by [role]: everyone else in the chat.
  String titleFor(String role) => members.where((OrderChatMember m) => m.role != role).map(_displayName).join(', ');

  /// The small line over someone else's message, e.g. "Ali Khan · Driver".
  ///
  /// Messages sent by these builds carry `senderName` and `senderRole`. Older
  /// messages, and messages from phones still on an older build, are matched
  /// to a member by `senderId`. Empty when the sender cannot be placed.
  String labelFor(Map<String, dynamic>? message) {
    if (message == null) return '';
    final OrderChatMember? member = memberWithId(_text(message['senderId']));
    String role = _text(message['senderRole']);
    if (role.isEmpty) role = member?.role ?? '';
    final String roleText = roleLabel(role);
    if (roleText.isEmpty) return '';
    String name = _text(message['senderName']).trim();
    if (name.isEmpty) name = member?.name ?? '';
    return name.isEmpty ? roleText : '$name · $roleText';
  }

  /// The name [role] sends under: the store's name for the store.
  String nameFor(String role, {String fallback = ''}) {
    final String name = memberWithRole(role)?.name ?? '';
    return name.isNotEmpty ? name : fallback.trim();
  }

  /// The inbox entries of this order after a message from [senderId].
  ///
  /// Every inbox list filters on a single `chatType` - the store's list and the
  /// customer's store list on `vendor`, the driver's list and the customer's
  /// driver list on `driver` - so one entry can never be in all of them. The
  /// order keeps its usual entry, `chat/{orderId}`, as the store one, and gets
  /// a second, `chat/{orderId}_driver`, for the driver lists. Both open the
  /// same thread, because an inbox row opens the entry's `orderId`, not the
  /// entry's id. Each keeps the customer and the other party in the slots the
  /// old entries used, so every row still shows the person it showed before,
  /// and each lists all members.
  Map<String, Map<String, dynamic>> inboxEntries({
    required String senderId,
    required String lastMessage,
    required String lastMessageType,
    required Timestamp createdAt,
  }) {
    final List<String> ids = members.map((OrderChatMember m) => m.id).toSet().toList();
    final String customerId = memberWithRole(customer)?.id ?? senderId;

    Map<String, dynamic> entry(String chatType, OrderChatMember other) => <String, dynamic>{
      'senderId': customerId,
      'lastMessage': lastMessage,
      'orderId': orderId,
      'receiverId': other.id,
      'lastSenderId': senderId,
      'createdAt': createdAt,
      'chatType': chatType,
      'lastMessageType': lastMessageType,
      'sender_receiver_id': ids,
      'type': 'orderChat',
    };

    final Map<String, Map<String, dynamic>> entries = <String, Map<String, dynamic>>{};
    final OrderChatMember? storeMember = memberWithRole(store);
    final OrderChatMember? driverMember = memberWithRole(driver);
    if (storeMember != null) entries[orderId] = entry(store, storeMember);
    if (driverMember != null) entries['$orderId$driverInboxSuffix'] = entry(driver, driverMember);
    return entries;
  }

  /// Everyone told about a message from [role]: the others with a device
  /// token, once per device.
  List<OrderChatMember> recipientsFor(String role) {
    final Set<String> tokens = <String>{};
    return members.where((OrderChatMember m) => m.role != role && m.token.isNotEmpty && tokens.add(m.token)).toList();
  }

  /// What a tap on the notification needs. The customer app opens its store or
  /// its driver inbox by `chatType`, so the customer is sent the sender's role;
  /// the store and the driver apps get their own.
  Map<String, dynamic> payloadFor(OrderChatMember to, {required String senderId, required String senderRole}) => <String, dynamic>{
    'type': 'orderChat',
    'chatType': to.role == customer ? senderRole : to.role,
    'orderId': orderId,
    'senderId': senderId,
  };

  /// Saves [message] in the order's thread, keeps every inbox entry current and
  /// tells the other members.
  Future<void> send(
    ConversationModel message, {
    required String senderRole,
    required String fallbackName,
    required String lastMessage,
    required String lastMessageType,
  }) async {
    final String senderId = message.senderId ?? '';
    final String name = nameFor(senderRole, fallback: fallbackName);
    final CollectionReference<Map<String, dynamic>> chat = FireStoreUtils.fireStore.collection(CollectionName.chat);

    await chat.doc(orderId).collection('thread').doc(message.id).set(<String, dynamic>{...message.toJson(), 'senderName': name, 'senderRole': senderRole});

    final Map<String, Map<String, dynamic>> entries = inboxEntries(
      senderId: senderId,
      lastMessage: lastMessage,
      lastMessageType: lastMessageType,
      createdAt: message.createdAt ?? Timestamp.now(),
    );
    await Future.wait(entries.entries.map((MapEntry<String, Map<String, dynamic>> e) => chat.doc(e.key).set(e.value)));

    final String roleText = roleLabel(senderRole);
    final String title = name.isEmpty ? roleText : '$name ($roleText)';
    for (final OrderChatMember to in recipientsFor(senderRole)) {
      unawaited(SendNotification.sendChatFcmMessage(title, message.message ?? '', to.token, payloadFor(to, senderId: senderId, senderRole: senderRole)));
    }
  }

  static String _text(Object? raw) => raw?.toString() ?? '';

  static Map<String, dynamic>? _map(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : null;

  static String _personName(Map<String, dynamic>? person) {
    if (person == null) return '';
    return '${_text(person['firstName'])} ${_text(person['lastName'])}'.trim();
  }
}
