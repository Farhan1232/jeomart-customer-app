import 'dart:convert';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/screen_ui/help_support_screen/help_support_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/restaurant_inbox_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
  // NotificationService.redirectScreen(message);
}

class NotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initInfo() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    var request = await FirebaseMessaging.instance.requestPermission(alert: true, announcement: false, badge: true, carPlay: false, criticalAlert: false, provisional: false, sound: true);

    if (request.authorizationStatus == AuthorizationStatus.authorized || request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      var iosInitializationSettings = const DarwinInitializationSettings();
      final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: iosInitializationSettings);
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            final data = jsonDecode(response.payload!);
            final String type = data['type'] ?? '';
            final String role = data['chatType'] ?? '';
            handleMessageClick(type: type, role: role, isBgApp: false);
          }
        },
      );
      setupInteractedMessage();
    }
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String type = initialMessage.data['type'] ?? '';
      final String role = initialMessage.data['chatType'] ?? '';
      handleMessageClick(type: type, role: role, isBgApp: true);
    }
    if (initialMessage != null) {
      FirebaseMessaging.onBackgroundMessage((message) => firebaseMessageBackgroundHandle(message));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log("::::::::::::onMessage:::::::::::::::::");
      if (message.notification != null) {
        log(message.notification.toString());
        // display(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) async {
      log("::::::::::::onMessageOpenedApp:::::::::::::::::");
      if (message != null) {
        final String type = message.data['type'] ?? '';
        final String role = message.data['chatType'] ?? '';
        handleMessageClick(type: type, role: role, isBgApp: true);
      }
    });
    log("::::::::::::Permission authorized:::::::::::::::::");
    await FirebaseMessaging.instance.subscribeToTopic("customer");
  }

  static Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token ?? '';
    } catch (e) {
      return '';
    }
  }

  // static redirectScreen(RemoteMessage message) async {
  //   Map<String, dynamic> data = message.data;
  //   if (data['type'] == "user_chat") {
  //     String senderId = data['senderId'];
  //     String receiverId = data['receiverId'];
  //
  //     ShowToastDialog.showLoader("Please wait".tr);
  //     UserModel? senderUserModel = await FireStoreUtils.getUserProfile(senderId);
  //     UserModel? receiverUserModel = await FireStoreUtils.getUserProfile(receiverId);
  //     ShowToastDialog.closeLoader();
  //     bool isMe = senderUserModel!.id == senderId;
  //     Get.to(const UserChatScreen(), arguments: {"receiverModel": isMe ? senderUserModel : receiverUserModel});
  //   } else if (data['type'] == "project_chat") {
  //     String isSender = data['isSender'];
  //     String businessId = data['businessId'];
  //     String projectId = data['projectId'];
  //
  //     ShowToastDialog.showLoader("Please wait".tr);
  //     PricingRequestModel? pricingRequestModel = await FireStoreUtils.getPricingRequestById(projectId);
  //     BusinessModel? businessModel = await FireStoreUtils.getBusinessById(businessId);
  //     UserModel? userModel = await FireStoreUtils.getUserProfile(pricingRequestModel!.userId.toString());
  //     ShowToastDialog.closeLoader();
  //     Get.to(ChatScreen(), arguments: {
  //       "userModel": userModel!,
  //       "businessModel": businessModel!,
  //       "projectModel": pricingRequestModel,
  //       "isSender": isSender == "business" ? "user" : "business",
  //     });
  //   } else if (data['type'] == "project_request") {
  //     String businessId = data['businessId'];
  //     String projectId = data['projectId'];
  //     BusinessModel? businessModel = await FireStoreUtils.getBusinessById(businessId);
  //     Get.to(BusinessProjectListScreen(), arguments: {"businessModel": businessModel});
  //   } else if (data['type'] == "review") {
  //     String businessId = data['businessId'];
  //     BusinessModel? businessModel = await FireStoreUtils.getBusinessById(businessId);
  //     Get.to(BusinessDetailsScreen(), arguments: {"businessModel": businessModel});
  //   } else if (data['type'] == "user_follow") {
  //     String userId = data['userId'];
  //     ShowToastDialog.showLoader("Please wait");
  //     UserModel? userModel0 = await FireStoreUtils.getUserProfile(userId.toString());
  //     ShowToastDialog.closeLoader();
  //     Get.to(OtherPeopleScreen(), arguments: {"userModel": userModel0});
  //   }
  // }

  /// Opens what a notification points at, **on top of what the customer is
  /// already doing**.
  ///
  /// This used to be `Get.offAll(DashBoardScreen())` followed by `Get.to(inbox)`
  /// - and `offAll` throws the whole navigation stack away. Three things the
  /// client reported come from that one line:
  ///
  ///  * *"the app changes the customer's selected area"* - `DashBoardScreen` is
  ///    the **multi-vendor** dashboard, and its home screen re-runs zone
  ///    detection against the customer's location. A customer whose location is
  ///    not inside a food zone is shown the *Change Zone* screen, so backing out
  ///    of a message asked them to pick their area again;
  ///  * *"white screen"* - that dashboard was opened whatever section the
  ///    customer was actually in. Cab, parcel or on-demand customers got a food
  ///    dashboard reading a section that has no restaurants;
  ///  * *"the app hangs"* - with the stack gone there is nothing behind the
  ///    dashboard, so Back no longer returns anywhere; it asks to exit the app.
  ///
  /// Pushing instead of replacing means Back walks out of the message the way
  /// it walked in, and the screen underneath - whichever section it belongs to -
  /// is exactly as it was left.
  ///
  /// [isBgApp] is kept for the three call sites, but it no longer decides
  /// anything: a tap in the foreground, from the background and from a cold
  /// start all open the same screen the same way, and [_openOnTop] works out
  /// for itself whether the app is still starting.
  Future<void> handleMessageClick({required String type, required String role, required bool isBgApp}) async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (type == 'admin_chat' && uid.isNotEmpty) {
      await Preferences.setBoolean(Preferences.isClickOnNotification, true);
      await _openOnTop(HelpSupportScreen(isNavigateViaNotification: true));
    } else if (type == 'orderChat') {
      await _openOnTop(role == Constant.userRoleVendor ? const RestaurantInboxScreen() : const DriverInboxScreen());
    }
  }

  /// Pushes [screen] over the screen the customer is on.
  ///
  /// The one case that needs care is a notification that *starts* the app: the
  /// splash screen is still deciding where the session belongs, and it finishes
  /// with `Get.offAll(...)`, which would take this screen down with it. So a
  /// push that lands on the splash waits for the splash to hand over - bounded,
  /// because a wait that cannot end is worse than a notification that opens
  /// nothing.
  static Future<void> _openOnTop(Widget screen) async {
    for (int attempt = 0; attempt < _splashWaitAttempts; attempt++) {
      // An empty route means the first screen has not been drawn yet, which is
      // the same situation for the same reason.
      final String route = Get.currentRoute;
      if (route.isNotEmpty && !route.contains('SplashScreen')) break;
      await Future<void>.delayed(_splashWaitInterval);
    }
    try {
      await Get.to(() => screen);
    } catch (error) {
      log('opening a notification screen failed :: $error');
    }
  }

  static const int _splashWaitAttempts = 40;
  static const Duration _splashWaitInterval = Duration(milliseconds: 250);

  void display(RemoteMessage message) async {
    log('Got a message whilst in the foreground!');
    log('Message data: ${message.notification!.body.toString()}');
    try {
      AndroidNotificationChannel channel = const AndroidNotificationChannel('0', 'JEOM', description: 'Show JEOM Notification', importance: Importance.max);
      AndroidNotificationDetails notificationDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: 'your channel Description',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const DarwinNotificationDetails darwinNotificationDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      NotificationDetails notificationDetailsBoth = NotificationDetails(android: notificationDetails, iOS: darwinNotificationDetails);
      await FlutterLocalNotificationsPlugin().show(
        id: 0,
        title: message.notification!.title,
        body: message.notification!.body,
        notificationDetails: notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      log(e.toString());
    }
  }
}
