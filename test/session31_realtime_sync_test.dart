import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Session 31 - "Accept takes twenty to thirty seconds, and sometimes the
/// driver app updates after more than a minute."
///
/// The customer half of that report, plus the "opening sections takes too
/// long" half of it. Each test names the thing it stops coming back:
///
///  1. the ride listener lived inside the customer's own `users` listener and
///     was cancelled and rebuilt on every snapshot of it, after a `get()` per
///     in-progress booking - so an unrelated profile write threw away the one
///     listener that reports "your driver accepted";
///  2. the booked driver's listener was rebuilt on every ride snapshot;
///  3. a routing request went out on every one of the driver's location
///     updates, and the two pin images were decoded again each time with it;
///  4. the free-vehicle map followed every active cab driver on the platform
///     and rebuilt every marker for each of them, all the way through a ride;
///  5. every push downloaded the service account and bought a fresh OAuth
///     token before it could be sent.
void main() {
  String read(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing - this test is stale');
    return file.readAsStringSync();
  }

  String methodBody(String source, String signature) {
    final int start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: 'cannot find `$signature` - this test is stale');
    final int end = source.indexOf('\n  }', start);
    expect(end, greaterThan(start), reason: 'cannot find the end of `$signature`');
    return source.substring(start, end);
  }

  String codeOnly(String body) =>
      body.split('\n').where((String line) => !line.trimLeft().startsWith('//')).join('\n');

  group('the ride listener is not rebuilt for nothing', () {
    test('the customer\'s own profile listener does no work of its own', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');

      // It used to hold the whole resolution - a `get()` per in-progress
      // booking, then cancel-and-resubscribe - and run it in full on every
      // snapshot of the customer's `users` document.
      expect(source, contains('userModel.value = UserModel.fromJson(userSnapshot.data()!);\n      await _followInProgressRide();'),
          reason: 'the profile listener hands off; it does not re-resolve the ride itself');
    });

    test('nothing is re-resolved unless the in-progress bookings changed', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');
      final String body = methodBody(source, 'Future<void> _followInProgressRide() async {');

      expect(body, contains("final String key = inProgress.join(',');"));
      expect(body, contains('if (key == _resolvedInProgressKey) return;'),
          reason: 'an unrelated profile write must not cost a read or a re-subscription');
      expect(body, contains('if (validRideId == _watchedRideId && _rideSub != null) return;'),
          reason: 'and the listener must not be replaced by an identical one');
    });

    test('the booked driver is followed once, not once per ride snapshot', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');
      final String body = methodBody(source, 'void _onRideSnapshot(String rideId, DocumentSnapshot<Map<String, dynamic>> rideSnapshot) {');

      expect(body, contains('if (driverId != null && driverId.isNotEmpty && (driverId != _watchedDriverId || _driverSub == null)) {'),
          reason: 're-subscribing on every ride snapshot threw away the driver\'s live position');
    });

    test('the sheet is chosen without waiting on anything', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');
      final String body = codeOnly(methodBody(source, 'void _onRideSnapshot(String rideId, DocumentSnapshot<Map<String, dynamic>> rideSnapshot) {'));

      // The whole value of this listener is that the instant the driver's app
      // writes `Driver Accepted`, this screen says so.
      expect(body.contains('await '), isFalse,
          reason: 'an await here is time between the driver accepting and the customer being told');
      expect(body, contains("bottomSheetType.value = 'driverDetails';"));
    });
  });

  group('following the driver costs one route, not one per location update', () {
    test('the route is only re-fetched when it would be a different route', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');
      final String body = methodBody(source, 'Future<void> updateDriverRoute(UserModel driverModel) async {');

      expect(body, contains("final String routeKey = '\${order.id}|\${order.status}|\${driverLat.toStringAsFixed(3)},\${driverLng.toStringAsFixed(3)}';"));
      expect(body, contains('if (routeKey == _driverRouteKey) return;'));
    });

    test('the two pin images are decoded once', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');
      final String body = methodBody(source, 'Future<void> updateRouteMarkers(UserModel driverModel) async {');

      expect(body, contains('if (departureIcon == null) {'));
      expect(body, contains('if (destinationIcon == null) {'));
    });
  });

  group('the free-vehicle map is not a firehose', () {
    test('it is closed for the duration of a ride', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');

      expect(source, contains("static const Set<String> _rideInProgressSheets = <String>{'waitingForDriver', 'driverDetails', 'bidOffers'};"));
      expect(source, contains('bool get _ridePoolIsRelevant => !_rideInProgressSheets.contains(bottomSheetType.value);'));

      final String body = methodBody(source, 'Future<void> listenForNearbyDrivers() async {');
      expect(body, contains('if (!_ridePoolIsRelevant) {'),
          reason: 'the pool is not on screen during a ride and must not be subscribed to');

      // And re-opened afterwards.
      expect(source, contains('ever<String>(bottomSheetType, (_) {'));
    });

    test('a snapshot that moves nobody visible rebuilds no markers', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');

      expect(source, contains('final String signature = _signatureFor(found);'));
      expect(source, contains('if (signature == _nearbySignature) return;'));

      // Sorted, so the order Firestore delivers documents in cannot make an
      // unchanged pool look changed.
      final String body = methodBody(source, 'String _signatureFor(Map<String, NearbyDriver> found) {');
      expect(body, contains('..sort();'));
    });

    test('a burst of writes from every driver on the platform is processed once, not once per write', () {
      final String source = read('lib/controllers/cab_booking_controller.dart');

      // The pool is read on an interval, not streamed: on Android a live
      // listener re-delivered every driver document on every driver's write,
      // and decoding that on the main thread is what Play reported as ANRs.
      final String listenBody = methodBody(source, 'Future<void> listenForNearbyDrivers() async {');
      expect(listenBody, isNot(contains('.snapshots()')),
          reason: 'no live listener over every active cab driver');
      expect(listenBody, contains('_nearbyPollTimer = Timer.periodic(_nearbyPollInterval, (_) => fetch());'),
          reason: 'the pool is decoded once per interval, however many drivers write');
      expect(listenBody, contains('if (_nearbyFetchInFlight) return;'),
          reason: 'a slow read is never stacked on another');
      expect(listenBody, contains('_nearbyPollTimer?.cancel();\n    _nearbyPollTimer = null;\n    _nearbyFetch = null;\n    final int generation = ++_nearbyGeneration;'),
          reason: 'a re-target (ride starts/ends, vehicle changes) must not leave the old timer running');
      expect(listenBody, contains('if (generation != _nearbyGeneration) return;'),
          reason: 'a read still in flight for an old target never draws over the current one');
      expect(listenBody, contains('if (!_appInForeground) return;'),
          reason: 'no driver-pool reads while the app is in the background');

      // A timer firing after the customer has left this screen would touch a
      // disposed controller.
      final String closeBody = methodBody(source, 'void onClose() {');
      expect(closeBody, contains('_nearbyPollTimer?.cancel();'),
          reason: 'leaving this screen must stop the refresh');

      // The actual per-snapshot work (the visibility/marker loop, the
      // signature check) is unchanged - only how often it runs.
      expect(source, contains('void _processNearbySnapshot('));
    });
  });

  group('a push costs one token exchange, not one per notification', () {
    test('the service account and its token are both kept', () {
      final String source = read('lib/service/send_notification.dart');

      expect(source, contains('static Map<String, dynamic>? _serviceAccount;'),
          reason: 'the credential file was downloaded again for every single notification');
      expect(source, contains('static String? _accessToken;'));
      expect(source, contains('if (cached != null && expiry != null && DateTime.now().isBefore(expiry)) {'));
      expect(source, contains('_accessTokenExpiry = token.expiry.toLocal().subtract(const Duration(minutes: 1));'));
    });

    test('the credential download is bounded', () {
      final String source = read('lib/service/send_notification.dart');

      expect(source, contains('.timeout(Constant.mapRequestTimeout);'),
          reason: 'package:http has no default timeout, and this await is on a send path');
    });
  });

  group('an open booking follows its own ride', () {
    test('the details screen listens instead of drawing what it was handed', () {
      final String source = read('lib/controllers/cab_order_details_controller.dart');

      expect(source, contains('_orderSub = FireStoreUtils.fireStore.collection(CollectionName.rides).doc(id).snapshots().listen('));
      expect(source, contains('_orderSub?.cancel();'), reason: 'and lets go of it with the screen');
      // The driver card is a second read; only worth doing when the ride has
      // actually found a different driver.
      expect(source, contains('if (cabOrder.value.driverId != previousDriverId) {'));
    });
  });
}
