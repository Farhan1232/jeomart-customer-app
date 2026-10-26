import 'dart:io';

import 'package:customer/models/zone_model.dart';
import 'package:customer/utils/zone_selection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 30 - the four customer-app defects the client reported on 11 Sep:
/// a trip booking that answered with an error, a message whose Back button left
/// the app blank or moved the customer's area, ride requests that never reached
/// a driver, and a banner that did nothing (or, before Session 28, froze).
void main() {
  String read(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing - this test is stale');
    return file.readAsStringSync();
  }

  /// Source with its comment lines dropped, so a comment quoting the old code
  /// is not mistaken for the old code still being there.
  String code(String source) => source
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//') && !line.trimLeft().startsWith('*') && !line.trimLeft().startsWith('///'))
      .join('\n');

  group('2. opening a message and pressing Back', () {
    test('a notification is opened on top of the screen, never instead of it', () {
      final String source = code(read('lib/utils/notification_service.dart'));

      expect(source.contains('Get.offAll'), isFalse,
          reason: 'offAll threw the customer\'s whole stack away - the section they were in, '
              'and anything to go Back to');
      expect(source, contains('_openOnTop('));
      expect(source.contains('DashBoardScreen()'), isFalse,
          reason: 'the multi-vendor dashboard is not where a cab or parcel customer belongs');
    });

    test('a message that started the app waits for the splash to finish', () {
      final String source = read('lib/utils/notification_service.dart');

      // The splash ends with `Get.offAll(...)`, which would take a screen
      // pushed before it down with it.
      expect(source, contains("final String route = Get.currentRoute;"));
      expect(source, contains("route.contains('SplashScreen')"));
      expect(source, contains('_splashWaitAttempts'));
    });

    test('leaving Help & Support pops, and falls back to the section list', () {
      final String source = code(read('lib/screen_ui/help_support_screen/help_support_screen.dart'));

      expect(source.contains('Get.offAll(DashBoardScreen())'), isFalse);
      expect(source, contains('Get.key.currentState?.canPop() == true'));
      expect(source, contains('Get.offAll(const ServiceListScreen())'),
          reason: 'the app\'s home is the section list, not one section\'s dashboard');
      expect('_leave()'.allMatches(source).length, greaterThanOrEqualTo(2),
          reason: 'the arrow and the system Back button must do the same thing');
    });

    test('a rebuilt home screen cannot move the customer to another area', () {
      final List<String> controllers = <String>[
        'lib/controllers/food_home_controller.dart',
        'lib/controllers/dine_in_controller.dart',
        'lib/controllers/category_restaurant_controller.dart',
        'lib/controllers/on_demand_home_controller.dart',
      ];

      for (final String path in controllers) {
        final String source = code(read(path));
        expect(source, contains('ZoneSelection.apply('), reason: '$path must use the shared rule');
        expect(source.contains('Constant.selectedZone = value[i];'), isFalse,
            reason: '$path assigned a zone on every miss as well as on the match, '
                'so a customer in no zone ended up in whichever came last');
      }
    });

    group('ZoneSelection', () {
      ZoneModel zone(String id, List<List<double>> points) => ZoneModel(
            id: id,
            name: id,
            publish: true,
            area: <GeoPoint>[for (final List<double> p in points) GeoPoint(p[0], p[1])],
          );

      // Two squares, far apart.
      final ZoneModel here = zone('here', <List<double>>[
        <double>[0, 0],
        <double>[0, 1],
        <double>[1, 1],
        <double>[1, 0],
      ]);
      final ZoneModel elsewhere = zone('elsewhere', <List<double>>[
        <double>[50, 50],
        <double>[50, 51],
        <double>[51, 51],
        <double>[51, 50],
      ]);

      test('a point inside a zone picks that zone', () {
        final ZoneChoice? choice = ZoneSelection.choose(<ZoneModel>[elsewhere, here], latitude: 0.5, longitude: 0.5);
        expect(choice!.zone!.id, 'here');
        expect(choice.isAvailable, isTrue);
      });

      test('overlapping zones do not flip the customer between them', () {
        // Kohat and Pakistan (Nationwide) both contain the same address on the
        // live project, and the old loop took whichever Firestore returned
        // first. The store list is filtered by the chosen zone.
        final ZoneModel wide = zone('wide', <List<double>>[
          <double>[-10, -10],
          <double>[-10, 10],
          <double>[10, 10],
          <double>[10, -10],
        ]);

        final ZoneChoice? choice = ZoneSelection.choose(
          <ZoneModel>[wide, here],
          latitude: 0.5,
          longitude: 0.5,
          current: here,
        );
        expect(choice!.zone!.id, 'here', reason: 'the zone in use still contains the point, so it stays');
        expect(choice.isAvailable, isTrue);
      });

      test('a point inside no zone keeps the area the customer already had', () {
        final ZoneChoice? choice = ZoneSelection.choose(
          <ZoneModel>[here, elsewhere],
          latitude: 20,
          longitude: 20,
          current: here,
        );
        expect(choice!.zone!.id, 'here', reason: 'the customer must not be moved to another city');
        expect(choice.isAvailable, isFalse, reason: 'but the app must know the area is not served');
      });

      test('with no zone at all, one is picked so nothing reads a null', () {
        final ZoneChoice? choice = ZoneSelection.choose(<ZoneModel>[here, elsewhere], latitude: 20, longitude: 20);
        expect(choice!.zone, isNotNull);
        expect(choice.isAvailable, isFalse);
      });

      test('no zones means no decision, and nothing is changed', () {
        expect(ZoneSelection.choose(<ZoneModel>[], latitude: 0.5, longitude: 0.5), isNull);
        expect(ZoneSelection.choose(null, latitude: 0.5, longitude: 0.5), isNull);
      });

      test('an unknown location does not move the customer either', () {
        final ZoneChoice? choice = ZoneSelection.choose(<ZoneModel>[elsewhere, here], latitude: null, longitude: null, current: here);
        expect(choice!.zone!.id, 'here');
        expect(choice.isAvailable, isFalse);
      });
    });
  });

  group('1. booking a driver\'s full-vehicle trip', () {
    test('a booking that went through is never reported as an error', () {
      final String source = code(read('lib/controllers/available_trips_controller.dart'));

      // The transaction is awaited inside its own try; everything after it -
      // the driver's notification, the list refresh, the tab switch - is
      // housekeeping and gets its own. One `try` around the whole method turned
      // any late failure into "Something went wrong. Please try again." on a
      // trip that was already booked.
      final int reserve = source.indexOf('result = await DriverTripService.reserveTrip(trip);');
      final int toast = source.indexOf('ShowToastDialog.showToast("Trip booked".tr);');
      final int notify = source.indexOf('await DriverTripService.notifyDriverOfReservation(trip);');
      final int refresh = source.indexOf('await tripsPaginator?.refresh();');

      expect(reserve, greaterThan(-1));
      expect(toast, greaterThan(reserve));
      expect(notify, greaterThan(toast), reason: 'the customer is told before the housekeeping runs');
      expect(refresh, greaterThan(toast));
      expect('} catch (error) {'.allMatches(source).length, greaterThanOrEqualTo(4),
          reason: 'each piece of housekeeping catches for itself');
    });

    test('booking a trip cannot be lost by the bookkeeping after it', () {
      // Both booking screens: the ride/trip document is written first, on its
      // own, and everything after it is allowed to fail without taking the
      // booking - or the loader - down with it.
      for (final String path in <String>[
        'lib/controllers/intercity_home_controller.dart',
        'lib/controllers/cab_booking_controller.dart',
      ]) {
        final String source = code(read(path));

        expect(source.contains('await FireStoreUtils.sendCabBookEmail(orderModel: orderModel);'), isFalse,
            reason: '$path: the confirmation e-mail is an SMTP connection from the phone - '
                'a booking must not wait behind it');
        expect(source, contains('unawaited(FireStoreUtils.sendCabBookEmail(orderModel: orderModel));'));

        // The guard Session 11 gave the ride screen, which the intercity copy
        // never had: `inProgressOrderID` is null on a profile that has never
        // held a ride, and the bare `!` threw after the trip was written.
        final int guards = '??= [];'.allMatches(source).length;
        final int appends = 'inProgressOrderID!.add('.allMatches(source).length;
        expect(guards, greaterThanOrEqualTo(appends),
            reason: '$path: every append is preceded by the null guard');
      }
    });

    test('a mail server that never answers cannot hold a booking open', () {
      final String source = code(read('lib/constant/constant.dart'));
      expect(source, contains('.timeout(_mailTimeout)'));
      expect(source, contains('on TimeoutException catch'));
    });

    test('the loader always comes down and the card is always released', () {
      final String source = code(read('lib/controllers/available_trips_controller.dart'));
      final int finallyAt = source.indexOf('} finally {');
      expect(finallyAt, greaterThan(-1));
      final String tail = source.substring(finallyAt);
      expect(tail, contains('ShowToastDialog.closeLoader();'));
      expect(tail, contains("bookingInFlight.value = '';"));
    });
  });

  group('4. tapping a banner', () {
    test('the app can see a browser, WhatsApp and the dialer', () {
      final String manifest = read('android/app/src/main/AndroidManifest.xml');

      // Android 11 hides other apps unless they are declared. Without this,
      // `canLaunchUrl` says no for every https link - and every advertising
      // banner on this project is an https://wa.me/... link.
      expect(manifest, contains('<data android:scheme="https" />'));
      expect(manifest, contains('<data android:scheme="http" />'));
      expect(manifest, contains('<data android:scheme="tel" />'));
    });

    test('a link is attempted even when canLaunchUrl says no', () {
      final String source = code(read('lib/utils/banner_tap.dart'));

      expect(source, contains('_launch(uri, LaunchMode.externalApplication)'));
      expect(source, contains('_launch(uri, LaunchMode.platformDefault)'));
      expect(source.contains('if (await canLaunchUrl(uri))'), isFalse,
          reason: 'a false "no" from the package manager must not be the last word');
      expect(source, contains('} catch (error) {'), reason: 'a launch that throws is a toast, not a crash');
    });

    test('a banner with no scheme is still opened', () {
      final String source = read('lib/utils/banner_tap.dart');
      expect(source, contains("if (!uri.hasScheme) uri = Uri.parse('https://\$trimmed');"));
    });
  });
}
