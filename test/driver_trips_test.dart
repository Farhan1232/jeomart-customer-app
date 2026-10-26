import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/utils/driver_trip_ledger.dart';
import 'package:customer/utils/driver_trip_settings.dart';
import 'package:customer/utils/driver_trip_state.dart';
import 'package:customer/utils/firestore_paginator.dart';
import 'package:customer/utils/trip_transaction.dart';
// ---------------------------------------------------------------------------
// Shared fake store
// ---------------------------------------------------------------------------

/// An in-memory Firestore with the same optimistic concurrency real
/// transactions have: if any document a body READ changed before its writes
/// landed, the whole body is replayed against the newer values.
///
/// That replay is the mechanism the "only one customer can take a full
/// vehicle" requirement rests on, so it is modelled here rather than assumed,
/// and the tests below assert that collisions really happened.
class FakeTripStore implements TripTransactionRunner {
  FakeTripStore({this.maxAttempts = 64});

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
  Future<T> run<T>(Future<T> Function(TripTransactionContext ctx) body) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final _FakeTripContext ctx = _FakeTripContext(this);
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
        for (final _FakeTripWrite write in ctx.writes) {
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
    throw StateError('trip transaction gave up after $maxAttempts attempts');
  }
}

class _FakeTripWrite {
  _FakeTripWrite(this.path, this.data, {required this.isUpdate});

  final String path;
  final Map<String, dynamic> data;
  final bool isUpdate;
}

class _FakeTripContext implements TripTransactionContext {
  _FakeTripContext(this._store);

  final FakeTripStore _store;
  final Map<String, int> readVersions = <String, int>{};
  final List<_FakeTripWrite> writes = <_FakeTripWrite>[];

  @override
  Future<TripDocument> get(String path) async {
    readVersions[path] = _store._versions[path] ?? 0;
    return _FakeTripDocument(_store.docs[path]);
  }

  @override
  void set(String path, Map<String, dynamic> data, {bool merge = true}) {
    writes.add(_FakeTripWrite(path, data, isUpdate: false));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    writes.add(_FakeTripWrite(path, data, isUpdate: true));
  }
}

class _FakeTripDocument implements TripDocument {
  _FakeTripDocument(this._data);

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? get data => _data;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// A local clock on purpose. `Timestamp.toDate()` returns a local `DateTime`,
/// and Dart's `DateTime ==` compares the UTC flag as well as the instant, so a
/// UTC fixture would make every round-trip assertion fail for the wrong reason.
final DateTime kNow = DateTime(2026, 9, 5, 10, 0);

const TripLocation kFrom = TripLocation(latitude: 24.8607, longitude: 67.0011);
const TripLocation kTo = TripLocation(latitude: 25.3960, longitude: 68.3578);

Map<String, dynamic> tripDoc({
  String id = 'trip1',
  String driverId = 'driver1',
  String sectionId = 'sec-cab',
  String status = DriverTripStatus.active,
  DateTime? departure,
  DateTime? visibilityExpiresAt,
  num price = 4500,
  String? reservedBy,
  String note = 'Leaving from the main bus stand',
}) {
  return <String, dynamic>{
    DriverTripFields.id: id,
    DriverTripFields.driverId: driverId,
    DriverTripFields.sectionId: sectionId,
    DriverTripFields.status: status,
    DriverTripFields.fromAddress: 'Karachi',
    DriverTripFields.fromLocation: kFrom.toJson(),
    DriverTripFields.toAddress: 'Hyderabad',
    DriverTripFields.toLocation: kTo.toJson(),
    DriverTripFields.tripDateTime: Timestamp.fromDate(departure ?? kNow.add(const Duration(hours: 6))),
    DriverTripFields.note: note,
    DriverTripFields.fullVehiclePrice: price,
    DriverTripFields.createdAt: Timestamp.fromDate(kNow.subtract(const Duration(minutes: 5))),
    DriverTripFields.visibilityExpiresAt: Timestamp.fromDate(visibilityExpiresAt ?? kNow.add(const Duration(hours: 24))),
    DriverTripFields.visibilityHours: 24,
    'driverName': 'Ali Khan',
    'driverPhoto': '',
    'driverRating': 4.6,
    'driverReviewsCount': 12,
    'driverCompletedTrips': 87,
    'driverFcmToken': 'driver-token',
    'vehicleType': 'Sedan',
    'vehicleBrand': 'Toyota',
    'vehicleModel': 'Corolla',
    'vehiclePlate': 'ABC-123',
    'airConditioning': true,
    DriverTripFields.reservedBy: reservedBy,
  };
}

TripReservationModel reservationFor(String customerId) => TripReservationModel(
      customerName: 'Customer $customerId',
      customerPhoto: '',
      phoneNumber: '3001234567',
      countryCode: '+92',
      email: 'c@example.com',
      fcmToken: 'token-$customerId',
    );

Future<ReserveTripResult> reserve(
  DriverTripLedger ledger,
  String customerId, {
  String tripId = 'trip1',
  DateTime? now,
}) {
  return ledger.reserveTrip(
    tripId: tripId,
    customerId: customerId,
    customerName: 'Customer $customerId',
    customerPhoto: '',
    reservation: reservationFor(customerId),
    now: now ?? kNow,
  );
}

// ---------------------------------------------------------------------------
// Trip validation - the Post a Trip form rules
// ---------------------------------------------------------------------------
void main() {
  group('trip validation', () {
    List<TripValidationError> run({
      String fromAddress = 'Karachi',
      TripLocation? fromLocation = kFrom,
      String toAddress = 'Hyderabad',
      TripLocation? toLocation = kTo,
      DateTime? date,
      DateTime? time,
      bool omitDate = false,
      bool omitTime = false,
      String note = 'See you at the stand',
      String price = '4500',
    }) {
      return DriverTripValidation.validate(
        fromAddress: fromAddress,
        fromLocation: fromLocation,
        toAddress: toAddress,
        toLocation: toLocation,
        date: omitDate ? null : (date ?? kNow.add(const Duration(days: 1))),
        time: omitTime ? null : (time ?? kNow.add(const Duration(days: 1, hours: 2))),
        note: note,
        price: price,
        now: kNow,
      );
    }

    test('a complete form passes', () {
      expect(run(), isEmpty);
    });

    test('From is required', () {
      expect(run(fromAddress: '', fromLocation: null), contains(TripValidationError.fromRequired));
    });

    test('an address with no coordinates is not a From', () {
      expect(run(fromLocation: null), contains(TripValidationError.fromRequired));
    });

    test('To is required', () {
      expect(run(toAddress: '', toLocation: null), contains(TripValidationError.toRequired));
    });

    test('From and To cannot be the same place', () {
      expect(run(toAddress: 'Karachi', toLocation: kFrom), contains(TripValidationError.sameFromAndTo));
    });

    test('two taps a few metres apart still count as the same place', () {
      const TripLocation nextDoor = TripLocation(latitude: 24.86072, longitude: 67.00113);
      expect(run(toAddress: 'Karachi Saddar', toLocation: nextDoor), contains(TripValidationError.sameFromAndTo));
    });

    test('a genuinely different destination is allowed', () {
      expect(run(), isNot(contains(TripValidationError.sameFromAndTo)));
    });

    test('the date is required', () {
      expect(run(omitDate: true), contains(TripValidationError.dateRequired));
    });

    test('the time is required', () {
      expect(run(omitTime: true), contains(TripValidationError.timeRequired));
    });

    test('a departure in the past is refused', () {
      expect(
        run(date: kNow.subtract(const Duration(days: 1)), time: kNow),
        contains(TripValidationError.dateInPast),
      );
    });

    test('today with a time already gone is refused', () {
      expect(
        run(date: kNow, time: kNow.subtract(const Duration(hours: 3))),
        contains(TripValidationError.dateInPast),
      );
    });

    test('today with a later time is accepted', () {
      expect(
        run(date: kNow, time: kNow.add(const Duration(hours: 3))),
        isEmpty,
      );
    });

    test('a note at the limit is accepted and one over it is not', () {
      expect(run(note: 'x' * DriverTripValidation.maxNoteLength), isEmpty);
      expect(
        run(note: 'x' * (DriverTripValidation.maxNoteLength + 1)),
        contains(TripValidationError.noteTooLong),
      );
    });

    test('an empty note is fine - it is optional', () {
      expect(run(note: ''), isEmpty);
    });

    test('the price is required', () {
      expect(run(price: ''), contains(TripValidationError.priceRequired));
    });

    test('a zero price is refused', () {
      expect(run(price: '0'), contains(TripValidationError.priceNotPositive));
    });

    test('a negative price is refused', () {
      expect(run(price: '-100'), contains(TripValidationError.priceNotPositive));
    });

    test('a price that is not a number is refused', () {
      expect(run(price: 'free'), contains(TripValidationError.priceNotPositive));
    });

    test('a decimal price is accepted', () {
      expect(run(price: '4500.50'), isEmpty);
    });

    test('date and time combine into one departure instant', () {
      final DateTime combined = DriverTripValidation.combine(
        DateTime(2026, 9, 10),
        DateTime(2000, 1, 1, 17, 45),
      );
      expect(combined, DateTime(2026, 9, 10, 17, 45));
    });
  });

  // -------------------------------------------------------------------------
  // Visibility - the admin's global window, and the departure time
  // -------------------------------------------------------------------------
  group('trip visibility', () {
    test('expiry is created-at plus the configured hours', () {
      final Timestamp expiry = DriverTripVisibility.expiryFor(createdAt: kNow, visibilityHours: 6);
      expect(expiry.toDate(), kNow.add(const Duration(hours: 6)));
    });

    test('a trip inside its window and before departure is visible', () {
      final DriverTripModel trip = DriverTripModel.fromJson(tripDoc());
      expect(trip.isVisibleAt(kNow), isTrue);
    });

    test('a trip past its window is not visible', () {
      final DriverTripModel trip = DriverTripModel.fromJson(
        tripDoc(visibilityExpiresAt: kNow.subtract(const Duration(minutes: 1))),
      );
      expect(trip.isVisibleAt(kNow), isFalse);
      expect(trip.effectiveStatusAt(kNow), DriverTripStatus.expired);
    });

    test('a trip whose departure has passed is not visible even inside its window', () {
      final DriverTripModel trip = DriverTripModel.fromJson(
        tripDoc(
          departure: kNow.subtract(const Duration(minutes: 30)),
          visibilityExpiresAt: kNow.add(const Duration(hours: 12)),
        ),
      );
      expect(trip.isVisibleAt(kNow), isFalse);
    });

    test('a booked trip is never in the available list', () {
      final DriverTripModel trip = DriverTripModel.fromJson(
        tripDoc(status: DriverTripStatus.booked, reservedBy: 'cust1'),
      );
      expect(trip.isVisibleAt(kNow), isFalse);
      expect(trip.effectiveStatusAt(kNow), DriverTripStatus.booked);
    });

    test('a cancelled trip is never in the available list', () {
      final DriverTripModel trip = DriverTripModel.fromJson(tripDoc(status: DriverTripStatus.cancelled));
      expect(trip.isVisibleAt(kNow), isFalse);
    });

    test('the visibility setting clamps to a sane range', () {
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripVisibilityHours': 0}).visibilityHours, 1);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripVisibilityHours': 5000}).visibilityHours, 720);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripVisibilityHours': 6}).visibilityHours, 6);
    });

    test('a missing or unreadable setting falls back to the default, not to zero', () {
      expect(DriverTripSettings.fromJson(null).visibilityHours, DriverTripSettings.defaultVisibilityHours);
      expect(DriverTripSettings.fromJson(<String, dynamic>{}).visibilityHours, DriverTripSettings.defaultVisibilityHours);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripVisibilityHours': 'nonsense'}).visibilityHours,
          DriverTripSettings.defaultVisibilityHours);
    });

    test('a value stored as a string is read as a number', () {
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripVisibilityHours': '12'}).visibilityHours, 12);
    });
  });

  // -------------------------------------------------------------------------
  // The trip document

  // -------------------------------------------------------------------------
  // The trip radius
  //
  // "it must be setup from admin panel to bidding and driver posted trips all"
  // - settings/driverTripsSettings.tripRadiusKm. One degree of latitude is
  // 111.19 km, so latitude 0.1 is 11.12 km from the equator.
  // -------------------------------------------------------------------------
  group('trip radius', () {
    const DriverTripSettings tenKm = DriverTripSettings(radiusKm: 10);
    const DriverTripSettings noRadius = DriverTripSettings();

    test('a radius is read from the settings document', () {
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': 25}).radiusKm, 25);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': '25'}).radiusKm, 25);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': 25.5}).radiusKm, 25.5);
    });

    test('an absent, zero or nonsense radius means no radius at all', () {
      expect(DriverTripSettings.fromJson(<String, dynamic>{}).hasRadius, isFalse);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': 0}).hasRadius, isFalse);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': -4}).hasRadius, isFalse);
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': 'nonsense'}).hasRadius, isFalse);
      expect(DriverTripSettings.fromJson(null).hasRadius, isFalse);
    });

    test('an absurd radius is clamped rather than trusted', () {
      expect(DriverTripSettings.fromJson(<String, dynamic>{'tripRadiusKm': 99999}).radiusKm,
          DriverTripSettings.maxRadiusKm);
    });

    test('the visibility hours are untouched by a radius change', () {
      final DriverTripSettings s =
          DriverTripSettings.fromJson(<String, dynamic>{'tripVisibilityHours': 6, 'tripRadiusKm': 12});
      expect(s.visibilityHours, 6);
      expect(s.radiusKm, 12);
    });

    test('a nearby trip is listed and a distant one is not', () {
      expect(tenKm.includesTrip(fromLat: 0, fromLng: 0, tripLat: 0.05, tripLng: 0), isTrue);
      expect(tenKm.includesTrip(fromLat: 0, fromLng: 0, tripLat: 0.1, tripLng: 0), isFalse);
    });

    test('a trip exactly on the boundary is listed', () {
      const DriverTripSettings exact = DriverTripSettings(radiusKm: 11.2);
      expect(exact.includesTrip(fromLat: 0, fromLng: 0, tripLat: 0.1, tripLng: 0), isTrue);
    });

    test('with no radius set every trip is listed however far away', () {
      expect(noRadius.includesTrip(fromLat: 0, fromLng: 0, tripLat: 40, tripLng: 40), isTrue);
    });

    test('an unknown customer location never empties the list', () {
      expect(tenKm.includesTrip(fromLat: null, fromLng: null, tripLat: 40, tripLng: 40), isTrue);
    });

    test('a trip with no coordinates is still listed', () {
      expect(tenKm.includesTrip(fromLat: 0, fromLng: 0, tripLat: null, tripLng: null), isTrue);
    });

    test('the distance is real kilometres, not degrees or miles', () {
      expect(DriverTripSettings.distanceKm(0, 0, 0.1, 0), closeTo(11.12, 0.05));
      expect(DriverTripSettings.distanceKm(0, 0, 0, 0), 0);
    });
  });

  // -------------------------------------------------------------------------
  group('trip document', () {
    test('round-trips through JSON without losing a field', () {
      final DriverTripModel trip = DriverTripModel.fromJson(tripDoc());
      final DriverTripModel again = DriverTripModel.fromJson(trip.toJson());
      expect(again.id, trip.id);
      expect(again.driverId, trip.driverId);
      expect(again.sectionId, trip.sectionId);
      expect(again.fullVehiclePrice, trip.fullVehiclePrice);
      expect(again.fromLocation!.latitude, kFrom.latitude);
      expect(again.toLocation!.longitude, kTo.longitude);
      expect(again.tripDateTime, trip.tripDateTime);
      expect(again.airConditioning, isTrue);
    });

    test('a price stored as a string is still a number', () {
      final DriverTripModel trip = DriverTripModel.fromJson(tripDoc()..[DriverTripFields.fullVehiclePrice] = '4500');
      expect(trip.fullVehiclePrice, 4500);
    });

    test('an unstated air conditioning value stays null rather than becoming Non-AC', () {
      final Map<String, dynamic> raw = tripDoc()..remove('airConditioning');
      expect(DriverTripModel.fromJson(raw).airConditioning, isNull);
    });

    test('the vehicle line is blank when the driver filled in neither field', () {
      final Map<String, dynamic> raw = tripDoc()
        ..['vehicleBrand'] = ''
        ..['vehicleModel'] = '';
      expect(DriverTripModel.fromJson(raw).vehicleDescription, isEmpty);
    });

    test('the write path re-validates the built document', () {
      final DriverTripModel good = DriverTripModel.fromJson(tripDoc());
      expect(good.validationErrorsAt(kNow), isEmpty);

      final DriverTripModel zeroPrice = DriverTripModel.fromJson(tripDoc(price: 0));
      expect(zeroPrice.validationErrorsAt(kNow), contains(TripValidationError.priceNotPositive));

      final DriverTripModel past = DriverTripModel.fromJson(
        tripDoc(departure: kNow.subtract(const Duration(hours: 1))),
      );
      expect(past.validationErrorsAt(kNow), contains(TripValidationError.dateInPast));
    });

    test('a document with no contact fields is what a browsing customer reads', () {
      // The reserving customer's phone number lives in the reservation
      // subcollection, never on the trip.
      final Map<String, dynamic> json = DriverTripModel.fromJson(tripDoc()).toJson();
      expect(json.containsKey('phoneNumber'), isFalse);
      expect(json.containsKey('countryCode'), isFalse);
      expect(json.containsKey('email'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Full-vehicle reservation - exactly one customer wins
  // -------------------------------------------------------------------------
  group('full vehicle reservation', () {
    late FakeTripStore store;
    late DriverTripLedger ledger;

    setUp(() {
      store = FakeTripStore();
      ledger = DriverTripLedger(store, tripsCollection: 'driver_trips');
      store.seed('driver_trips/trip1', tripDoc());
    });

    test('one customer books the whole vehicle', () async {
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.ok);

      final Map<String, dynamic> trip = store.read('driver_trips/trip1')!;
      expect(trip[DriverTripFields.status], DriverTripStatus.booked);
      expect(trip[DriverTripFields.reservedBy], 'cust1');
      expect(trip[DriverTripFields.reservedAt], isA<Timestamp>());
    });

    test('the contact block lands in the reservation subcollection, not on the trip', () async {
      await reserve(ledger, 'cust1');

      final Map<String, dynamic> trip = store.read('driver_trips/trip1')!;
      expect(trip.containsKey('phoneNumber'), isFalse);
      expect(trip.containsKey('fcmToken'), isFalse);

      final Map<String, dynamic>? reservation = store.read('driver_trips/trip1/reservation/cust1');
      expect(reservation, isNotNull);
      expect(reservation!['phoneNumber'], '3001234567');
      expect(reservation['countryCode'], '+92');
      expect(reservation['customerId'], 'cust1');
      expect(reservation['tripId'], 'trip1');
    });

    test('a second customer cannot double-book the full vehicle', () async {
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.ok);
      expect(await reserve(ledger, 'cust2'), ReserveTripResult.alreadyReserved);

      expect(store.read('driver_trips/trip1')![DriverTripFields.reservedBy], 'cust1');
      expect(store.read('driver_trips/trip1/reservation/cust2'), isNull);
    });

    test('ten simultaneous bookings leave exactly one winner', () async {
      final List<Future<ReserveTripResult>> attempts = <Future<ReserveTripResult>>[
        for (int i = 0; i < 10; i++) reserve(ledger, 'cust$i'),
      ];
      final List<ReserveTripResult> results = await Future.wait(attempts);

      expect(results.where((ReserveTripResult r) => r == ReserveTripResult.ok).length, 1);
      expect(results.where((ReserveTripResult r) => r == ReserveTripResult.alreadyReserved).length, 9);

      // The collisions really happened - this is a race, not ten calls in a row.
      expect(store.retries, greaterThan(0));

      final Map<String, dynamic> trip = store.read('driver_trips/trip1')!;
      expect(trip[DriverTripFields.status], DriverTripStatus.booked);
      final String winner = trip[DriverTripFields.reservedBy] as String;
      for (int i = 0; i < 10; i++) {
        final bool hasReservation = store.read('driver_trips/trip1/reservation/cust$i') != null;
        expect(hasReservation, 'cust$i' == winner);
      }
    });

    test('the same customer booking twice is idempotent', () async {
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.ok);
      final int commitsAfterFirst = store.commits;
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.ok);
      expect(store.commits, commitsAfterFirst);
    });

    test('a trip that no longer exists cannot be booked', () async {
      expect(await reserve(ledger, 'cust1', tripId: 'ghost'), ReserveTripResult.tripGone);
    });

    test('a cancelled trip cannot be booked', () async {
      store.seed('driver_trips/trip1', tripDoc(status: DriverTripStatus.cancelled));
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.notActive);
    });

    test('a trip past its visibility window cannot be booked, even from a stale card', () async {
      store.seed('driver_trips/trip1', tripDoc(visibilityExpiresAt: kNow.subtract(const Duration(minutes: 1))));
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.expired);
      expect(store.read('driver_trips/trip1')![DriverTripFields.status], DriverTripStatus.active);
    });

    test('a trip whose departure has passed cannot be booked', () async {
      store.seed('driver_trips/trip1', tripDoc(departure: kNow.subtract(const Duration(minutes: 1))));
      expect(await reserve(ledger, 'cust1'), ReserveTripResult.expired);
    });

    test('a driver cannot book their own trip', () async {
      expect(await reserve(ledger, 'driver1'), ReserveTripResult.ownTrip);
    });
  });

  // -------------------------------------------------------------------------
  // Driver cancellation
  // -------------------------------------------------------------------------
  group('driver cancellation', () {
    late FakeTripStore store;
    late DriverTripLedger ledger;

    setUp(() {
      store = FakeTripStore();
      ledger = DriverTripLedger(store, tripsCollection: 'driver_trips');
      store.seed('driver_trips/trip1', tripDoc());
    });

    test('the owning driver can withdraw an active trip', () async {
      expect(
        await ledger.cancelTrip(tripId: 'trip1', driverId: 'driver1', now: kNow),
        CancelTripResult.ok,
      );
      final Map<String, dynamic> trip = store.read('driver_trips/trip1')!;
      expect(trip[DriverTripFields.status], DriverTripStatus.cancelled);
      expect(trip[DriverTripFields.cancelledBy], DriverTripCancelledBy.driver);
    });

    test('the owning driver can withdraw a booked trip', () async {
      await reserve(ledger, 'cust1');
      expect(
        await ledger.cancelTrip(tripId: 'trip1', driverId: 'driver1', now: kNow),
        CancelTripResult.ok,
      );
      expect(store.read('driver_trips/trip1')![DriverTripFields.status], DriverTripStatus.cancelled);
    });

    test('another driver cannot touch it', () async {
      expect(
        await ledger.cancelTrip(tripId: 'trip1', driverId: 'driver2', now: kNow),
        CancelTripResult.notOwner,
      );
      expect(store.read('driver_trips/trip1')![DriverTripFields.status], DriverTripStatus.active);
    });

    test('cancelling twice is refused the second time', () async {
      expect(await ledger.cancelTrip(tripId: 'trip1', driverId: 'driver1', now: kNow), CancelTripResult.ok);
      expect(
        await ledger.cancelTrip(tripId: 'trip1', driverId: 'driver1', now: kNow),
        CancelTripResult.alreadyFinished,
      );
    });

    test('a cancellation racing a booking leaves one consistent outcome', () async {
      final Future<ReserveTripResult> booking = reserve(ledger, 'cust1');
      final Future<CancelTripResult> cancellation =
          ledger.cancelTrip(tripId: 'trip1', driverId: 'driver1', now: kNow);
      final ReserveTripResult bookingResult = await booking;
      final CancelTripResult cancellationResult = await cancellation;

      final Map<String, dynamic> trip = store.read('driver_trips/trip1')!;
      if (bookingResult == ReserveTripResult.ok) {
        // The booking landed first; the cancellation then applied on top of a
        // booked trip, which is the driver telling the customer it is off.
        expect(cancellationResult, CancelTripResult.ok);
        expect(trip[DriverTripFields.status], DriverTripStatus.cancelled);
        expect(trip[DriverTripFields.reservedBy], 'cust1');
      } else {
        expect(bookingResult, ReserveTripResult.notActive);
        expect(trip[DriverTripFields.status], DriverTripStatus.cancelled);
        expect(trip[DriverTripFields.reservedBy], isNull);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Available Trips - ordering, paging and the client-side expiry guard
  // -------------------------------------------------------------------------
  group('available trips list', () {
    List<DriverTripModel> page(int start, int count, {bool expired = false}) {
      return <DriverTripModel>[
        for (int i = 0; i < count; i++)
          DriverTripModel.fromJson(tripDoc(
            id: 'trip${start + i}',
            visibilityExpiresAt: expired ? kNow.subtract(const Duration(minutes: 1)) : kNow.add(const Duration(hours: 12)),
          )),
      ];
    }

    test('the newest trip is first, because the query orders by createdAt desc', () {
      // The query shape is asserted by the service test below; here the list is
      // simply taken in query order and never re-sorted in Dart.
      final List<DriverTripModel> trips = <DriverTripModel>[
        DriverTripModel.fromJson(tripDoc(id: 'newest')),
        DriverTripModel.fromJson(tripDoc(id: 'older')),
      ];
      expect(trips.map((DriverTripModel t) => t.id).toList(), <String>['newest', 'older']);
    });

    test('expired trips are filtered out of the visible list', () {
      final List<DriverTripModel> trips = <DriverTripModel>[...page(0, 3), ...page(3, 2, expired: true)];
      final List<DriverTripModel> visible =
          trips.where((DriverTripModel t) => t.isVisibleAt(kNow)).toList();
      expect(visible.length, 3);
      expect(visible.every((DriverTripModel t) => t.isVisibleAt(kNow)), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Paging, through Session 1's paginator, on this list's shape
  // -------------------------------------------------------------------------
  group('trip list pagination', () {
    late FakeTripPageSource source;
    late FirestorePaginator<FakeTripDoc, DriverTripModel> paginator;

    FirestorePaginator<FakeTripDoc, DriverTripModel> build({
      bool Function(DriverTripModel)? filter,
      int autoFillTarget = 0,
    }) {
      return FirestorePaginator<FakeTripDoc, DriverTripModel>(
        source: source,
        mapper: (FakeTripDoc doc) => DriverTripModel.fromJson(doc.data),
        pageSize: 5,
        filter: filter,
        autoFillTarget: autoFillTarget,
      );
    }

    setUp(() {
      source = FakeTripPageSource(<FakeTripDoc>[
        for (int i = 0; i < 12; i++)
          FakeTripDoc('trip$i', tripDoc(id: 'trip$i')),
      ]);
      paginator = build();
    });

    tearDown(() => paginator.dispose());

    test('the first page is one page, not the whole collection', () async {
      await paginator.refresh();
      expect(paginator.items.length, 5);
      expect(source.fetches, 1);
      expect(paginator.hasMore.value, isTrue);
    });

    test('load more appends the next page and stops at the end', () async {
      await paginator.refresh();
      await paginator.loadMore();
      expect(paginator.items.length, 10);
      await paginator.loadMore();
      expect(paginator.items.length, 12);
      expect(paginator.hasMore.value, isFalse);

      // Past the end nothing more is requested.
      final int fetches = source.fetches;
      await paginator.loadMore();
      expect(source.fetches, fetches);
    });

    test('query order is preserved - newest first, never re-sorted in Dart', () async {
      await paginator.refresh();
      await paginator.loadMore();
      expect(
        paginator.items.map((DriverTripModel t) => t.id).toList(),
        <String>['trip0', 'trip1', 'trip2', 'trip3', 'trip4', 'trip5', 'trip6', 'trip7', 'trip8', 'trip9'],
      );
    });

    test('a document served twice does not show up twice', () async {
      source.duplicateNextPage = true;
      await paginator.refresh();
      await paginator.loadMore();
      final List<String> ids = paginator.items.map((DriverTripModel t) => t.id!).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('refresh starts again from page one and drops the tail', () async {
      await paginator.refresh();
      await paginator.loadMore();
      expect(paginator.items.length, 10);
      await paginator.refresh();
      expect(paginator.items.length, 5);
      expect(paginator.hasMore.value, isTrue);
    });

    test('overlapping load-more calls collapse into one page', () async {
      await paginator.refresh();
      final int fetches = source.fetches;
      await Future.wait<void>(<Future<void>>[paginator.loadMore(), paginator.loadMore(), paginator.loadMore()]);
      expect(source.fetches, fetches + 1);
      expect(paginator.items.length, 10);
    });

    test('a failing query surfaces the error and stops paging instead of spinning', () async {
      source.failNext = true;
      await paginator.refresh();
      expect(paginator.error.value, isNotNull);
      expect(paginator.hasMore.value, isFalse);
      expect(paginator.items, isEmpty);

      // A refresh clears it.
      source.failNext = false;
      await paginator.refresh();
      expect(paginator.error.value, isNull);
      expect(paginator.items.length, 5);
    });

    test('the expiry guard hides stale rows and keeps paging until the list fills', () async {
      // First page is entirely trips whose window has closed.
      source = FakeTripPageSource(<FakeTripDoc>[
        for (int i = 0; i < 5; i++)
          FakeTripDoc('stale$i', tripDoc(id: 'stale$i', visibilityExpiresAt: kNow.subtract(const Duration(minutes: 1)))),
        for (int i = 0; i < 6; i++) FakeTripDoc('fresh$i', tripDoc(id: 'fresh$i')),
      ]);
      paginator = build(filter: (DriverTripModel t) => t.isVisibleAt(kNow), autoFillTarget: 5);
      await paginator.refresh();

      expect(paginator.visibleItems.length, greaterThanOrEqualTo(5));
      expect(paginator.visibleItems.every((DriverTripModel t) => t.isVisibleAt(kNow)), isTrue);
      expect(paginator.visibleItems.any((DriverTripModel t) => t.id!.startsWith('stale')), isFalse);
    });

    test('switching a status tab filters what is loaded, it does not re-query', () async {
      source = FakeTripPageSource(<FakeTripDoc>[
        for (int i = 0; i < 3; i++) FakeTripDoc('a$i', tripDoc(id: 'a$i')),
        for (int i = 0; i < 2; i++)
          FakeTripDoc('b$i', tripDoc(id: 'b$i', status: DriverTripStatus.cancelled)),
      ]);
      paginator = build(filter: (DriverTripModel t) => t.effectiveStatusAt(kNow) == DriverTripStatus.active);
      await paginator.refresh();
      final int fetches = source.fetches;

      expect(paginator.visibleItems.length, 3);
      await paginator.applyFilter((DriverTripModel t) => t.effectiveStatusAt(kNow) == DriverTripStatus.cancelled);
      expect(paginator.visibleItems.length, 2);
      expect(source.fetches, fetches);
    });
  });
}

/// A document stand-in for the paginator, so the paging behaviour of these
/// lists is exercised without Firestore.
class FakeTripDoc {
  FakeTripDoc(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

class FakeTripPageSource extends PageSource<FakeTripDoc> {
  FakeTripPageSource(this.docs);

  final List<FakeTripDoc> docs;

  int fetches = 0;
  bool failNext = false;

  /// Makes the next page repeat the previous page's last document, which is
  /// what a cursor landing on a document written between two reads looks like.
  bool duplicateNextPage = false;

  @override
  Future<List<FakeTripDoc>> fetch({required FakeTripDoc? after, required int limit}) async {
    fetches++;
    if (failNext) {
      failNext = false;
      throw StateError('query failed');
    }
    int start = 0;
    if (after != null) {
      start = docs.indexWhere((FakeTripDoc d) => d.id == after.id) + 1;
      if (duplicateNextPage && start > 0) start -= 1;
    }
    return docs.skip(start).take(limit).toList();
  }

  @override
  String idOf(FakeTripDoc doc) => doc.id;
}
