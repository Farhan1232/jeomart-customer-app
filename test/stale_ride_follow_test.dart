import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ride screen follows the ride that is still going.
///
/// The client's report: *"when driver accept the order still customer app is
/// showing waiting for driver"*, cleared only by deleting the order in the
/// admin panel. The screen took `inProgress.first` whatever its check had
/// found, and a ride the panel deleted or one that ended Order Rejected stayed
/// first in the list - so the next booking's acceptance was never seen.
void main() {
  String code(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync().split('\n').where((String line) => !line.trimLeft().startsWith('//')).join('\n');
  }

  String bodyOf(String source, String signature) {
    final int start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature is missing');
    final int end = source.indexOf('\n  }\n', start);
    return source.substring(start, end == -1 ? source.length : end);
  }

  late String controller;
  late String follow;
  setUpAll(() {
    controller = code('lib/controllers/cab_booking_controller.dart');
    follow = bodyOf(controller, 'Future<void> _followInProgressRide() async {');
  });

  test('the first entry of the list is no longer followed blindly', () {
    expect(follow.contains('validRideId = inProgress.first'), isFalse);
    expect(follow, contains('final String? validRideId = activeRideId ?? firstRideId;'));
  });

  test('a ride still going wins over an ended one, whatever the order', () {
    expect(follow, contains('if (_endedRideStatuses.contains(rideDoc.data()?[\'status\'])) {'));
    expect(follow, contains('activeRideId ??= id;'));
    expect(controller, contains('static const Set<String> _endedRideStatuses = <String>{Constant.orderRejected, Constant.orderCancelled, Constant.orderCompleted};'));
  });

  test('only a server answer marks a ride deleted, and ended rides go only once a newer one is under way', () {
    expect(follow, contains('if (!rideDoc.metadata.isFromCache) deletedIds.add(id);'));
    expect(follow, contains('<String>[...deletedIds, if (activeRideId != null) ...endedIds]'));
  });

  test('the list is cleaned with one field update, never a whole-profile save', () {
    final String drop = bodyOf(controller, 'Future<void> _dropRidesFromProfile(List<String> rideIds) async {');
    expect(drop, contains("'inProgressOrderID': FieldValue.arrayRemove(rideIds)"));
    expect(drop.contains('updateUser('), isFalse);
  });
}
