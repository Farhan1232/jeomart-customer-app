import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Booking a normal ride and placing a bid must stay two separate flows.
///
/// This guards a regression the client hit in the field: *"when i started
/// normal ride its given me bid option in normal ride. I did not clicked on
/// bid"* and *"the normal taxi system is also vanished"*. The cause was that
/// every branch in the booking flow was gated on `Constant.isBiddingEnabled`,
/// which is one global admin-panel switch. Turning bidding on therefore did
/// not *add* bidding, it *replaced* the metered booking - the vehicle sheet
/// grew a price box, the pay button lost its amount, and Confirm Booking
/// became Send Offer to Drivers, for every customer, with no way back.
///
/// The mode now comes from the entry point instead: `CabBookingScreen.bidding`
/// is false for Ride on the home screen and true for the Bid section. These
/// are source checks because the invariant is about *which* flag each call
/// site reads, and both flags are ordinary bools that no type can tell apart.
void main() {
  String read(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return file.readAsStringSync();
  }

  /// Source lines with `//` comments and doc comments stripped, so prose about
  /// the old behaviour never fails a check about the code.
  List<String> codeLines(String source) {
    return source
        .split('\n')
        .where((String line) => !line.trimLeft().startsWith('//'))
        .toList(growable: false);
  }

  const String screen = 'lib/screen_ui/cab_service_screens/cab_booking_screen.dart';
  const String home = 'lib/screen_ui/cab_service_screens/cab_home_screen.dart';
  const String bids = 'lib/screen_ui/cab_service_screens/my_bids_screen.dart';
  const String controller = 'lib/controllers/cab_booking_controller.dart';

  group('the booking screen decides by entry point, not by the global switch', () {
    test('bidding defaults to off, so any forgotten call site books normally', () {
      expect(read(screen), contains('const CabBookingScreen({super.key, this.bidding = false});'));
    });

    test('the global switch is read in exactly one place, and never on its own', () {
      final List<String> hits = codeLines(read(screen))
          .where((String line) => line.contains('Constant.isBiddingEnabled'))
          .map((String line) => line.trim())
          .toList(growable: false);

      // One line only: the getter, which also requires `bidding`. Any other
      // use would be a sheet keying off the setting alone again.
      expect(hits, <String>['bool get isBidMode => bidding && Constant.isBiddingEnabled;']);
    });

    test('every bidding branch in the booking flow goes through isBidMode', () {
      final String source = read(screen);
      // The four places the two flows differ.
      expect(source, contains('final double sheetSize = isBidMode ? 0.58 : 0.40;'));
      expect(source, contains('if (isBidMode) Obx(() => offeredFareField(controller, isDark, compact: true)),'));
      expect(source, contains('if (isBidMode) offeredFareField(controller, isDark),'));
      expect(source, contains('title: isBidMode ? "Send Offer to Drivers".tr : "Confirm Booking".tr,'));
    });

    test('the pay button subscribes to a vehicle before it branches on the mode', () {
      // The bidding title is the constant string "Continue", so on that branch
      // the builder used to read no observable at all - and an Obx that
      // subscribes to nothing throws "[Get] the improper use of a GetX has
      // been detected", drawn as an error box where the button belongs. The
      // read has to come first, not inside the metered branch.
      final String source = read(screen);
      final int subscribe = source.indexOf('final VehicleType selected = controller.selectedVehicleType.value;');
      final int branch = source.indexOf('title: isBidMode');
      expect(subscribe, greaterThan(-1), reason: 'the unconditional read is gone');
      expect(branch, greaterThan(-1));
      expect(subscribe, lessThan(branch), reason: 'the observable must be read before the mode is branched on');
    });
  });

  group('the entry points', () {
    test('Ride on the home screen opens the plain booking flow', () {
      final List<String> hits = codeLines(read(home))
          .where((String line) => line.contains('CabBookingScreen('))
          .map((String line) => line.trim())
          .toList(growable: false);

      expect(hits, isNotEmpty, reason: 'the Ride tile no longer opens the booking screen');
      for (final String hit in hits) {
        expect(hit, contains('const CabBookingScreen()'));
        expect(hit, isNot(contains('bidding')), reason: 'Ride must never open the bid flow: $hit');
      }
    });

    test('the Bid section is the only thing that opens the bid flow', () {
      final List<String> hits = codeLines(read(bids))
          .where((String line) => line.contains('CabBookingScreen('))
          .map((String line) => line.trim())
          .toList(growable: false);

      expect(hits.length, 2, reason: 'expected the Place a Bid button and the live-request card');
      for (final String hit in hits) {
        expect(hit, contains('CabBookingScreen(bidding: true)'));
      }
    });
  });

  group('the offer box is never filled from inside a build', () {
    // Writing to a TextEditingController that a TextField is already listening
    // to rebuilds that field. Done from a builder it marks the tree dirty in
    // the middle of a build, which the framework reports on screen - the
    // client's "it shown me an error".
    test('the screen only primes the fare from a tap handler', () {
      final List<String> hits = codeLines(read(screen))
          .where((String line) => line.contains('primeOfferedFare()'))
          .map((String line) => line.trim())
          .toList(growable: false);

      expect(hits, <String>['controller.primeOfferedFare();'],
          reason: 'the only remaining call is the Continue handler on the payment sheet');
    });

    test('the controller primes from workers, and only for a bid', () {
      final String source = read(controller);
      expect(source, contains('if (bidMode && distance.value > 0) primeOfferedFare();'));
      expect(source, contains('ever<double>(distance, (double km) {'));
      expect(source, contains('if (bidMode && km > 0) primeOfferedFare();'));
    });

    test('the mode is a plain field, so setting it cannot schedule a rebuild', () {
      expect(read(controller), contains('bool bidMode = false;'));
      expect(read(controller), isNot(contains('RxBool bidMode')));
    });
  });

  test('placing a normal ride survives a user document with no ride list', () {
    // `inProgressOrderID!.add(...)` threw on a customer who had never taken a
    // ride. The bidding path already guarded it; the normal one did not, and
    // the normal one is the path this session put back in reach.
    // Session 30 moved both lines inside a `try`, so the indentation changed;
    // what matters is that the guard is still immediately above the append.
    final String source = read(controller);
    for (final Match append in RegExp(r'userModel\.value\.inProgressOrderID!\.add\(').allMatches(source)) {
      final String before = source.substring(0, append.start);
      expect(before.trimRight().endsWith('userModel.value.inProgressOrderID ??= [];'), isTrue,
          reason: 'every append must be preceded by the null guard');
    }
    expect(RegExp(r'userModel\.value\.inProgressOrderID!\.add\(').allMatches(source).length, greaterThanOrEqualTo(1));
  });
}
