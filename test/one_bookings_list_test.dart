import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/booking_entry.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/utils/driver_trip_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 10 — one booking list, and the Bid section's blank guest screen.
///
/// The client, 07 Sep 2026:
///
/// > *"I booked a vehicle on this date and time and its showing to driver app
/// > but in customer app its vanished... In customer app it must show in On
/// > Going but that trip is nowhere."*
/// > *"I was thinking all booking must go to my booking tab then it will be
/// > good... when a bid is accepted OR when my trip is accepted then all
/// > bookings goes to my bookings tab. My booking section will be same for all
/// > kind of trips so nobody will get confused."*
/// > *"when we are in guest mode then in every section it shows to login but in
/// > BID section it was not showing Login. It was a blank screen."*
///
/// The tab rules are pure Dart and are run for real below. The wiring around
/// them needs Firebase, GetX and a Flutter binding, so it is pinned with source
/// tests — the same shape Sessions 8 and 9 used.
void main() {
  // ---------------------------------------------------------------------
  // 1. Which tab a booking lands in
  // ---------------------------------------------------------------------
  group('every kind of booking sorts into the same four tabs', () {
    test('an accepted bid is On Going, because the award sets the ride status', () {
      // `BiddingService.acceptOffer` patches the ride with
      // `status: Constant.driverAccepted`. Nothing bidding-specific is needed
      // here — that is the point. It was already true, and it is why the Bid
      // section does not need a Booked tab of its own.
      expect(BookingTab.forRideStatus('Driver Accepted'), BookingTab.onGoing);
    });

    test('an ordinary ride keeps the tab it has always had', () {
      expect(BookingTab.forRideStatus('Order Placed'), BookingTab.isNew);
      expect(BookingTab.forRideStatus('In Transit'), BookingTab.onGoing);
      expect(BookingTab.forRideStatus('Order Completed'), BookingTab.completed);
      expect(BookingTab.forRideStatus('Order Cancelled'), BookingTab.cancelled);
      expect(BookingTab.forRideStatus('something else'), isNull);
    });

    test('a booked full-vehicle trip is On Going — the tab the client looked in', () {
      expect(BookingTab.forTripStatus(DriverTripStatus.booked), BookingTab.onGoing);
    });

    test('a trip the driver withdrew, or that ran out, is Cancelled', () {
      expect(BookingTab.forTripStatus(DriverTripStatus.cancelled), BookingTab.cancelled);
      expect(BookingTab.forTripStatus(DriverTripStatus.expired), BookingTab.cancelled);
    });

    test('a booked trip is never moved to Completed by this APP', () {
      // Session 10 asserted there was no `completed` status at all, which was
      // the defect: a booked trip sat in On Going for ever. Session 14 added
      // one - written by the maintenance sweep, on the server clock. What
      // still holds, and is the part that matters, is that neither app writes
      // it. If this app decided a trip was finished, Ride History and the
      // driver's own My Trips could disagree about the same trip.
      expect(DriverTripStatus.all.contains(DriverTripStatus.completed), isTrue);
      expect(BookingTab.forTripStatus(DriverTripStatus.completed), BookingTab.completed);
      expect(BookingTab.rideStatuses[BookingTab.completed], <String>['Order Completed']);

      // A ride reaches Completed through its own `Order Completed` status, not
      // through the trip status. The two paths stay separate.
      expect(BookingTab.rideStatuses[BookingTab.completed]!.contains(DriverTripStatus.completed), isFalse);
    });
  });

  // ---------------------------------------------------------------------
  // 2. The merge
  // ---------------------------------------------------------------------
  group('rides and trips interleave newest first', () {
    CabOrderModel ride(String id, String status, DateTime createdAt) {
      return CabOrderModel.fromJson(<String, dynamic>{
        'id': id,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      });
    }

    DriverTripModel trip(String id, String status, DateTime reservedAt) {
      return DriverTripModel.fromJson(<String, dynamic>{
        DriverTripFields.id: id,
        DriverTripFields.driverId: 'drv1',
        DriverTripFields.status: status,
        DriverTripFields.reservedBy: 'cust1',
        DriverTripFields.reservedAt: Timestamp.fromDate(reservedAt),
        DriverTripFields.createdAt: Timestamp.fromDate(reservedAt.subtract(const Duration(hours: 3))),
      });
    }

    test('the trip from the screenshot appears in On Going beside the rides', () {
      final List<BookingEntry> onGoing = BookingEntry.merge(
        rides: <CabOrderModel>[ride('r1', 'Driver Accepted', DateTime(2026, 9, 7, 10))],
        trips: <DriverTripModel>[trip('t1', DriverTripStatus.booked, DateTime(2026, 9, 7, 16, 49))],
        tab: BookingTab.onGoing,
      );

      expect(onGoing.map((BookingEntry e) => e.id).toList(), <String>['t1', 'r1']);
      expect(onGoing.first.isTrip, isTrue);
      expect(onGoing.last.isTrip, isFalse);
    });

    test('a tab only ever holds what belongs to it', () {
      final List<CabOrderModel> rides = <CabOrderModel>[
        ride('r1', 'Order Placed', DateTime(2026, 9, 7, 12)),
        ride('r2', 'Order Completed', DateTime(2026, 9, 6, 12)),
      ];
      final List<DriverTripModel> trips = <DriverTripModel>[
        trip('t1', DriverTripStatus.booked, DateTime(2026, 9, 7, 13)),
        trip('t2', DriverTripStatus.cancelled, DateTime(2026, 9, 5, 13)),
      ];

      expect(BookingEntry.merge(rides: rides, trips: trips, tab: BookingTab.isNew).map((BookingEntry e) => e.id), <String>['r1']);
      expect(BookingEntry.merge(rides: rides, trips: trips, tab: BookingTab.onGoing).map((BookingEntry e) => e.id), <String>['t1']);
      expect(BookingEntry.merge(rides: rides, trips: trips, tab: BookingTab.completed).map((BookingEntry e) => e.id), <String>['r2']);
      expect(BookingEntry.merge(rides: rides, trips: trips, tab: BookingTab.cancelled).map((BookingEntry e) => e.id), <String>['t2']);
    });

    test('a booking with no usable date sorts last, not first', () {
      final DriverTripModel undated = DriverTripModel.fromJson(<String, dynamic>{
        DriverTripFields.id: 't0',
        DriverTripFields.status: DriverTripStatus.booked,
        DriverTripFields.reservedBy: 'cust1',
      });

      final List<BookingEntry> merged = BookingEntry.merge(
        rides: <CabOrderModel>[ride('r1', 'Driver Accepted', DateTime(2026, 9, 1))],
        trips: <DriverTripModel>[undated],
        tab: BookingTab.onGoing,
      );

      expect(merged.map((BookingEntry e) => e.id).toList(), <String>['r1', 't0']);
    });

    test('a trip falls back to when it was posted if the reservation stamp is missing', () {
      final DriverTripModel posted = DriverTripModel.fromJson(<String, dynamic>{
        DriverTripFields.id: 't9',
        DriverTripFields.status: DriverTripStatus.booked,
        DriverTripFields.reservedBy: 'cust1',
        DriverTripFields.createdAt: Timestamp.fromDate(DateTime(2026, 9, 7, 20)),
      });

      expect(BookingEntry.trip(posted).sortedOn, DateTime(2026, 9, 7, 20));

      // ...and it still outranks an older ride, which is the point of the
      // fallback: a booking with a date must never sink below one without.
      final List<BookingEntry> merged = BookingEntry.merge(
        rides: <CabOrderModel>[ride('r1', 'Driver Accepted', DateTime(2026, 9, 7, 9))],
        trips: <DriverTripModel>[posted],
        tab: BookingTab.onGoing,
      );
      expect(merged.first.id, 't9');
    });
  });

  // ---------------------------------------------------------------------
  // 3. The wiring
  // ---------------------------------------------------------------------
  group('Ride History is the one place a booking ends up', () {
    final String historyController = File('lib/controllers/my_cab_booking_controller.dart').readAsStringSync();
    final String history = File('lib/screen_ui/cab_service_screens/my_cab_booking_screen.dart').readAsStringSync();
    final String feed = File('lib/utils/booked_trips_feed.dart').readAsStringSync();

    test('it reads driver_trips as well as rides', () {
      expect(historyController.contains('BookedTripsFeed()'), isTrue);
      expect(feed.contains('DriverTripService.myBookedTripsQuery'), isTrue);
    });

    test('nothing writes a trip into the rides collection', () {
      // `driver_trips` exists so that an author-less document never reaches the
      // dispatcher or an existing ride query. The merge is display-only.
      expect(historyController.contains("collection('rides')"), isFalse);
      expect(feed.contains('CollectionName.rides'), isFalse);
    });

    test('both sources refresh and page together', () {
      expect(historyController.contains('bookedTrips.refresh()'), isTrue);
      expect(historyController.contains('bookedTrips.loadMore()'), isTrue);
      expect(historyController.contains('hasMoreEntries'), isTrue);
      expect(history.contains('controller.hasMoreEntries'), isTrue);
    });

    test('the feed is disposed with the screen', () {
      expect(historyController.contains('bookedTrips.dispose()'), isTrue);
    });

    test('the driver map is read in the builder, not in itemBuilder', () {
      // `itemBuilder` runs during layout, after GetX has stopped recording
      // dependencies, so a profile that lands late would never repaint its card.
      final int builderRead = history.indexOf('Map<String, UserModel>.from(controller.bookedTrips.drivers)');
      final int itemBuilder = history.indexOf('itemBuilder:', builderRead < 0 ? 0 : builderRead);
      expect(builderRead, greaterThan(-1));
      expect(builderRead, lessThan(itemBuilder));
    });
  });

  group('the Bid section is for bidding, not for booked rides', () {
    final String bidsController = File('lib/controllers/my_bids_controller.dart').readAsStringSync();
    final String bids = File('lib/screen_ui/cab_service_screens/my_bids_screen.dart').readAsStringSync();

    test('there is no Booked tab to duplicate Ride History', () {
      expect(bidsController.contains('tabKeys = <String>[openTab, closedTab]'), isTrue);
    });

    test('the section still knows what booked means, it just does not list it', () {
      expect(bidsController.contains('return bookedTab;'), isTrue);
    });

    test('it says where an accepted offer went', () {
      expect(bids.contains('Once you accept an offer, the ride moves to your Bookings tab.'), isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // 4. The blank guest screen
  // ---------------------------------------------------------------------
  group('a guest sees Log in, not a blank screen', () {
    /// The bug: a `GetX`/`Obx` builder that reads no observable throws
    /// "Improper use of a GetX has been detected" during build. In a release
    /// build that renders as an empty body with no message. The Bid section's
    /// signed-out and bidding-switched-off states read none, so a guest got a
    /// blank screen where every other section shows a Log in prompt.
    ///
    /// The guard is the same in both cab sections that branch before drawing a
    /// list: read one observable at the top of the builder, unconditionally.
    for (final List<String> screen in <List<String>>[
      <String>['lib/screen_ui/cab_service_screens/my_bids_screen.dart', 'Bid'],
      <String>['lib/screen_ui/cab_service_screens/available_trips_screen.dart', 'Trips'],
    ]) {
      test('${screen[1]}: the builder subscribes before it branches on sign-in', () {
        final String source = File(screen[0]).readAsStringSync();
        final int subscribe = source.indexOf('controller.isLoading.value;');
        final int branch = source.indexOf('!controller.isSignedIn');
        expect(subscribe, greaterThan(-1), reason: 'no unconditional observable read');
        expect(branch, greaterThan(-1));
        expect(subscribe, lessThan(branch), reason: 'the read must come before the branch that skips the list');
      });

      test('${screen[1]}: the signed-out state offers a way in', () {
        final String source = File(screen[0]).readAsStringSync();
        expect(source.contains('Please Log In to Continue'), isTrue);
        expect(source.contains('LoginScreen()'), isTrue);
      });
    }
  });
}
