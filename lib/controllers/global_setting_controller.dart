import 'dart:async';
import 'dart:developer';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../constant/collection_name.dart';
import '../service/fire_store_utils.dart';

class GlobalSettingController extends GetxController {

  /// Completes when the first pass of [FireStoreUtils.getSettings] has finished.
  ///
  /// The splash screen waits on this instead of sleeping for a fixed three
  /// seconds. That timer was a guess at how long the settings reads take, and
  /// it was wrong in both directions: too long on a good connection, and on a
  /// slow one the app left the splash and started building screens against an
  /// unread `Constant` - the app colour, the currency, the distance unit and
  /// the OTP switches all still at their compile-time defaults.
  ///
  /// Static because the splash controller needs it without holding the
  /// instance, and because the first pass only ever happens once per launch.
  static final Completer<void> _settingsReady = Completer<void>();

  static Future<void> get settingsReady => _settingsReady.future;

  static void _markSettingsReady() {
    if (!_settingsReady.isCompleted) _settingsReady.complete();
  }
  /// Firestore listeners opened by this controller.
  ///
  /// They used to run for the rest of the session because nothing cancelled
  /// them when the screen closed, and re-entering the screen opened another
  /// set on top.
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void onClose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.onClose();
  }

  @override
  void onInit() {
    notificationInit();
    getCurrentCurrency();

    super.onInit();
  }

  Future<void> getCurrentCurrency() async {
    _subscriptions.add(
      FireStoreUtils.fireStore.collection(CollectionName.currencies).where("isActive", isEqualTo: true).snapshots().listen((event) {
        if (event.docs.isNotEmpty) {
          Constant.currencyModel = CurrencyModel.fromJson(event.docs.first.data());
        } else {
          Constant.currencyModel = CurrencyModel(id: "", code: "USD", decimal: 2, isactive: true, name: "US Dollar", symbol: "\$", symbolatright: false);
        }
      }),
    );
    try {
      await FireStoreUtils.getSettings();
    } finally {
      // In a `finally`: settings that could not be read must still release the
      // splash screen, or a failed read strands the app on the logo.
      _markSettingsReady();
    }
  }

  NotificationService notificationService = NotificationService();

  void notificationInit() {
    notificationService.initInfo().then((value) async {
      String token = await NotificationService.getToken();
      log(":::::::TOKEN:::::: $token");
      if (FirebaseAuth.instance.currentUser != null) {
        await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
          if (value != null) {
            UserModel driverUserModel = value;
            // Published on the read, not on the write that follows it - see the
            // same change in `SplashController.redirectScreen`.
            Constant.userModel = driverUserModel;
            driverUserModel.fcmToken = token;
            FireStoreUtils.updateUser(driverUserModel);
          }
        });
      }
    });
  }
}
