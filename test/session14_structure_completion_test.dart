import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/controllers/my_cab_booking_controller.dart';
import 'package:customer/models/booking_entry.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/utils/driver_trip_state.dart';

/// Session 14 — the customer side of four structural changes.
///
/// 1. The Bookings tabs are relabelled to the client's own wording: Pending,
///    Confirmed, Completed, Cancelled. The tab **keys** are untouched.
/// 2. A booked driver-posted trip can finally leave Confirmed, because
///    `DriverTripStatus.completed` now exists and the server writes it.
/// 4. The customer's Inbox is reachable from the cab section.
///
/// Item 3 is driver-app-only and is covered there.
void main() {
  /// Reads a source file. Deliberately free of `expect`, because two of the
  /// groups below read their file once at group level - where `expect` is
  /// outside any test and throws `OutsideTestException`.
  String source(String path) {
    final File file = File(path);
    if (!file.existsSync()) throw StateError('$path is missing');
    return file.readAsStringSync();
  }

  // =========================================================================
  // ITEM 1 — the labels change, the keys do not
  // =========================================================================
  group('Item 1: the Bookings tabs carry the client\'s wording', () {
    final MyCabBookingController controller = MyCabBookingController();

    test('the four rendered labels are Pending, Confirmed, Completed, Cancelled', () {
      expect(
        controller.tabKeys.map(controller.getLocalizedTabTitle).toList(),
        <String>['Pending', 'Confirmed', 'Completed', 'Cancelled'],
      );
    });

    test('the tab order is unchanged — Pending first, Cancelled last', () {
      // The client's document lists the statuses in a different order. That
      // reads as a status list rather than a tab order, so the order the
      // customer already knows is kept and the question is raised in the
      // report instead of being answered by a silent reshuffle.
      expect(BookingTab.all, <String>[
        BookingTab.isNew,
        BookingTab.onGoing,
        BookingTab.completed,
        BookingTab.cancelled,
      ]);
    });

    test('the keys behind those labels are still New and On Going', () {
      // This is the whole point of relabelling rather than renaming. The keys
      // index `BookingTab.rideStatuses` and are what `forRideStatus()` and
      // `forTripStatus()` return; changing them would break the merge of rides
      // and driver-posted trips into this one list.
      expect(BookingTab.isNew, 'New');
      expect(BookingTab.onGoing, 'On Going');
      expect(BookingTab.completed, 'Completed');
      expect(BookingTab.cancelled, 'Cancelled');
    });

    test('the status to tab mapping is completely unchanged', () {
      expect(BookingTab.rideStatuses, <String, List<String>>{
        'New': <String>['Order Placed', 'Driver Pending'],
        'On Going': <String>['Driver Accepted', 'Order Shipped', 'In Transit'],
        'Completed': <String>['Order Completed'],
        'Cancelled': <String>['Order Rejected', 'Order Cancelled', 'Driver Rejected'],
      });

      expect(BookingTab.forRideStatus('Order Placed'), BookingTab.isNew);
      expect(BookingTab.forRideStatus('Driver Pending'), BookingTab.isNew);
      expect(BookingTab.forRideStatus('Driver Accepted'), BookingTab.onGoing);
      expect(BookingTab.forRideStatus('Order Shipped'), BookingTab.onGoing);
      expect(BookingTab.forRideStatus('In Transit'), BookingTab.onGoing);
      expect(BookingTab.forRideStatus('Order Completed'), BookingTab.completed);
      expect(BookingTab.forRideStatus('Order Rejected'), BookingTab.cancelled);
      expect(BookingTab.forRideStatus('Order Cancelled'), BookingTab.cancelled);
      expect(BookingTab.forRideStatus('Driver Rejected'), BookingTab.cancelled);
      expect(BookingTab.forRideStatus('anything else'), isNull);
    });

    test('an unknown key falls through to itself rather than to a blank tab', () {
      expect(controller.getLocalizedTabTitle('Archived'), 'Archived');
    });

    test('the tab bar renders through getLocalizedTabTitle and nowhere else', () {
      // The screen builds its tabs from `tabKeys` mapped through
      // `getLocalizedTabTitle`. If a raw key were printed anywhere else in it,
      // relabelling would show Pending on one row and New on another.
      final String screen = source('lib/screen_ui/cab_service_screens/my_cab_booking_screen.dart');
      expect(screen.contains('controller.getLocalizedTabTitle(key)'), isTrue);
      expect(screen.contains("Text('New'"), isFalse);
      expect(screen.contains('Text("New"'), isFalse);
      expect(screen.contains("'On Going'.tr"), isFalse);
      expect(screen.contains('"On Going".tr'), isFalse);
    });

    test('both lang files carry the two new strings', () {
      for (final String path in <String>['lib/lang/app_en.dart', 'lib/lang/app_ar.dart']) {
        final String lang = source(path);
        expect(lang.contains("'Pending':"), isTrue, reason: '$path has no Pending');
        expect(lang.contains("'Confirmed':"), isTrue, reason: '$path has no Confirmed');
        // The old keys stay: they are still the map keys, and other screens
        // (rental, parcel) render them as labels of their own.
        expect(lang.contains("'New':"), isTrue, reason: '$path lost New');
        expect(lang.contains("'On Going':"), isTrue, reason: '$path lost On Going');
      }
    });
  });

  // =========================================================================
  // ITEM 2 — a booked trip can finish
  // =========================================================================
  group('Item 2: a booked trip no longer sits in Confirmed for ever', () {
    test('completed is a real status now, and it counts as finished', () {
      expect(DriverTripStatus.completed, 'completed');
      expect(DriverTripStatus.all.contains(DriverTripStatus.completed), isTrue);
      expect(DriverTripStatus.isFinished(DriverTripStatus.completed), isTrue);
    });

    test('the states that were already finished still are', () {
      expect(DriverTripStatus.isFinished(DriverTripStatus.expired), isTrue);
      expect(DriverTripStatus.isFinished(DriverTripStatus.cancelled), isTrue);
      expect(DriverTripStatus.isFinished(DriverTripStatus.active), isFalse);
      expect(DriverTripStatus.isFinished(DriverTripStatus.booked), isFalse);
      expect(DriverTripStatus.isFinished(null), isFalse);
    });

    test('a completed trip lands in the Completed tab', () {
      expect(BookingTab.forTripStatus(DriverTripStatus.completed), BookingTab.completed);
    });

    test('every other trip status keeps the tab it had', () {
      expect(BookingTab.forTripStatus(DriverTripStatus.booked), BookingTab.onGoing);
      expect(BookingTab.forTripStatus(DriverTripStatus.cancelled), BookingTab.cancelled);
      expect(BookingTab.forTripStatus(DriverTripStatus.expired), BookingTab.cancelled);
      expect(BookingTab.forTripStatus(DriverTripStatus.active), BookingTab.isNew);
    });

    test('a completed trip is still a row — it does not fall out of the list', () {
      // The rollout hazard worth pinning: `merge` drops anything whose tab is
      // null, so a status the mapping does not claim disappears from Ride
      // History entirely.
      final DriverTripModel trip = DriverTripModel.fromJson(<String, dynamic>{
        DriverTripFields.id: 't1',
        DriverTripFields.status: DriverTripStatus.completed,
        DriverTripFields.reservedAt: Timestamp.fromDate(DateTime(2026, 9, 1)),
      });
      final List<BookingEntry> completed = BookingEntry.merge(
        rides: const <Never>[],
        trips: <DriverTripModel>[trip],
        tab: BookingTab.completed,
      );
      expect(completed.length, 1);
      expect(completed.single.id, 't1');

      // and it is in exactly one tab, not several
      for (final String tab in <String>[BookingTab.isNew, BookingTab.onGoing, BookingTab.cancelled]) {
        expect(
          BookingEntry.merge(rides: const <Never>[], trips: <DriverTripModel>[trip], tab: tab),
          isEmpty,
          reason: 'a completed trip should not also be in $tab',
        );
      }
    });

    test('a build shipped BEFORE the sweep cannot lose a trip', () {
      // An older app has no `completed` case, so it falls through `default`.
      // That branch returns `isNew`, which is a real tab - so the booking is
      // listed under Pending rather than vanishing. This pins the safety net.
      final String model = source('lib/models/booking_entry.dart');
      final int defaultAt = model.indexOf('default:');
      expect(defaultAt, greaterThan(0));
      expect(model.substring(defaultAt).contains('return isNew;'), isTrue);
    });

    test('neither app writes the status — only the server does', () {
      // The whole point of putting completion on the server clock. If either
      // app started writing it, a driver could finish a trip by moving their
      // phone forward.
      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('driver_trip_state.dart')) continue;
        if (entity.path.endsWith('booking_entry.dart')) continue;
        final String text = entity.readAsStringSync();
        expect(
          text.contains('DriverTripStatus.completed'),
          isFalse,
          reason: '${entity.path} references the completed status; only the sweep may set it',
        );
      }
    });
  });

  // =========================================================================
  // ITEM 4 — chat is reachable from the cab section
  // =========================================================================
  group('Item 4: the Inbox is reachable from the cab section', () {
    final String screen = source('lib/screen_ui/cab_service_screens/my_cab_booking_screen.dart');

    test('the cab Bookings AppBar has an entry point', () {
      expect(screen.contains('actions:'), isTrue, reason: 'the AppBar has no actions');
      expect(screen.contains('"Messages".tr'), isTrue);
    });

    test('it opens the existing DriverInboxScreen, not a new class', () {
      expect(screen.contains('Get.to(const DriverInboxScreen())'), isTrue);
      expect(
        screen.contains("import 'package:customer/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart';"),
        isTrue,
      );
    });

    test('no second inbox screen was created', () {
      final List<String> inboxScreens = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .where((File f) => f.readAsStringSync().contains('class DriverInboxScreen'))
          .map((File f) => f.path)
          .toList();
      expect(inboxScreens.length, 1, reason: 'DriverInboxScreen is declared in ${inboxScreens.join(', ')}');
    });

    test('the chat call sites and their controller are untouched', () {
      // Item 4 is reachability only. Nothing about how chat works changed.
      expect(File('lib/controllers/chat_controller.dart').existsSync(), isTrue);
      expect(File('lib/models/inbox_model.dart').existsSync(), isTrue);
      expect(File('lib/models/conversation_model.dart').existsSync(), isTrue);
      // The Profile screen keeps the entry point it always had, so the new one
      // is a second door and not a move.
      final String profile = source('lib/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart');
      expect(profile.contains('Get.to(const DriverInboxScreen())'), isTrue);
    });

    test('the string is in both lang files', () {
      for (final String path in <String>['lib/lang/app_en.dart', 'lib/lang/app_ar.dart']) {
        expect(source(path).contains("'Messages':"), isTrue, reason: '$path has no Messages');
      }
    });
  });
}
