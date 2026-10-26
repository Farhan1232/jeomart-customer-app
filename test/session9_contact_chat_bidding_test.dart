import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/utils/bidding_fare_rules.dart';
import 'package:customer/utils/bidding_settings.dart';
import 'package:customer/utils/driver_trip_state.dart';
import 'package:customer/utils/ride_bidding_state.dart';

/// Session 9 — the four things the client reported on 06 Sep 2026.
///
/// 1. A booked trip vanished from the customer side.
/// 2. Neither side could see the other's phone number after a booking.
/// 3. Chat existed but was not wired into a driver-posted trip - and the cab
///    chat button was passing argument keys the controller does not read.
/// 4. The bidding minimum fare was PKR 742 on a trip whose metered price was
///    PKR 445, because a motorcycle was held to one global rate.
///
/// Every test below is one of those, expressed as behaviour rather than as a
/// screenshot.
void main() {
  // -------------------------------------------------------------------------
  // 4. The motorcycle fare floor
  // -------------------------------------------------------------------------
  group('minimum fare per vehicle type', () {
    const BiddingSettings global = BiddingSettings(
      enabled: true,
      minimumFarePerKmEnabled: true,
      // The rate that produced the client's PKR 742 on a 14.84 km trip.
      minimumFarePerKm: 50,
    );

    test('the reported case: a motorcycle rate brings the floor under the metered price', () {
      // The client's screenshot: metered PKR 445, floor PKR 742.
      const double distanceKm = 14.84;
      const double meteredPrice = 445;

      final double carFloor = BiddingFareRules.minimumAllowedFare(
        settings: global,
        distanceKm: distanceKm,
        currencyDecimals: 0,
      );
      expect(carFloor, 742, reason: 'this is the number the client photographed');
      expect(carFloor > meteredPrice, isTrue, reason: 'and this is why it was wrong');

      // Give the motorcycle a rate of its own and the floor follows the
      // vehicle, not the fleet.
      final double bikeFloor = BiddingFareRules.minimumAllowedFare(
        settings: global,
        distanceKm: distanceKm,
        currencyDecimals: 0,
        vehicleRatePerKm: 25,
      );
      expect(bikeFloor, 371);
      expect(bikeFloor < meteredPrice, isTrue);
    });

    test('a vehicle with no rate of its own still uses the global one', () {
      for (final num? rate in <num?>[null, 0, -5]) {
        expect(
          BiddingFareRules.minimumAllowedFare(
            settings: global,
            distanceKm: 10,
            currencyDecimals: 0,
            vehicleRatePerKm: rate,
          ),
          500,
          reason: 'rate $rate means "not set"',
        );
      }
    });

    test('the briefed 50 x 10 KM = 500 is unchanged', () {
      expect(
        BiddingFareRules.minimumAllowedFare(settings: global, distanceKm: 10, currencyDecimals: 0),
        500,
      );
    });

    test('a per-vehicle rate cannot create a floor while the rule is off', () {
      const BiddingSettings ruleOff = BiddingSettings(enabled: true, minimumFarePerKmEnabled: false);
      expect(
        BiddingFareRules.minimumAllowedFare(
          settings: ruleOff,
          distanceKm: 10,
          currencyDecimals: 0,
          vehicleRatePerKm: 25,
        ),
        0,
        reason: 'the vehicle chooses which rate applies, it does not switch the rule on',
      );
      expect(
        BiddingFareRules.check(amount: 1, settings: ruleOff, distanceKm: 10, vehicleRatePerKm: 25),
        FareCheckResult.ok,
      );
    });

    test('a per-vehicle rate cannot create a floor while bidding is off', () {
      const BiddingSettings biddingOff = BiddingSettings(minimumFarePerKmEnabled: true, minimumFarePerKm: 50);
      expect(
        BiddingFareRules.minimumAllowedFare(
          settings: biddingOff,
          distanceKm: 10,
          currencyDecimals: 0,
          vehicleRatePerKm: 25,
        ),
        0,
      );
    });

    test('an offer between the two floors is refused for a car and accepted for a motorcycle', () {
      const double distanceKm = 10;
      const double offer = 400; // above 25x10, below 50x10

      expect(
        BiddingFareRules.check(amount: offer, settings: global, distanceKm: distanceKm, currencyDecimals: 0),
        FareCheckResult.belowMinimum,
      );
      expect(
        BiddingFareRules.check(
          amount: offer,
          settings: global,
          distanceKm: distanceKm,
          currencyDecimals: 0,
          vehicleRatePerKm: 25,
        ),
        FareCheckResult.ok,
      );
    });

    test('the vehicle rate survives a round trip through the vehicle_type document', () {
      final VehicleType bike = VehicleType.fromJson(<String, dynamic>{
        'id': 'bike',
        'name': 'Motorcycle',
        'delivery_charges_per_km': 30,
        'biddingMinimumFarePerKm': 25,
      });
      expect(bike.biddingMinimumFarePerKm, 25);
      expect(VehicleType.fromJson(bike.toJson()).biddingMinimumFarePerKm, 25);
    });

    test('a numeric string is accepted, the way every other rate in this project is', () {
      expect(
        VehicleType.fromJson(<String, dynamic>{'id': 'v', 'biddingMinimumFarePerKm': '25.5'}).biddingMinimumFarePerKm,
        25.5,
      );
    });

    test('a vehicle the admin never configured writes no rate back', () {
      final VehicleType car = VehicleType.fromJson(<String, dynamic>{'id': 'car', 'name': 'Sedan'});
      expect(car.biddingMinimumFarePerKm, isNull);
      expect(car.toJson().containsKey('biddingMinimumFarePerKm'), isFalse,
          reason: 'an app round trip must not add a zero rate to a vehicle nobody configured');
    });
  });

  // -------------------------------------------------------------------------
  // The floor is recomputed, never trusted from the request
  // -------------------------------------------------------------------------
  group('the floor is recomputed from settings, not read off the ride', () {
    test('the vehicle rate is read from the ride, but the switches are not', () {
      final RideBiddingState state = RideBiddingState.fromJson(<String, dynamic>{
        RideBiddingFields.enabled: true,
        RideBiddingFields.distanceKm: 10,
        // A client that wrote itself no floor at all.
        RideBiddingFields.minFarePerKmAtRequest: 0,
        RideBiddingFields.minimumAllowedFare: 0,
        'vehicleType': <String, dynamic>{'id': 'bike', 'biddingMinimumFarePerKm': 25},
      });

      expect(state.vehicleRatePerKm, 25);

      const BiddingSettings on = BiddingSettings(
        enabled: true,
        minimumFarePerKmEnabled: true,
        minimumFarePerKm: 50,
      );
      expect(
        BiddingFareRules.check(
          amount: 100,
          settings: on,
          distanceKm: state.distanceKm.toDouble(),
          currencyDecimals: 0,
          vehicleRatePerKm: state.vehicleRatePerKm,
        ),
        FareCheckResult.belowMinimum,
        reason: 'the ride claimed no floor; the settings still impose one',
      );
    });

    test('a ride with no vehicle rate reads as null rather than zero', () {
      for (final Object? vehicleType in <Object?>[
        null,
        'not a map',
        <String, dynamic>{'id': 'car'},
        <String, dynamic>{'id': 'car', 'biddingMinimumFarePerKm': 0},
      ]) {
        final RideBiddingState state = RideBiddingState.fromJson(<String, dynamic>{
          RideBiddingFields.enabled: true,
          'vehicleType': vehicleType,
        });
        expect(state.vehicleRatePerKm, isNull, reason: 'vehicleType $vehicleType');
      }
    });
  });

  // -------------------------------------------------------------------------
  // 1. The booked trip that vanished
  // -------------------------------------------------------------------------
  group('a booked trip is still findable by the customer', () {
    Map<String, dynamic> tripJson({required String status, String? reservedBy}) => <String, dynamic>{
          DriverTripFields.id: 'trip1',
          DriverTripFields.driverId: 'drv1',
          DriverTripFields.sectionId: 'cab',
          DriverTripFields.status: status,
          DriverTripFields.fromAddress: 'Kohat',
          DriverTripFields.toAddress: 'Gadakhel',
          DriverTripFields.fullVehiclePrice: 1000,
          DriverTripFields.reservedBy: reservedBy,
          DriverTripFields.reservedByName: reservedBy == null ? null : 'Sameer Khan',
          DriverTripFields.createdAt: Timestamp.fromDate(DateTime(2026, 9, 6, 23, 33)),
        };

    test('booking it takes it out of the browsing list — which is why it needed a second one', () {
      final DriverTripModel booked = DriverTripModel.fromJson(tripJson(status: DriverTripStatus.booked, reservedBy: 'cust1'));

      // This is the exact behaviour the client reported as "it vanished": the
      // browsing query filters `status == active`, and a booked trip is not.
      expect(booked.isActive, isFalse);
      expect(booked.isVisibleAt(DateTime(2026, 9, 6, 23, 40)), isFalse);

      // But it is still the customer's, and that is what the My Bookings tab
      // matches on.
      expect(booked.hasReservation, isTrue);
      expect(booked.reservedBy, 'cust1');
    });

    test('the trip carries the name the card needs before any extra read lands', () {
      final DriverTripModel booked = DriverTripModel.fromJson(tripJson(status: DriverTripStatus.booked, reservedBy: 'cust1'));
      expect(booked.reservedByName, 'Sameer Khan');
      expect(booked.driverId, 'drv1', reason: 'the customer card looks the driver up by this');
    });

    test('an unbooked trip belongs to nobody', () {
      final DriverTripModel active = DriverTripModel.fromJson(tripJson(status: DriverTripStatus.active));
      expect(active.hasReservation, isFalse);
      expect(active.isActive, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 2. The phone numbers
  // -------------------------------------------------------------------------
  group('the contact block both sides read', () {
    test('the reservation carries a dialable number for the driver', () {
      final TripReservationModel reservation = TripReservationModel.fromJson(<String, dynamic>{
        'id': 'cust1',
        'tripId': 'trip1',
        'customerId': 'cust1',
        'customerName': 'Sameer Khan',
        'phoneNumber': '3001234567',
        'countryCode': '+92',
        'fcmToken': 'tok-customer',
      });

      expect(reservation.fullPhoneNumber, '+923001234567');
      expect(reservation.customerId, 'cust1');
      expect(reservation.fcmToken, 'tok-customer', reason: 'the chat notifies through this');
    });

    test('a customer who never gave a number produces an empty string, not "nullnull"', () {
      final TripReservationModel reservation = TripReservationModel.fromJson(<String, dynamic>{'id': 'cust1'});
      expect(reservation.fullPhoneNumber, '');
    });

    test('the contact block round-trips, so what the customer writes is what the driver reads', () {
      final TripReservationModel written = TripReservationModel(
        id: 'cust1',
        tripId: 'trip1',
        customerId: 'cust1',
        customerName: 'Sameer Khan',
        phoneNumber: '3001234567',
        countryCode: '+92',
        email: 'sameer@example.com',
        fcmToken: 'tok',
      );
      final TripReservationModel read = TripReservationModel.fromJson(written.toJson());
      expect(read.fullPhoneNumber, '+923001234567');
      expect(read.customerName, 'Sameer Khan');
    });
  });
}
