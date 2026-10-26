import 'dart:io';

import 'package:customer/utils/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Session 23 - the back button, and screens closing themselves.
///
/// The client asked that "every module, page and back button" work. Two
/// distinct faults were found, and they are the same fault twice:
///
///  * a Firestore listener calling `Get.back()` when a ride completes pops
///    **whatever is on top**, which is not necessarily its own screen;
///  * the payment callbacks on the live-ride screens call `Get.back()` to close
///    a payment UI that has, in almost every case, already closed itself - so
///    the pop lands on the ride screen and ejects a customer who has just paid.
///
/// Session 21 fixed exactly this in `CabBookingController`'s **cash** branch.
/// It was never applied to the intercity flow at all, and the gateway branches
/// were left alone in both.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

class _Ride extends StatelessWidget {
  const _Ride();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('ride'));
}

class _Chat extends StatelessWidget {
  const _Chat();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('chat'));
}

/// Stands in for the three real controllers, which capture their route the same
/// way: a field initialiser evaluated when GetX constructs the controller.
class _RouteCapturingController extends GetxController {
  final String ownRoute = SafePop.currentRoute();

  /// GetX refuses to build without an observable in scope.
  final RxInt ticks = 0.obs;
}

/// A screen wired exactly as the real ones are - `GetX(init: Controller())`.
class _RideWithController extends StatelessWidget {
  const _RideWithController();

  @override
  Widget build(BuildContext context) {
    return GetX<_RouteCapturingController>(
      init: _RouteCapturingController(),
      builder: (_RouteCapturingController controller) => Scaffold(body: Text('ride:${controller.ticks.value}:${controller.ownRoute}')),
    );
  }
}

void main() {
  group('SafePop', () {
    Future<String> pumpToRide(WidgetTester tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: _Home()));
      await tester.pumpAndSettle();
      Get.to(() => const _Ride());
      await tester.pumpAndSettle();
      return Get.currentRoute;
    }

    testWidgets('a controller built by GetX(init:) captures its OWN route, not the one it came from', (WidgetTester tester) async {
      // This is the assumption everything else here rests on, and it is worth
      // proving rather than reasoning about. `_ownRoute` is a field
      // initialiser, so it runs whenever GetX constructs the controller - and
      // if that happened before the navigator had recorded the push, the
      // controller would hold the *previous* screen's route. That would be
      // worse than the bug being fixed: popIfCurrent would never close the ride
      // screen, and popUnlessCurrent would pop on every payment callback,
      // ejecting exactly the customer it is meant to protect.
      await tester.pumpWidget(const GetMaterialApp(home: _Home()));
      await tester.pumpAndSettle();
      final String homeRoute = Get.currentRoute;

      Get.to(() => const _RideWithController());
      await tester.pumpAndSettle();
      final String rideRoute = Get.currentRoute;

      expect(rideRoute, isNot(homeRoute), reason: 'the two screens must be distinguishable by route');
      expect(find.text('ride:0:$rideRoute'), findsOneWidget, reason: 'the controller captured $homeRoute instead of $rideRoute');
    });

    testWidgets('popIfCurrent closes the screen when it is the one on top', (WidgetTester tester) async {
      final String rideRoute = await pumpToRide(tester);
      expect(find.text('ride'), findsOneWidget);

      expect(SafePop.popIfCurrent(rideRoute), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('ride'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('popIfCurrent leaves another screen alone', (WidgetTester tester) async {
      // The customer opened chat from the ride screen and the ride completed.
      // The old `Get.back()` closed the chat out from under them.
      final String rideRoute = await pumpToRide(tester);
      Get.to(() => const _Chat());
      await tester.pumpAndSettle();
      expect(find.text('chat'), findsOneWidget);

      expect(SafePop.popIfCurrent(rideRoute), isFalse);
      await tester.pumpAndSettle();

      expect(find.text('chat'), findsOneWidget, reason: 'the chat must stay open');
    });

    testWidgets('popIfCurrent never pops the last route away', (WidgetTester tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: _Home()));
      await tester.pumpAndSettle();

      expect(SafePop.popIfCurrent(Get.currentRoute), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('popUnlessCurrent closes a payment page that is still open', (WidgetTester tester) async {
      final String rideRoute = await pumpToRide(tester);
      Get.to(() => const _Chat()); // stands in for a payment page
      await tester.pumpAndSettle();

      expect(SafePop.popUnlessCurrent(rideRoute), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('chat'), findsNothing);
      expect(find.text('ride'), findsOneWidget, reason: 'the ride screen must survive');
    });

    testWidgets('popUnlessCurrent does not eject the customer from their ride', (WidgetTester tester) async {
      // PayFastScreen, PayStackScreen and MercadoPagoScreen all close
      // themselves with `Get.back(result: ...)`, and Stripe and Razorpay push
      // no route at all - so by the time the callback runs the ride screen is
      // usually back on top and the old pop threw the customer out of it.
      final String rideRoute = await pumpToRide(tester);
      expect(find.text('ride'), findsOneWidget);

      expect(SafePop.popUnlessCurrent(rideRoute), isFalse);
      await tester.pumpAndSettle();

      expect(find.text('ride'), findsOneWidget, reason: 'a paid-up customer must stay on their ride');
    });
  });

  group('the live-ride screens no longer pop blindly', () {
    String read(String path) => File(path).readAsStringSync();

    const List<String> liveRideControllers = <String>[
      'lib/controllers/cab_booking_controller.dart',
      'lib/controllers/intercity_home_controller.dart',
      'lib/controllers/live_tracking_controller.dart',
    ];

    test('no bare Get.back() is left in them', () {
      for (final String path in liveRideControllers) {
        final List<String> bare = <String>[];
        final List<String> lines = read(path).split('\n');
        for (int i = 0; i < lines.length; i++) {
          final String trimmed = lines[i].trim();
          if (trimmed == 'Get.back();') bare.add('$path:${i + 1}');
        }
        expect(bare, isEmpty, reason: 'these pops are unguarded:\n  ${bare.join('\n  ')}');
      }
    });

    test('each one knows the route it was opened as', () {
      for (final String path in liveRideControllers) {
        expect(read(path).contains('SafePop.currentRoute()'), isTrue, reason: '$path must capture its own route');
      }
    });

    test('intercity Pay Now no longer pops twice on cash', () {
      // The exact fault Session 21 fixed in the cab flow and never applied
      // here: `Pay Now` on an intercity ride opens neither a sheet nor a
      // payment page, so both pops landed on real screens.
      final String source = read('lib/controllers/intercity_home_controller.dart');
      final int at = source.indexOf('Future<void> completeOrder() async {');
      expect(at, greaterThan(-1));
      final String cashBranch = source.substring(at, source.indexOf('} else {', at));

      expect(cashBranch.contains('Get.back()'), isFalse, reason: 'the cash branch must close nothing');
      expect(cashBranch.contains('SafePop'), isFalse, reason: 'the cash branch should not pop at all');
      expect(cashBranch.contains('Please pay the fare to your driver in cash'), isTrue);
    });

    test('the cab flow keeps the Session 21 wording', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');
      expect(source.contains('Please pay the fare to your driver in cash'), isTrue);
    });

    test('both cash messages have a translation', () {
      // A `.tr` with no entry renders the raw English key to the customer.
      final String english = read('lib/lang/app_en.dart');
      expect(english.contains('Please pay the fare to your driver in cash'), isTrue);
    });
  });
}
