import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/inbox_model.dart';
import 'package:customer/utils/shared_order_chat.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 51 - one chat per store order for the customer, the store and the
/// driver.
///
/// The messages were already in one thread, `chat/{orderId}/thread`; what kept
/// them apart was one-person notifications, an inbox entry that named two
/// people and moved between lists, and no sender on a message.
void main() {
  Map<String, dynamic> order({String? driverId, Map<String, dynamic>? driver}) => <String, dynamic>{
    'id': 'order1',
    'authorID': 'cust1',
    'author': <String, dynamic>{'id': 'cust1', 'firstName': 'Sara', 'lastName': 'Khan', 'fcmToken': 'tok-cust'},
    'vendorID': 'store1',
    'vendor': <String, dynamic>{'id': 'store1', 'author': 'owner1', 'title': 'Food Factory', 'fcmToken': 'tok-store'},
    'driverID': driverId,
    'driver': driver,
  };

  final Map<String, dynamic> aliKhan = <String, dynamic>{'id': 'drv1', 'firstName': 'Ali', 'lastName': 'Khan', 'fcmToken': 'tok-drv'};

  group('who takes part', () {
    test('nothing that is not a store order', () {
      expect(SharedOrderChat.fromOrder('ride1', null), isNull);
      expect(SharedOrderChat.fromOrder('', order()), isNull);
      expect(SharedOrderChat.fromOrder('order1', <String, dynamic>{'authorID': 'cust1'}), isNull);
    });

    test('customer and store before a driver has accepted', () {
      final SharedOrderChat chat = SharedOrderChat.fromOrder('order1', order())!;
      expect(chat.members.map((OrderChatMember m) => m.role), <String>['customer', 'vendor']);
      expect(chat.memberWithRole(SharedOrderChat.customer)!.name, 'Sara Khan');
      expect(chat.memberWithRole(SharedOrderChat.store)!.id, 'owner1');
      expect(chat.memberWithRole(SharedOrderChat.store)!.name, 'Food Factory');
      expect(chat.memberWithRole(SharedOrderChat.store)!.token, 'tok-store');
      expect(chat.memberWithRole(SharedOrderChat.driver), isNull);
      expect(SharedOrderChat.fromOrder('order1', order(driverId: ''))!.memberWithRole(SharedOrderChat.driver), isNull);
    });

    test('the driver joins once one has accepted', () {
      final SharedOrderChat chat = SharedOrderChat.fromOrder('order1', order(driverId: 'drv1', driver: aliKhan))!;
      final OrderChatMember driver = chat.memberWithRole(SharedOrderChat.driver)!;
      expect(driver.id, 'drv1');
      expect(driver.name, 'Ali Khan');
      expect(driver.token, 'tok-drv');
    });

    test('a driver copied into the order is not used for another driver', () {
      final SharedOrderChat chat = SharedOrderChat.fromOrder('order1', order(driverId: 'drv2', driver: aliKhan))!;
      final OrderChatMember driver = chat.memberWithRole(SharedOrderChat.driver)!;
      expect(driver.id, 'drv2');
      expect(driver.name, isEmpty);
      expect(driver.token, isEmpty);
    });
  });

  group('what each person sees', () {
    final SharedOrderChat chat = SharedOrderChat.fromOrder('order1', order(driverId: 'drv1', driver: aliKhan))!;

    test('the header names the other two', () {
      expect(chat.titleFor(SharedOrderChat.customer), 'Food Factory, Ali Khan');
      expect(chat.titleFor(SharedOrderChat.store), 'Sara Khan, Ali Khan');
      expect(chat.titleFor(SharedOrderChat.driver), 'Sara Khan, Food Factory');
    });

    test('before a driver, the header is the one it always was', () {
      expect(SharedOrderChat.fromOrder('order1', order())!.titleFor(SharedOrderChat.customer), 'Food Factory');
    });

    test('a member with no name is shown by role', () {
      final SharedOrderChat unnamed = SharedOrderChat.fromOrder('order1', order(driverId: 'drv2', driver: aliKhan))!;
      expect(unnamed.titleFor(SharedOrderChat.customer), 'Food Factory, Driver');
    });

    test('a message says who sent it', () {
      expect(chat.labelFor(<String, dynamic>{'senderId': 'employee7', 'senderName': 'Food Factory', 'senderRole': 'vendor'}), 'Food Factory · Store');
    });

    test('older messages are placed by their sender id', () {
      expect(chat.labelFor(<String, dynamic>{'senderId': 'drv1'}), 'Ali Khan · Driver');
      expect(chat.labelFor(<String, dynamic>{'senderId': 'cust1'}), 'Sara Khan · Customer');
      expect(chat.labelFor(<String, dynamic>{'senderId': 'owner1'}), 'Food Factory · Store');
    });

    test('a sender who cannot be placed gets no label', () {
      expect(chat.labelFor(<String, dynamic>{'senderId': 'someone'}), isEmpty);
      expect(chat.labelFor(<String, dynamic>{}), isEmpty);
      expect(chat.labelFor(null), isEmpty);
    });

    test('the store sends under its name', () {
      expect(chat.nameFor(SharedOrderChat.store, fallback: 'Owner Name'), 'Food Factory');
      expect(SharedOrderChat(orderId: 'o', members: <OrderChatMember>[]).nameFor(SharedOrderChat.store, fallback: ' Owner '), 'Owner');
    });
  });

  group('inbox', () {
    final Timestamp at = Timestamp.fromMillisecondsSinceEpoch(1000);
    final SharedOrderChat chat = SharedOrderChat.fromOrder('order1', order(driverId: 'drv1', driver: aliKhan))!;
    final Map<String, Map<String, dynamic>> entries = chat.inboxEntries(senderId: 'drv1', lastMessage: 'on my way', lastMessageType: 'text', createdAt: at);

    test('one entry for the store lists and one for the driver lists', () {
      expect(entries.keys, unorderedEquals(<String>['order1', 'order1_driver']));
      expect(entries['order1']!['chatType'], 'vendor');
      expect(entries['order1_driver']!['chatType'], 'driver');
    });

    test('both open the same thread', () {
      for (final Map<String, dynamic> entry in entries.values) {
        expect(InboxModel.fromJson(entry).orderId, 'order1');
        expect(entry['type'], 'orderChat');
      }
    });

    test('everyone finds it in their inbox', () {
      for (final Map<String, dynamic> entry in entries.values) {
        expect(entry['sender_receiver_id'], unorderedEquals(<String>['cust1', 'owner1', 'drv1']));
      }
    });

    test('each row shows the person it always showed', () {
      final InboxModel storeEntry = InboxModel.fromJson(entries['order1']!);
      expect(storeEntry.senderId, 'cust1');
      expect(storeEntry.receiverId, 'owner1');
      final InboxModel driverEntry = InboxModel.fromJson(entries['order1_driver']!);
      expect(driverEntry.senderId, 'cust1');
      expect(driverEntry.receiverId, 'drv1');
    });

    test('the last message and its sender are kept', () {
      for (final Map<String, dynamic> entry in entries.values) {
        expect(entry['lastSenderId'], 'drv1');
        expect(entry['lastMessage'], 'on my way');
        expect(entry['lastMessageType'], 'text');
        expect(entry['createdAt'], at);
      }
    });

    test('the same fields an inbox entry has always had', () {
      final Set<String> fields = InboxModel(chatType: 'vendor').toJson().keys.toSet();
      for (final Map<String, dynamic> entry in entries.values) {
        expect(entry.keys.toSet(), fields);
      }
    });

    test('no driver entry before a driver', () {
      final SharedOrderChat noDriver = SharedOrderChat.fromOrder('order1', order())!;
      expect(noDriver.inboxEntries(senderId: 'cust1', lastMessage: 'hi', lastMessageType: 'text', createdAt: at).keys, <String>['order1']);
    });
  });

  group('notifications', () {
    final SharedOrderChat chat = SharedOrderChat.fromOrder('order1', order(driverId: 'drv1', driver: aliKhan))!;

    test('both others are told, never the sender', () {
      expect(chat.recipientsFor(SharedOrderChat.customer).map((OrderChatMember m) => m.id), <String>['owner1', 'drv1']);
      expect(chat.recipientsFor(SharedOrderChat.store).map((OrderChatMember m) => m.id), <String>['cust1', 'drv1']);
      expect(chat.recipientsFor(SharedOrderChat.driver).map((OrderChatMember m) => m.id), <String>['cust1', 'owner1']);
    });

    test('no device, no notification; one per device', () {
      final SharedOrderChat noTokens = SharedOrderChat(orderId: 'o', members: <OrderChatMember>[
        OrderChatMember(role: SharedOrderChat.customer, id: 'c', token: 'same'),
        OrderChatMember(role: SharedOrderChat.store, id: 's', token: 'same'),
        OrderChatMember(role: SharedOrderChat.driver, id: 'd'),
      ]);
      expect(noTokens.recipientsFor(SharedOrderChat.customer).map((OrderChatMember m) => m.id), <String>['s']);
      expect(noTokens.recipientsFor(SharedOrderChat.driver).map((OrderChatMember m) => m.id), <String>['c']);
    });

    test('a tap opens the right place in each app', () {
      final OrderChatMember customer = chat.memberWithRole(SharedOrderChat.customer)!;
      final OrderChatMember store = chat.memberWithRole(SharedOrderChat.store)!;
      final OrderChatMember driver = chat.memberWithRole(SharedOrderChat.driver)!;
      // The customer app picks its store or driver inbox by chatType.
      expect(chat.payloadFor(customer, senderId: 'owner1', senderRole: 'vendor')['chatType'], 'vendor');
      expect(chat.payloadFor(customer, senderId: 'drv1', senderRole: 'driver')['chatType'], 'driver');
      expect(chat.payloadFor(store, senderId: 'drv1', senderRole: 'driver')['chatType'], 'vendor');
      expect(chat.payloadFor(driver, senderId: 'owner1', senderRole: 'vendor')['chatType'], 'driver');
      final Map<String, dynamic> payload = chat.payloadFor(driver, senderId: 'owner1', senderRole: 'vendor');
      expect(payload['type'], 'orderChat');
      expect(payload['orderId'], 'order1');
      expect(payload['senderId'], 'owner1');
      // FCM data values must be strings.
      expect(payload.values.every((Object? v) => v is String), isTrue);
    });
  });

  group('this app', () {
    String code(String path) => File(path).readAsStringSync().split('\n').where((String line) => !line.trimLeft().startsWith('//')).join('\n');

    final String controller = code('lib/controllers/chat_controller.dart');
    final String screen = code('lib/screen_ui/multi_vendor_service/chat_screens/chat_screen.dart');

    test('only a store or driver chat looks for its order', () {
      expect(controller, contains('if (chatType.value == Constant.userRoleVendor || chatType.value == Constant.userRoleDriver) {\n        _sharedChatLoad = _loadSharedChat();'));
    });

    test('an order chat is sent as the customer to everyone', () {
      expect(controller, contains('senderRole: SharedOrderChat.customer,'));
    });

    test('the typed text is read before anything is awaited', () {
      final int send = controller.indexOf('Future<void> sendMessage(');
      final int typed = controller.indexOf('final String typedText = messageController.value.text;', send);
      final int firstAwait = controller.indexOf('await ', send);
      expect(typed, greaterThan(send));
      expect(typed, lessThan(firstAwait));
      expect(controller, contains('lastMessage: typedText,'));
      expect(controller, isNot(contains('lastMessage: messageController.value.text')));
    });

    test('other chats still send the way they did', () {
      expect(controller, contains('await FireStoreUtils.addInbox(inboxModel);'));
      expect(controller, contains('await FireStoreUtils.addChat(conversationModel);'));
    });

    test('the screen names everyone and every sender', () {
      expect(screen, contains('shared?.titleFor(SharedOrderChat.customer) ?? controller.receivedName.value'));
      expect(screen, contains("withSenderLabel(isDark, isMe ? '' : shared?.labelFor(data) ?? '', chatItemView(isDark, isMe, inboxModel))"));
    });
  });
}
