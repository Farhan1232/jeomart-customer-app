import 'dart:async';
import 'dart:developer';

import 'package:flutter_easyloading/flutter_easyloading.dart';

class ShowToastDialog {
  /// Show a toast message with customizable position.
  static void showToast(
    String? message, {
    EasyLoadingToastPosition position = EasyLoadingToastPosition.top,
  }) {
    if (message == null || message.isEmpty) return;
    EasyLoading.showToast(message, toastPosition: position);
  }

  /// How long a blocking loader may stay on screen before it takes itself down.
  ///
  /// The customer app calls [showLoader] from 114 places that go on to `await`
  /// something - a Firestore read, a payment gateway, a geocode - and then call
  /// [closeLoader] on the line after. Most of those are not inside a `try`, so
  /// **any** throw on the awaited call skips the close and leaves a full-screen,
  /// tap-blocking overlay up for the rest of the session. From the outside that
  /// is indistinguishable from the app freezing, which is what the client
  /// reported.
  ///
  /// Guarding all 114 call sites individually would mean touching every payment
  /// and booking flow in the app. This does the same job in one place: the
  /// loader is a UI affordance, not state, so nothing is lost by putting a
  /// ceiling on how long it may block the screen.
  ///
  /// Deliberately generous. It is a backstop against a dropped future, not a
  /// request timeout - a slow payment redirect on a bad connection must still be
  /// allowed to finish. Anything that legitimately takes longer than this should
  /// not be behind a blocking loader in the first place.
  static const Duration loaderWatchdog = Duration(seconds: 30);

  static Timer? _watchdog;

  /// Show a loading indicator with a status message.
  ///
  /// The loader can no longer outlive [loaderWatchdog]. Whichever comes first -
  /// the matching [closeLoader] or the watchdog - takes it down, and the
  /// watchdog logs when it fires so a stranded loader is findable rather than
  /// merely survivable.
  static void showLoader(String message) {
    _watchdog?.cancel();
    _watchdog = Timer(loaderWatchdog, () {
      log('ShowToastDialog: loader "$message" was never closed after ${loaderWatchdog.inSeconds}s - dismissing it');
      EasyLoading.dismiss();
      _watchdog = null;
    });
    EasyLoading.show(
      status: message,
      dismissOnTap: false,
      maskType: EasyLoadingMaskType.clear,
    );
  }

  /// Dismiss any active loading indicator.
  static void closeLoader() {
    _watchdog?.cancel();
    _watchdog = null;
    EasyLoading.dismiss();
  }

  /// Test seam: whether a loader is currently being watched.
  static bool get hasPendingLoader => _watchdog != null;
}
