import 'package:get/get.dart';

/// Closing a screen from a Firestore listener, safely.
///
/// ## The problem
///
/// Three controllers close their own screen when the ride or order they are
/// watching reaches its final state:
///
/// ```dart
/// } else if (status == Constant.orderCompleted) {
///   ...
///   Get.back();
/// }
/// ```
///
/// `Get.back()` pops **whatever route is on top at that moment**, and a
/// Firestore listener has no idea what that is. Two ways it goes wrong, both of
/// them things a customer would report as the back button misbehaving:
///
///  * **It pops the wrong screen.** If the customer opened chat, the driver's
///    profile or a payment sheet from the ride screen, the ride completing
///    closes *that* instead - the screen vanishes from under them and the ride
///    screen is still underneath, unclosed.
///  * **It pops the root away.** The cab and intercity home screens sit
///    directly inside their dashboard. Popping there can unwind past the
///    screen the listener meant to close.
///
/// ## The rule
///
/// A screen may only close itself while it is the screen the customer is
/// looking at. If something else is on top, the pop is skipped - the customer
/// finds the ride screen already in its finished state when they come back to
/// it, which is where they were going anyway.
///
/// `Get.to(() => Foo())` names its route `/Foo`, so [Get.currentRoute] is a
/// usable identity for an app with no named routes, which this one is.
class SafePop {
  SafePop._();

  /// The route to compare against later. Call this where the controller starts,
  /// before anything is pushed on top of it.
  static String currentRoute() => Get.currentRoute;

  /// Pops only if [ownRoute] is still the route on top, and only if there is
  /// something below it to go back to.
  ///
  /// Returns whether it popped, which is what the tests assert on.
  static bool popIfCurrent(String ownRoute) {
    if (Get.currentRoute != ownRoute) return false;
    if (!(Get.key.currentState?.canPop() ?? false)) return false;
    Get.back();
    return true;
  }

  /// Closes whatever the payment flow put on top - and nothing if it put
  /// nothing there.
  ///
  /// ## Why the plain `Get.back()` was wrong
  ///
  /// The gateway callbacks on the live-ride screens all end with a bare
  /// `Get.back()`, meaning "close the payment UI". That is correct where `Pay
  /// Now` opened a bottom sheet first - which is how `MyCabBookingController`
  /// works, and where this code was copied from.
  ///
  /// On the live-ride screens `Pay Now` is a button on the screen itself. It
  /// opens no sheet, and the payment pages that *are* pushed
  /// (`PayFastScreen`, `PayStackScreen`, `MercadoPagoScreen`) each close
  /// themselves with `Get.back(result: ...)` before the awaiting callback runs.
  /// Stripe and Razorpay do not push a route at all - they use a native sheet.
  ///
  /// So by the time these callbacks fire there is usually nothing left to
  /// close, and the pop landed on the ride screen: a customer who had just paid
  /// was thrown out of the ride they were in. It is the same fault Session 21
  /// fixed in the cash branch, in the branches that were left alone.
  ///
  /// Returns whether it popped.
  static bool popUnlessCurrent(String ownRoute) {
    if (Get.currentRoute == ownRoute) return false;
    if (!(Get.key.currentState?.canPop() ?? false)) return false;
    Get.back();
    return true;
  }
}
