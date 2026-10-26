import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/models/ride_bid_model.dart';
import 'package:customer/utils/bidding_fare_rules.dart';
import 'package:customer/utils/bidding_settings.dart';
import 'package:customer/utils/ride_author_privacy.dart';
import 'package:customer/utils/ride_bid_ledger.dart';
import 'package:customer/utils/ride_bidding_state.dart';

/// An in-memory Firestore with the same optimistic concurrency real
/// transactions have: if any document a body READ changed before its writes
/// landed, the whole body is replayed against the newer values.
///
/// That replay is the mechanism the "only one driver can win" requirement
/// rests on, so it is modelled here rather than assumed, and the tests below
/// assert that collisions really happened.
class FakeBidStore implements BidTransactionRunner {
  FakeBidStore({this.maxAttempts = 64});

  final int maxAttempts;

  final Map<String, Map<String, dynamic>> docs = <String, Map<String, dynamic>>{};
  final Map<String, int> _versions = <String, int>{};

  /// How many times a body had to be replayed because of a conflict.
  int retries = 0;

  /// How many transactions committed at least one write.
  int commits = 0;

  void seed(String path, Map<String, dynamic> data) {
    docs[path] = Map<String, dynamic>.from(data);
    _versions[path] = (_versions[path] ?? 0) + 1;
  }

  Map<String, dynamic>? read(String path) => docs[path];

  @override
  Future<T> run<T>(Future<T> Function(BidTransactionContext ctx) body) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final _FakeContext ctx = _FakeContext(this);
      final T result = await body(ctx);

      // Yield, so bodies started together really do interleave between their
      // reads and their writes.
      await Future<void>.delayed(Duration.zero);

      final bool stale = ctx.readVersions.entries.any((MapEntry<String, int> e) => (_versions[e.key] ?? 0) != e.value);
      if (stale) {
        retries++;
        continue;
      }

      if (ctx.writes.isNotEmpty) {
        for (final _FakeWrite write in ctx.writes) {
          final Map<String, dynamic> existing = docs[write.path] ?? <String, dynamic>{};
          if (write.isUpdate && !docs.containsKey(write.path)) {
            // Firestore's update() fails on a missing document. Skipping keeps
            // the fake honest rather than silently creating the row.
            continue;
          }
          docs[write.path] = <String, dynamic>{...existing, ...write.data};
          _versions[write.path] = (_versions[write.path] ?? 0) + 1;
        }
        commits++;
      }
      return result;
    }
    throw StateError('bidding transaction gave up after $maxAttempts attempts');
  }
}

class _FakeWrite {
  _FakeWrite(this.path, this.data, {required this.isUpdate});

  final String path;
  final Map<String, dynamic> data;
  final bool isUpdate;
}

class _FakeContext implements BidTransactionContext {
  _FakeContext(this._store);

  final FakeBidStore _store;
  final Map<String, int> readVersions = <String, int>{};
  final List<_FakeWrite> writes = <_FakeWrite>[];

  @override
  Future<BidDocument> get(String path) async {
    readVersions[path] = _store._versions[path] ?? 0;
    final Map<String, dynamic>? data = _store.docs[path];
    return _FakeDocument(data);
  }

  @override
  void set(String path, Map<String, dynamic> data, {bool merge = true}) => writes.add(_FakeWrite(path, data, isUpdate: false));

  @override
  void update(String path, Map<String, dynamic> data) => writes.add(_FakeWrite(path, data, isUpdate: true));
}

class _FakeDocument implements BidDocument {
  _FakeDocument(this._data);

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? get data => _data == null ? null : Map<String, dynamic>.from(_data);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const BiddingSettings kBiddingOn = BiddingSettings(enabled: true);

const BiddingSettings kBiddingOnWithFloor = BiddingSettings(
  enabled: true,
  minimumFarePerKmEnabled: true,
  minimumFarePerKm: 50,
);

final DateTime kNow = DateTime.utc(2026, 9, 5, 12, 0, 0);

Map<String, dynamic> customerProfile() => <String, dynamic>{
      'id': 'cust1',
      'firstName': 'Amina',
      'lastName': 'Yusuf',
      'profilePictureURL': 'https://example.test/a.png',
      'role': 'customer',
      'reviewsCount': '4',
      'reviewsSum': '18',
      'fcmToken': 'cust-token',
      'phoneNumber': '5551234567',
      'countryCode': '+357',
      'countryISOCode': 'CY',
      'email': 'amina@example.test',
      'wallet_amount': 120,
      'shippingAddress': <dynamic>[
        <String, dynamic>{'address': '12 Home Street'}
      ],
      'userBankDetails': <String, dynamic>{'accountNumber': '000111222'},
    };

/// A bidding ride, exactly as `BiddingService.placeBiddingRide` writes it.
Map<String, dynamic> biddingRide({
  String status = RideBiddingStatus.open,
  List<String> eligible = const <String>['drvA', 'drvB'],
  double distanceKm = 10,
  double offeredFare = 500,
  double minimumAllowedFare = 0,
  String? winner,
  DateTime? expiresAt,
}) =>
    <String, dynamic>{
      'id': 'ride1',
      'authorID': 'cust1',
      'status': 'Order Placed',
      'distance': distanceKm.toString(),
      'sourceLocationName': '12 Harbour Road',
      'destinationLocationName': '4 Airport Way',
      'sourceLocation': <String, dynamic>{'latitude': 0.0, 'longitude': 0.0},
      'destinationLocation': <String, dynamic>{'latitude': 0.0, 'longitude': 0.05},
      'author': RideAuthorPrivacy.redact(customerProfile()),
      RideBiddingFields.enabled: true,
      RideBiddingFields.status: status,
      RideBiddingFields.offeredFare: offeredFare,
      RideBiddingFields.minimumAllowedFare: minimumAllowedFare,
      RideBiddingFields.distanceKm: distanceKm,
      RideBiddingFields.eligibleDriverIds: eligible,
      RideBiddingFields.winningBidId: winner,
      RideBiddingFields.bidCount: 0,
      RideBiddingFields.expiresAt: Timestamp.fromDate(expiresAt ?? kNow.add(const Duration(minutes: 5))),
    };

/// A ride booked the ordinary way, with no bidding fields at all.
Map<String, dynamic> normalRide() => <String, dynamic>{
      'id': 'ride0',
      'authorID': 'cust1',
      'status': 'Order Placed',
      'distance': '10.0',
      'author': customerProfile(),
    };

Map<String, dynamic> bidDoc({
  required String driverId,
  required num amount,
  String status = RideBidStatus.pending,
  String type = RideBidType.counter,
  DateTime? expiresAt,
}) =>
    <String, dynamic>{
      'id': driverId,
      'rideId': 'ride1',
      'driverId': driverId,
      'customerId': 'cust1',
      'amount': amount,
      'type': type,
      'status': status,
      'createdAt': Timestamp.fromDate(kNow),
      'expiresAt': Timestamp.fromDate(expiresAt ?? kNow.add(const Duration(minutes: 5))),
      'driverName': 'Driver $driverId',
    };

RideBidModel newBid({required String driverId, required num amount, String type = RideBidType.counter, String? note}) => RideBidModel(
      id: driverId,
      rideId: 'ride1',
      driverId: driverId,
      customerId: 'cust1',
      amount: amount,
      type: type,
      status: RideBidStatus.pending,
      note: note,
      driverName: 'Driver $driverId',
      driverRating: 4.5,
      driverCompletedTrips: 120,
      vehicleType: 'Sedan',
      airConditioning: true,
    );

RideBidLedger ledgerOn(FakeBidStore store) => RideBidLedger(store);

void main() {
  // -----------------------------------------------------------------------
  // 1. The global switch
  // -----------------------------------------------------------------------
  group('BIDDING ON/OFF', () {
    test('a missing settings document reads as everything off', () {
      final BiddingSettings settings = BiddingSettings.fromJson(null);
      expect(settings.enabled, isFalse);
      expect(settings.minimumFarePerKmEnabled, isFalse);
      expect(settings.hasMinimumFare, isFalse);
    });

    test('an empty settings document reads as everything off', () {
      expect(BiddingSettings.fromJson(<String, dynamic>{}).enabled, isFalse);
    });

    test('the switch is read from the settings document, not hardcoded', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'enabled': true,
        'minimumFarePerKmEnabled': true,
        'minimumFarePerKm': 50,
        'bidExpiryMinutes': 7,
        'maxDriversPerRequest': 12,
      });
      expect(settings.enabled, isTrue);
      expect(settings.minimumFarePerKm, 50);
      expect(settings.bidExpiryMinutes, 7);
      expect(settings.maxDriversPerRequest, 12);
    });

    test('numeric strings are accepted, as older hand-edited documents store them', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'enabled': 'true',
        'minimumFarePerKmEnabled': 1,
        'minimumFarePerKm': '50',
      });
      expect(settings.enabled, isTrue);
      expect(settings.minimumFarePerKmEnabled, isTrue);
      expect(settings.minimumFarePerKm, 50);
    });

    test('expiry and fan-out are clamped to sane values', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'bidExpiryMinutes': 9999,
        'maxDriversPerRequest': 0,
      });
      expect(settings.bidExpiryMinutes, 120);
      expect(settings.maxDriversPerRequest, 1);
    });
  });

  // -----------------------------------------------------------------------
  // 1b. TEMPORARY DEVELOPMENT TEST SCOPE (settings/biddingSettings.testUids)
  //
  // These exist to prove the scope is INERT unless someone populates it, so
  // the shipped production behaviour is still the plain global switch.
  // -----------------------------------------------------------------------
  group('temporary test scope', () {
    test('with no testUids field the scope is empty', () {
      expect(BiddingSettings.fromJson(<String, dynamic>{'enabled': false}).testUids, isEmpty);
      expect(BiddingSettings.fromJson(null).testUids, isEmpty);
    });

    test('OFF with an empty scope is off for everybody, exactly like enabled alone', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{'enabled': false});
      expect(settings.isEnabledFor('anyone'), isFalse);
      expect(settings.isEnabledFor(''), isFalse);
      expect(settings.isEnabledFor(null), isFalse);
      expect(settings.isEnabledFor('anyone'), settings.enabled);
    });

    test('ON is on for everybody, whatever the scope says', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'enabled': true,
        'testUids': <String>['someone-else'],
      });
      expect(settings.isEnabledFor('a-real-customer'), isTrue);
      expect(settings.isEnabledFor(null), isTrue);
    });

    test('OFF with a populated scope admits only the listed uids', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'enabled': false,
        'testUids': <String>['test-cust', 'test-driver'],
      });
      expect(settings.isEnabledFor('test-cust'), isTrue);
      expect(settings.isEnabledFor('test-driver'), isTrue);
      expect(settings.isEnabledFor('a-real-customer'), isFalse);
      expect(settings.isEnabledFor(''), isFalse);
      expect(settings.isEnabledFor(null), isFalse);
    });

    test('blanks and non-strings are dropped from the scope', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'testUids': <dynamic>['a', '', '   ', 7, null, ' b '],
      });
      expect(settings.testUids, <String>['a', '7', 'b']);
    });

    test('a non-list testUids is ignored rather than throwing', () {
      expect(BiddingSettings.fromJson(<String, dynamic>{'testUids': 'test-cust'}).testUids, isEmpty);
      expect(BiddingSettings.fromJson(<String, dynamic>{'testUids': 'test-cust'}).isEnabledFor('test-cust'), isFalse);
    });

    test('toJson omits the scope entirely when it is empty', () {
      expect(const BiddingSettings().toJson().containsKey('testUids'), isFalse);
      expect(
        const BiddingSettings(testUids: <String>['x']).toJson()['testUids'],
        <String>['x'],
      );
    });

    test('the scope cannot switch the minimum-fare floor on by itself', () {
      final BiddingSettings settings = BiddingSettings.fromJson(<String, dynamic>{
        'enabled': false,
        'minimumFarePerKmEnabled': true,
        'minimumFarePerKm': 50,
        'testUids': <String>['test-cust'],
      });
      expect(settings.isEnabledFor('test-cust'), isTrue);
      expect(settings.hasMinimumFare, isFalse,
          reason: 'hasMinimumFare still keys on the global switch, as shipped');
    });
  });

  // -----------------------------------------------------------------------
  // 2. NORMAL BOOKING WHILE BIDDING IS OFF
  // -----------------------------------------------------------------------
  group('normal booking is untouched while bidding is off', () {
    test('a ride written by the normal flow has no bidding state', () {
      final RideBiddingState state = RideBiddingState.fromJson(normalRide());
      expect(state.enabled, isFalse);
      expect(state.acceptsOffers, isFalse);
      expect(state.status, isNull);
      expect(state.winningBidId, isNull);
    });

    test('the normal flow still embeds the full author, phone included', () {
      // The privacy change is scoped to bidding rides: a normal booking keeps
      // storing what it always stored, so the dispatched driver's contact card
      // works exactly as before.
      expect(normalRide()['author']['phoneNumber'], '5551234567');
    });

    test('no offer can be filed against a non-bidding ride', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride0', normalRide());
      final SubmitBidResult result = await RideBidLedger(store).submitBid(
        bid: newBid(driverId: 'drvA', amount: 400)..rideId = 'ride0',
        settings: kBiddingOn,
        now: kNow,
      );
      expect(result, SubmitBidResult.notOpen);
      expect(store.docs.containsKey('rides/ride0/bids/drvA'), isFalse);
    });

    test('a bidding ride created while the floor is off carries no floor', () {
      final RideBiddingState state = RideBiddingState.fromJson(biddingRide());
      expect(state.enabled, isTrue);
      expect(state.minimumAllowedFare, 0);
    });
  });

  // -----------------------------------------------------------------------
  // 3. MINIMUM FARE PER KM
  // -----------------------------------------------------------------------
  group('MINIMUM FARE PER KM', () {
    test('the briefed example: 50 x 10 KM = 500', () {
      expect(
        BiddingFareRules.minimumAllowedFare(settings: kBiddingOnWithFloor, distanceKm: 10),
        500,
      );
    });

    test('the floor is one global rate, not per vehicle type', () {
      // The same settings object produces the same rate for any ride; there is
      // no vehicle input to the calculation at all.
      expect(BiddingFareRules.minimumAllowedFare(settings: kBiddingOnWithFloor, distanceKm: 3), 150);
      expect(BiddingFareRules.minimumAllowedFare(settings: kBiddingOnWithFloor, distanceKm: 7.5), 375);
    });

    test('with the switch off there is no floor', () {
      const BiddingSettings noFloor = BiddingSettings(enabled: true, minimumFarePerKm: 50);
      expect(BiddingFareRules.minimumAllowedFare(settings: noFloor, distanceKm: 10), 0);
      expect(
        BiddingFareRules.check(amount: 1, settings: noFloor, distanceKm: 10),
        FareCheckResult.ok,
      );
    });

    test('with bidding off there is no floor either, whatever the rate says', () {
      const BiddingSettings biddingOff = BiddingSettings(minimumFarePerKmEnabled: true, minimumFarePerKm: 50);
      expect(BiddingFareRules.minimumAllowedFare(settings: biddingOff, distanceKm: 10), 0);
    });

    test('a switch left on with the rate cleared to zero does not block every offer', () {
      const BiddingSettings zeroRate = BiddingSettings(enabled: true, minimumFarePerKmEnabled: true, minimumFarePerKm: 0);
      expect(zeroRate.hasMinimumFare, isFalse);
      expect(BiddingFareRules.check(amount: 5, settings: zeroRate, distanceKm: 10), FareCheckResult.ok);
    });

    test('the floor is rounded to the currency, matching how fares are shown', () {
      const BiddingSettings odd = BiddingSettings(enabled: true, minimumFarePerKmEnabled: true, minimumFarePerKm: 12.345);
      expect(BiddingFareRules.minimumAllowedFare(settings: odd, distanceKm: 3, currencyDecimals: 2), 37.04);
      expect(BiddingFareRules.minimumAllowedFare(settings: odd, distanceKm: 3, currencyDecimals: 0), 37);
    });

    test('an offer of exactly the minimum is accepted despite float arithmetic', () {
      const BiddingSettings s = BiddingSettings(enabled: true, minimumFarePerKmEnabled: true, minimumFarePerKm: 0.1);
      // 0.1 * 3 is 0.30000000000000004 in binary floating point.
      expect(BiddingFareRules.check(amount: 0.3, settings: s, distanceKm: 3), FareCheckResult.ok);
    });

    test('a cent under the minimum is refused', () {
      expect(
        BiddingFareRules.check(amount: 499.5, settings: kBiddingOnWithFloor, distanceKm: 10),
        FareCheckResult.belowMinimum,
      );
    });

    test('zero, negative and unparseable amounts are refused', () {
      expect(BiddingFareRules.check(amount: 0, settings: kBiddingOn, distanceKm: 10), FareCheckResult.notPositive);
      expect(BiddingFareRules.check(amount: -5, settings: kBiddingOn, distanceKm: 10), FareCheckResult.notPositive);
      expect(BiddingFareRules.check(amount: null, settings: kBiddingOn, distanceKm: 10), FareCheckResult.notANumber);
    });

    test('what the user typed is parsed the way a phone keypad produces it', () {
      expect(BiddingFareRules.parseAmount('500'), 500);
      expect(BiddingFareRules.parseAmount(' 500.50 '), 500.5);
      expect(BiddingFareRules.parseAmount('500,50'), 500.5);
      expect(BiddingFareRules.parseAmount('abc'), isNull);
      expect(BiddingFareRules.parseAmount(''), isNull);
      expect(BiddingFareRules.parseAmount(null), isNull);
    });
  });


  // -----------------------------------------------------------------------
  // 3b. MINIMUM FARE — the audit checklist, customer side and driver side
  //     named explicitly.
  //
  //     `BiddingFareRules.check` is the single rule both sides run:
  //     the customer's `validateOfferedFare()` calls it before writing the
  //     ride, the driver's `sendCounterOffer()` calls it before writing an
  //     offer, and `RideBidLedger` calls it again inside the transaction so a
  //     client that skipped its own copy still fails.
  // -----------------------------------------------------------------------
  group('minimum fare: customer bid', () {
    test('a customer bid BELOW the minimum is refused', () {
      expect(
        BiddingFareRules.check(amount: 499, settings: kBiddingOnWithFloor, distanceKm: 10),
        FareCheckResult.belowMinimum,
      );
    });

    test('a customer bid at EXACTLY the minimum is accepted', () {
      expect(
        BiddingFareRules.check(amount: 500, settings: kBiddingOnWithFloor, distanceKm: 10),
        FareCheckResult.ok,
      );
    });

    test('the floor stored on the ride is the floor the rule computes', () {
      final double floor = BiddingFareRules.minimumAllowedFare(settings: kBiddingOnWithFloor, distanceKm: 10);
      final Map<String, dynamic> ride = biddingRide(minimumAllowedFare: floor);
      expect(RideBiddingState.fromJson(ride).minimumAllowedFare, 500);
    });

    test('a malformed, zero or negative customer bid never reaches the ride', () {
      for (final String typed in <String>['', '   ', 'abc', '-1', '0']) {
        final double? parsed = BiddingFareRules.parseAmount(typed);
        expect(
          BiddingFareRules.check(amount: parsed, settings: kBiddingOnWithFloor, distanceKm: 10),
          isNot(FareCheckResult.ok),
          reason: 'typed "$typed"',
        );
      }
    });
  });

  group('minimum fare: driver counter-offer', () {
    test('a counter-offer BELOW the minimum is refused by the transaction', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(minimumAllowedFare: 500));
      expect(
        await ledgerOn(store).submitBid(
          bid: newBid(driverId: 'drvA', amount: 499),
          settings: kBiddingOnWithFloor,
          now: kNow,
        ),
        SubmitBidResult.belowMinimum,
      );
      expect(store.docs.containsKey('rides/ride1/bids/drvA'), isFalse);
    });

    test('a counter-offer at EXACTLY the minimum is accepted by the transaction', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(minimumAllowedFare: 500));
      expect(
        await ledgerOn(store).submitBid(
          bid: newBid(driverId: 'drvA', amount: 500),
          settings: kBiddingOnWithFloor,
          now: kNow,
        ),
        SubmitBidResult.ok,
      );
      expect(store.read('rides/ride1/bids/drvA')!['amount'], 500);
    });

    test('the transaction recomputes the floor rather than trusting the stored one', () async {
      // The ride claims no floor, but the settings say there is one. The
      // transaction must use the settings, so a ride written by a client that
      // skipped the calculation cannot buy a cheaper offer.
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(minimumAllowedFare: 0));
      expect(
        await ledgerOn(store).submitBid(
          bid: newBid(driverId: 'drvA', amount: 100),
          settings: kBiddingOnWithFloor,
          now: kNow,
        ),
        SubmitBidResult.belowMinimum,
      );
    });

    test('with the minimum setting OFF neither side has a floor', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 1), settings: kBiddingOn, now: kNow),
        SubmitBidResult.ok,
      );
      expect(BiddingFareRules.check(amount: 1, settings: kBiddingOn, distanceKm: 10), FareCheckResult.ok);
    });

    test('a malformed, zero or negative counter-offer is refused', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      for (final num amount in <num>[0, -1, -500]) {
        expect(
          await ledgerOn(store).submitBid(
            bid: newBid(driverId: 'drvA', amount: amount),
            settings: kBiddingOn,
            now: kNow,
          ),
          SubmitBidResult.invalidAmount,
          reason: 'amount $amount',
        );
      }
    });

    test('a counter-offer against a STALE, already-awarded request is refused', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(status: RideBiddingStatus.accepted, winner: 'drvB'));
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 500), settings: kBiddingOn, now: kNow),
        SubmitBidResult.notOpen,
      );
    });
  });

  // -----------------------------------------------------------------------
  // 3c. DISTANCE UNITS
  //
  //     `settings/DriverNearBy.distanceType` is "Km" on some installs and
  //     "Miles" on others, and the apps write `rides.distance` in that unit.
  //     The admin rate is per KILOMETRE, so the trip has to be converted
  //     before the rule is applied — otherwise a miles install silently gets a
  //     floor 1.6x too low.
  // -----------------------------------------------------------------------
  group('distance units', () {
    test('kilometres pass through unchanged', () {
      expect(BiddingFareRules.toKilometres(10, 'Km'), 10);
      expect(BiddingFareRules.toKilometres(10, 'km'), 10);
      expect(BiddingFareRules.toKilometres(10, null), 10);
      expect(BiddingFareRules.toKilometres(10, ''), 10);
    });

    test('miles are converted, however the setting is cased', () {
      expect(BiddingFareRules.toKilometres(10, 'Miles'), closeTo(16.0934, 0.0001));
      expect(BiddingFareRules.toKilometres(10, 'miles'), closeTo(16.0934, 0.0001));
      expect(BiddingFareRules.toKilometres(10, ' MILES '), closeTo(16.0934, 0.0001));
    });

    test('a 10-mile trip does not get the floor of a 10-km trip', () {
      final double kmFloor = BiddingFareRules.minimumAllowedFare(
        settings: kBiddingOnWithFloor,
        distanceKm: BiddingFareRules.toKilometres(10, 'Km'),
      );
      final double milesFloor = BiddingFareRules.minimumAllowedFare(
        settings: kBiddingOnWithFloor,
        distanceKm: BiddingFareRules.toKilometres(10, 'Miles'),
      );
      expect(kmFloor, 500);
      expect(milesFloor, closeTo(804.67, 0.01));
      expect(milesFloor, greaterThan(kmFloor));
    });

    test('a non-positive distance yields no floor rather than a negative one', () {
      expect(BiddingFareRules.toKilometres(0, 'Miles'), 0);
      expect(BiddingFareRules.toKilometres(-5, 'Km'), 0);
      expect(BiddingFareRules.minimumAllowedFare(settings: kBiddingOnWithFloor, distanceKm: 0), 0);
    });

    test('the ride carries the normalised kilometres, not the display unit', () {
      // biddingDistanceKm is what the ledger, the dispatcher and the security
      // rules all read; rides.distance stays in the app's display unit exactly
      // as the normal booking flow has always written it.
      final Map<String, dynamic> ride = biddingRide(distanceKm: 16.0934);
      expect(RideBiddingState.fromJson(ride).distanceKm, closeTo(16.0934, 0.0001));
    });
  });

  // -----------------------------------------------------------------------
  // 4. CUSTOMER PHONE PRIVACY
  // -----------------------------------------------------------------------
  group('CUSTOMER PHONE PRIVACY', () {
    test('the author stored on an open bidding ride has no contact details', () {
      final Map<String, dynamic> author = biddingRide()['author'] as Map<String, dynamic>;
      expect(author.containsKey('phoneNumber'), isFalse);
      expect(author.containsKey('countryCode'), isFalse);
      expect(author.containsKey('countryISOCode'), isFalse);
      expect(author.containsKey('email'), isFalse);
      expect(RideAuthorPrivacy.leaksContact(author), isFalse);
    });

    test('other personal fields are withheld too, not just the phone number', () {
      final Map<String, dynamic> author = RideAuthorPrivacy.redact(customerProfile());
      expect(author.containsKey('shippingAddress'), isFalse);
      expect(author.containsKey('userBankDetails'), isFalse);
      expect(author.containsKey('wallet_amount'), isFalse);
    });

    test('redaction is an allowlist, so a new profile field is withheld by default', () {
      final Map<String, dynamic> profile = customerProfile()..['nationalIdNumber'] = 'X-1234';
      expect(RideAuthorPrivacy.redact(profile).containsKey('nationalIdNumber'), isFalse);
    });

    test('what the driver does need is still there', () {
      final Map<String, dynamic> author = RideAuthorPrivacy.redact(customerProfile());
      expect(author['id'], 'cust1');
      expect(author['firstName'], 'Amina');
      expect(author['profilePictureURL'], isNotNull);
      expect(author['reviewsSum'], '18');
    });

    test('leaksContact catches a phone that slipped through', () {
      expect(RideAuthorPrivacy.leaksContact(<String, dynamic>{'phoneNumber': '5551234567'}), isTrue);
      expect(RideAuthorPrivacy.leaksContact(<String, dynamic>{'phoneNumber': ''}), isFalse);
      expect(RideAuthorPrivacy.leaksContact(null), isFalse);
    });

    test('the open request carries no pickup OTP either', () {
      // A normal booking hands the OTP to exactly one dispatched driver. A
      // bidding request is readable by every eligible driver, so it must not
      // carry the code that proves who the customer booked.
      final Map<String, dynamic> ride = RideAuthorPrivacy.redactRide(
        <String, dynamic>{'id': 'ride1', 'otpCode': '4821', 'author': customerProfile()},
      );
      expect(ride.containsKey('otpCode'), isFalse);
      expect(RideAuthorPrivacy.leaksOnOpenRequest(ride), isFalse);
    });

    test('leaksOnOpenRequest catches an OTP or a phone that slipped through', () {
      expect(RideAuthorPrivacy.leaksOnOpenRequest(<String, dynamic>{'otpCode': '4821'}), isTrue);
      expect(
        RideAuthorPrivacy.leaksOnOpenRequest(<String, dynamic>{
          'author': <String, dynamic>{'phoneNumber': '5551234567'}
        }),
        isTrue,
      );
      expect(RideAuthorPrivacy.leaksOnOpenRequest(<String, dynamic>{'otpCode': ''}), isFalse);
      expect(RideAuthorPrivacy.leaksOnOpenRequest(null), isFalse);
    });

    test('redactRide keeps everything the driver legitimately needs to bid', () {
      final Map<String, dynamic> ride = RideAuthorPrivacy.redactRide(biddingRide());
      for (final String field in <String>[
        'id',
        'sourceLocationName',
        'destinationLocationName',
        'distance',
        RideBiddingFields.offeredFare,
        RideBiddingFields.eligibleDriverIds,
      ]) {
        expect(ride.containsKey(field), isTrue, reason: field);
      }
    });

    test('acceptance, and only acceptance, puts the contact details on the ride', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480));

      // Before: nothing to read.
      expect(RideAuthorPrivacy.leaksContact(store.read('rides/ride1')!['author'] as Map<String, dynamic>), isFalse);

      final AcceptBidResult result = await ledgerOn(store).acceptBid(
        rideId: 'ride1',
        winningDriverId: 'drvA',
        losingDriverIds: const <String>[],
        rideAwardPatch: <String, dynamic>{'status': 'Driver Accepted', 'driverId': 'drvA', 'subTotal': '480'},
        contactPatch: RideAuthorPrivacy.contactPatch(customerProfile()),
        settings: kBiddingOn,
        now: kNow,
      );

      expect(result, AcceptBidResult.ok);
      final Map<String, dynamic> author = store.read('rides/ride1')!['author'] as Map<String, dynamic>;
      expect(author['phoneNumber'], '5551234567');
    });
  });

  // -----------------------------------------------------------------------
  // 5. DRIVER FLOW - submitting and countering
  // -----------------------------------------------------------------------
  group('driver flow: offers and counter offers', () {
    test('an eligible driver can accept the offered fare', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      final SubmitBidResult result = await ledgerOn(store).submitBid(
        bid: newBid(driverId: 'drvA', amount: 500, type: RideBidType.accept),
        settings: kBiddingOn,
        now: kNow,
      );
      expect(result, SubmitBidResult.ok);
      expect(store.read('rides/ride1/bids/drvA')!['status'], RideBidStatus.pending);
      expect(store.read('rides/ride1/bids/drvA')!['type'], RideBidType.accept);
      expect(store.read('rides/ride1')![RideBiddingFields.bidCount], 1);
    });

    test('a counter offer carries the note as a translation key, not fixed text', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      await ledgerOn(store).submitBid(
        bid: newBid(driverId: 'drvA', amount: 620, note: 'Come fast or take that ruote'),
        settings: kBiddingOn,
        now: kNow,
      );
      expect(store.read('rides/ride1/bids/drvA')!['note'], 'Come fast or take that ruote');
    });

    test('COUNTER-OFFER VALIDATION: below the minimum is refused by the database', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(minimumAllowedFare: 500));
      final SubmitBidResult result = await ledgerOn(store).submitBid(
        bid: newBid(driverId: 'drvA', amount: 300),
        settings: kBiddingOnWithFloor,
        now: kNow,
      );
      expect(result, SubmitBidResult.belowMinimum);
      expect(store.docs.containsKey('rides/ride1/bids/drvA'), isFalse);
    });

    test('the same counter offer is accepted once the floor is switched off', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      final SubmitBidResult result = await ledgerOn(store).submitBid(
        bid: newBid(driverId: 'drvA', amount: 300),
        settings: kBiddingOn,
        now: kNow,
      );
      expect(result, SubmitBidResult.ok);
    });

    test('a zero or negative counter offer is refused', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 0), settings: kBiddingOn, now: kNow),
        SubmitBidResult.invalidAmount,
      );
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: -10), settings: kBiddingOn, now: kNow),
        SubmitBidResult.invalidAmount,
      );
    });

    test('a driver who is not eligible cannot bid', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(eligible: <String>['drvA']));
      final SubmitBidResult result = await ledgerOn(store).submitBid(
        bid: newBid(driverId: 'drvZ', amount: 500),
        settings: kBiddingOn,
        now: kNow,
      );
      expect(result, SubmitBidResult.notEligible);
    });

    test('an expired request takes no more offers', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(expiresAt: kNow.subtract(const Duration(minutes: 1))));
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 500), settings: kBiddingOn, now: kNow),
        SubmitBidResult.requestExpired,
      );
    });

    test('a cancelled request takes no more offers', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(status: RideBiddingStatus.cancelled));
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 500), settings: kBiddingOn, now: kNow),
        SubmitBidResult.notOpen,
      );
    });

    test('DUPLICATE SUBMIT: two taps leave one offer, not two', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      final RideBidLedger ledger = ledgerOn(store);
      await Future.wait<SubmitBidResult>(<Future<SubmitBidResult>>[
        ledger.submitBid(bid: newBid(driverId: 'drvA', amount: 600), settings: kBiddingOn, now: kNow),
        ledger.submitBid(bid: newBid(driverId: 'drvA', amount: 640), settings: kBiddingOn, now: kNow),
      ]);
      final Iterable<String> bidPaths = store.docs.keys.where((String k) => k.startsWith('rides/ride1/bids/'));
      expect(bidPaths.length, 1);
      expect(store.read('rides/ride1')![RideBiddingFields.bidCount], 1);
    });

    test('re-offering keeps the original response time so the list does not reshuffle', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      final RideBidLedger ledger = ledgerOn(store);
      await ledger.submitBid(bid: newBid(driverId: 'drvA', amount: 600), settings: kBiddingOn, now: kNow);
      final Object? first = store.read('rides/ride1/bids/drvA')!['createdAt'];
      await ledger.submitBid(
        bid: newBid(driverId: 'drvA', amount: 560),
        settings: kBiddingOn,
        now: kNow.add(const Duration(minutes: 1)),
      );
      expect(store.read('rides/ride1/bids/drvA')!['createdAt'], first);
      expect(store.read('rides/ride1/bids/drvA')!['amount'], 560);
    });

    test('a driver can withdraw, and cannot withdraw twice', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 500));
      final RideBidLedger ledger = ledgerOn(store);
      expect(await ledger.withdrawBid(rideId: 'ride1', driverId: 'drvA', now: kNow), isTrue);
      expect(store.read('rides/ride1/bids/drvA')!['status'], RideBidStatus.withdrawn);
      expect(await ledger.withdrawBid(rideId: 'ride1', driverId: 'drvA', now: kNow), isFalse);
    });

    test('a withdrawn offer cannot then be accepted', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 500, status: RideBidStatus.withdrawn));
      expect(
        await ledgerOn(store).acceptBid(
          rideId: 'ride1',
          winningDriverId: 'drvA',
          losingDriverIds: const <String>[],
          rideAwardPatch: const <String, dynamic>{},
          contactPatch: const <String, dynamic>{},
          settings: kBiddingOn,
          now: kNow,
        ),
        AcceptBidResult.bidNotPending,
      );
    });
  });

  // -----------------------------------------------------------------------
  // 6. THE CRITICAL CONCURRENCY REQUIREMENT
  // -----------------------------------------------------------------------
  group('only one driver can win', () {
    Future<FakeBidStore> threeOffers() async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(eligible: <String>['drvA', 'drvB', 'drvC']))
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480))
        ..seed('rides/ride1/bids/drvB', bidDoc(driverId: 'drvB', amount: 500))
        ..seed('rides/ride1/bids/drvC', bidDoc(driverId: 'drvC', amount: 520));
      return store;
    }

    Future<AcceptBidResult> accept(FakeBidStore store, String winner, List<String> losers) {
      return ledgerOn(store).acceptBid(
        rideId: 'ride1',
        winningDriverId: winner,
        losingDriverIds: losers,
        rideAwardPatch: <String, dynamic>{'status': 'Driver Accepted', 'driverId': winner},
        contactPatch: RideAuthorPrivacy.contactPatch(customerProfile()),
        settings: kBiddingOn,
        now: kNow,
      );
    }

    test('accepting books the ride and names the winner', () async {
      final FakeBidStore store = await threeOffers();
      expect(await accept(store, 'drvB', <String>['drvA', 'drvC']), AcceptBidResult.ok);

      final Map<String, dynamic> ride = store.read('rides/ride1')!;
      expect(ride[RideBiddingFields.winningBidId], 'drvB');
      expect(ride[RideBiddingFields.status], RideBiddingStatus.accepted);
      expect(ride['status'], 'Driver Accepted');
      expect(ride['driverId'], 'drvB');
    });

    test('COMPETING OFFERS CLOSE in the same write as the award', () async {
      final FakeBidStore store = await threeOffers();
      await accept(store, 'drvB', <String>['drvA', 'drvC']);

      expect(store.read('rides/ride1/bids/drvB')!['status'], RideBidStatus.accepted);
      expect(store.read('rides/ride1/bids/drvA')!['status'], RideBidStatus.closed);
      expect(store.read('rides/ride1/bids/drvC')!['status'], RideBidStatus.closed);
      // One commit: award and closures are not two observable states.
      expect(store.commits, 1);
    });

    test('the losing drivers are dropped from the request immediately', () async {
      final FakeBidStore store = await threeOffers();
      await accept(store, 'drvB', <String>['drvA', 'drvC']);
      expect(store.read('rides/ride1')![RideBiddingFields.eligibleDriverIds], <String>['drvB']);
    });

    test('two simultaneous acceptances of DIFFERENT drivers leave exactly one winner', () async {
      final FakeBidStore store = await threeOffers();
      final List<AcceptBidResult> results = await Future.wait<AcceptBidResult>(<Future<AcceptBidResult>>[
        accept(store, 'drvA', <String>['drvB', 'drvC']),
        accept(store, 'drvC', <String>['drvA', 'drvB']),
      ]);

      expect(results.where((AcceptBidResult r) => r == AcceptBidResult.ok).length, 1);
      expect(results.where((AcceptBidResult r) => r == AcceptBidResult.alreadyAwarded).length, 1);
      expect(store.retries, greaterThan(0), reason: 'the two transactions must really have collided');

      final String winner = store.read('rides/ride1')![RideBiddingFields.winningBidId] as String;
      final Iterable<String> accepted = store.docs.entries
          .where((MapEntry<String, Map<String, dynamic>> e) => e.key.startsWith('rides/ride1/bids/'))
          .where((MapEntry<String, Map<String, dynamic>> e) => e.value['status'] == RideBidStatus.accepted)
          .map((MapEntry<String, Map<String, dynamic>> e) => e.value['driverId'] as String);
      expect(accepted, <String>[winner]);
    });

    test('ten simultaneous acceptances still leave exactly one winner', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide(eligible: <String>[]));
      final List<String> drivers = List<String>.generate(10, (int i) => 'drv$i');
      for (final String d in drivers) {
        store.seed('rides/ride1/bids/$d', bidDoc(driverId: d, amount: 500));
      }
      store.seed('rides/ride1', biddingRide(eligible: drivers));

      final List<AcceptBidResult> results = await Future.wait<AcceptBidResult>(
        drivers.map((String d) => accept(store, d, drivers.where((String o) => o != d).toList())),
      );

      expect(results.where((AcceptBidResult r) => r == AcceptBidResult.ok).length, 1);
      expect(results.where((AcceptBidResult r) => r == AcceptBidResult.alreadyAwarded).length, 9);

      final int acceptedCount = store.docs.entries
          .where((MapEntry<String, Map<String, dynamic>> e) => e.key.startsWith('rides/ride1/bids/'))
          .where((MapEntry<String, Map<String, dynamic>> e) => e.value['status'] == RideBidStatus.accepted)
          .length;
      expect(acceptedCount, 1);
    });

    test('DUPLICATE ACCEPTANCE of the same driver is idempotent, not a second booking', () async {
      final FakeBidStore store = await threeOffers();
      expect(await accept(store, 'drvB', <String>['drvA', 'drvC']), AcceptBidResult.ok);
      expect(await accept(store, 'drvB', <String>['drvA', 'drvC']), AcceptBidResult.ok);
      expect(store.read('rides/ride1')![RideBiddingFields.winningBidId], 'drvB');
      // The second call re-read an already-awarded ride and wrote nothing.
      expect(store.commits, 1);
    });

    test('a driver cannot squeeze an offer in after the ride was awarded', () async {
      final FakeBidStore store = await threeOffers();
      await accept(store, 'drvB', <String>['drvA', 'drvC']);
      final SubmitBidResult late = await ledgerOn(store).submitBid(
        bid: newBid(driverId: 'drvA', amount: 100),
        settings: kBiddingOn,
        now: kNow,
      );
      expect(late, SubmitBidResult.notOpen);
    });

    test('an offer landing at the same instant as the acceptance does not win', () async {
      final FakeBidStore store = await threeOffers();
      final RideBidLedger ledger = ledgerOn(store);

      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        accept(store, 'drvB', <String>['drvA', 'drvC']),
        ledger.submitBid(bid: newBid(driverId: 'drvA', amount: 1), settings: kBiddingOn, now: kNow),
      ]);

      expect(store.read('rides/ride1')![RideBiddingFields.winningBidId], 'drvB');
      // Whichever order they serialised in, drvA is not the winner and their
      // offer is not pending on a booked ride.
      expect(results.contains(AcceptBidResult.ok) || results.contains(SubmitBidResult.notOpen), isTrue);
      expect(store.read('rides/ride1/bids/drvA')!['status'], isNot(RideBidStatus.accepted));
    });

    test('a REJECTED offer cannot later win', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480));

      expect(await ledgerOn(store).rejectBid(rideId: 'ride1', driverId: 'drvA', now: kNow), RejectBidResult.ok);
      expect(await accept(store, 'drvA', const <String>[]), AcceptBidResult.bidNotPending);
      expect(store.read('rides/ride1')![RideBiddingFields.winningBidId], isNull);
    });

    test('a rejected driver cannot re-bid their way back onto a closed request', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(status: RideBiddingStatus.expired))
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480, status: RideBidStatus.rejected));
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 900), settings: kBiddingOn, now: kNow),
        SubmitBidResult.notOpen,
      );
    });

    test('an expired offer cannot be accepted even if it is still on screen', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed(
          'rides/ride1/bids/drvA',
          bidDoc(driverId: 'drvA', amount: 500, expiresAt: kNow.subtract(const Duration(minutes: 1))),
        );
      expect(await accept(store, 'drvA', const <String>[]), AcceptBidResult.bidExpired);
    });

    test('an under-minimum offer cannot be accepted even if it reached the list', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(minimumAllowedFare: 500))
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 300));
      final AcceptBidResult result = await ledgerOn(store).acceptBid(
        rideId: 'ride1',
        winningDriverId: 'drvA',
        losingDriverIds: const <String>[],
        rideAwardPatch: const <String, dynamic>{},
        contactPatch: const <String, dynamic>{},
        settings: kBiddingOnWithFloor,
        now: kNow,
      );
      expect(result, AcceptBidResult.belowMinimum);
      expect(store.read('rides/ride1')![RideBiddingFields.winningBidId], isNull);
    });

    test('accepting an offer on a ride that no longer exists is refused', () async {
      final FakeBidStore store = FakeBidStore();
      expect(await accept(store, 'drvA', const <String>[]), AcceptBidResult.rideGone);
    });
  });

  // -----------------------------------------------------------------------
  // 7. REJECTING AND CANCELLING - no orphaned records
  // -----------------------------------------------------------------------
  group('rejecting and cancelling', () {
    test('rejecting one offer leaves the request open for the rest', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480))
        ..seed('rides/ride1/bids/drvB', bidDoc(driverId: 'drvB', amount: 520));

      expect(await ledgerOn(store).rejectBid(rideId: 'ride1', driverId: 'drvA', now: kNow), RejectBidResult.ok);
      expect(store.read('rides/ride1/bids/drvA')!['status'], RideBidStatus.rejected);
      expect(store.read('rides/ride1/bids/drvB')!['status'], RideBidStatus.pending);
      expect(RideBiddingState.fromJson(store.read('rides/ride1')).acceptsOffers, isTrue);
    });

    test('an offer cannot be rejected once the ride is booked', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(status: RideBiddingStatus.accepted, winner: 'drvB'))
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480));
      expect(
        await ledgerOn(store).rejectBid(rideId: 'ride1', driverId: 'drvA', now: kNow),
        RejectBidResult.alreadyAwarded,
      );
    });

    test('cancelling closes every open offer, so nothing is left orphaned', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide())
        ..seed('rides/ride1/bids/drvA', bidDoc(driverId: 'drvA', amount: 480))
        ..seed('rides/ride1/bids/drvB', bidDoc(driverId: 'drvB', amount: 520));

      final bool done = await ledgerOn(store).cancelRequest(
        rideId: 'ride1',
        openDriverIds: <String>['drvA', 'drvB'],
        ridePatch: <String, dynamic>{'status': 'Order Rejected'},
        now: kNow,
      );

      expect(done, isTrue);
      final Map<String, dynamic> ride = store.read('rides/ride1')!;
      expect(ride[RideBiddingFields.status], RideBiddingStatus.cancelled);
      expect(ride[RideBiddingFields.eligibleDriverIds], isEmpty);
      expect(store.read('rides/ride1/bids/drvA')!['status'], RideBidStatus.closed);
      expect(store.read('rides/ride1/bids/drvB')!['status'], RideBidStatus.closed);
    });

    test('a booked ride is not cancelled through the bidding path', () async {
      final FakeBidStore store = FakeBidStore()
        ..seed('rides/ride1', biddingRide(status: RideBiddingStatus.accepted, winner: 'drvB'));
      expect(
        await ledgerOn(store).cancelRequest(
          rideId: 'ride1',
          openDriverIds: const <String>[],
          ridePatch: const <String, dynamic>{},
          now: kNow,
        ),
        isFalse,
      );
    });

    test('no offer can be filed on a cancelled request afterwards', () async {
      final FakeBidStore store = FakeBidStore()..seed('rides/ride1', biddingRide());
      await ledgerOn(store).cancelRequest(
        rideId: 'ride1',
        openDriverIds: const <String>[],
        ridePatch: const <String, dynamic>{},
        now: kNow,
      );
      expect(
        await ledgerOn(store).submitBid(bid: newBid(driverId: 'drvA', amount: 500), settings: kBiddingOn, now: kNow),
        SubmitBidResult.notOpen,
      );
    });
  });

  // -----------------------------------------------------------------------
  // 8. State model
  // -----------------------------------------------------------------------
  group('bidding state', () {
    test('only an open, unawarded request takes offers', () {
      expect(RideBiddingState.fromJson(biddingRide()).acceptsOffers, isTrue);
      expect(RideBiddingState.fromJson(biddingRide(status: RideBiddingStatus.pendingDispatch)).acceptsOffers, isFalse);
      expect(RideBiddingState.fromJson(biddingRide(winner: 'drvA')).acceptsOffers, isFalse);
      expect(RideBiddingState.fromJson(biddingRide(status: RideBiddingStatus.expired)).acceptsOffers, isFalse);
    });

    test('every terminal state reports as finished', () {
      for (final String status in <String>[
        RideBiddingStatus.accepted,
        RideBiddingStatus.booked,
        RideBiddingStatus.expired,
        RideBiddingStatus.cancelled,
        RideBiddingStatus.noDrivers,
      ]) {
        expect(RideBiddingStatus.isFinished(status), isTrue, reason: status);
      }
      expect(RideBiddingStatus.isFinished(RideBiddingStatus.open), isFalse);
      expect(RideBiddingStatus.isFinished(RideBiddingStatus.pendingDispatch), isFalse);
    });

    test('expiry is read from the stored deadline', () {
      final RideBiddingState state = RideBiddingState.fromJson(biddingRide(expiresAt: kNow.add(const Duration(minutes: 5))));
      expect(state.isExpiredAt(kNow), isFalse);
      expect(state.isExpiredAt(kNow.add(const Duration(minutes: 6))), isTrue);
    });

    test('a bid round-trips through Firestore JSON unchanged', () {
      final RideBidModel bid = newBid(driverId: 'drvA', amount: 512.5, note: 'Come fast or take that ruote');
      final RideBidModel back = RideBidModel.fromJson(bid.toJson());
      expect(back.driverId, 'drvA');
      expect(back.amount, 512.5);
      expect(back.note, 'Come fast or take that ruote');
      expect(back.airConditioning, isTrue);
      expect(back.driverCompletedTrips, 120);
      expect(back.vehicleDescription, '');
      expect(back.isLive, isTrue);
    });

    test('an unstated AC value stays null rather than becoming a claim', () {
      final RideBidModel bid = RideBidModel.fromJson(<String, dynamic>{'driverId': 'drvA'});
      expect(bid.airConditioning, isNull);
    });
  });
}
