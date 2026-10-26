import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The customer's bidding section — "Choose Your Price".
///
/// The client's report was that bidding was unfindable: "I cant use bidding and
/// its not showing... oh i seen now its in last part of the order but thats not
/// good", and then, twice, "make another section for bid same like my trips for
/// drivers... in bottombar".
///
/// These are source tests. The screens they check need GetX, Firebase and a
/// running Flutter binding, so what is pinned here is the wiring a widget test
/// could not reach anyway: that the section exists, that it is in the bar, and
/// that the bar and the page list cannot drift apart — which is the defect the
/// old two-hand-written-lists version was one edit away from.
void main() {
  final String controller = File('lib/controllers/cab_dashboard_controller.dart').readAsStringSync();
  final String screen = File('lib/screen_ui/cab_service_screens/cab_dashboard_screen.dart').readAsStringSync();

  group('the Bid section is in the customer bottom bar', () {
    test('the bidding screen exists', () {
      expect(File('lib/screen_ui/cab_service_screens/my_bids_screen.dart').existsSync(), isTrue);
      expect(File('lib/controllers/my_bids_controller.dart').existsSync(), isTrue);
    });

    test('the dashboard routes a tab to it', () {
      expect(controller.contains('MyBidsScreen()'), isTrue);
      expect(controller.contains('bidTab'), isTrue);
    });

    test('it has an icon of its own, and a NEW ribbon', () {
      // The tab is labelled "My Price" now and draws a price tag rather than
      // the old `ic_bid_cab.svg` gavel - the client asked for both. What this
      // still pins is that the tab has an icon nothing else uses, and that the
      // NEW mark is on it.
      expect(screen.contains('CabDashboardController.bidTab: Icons.sell_outlined'), isTrue);
      expect(screen.contains('CabDashboardController.bidTab,'), isTrue, reason: 'bid tab must be in _newTabs');
      expect(screen.contains('"NEW".tr'), isTrue);
    });

    test('the label is the client\'s wording, and only the label changed', () {
      expect(screen.contains("return 'My Price'.tr;"), isTrue);
      // The tab key, and therefore the route and every backend field, is
      // untouched - this rename is display text only.
      expect(controller.contains("static const String bidTab = 'bid';"), isTrue);
    });

    test('the heading is the one the client asked for', () {
      final String bids = File('lib/screen_ui/cab_service_screens/my_bids_screen.dart').readAsStringSync();
      expect(bids.contains('Choose Your Price'), isTrue);
      expect(bids.contains('Place a Bid'), isTrue);
    });
  });

  group('the bar and the page list cannot drift apart', () {
    test('both are generated from one list of tabs', () {
      expect(controller.contains('pageList.value = tabs.map(_pageFor).toList()'), isTrue);
      expect(screen.contains('CabDashboardController.tabs'), isTrue,
          reason: 'the bar must be built from the same list the pages are');
    });

    test('the wallet tab is the only conditional entry, in one place', () {
      expect(controller.contains("if (Constant.walletSetting != false) walletTab"), isTrue);
      // The old shape - two full literal lists, one per branch - is what let an
      // index mean a different page depending on a setting.
      expect(controller.contains('pageList.value = [CabHomeScreen()'), isFalse);
    });

    test('every tab has an icon and a label', () {
      for (final String tab in <String>['homeTab', 'bookingsTab', 'bidTab', 'tripsTab', 'walletTab', 'profileTab']) {
        expect(controller.contains('static const String $tab'), isTrue, reason: tab);
        expect(screen.contains('CabDashboardController.$tab'), isTrue, reason: '$tab has no icon entry');
      }
    });

    test('the selected index is clamped, so a shorter bar cannot index past its pages', () {
      expect(screen.contains('.clamp(0, tabs.length - 1)'), isTrue);
    });
  });

  group('the bid box appears before the last sheet', () {
    final String booking = File('lib/screen_ui/cab_service_screens/cab_booking_screen.dart').readAsStringSync();

    test('the vehicle sheet - the screen after the destination - carries the fare box', () {
      final int vehicleSheet = booking.indexOf('Widget vehicleSelection(');
      final int confirmSheet = booking.indexOf('Widget conformRide(');
      expect(vehicleSheet, greaterThan(-1));

      final int boxOnVehicleSheet = booking.indexOf('offeredFareField(controller, isDark, compact: true)', vehicleSheet);
      expect(boxOnVehicleSheet, greaterThan(vehicleSheet));
      if (confirmSheet > vehicleSheet) {
        expect(boxOnVehicleSheet, lessThan(confirmSheet),
            reason: 'the box must be on the vehicle sheet, not only on the confirm sheet');
      }
    });

    test('it is the same controller as the confirm sheet, so it is one number', () {
      expect('offeredFareTextEditController'.allMatches(booking).length, greaterThanOrEqualTo(1));
      expect(booking.contains('offeredFareField(controller, isDark)'), isTrue,
          reason: 'the confirm sheet still shows it too, still editable');
    });

    test('an unusable offer is refused on the vehicle sheet rather than three sheets later', () {
      final int vehicleSheet = booking.indexOf('Widget vehicleSelection(');
      final int guard = booking.indexOf('controller.validateOfferedFare()', vehicleSheet);
      expect(guard, greaterThan(vehicleSheet));
    });
  });

  group('a booked full-vehicle trip is still reachable', () {
    final String trips = File('lib/screen_ui/cab_service_screens/available_trips_screen.dart').readAsStringSync();
    final String tripsController = File('lib/controllers/available_trips_controller.dart').readAsStringSync();
    final String history = File('lib/screen_ui/cab_service_screens/my_cab_booking_screen.dart').readAsStringSync();
    final String historyController = File('lib/controllers/my_cab_booking_controller.dart').readAsStringSync();

    // The tab this group was written for has moved. The client asked for one
    // booking list rather than two: "My booking section will be same for all
    // kind of trips so nobody will get confused. Only to place bid or to see
    // trips that sections will work." So the assertions moved with it - what
    // must stay true is that a booked trip has a home, not which screen it is.
    test('the Trips section is browsing only now', () {
      expect(trips.contains('AvailableTripsController.bookedTab'), isFalse,
          reason: 'the second tab moved to Ride History');
      expect(tripsController.contains('static const String bookedTab'), isFalse);
      expect(tripsController.contains('bookingsPaginator'), isFalse);
    });

    test('Ride History is where a booked trip is listed', () {
      expect(historyController.contains('BookedTripsFeed()'), isTrue);
      expect(historyController.contains('getEntriesForTab'), isTrue);
      expect(history.contains('BookedTripCard('), isTrue);
    });

    test('booking one moves the customer to the tab that now holds it', () {
      expect(tripsController.contains('CabDashboardController.openBookings(bookingTab: BookingTab.onGoing)'), isTrue);
    });

    test('the bookings query needs no composite index to work', () {
      final String service = File('lib/service/driver_trip_service.dart').readAsStringSync();
      final int query = service.indexOf('myBookedTripsQuery');
      expect(query, greaterThan(-1));
      final String body = service.substring(query, service.indexOf('}', query));
      expect(body.contains('orderBy'), isFalse,
          reason: 'an equality on one field is served by the automatic index; adding orderBy would need a deploy first');
      expect(body.contains('DriverTripFields.reservedBy'), isTrue);
    });

    test('the card shows the driver and both ways to reach them', () {
      final String card = File('lib/widget/booked_trip_card.dart').readAsStringSync();
      expect(card.contains('Your driver'), isTrue);
      expect(card.contains('Constant.makePhoneCall'), isTrue);
      expect(card.contains('ChatScreen()'), isTrue);
    });
  });
}
