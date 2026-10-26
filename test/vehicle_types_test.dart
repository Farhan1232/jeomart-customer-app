import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:customer/models/vehicle_type.dart';
import 'package:customer/utils/bidding_fare_rules.dart';
import 'package:customer/utils/bidding_settings.dart';
import 'package:customer/utils/ride_bidding_state.dart';
import 'package:customer/utils/vehicle_display.dart';
import 'package:customer/utils/vehicle_fare.dart';

/// Session 16: every vehicle type the admin adds has to work.
///
/// The client's cab section holds a car, a mini, an auto rickshaw, a
/// motorcycle, a ten-seater and a scooty, and the request was that the apps
/// carry all of them rather than only the cars. Two things stopped that, and
/// both are asserted here against the shapes the live `vehicle_type`
/// collection really holds rather than the shapes it is supposed to hold:
///
///  * a charge box left empty in the panel is saved as a real `NaN`, which
///    used to reach the customer as the price `NaN` on a button that offered
///    to charge it;
///  * a field saved in the wrong type threw while being read, and the throw
///    was swallowed one level up, so the new vehicle simply never appeared.
void main() {
  /// `Ookla Scooty`, exactly as it sits in Firestore today: three `NaN`
  /// charges, and a capacity with a distance typed into it.
  Map<String, dynamic> ooklaScooty() => <String, dynamic>{
        'id': '6a8fad84d238d',
        'name': 'Ookla Scooty',
        'capacity': '50km',
        'description': 'scooty ',
        'short_description': 'scooty',
        'supported_vehicle': 'Ookla',
        'sectionId': '631852d1bc978',
        'isActive': false,
        'vehicle_icon': 'https://example.invalid/scooty.png',
        'delivery_charges_per_km': double.nan,
        'minimum_delivery_charges': double.nan,
        'minimum_delivery_charges_within_km': double.nan,
      };

  /// `Auto Rikshaw`, a healthy document, as a control.
  Map<String, dynamic> autoRikshaw() => <String, dynamic>{
        'id': '66176a92ef4e4',
        'name': 'Auto Rikshaw',
        'capacity': '3',
        'description': 'auto',
        'short_description': 'auto',
        'supported_vehicle': 'auto',
        'sectionId': '631852d1bc978',
        'isActive': true,
        'vehicle_icon': 'https://example.invalid/riksha.png',
        'delivery_charges_per_km': 60,
        'minimum_delivery_charges': 150,
        'minimum_delivery_charges_within_km': 3,
      };

  group('a vehicle the admin added is always readable', () {
    test('a healthy document reads exactly as before', () {
      final VehicleType vehicle = VehicleType.fromJson(autoRikshaw());

      expect(vehicle.id, '66176a92ef4e4');
      expect(vehicle.name, 'Auto Rikshaw');
      expect(vehicle.isActive, isTrue);
      expect(vehicle.capacity, '3');
      expect(vehicle.supportedVehicle, 'auto');
      expect(vehicle.delivery_charges_per_km, 60);
      expect(vehicle.minimum_delivery_charges, 150);
      expect(vehicle.minimum_delivery_charges_within_km, 3);
      expect(vehicle.biddingMinimumFarePerKm, isNull);
    });

    test('a capacity saved as a number does not throw the vehicle away', () {
      // This is the failure that has no symptom: `String? capacity` assigned an
      // int throws, `getVehicleType()` catches it, and the vehicle is missing
      // from the list with nothing on screen to say why.
      final Map<String, dynamic> json = autoRikshaw()..['capacity'] = 3;

      final VehicleType vehicle = VehicleType.fromJson(json);

      expect(vehicle.capacity, '3');
      expect(vehicle.seats, 3);
    });

    test('charges saved as strings are still numbers', () {
      final Map<String, dynamic> json = autoRikshaw()
        ..['delivery_charges_per_km'] = '60'
        ..['minimum_delivery_charges'] = '150'
        ..['minimum_delivery_charges_within_km'] = ' 3 ';

      final VehicleType vehicle = VehicleType.fromJson(json);

      expect(vehicle.delivery_charges_per_km, 60);
      expect(vehicle.minimum_delivery_charges, 150);
      expect(vehicle.minimum_delivery_charges_within_km, 3);
    });

    test('an isActive saved as text is still a flag', () {
      expect(VehicleType.fromJson(autoRikshaw()..['isActive'] = 'true').isActive, isTrue);
      expect(VehicleType.fromJson(autoRikshaw()..['isActive'] = 'false').isActive, isFalse);
      expect(VehicleType.fromJson(autoRikshaw()..['isActive'] = 1).isActive, isTrue);
    });

    test('a document with nothing in it reads rather than throws', () {
      final VehicleType vehicle = VehicleType.fromJson(<String, dynamic>{});

      expect(vehicle.name, isNull);
      expect(vehicle.seats, isNull);
      expect(vehicle.delivery_charges_per_km, 0);
      expect(vehicle.minimum_delivery_charges, 0);
      expect(vehicle.minimum_delivery_charges_within_km, 0);
    });
  });

  group('NaN never reaches a price', () {
    test('the NaN charges Ookla Scooty carries are read as no charge', () {
      final VehicleType vehicle = VehicleType.fromJson(ooklaScooty());

      expect(vehicle.delivery_charges_per_km, 0);
      expect(vehicle.minimum_delivery_charges, 0);
      expect(vehicle.minimum_delivery_charges_within_km, 0);
    });

    test('its fare is a number a customer could be shown', () {
      final VehicleType vehicle = VehicleType.fromJson(ooklaScooty());

      final double fare = VehicleFare.meteredFare(vehicleType: vehicle, distanceKm: 12.5);

      expect(fare.isNaN, isFalse);
      expect(fare, 0.0);
    });

    test('a NaN bidding rate is no rate, so the global one applies', () {
      final Map<String, dynamic> json = autoRikshaw()..['biddingMinimumFarePerKm'] = double.nan;

      expect(VehicleType.fromJson(json).biddingMinimumFarePerKm, isNull);
    });

    test('a bidding rate the admin did set is kept, string or number', () {
      expect(VehicleType.fromJson(autoRikshaw()..['biddingMinimumFarePerKm'] = 20).biddingMinimumFarePerKm, 20);
      expect(VehicleType.fromJson(autoRikshaw()..['biddingMinimumFarePerKm'] = '20.5').biddingMinimumFarePerKm, 20.5);
    });
  });

  group('the metered fare is the rule both screens always applied', () {
    final VehicleType rikshaw = VehicleType.fromJson(autoRikshaw());

    test('inside the minimum distance it is the minimum charge', () {
      expect(VehicleFare.meteredFare(vehicleType: rikshaw, distanceKm: 1.0), 150.0);
      expect(VehicleFare.meteredFare(vehicleType: rikshaw, distanceKm: 3.0), 150.0);
    });

    test('beyond it, the per-km rate', () {
      expect(VehicleFare.meteredFare(vehicleType: rikshaw, distanceKm: 10.0), 600.0);
    });

    test('a distance the map never measured is not a NaN price', () {
      expect(VehicleFare.meteredFare(vehicleType: rikshaw, distanceKm: double.nan), 0.0);
      expect(VehicleFare.meteredFare(vehicleType: rikshaw, distanceKm: double.infinity), 0.0);
    });

    test('a motorcycle and a ten-seater are priced by their own numbers', () {
      // The two the client added either side of the cars.
      final VehicleType motorcycle = VehicleType.fromJson(<String, dynamic>{
        'name': 'Motorcycle',
        'capacity': '2',
        'delivery_charges_per_km': 30,
        'minimum_delivery_charges': 100,
        'minimum_delivery_charges_within_km': 3,
      });
      final VehicleType suzuki = VehicleType.fromJson(<String, dynamic>{
        'name': 'Suzuki',
        'capacity': '10',
        'delivery_charges_per_km': 100,
        'minimum_delivery_charges': 600,
        'minimum_delivery_charges_within_km': 4,
      });

      expect(VehicleFare.meteredFare(vehicleType: motorcycle, distanceKm: 10.0), 300.0);
      expect(VehicleFare.meteredFare(vehicleType: suzuki, distanceKm: 10.0), 1000.0);
    });
  });

  group('seats, from a free-text box', () {
    test('a plain count is a count', () {
      expect(VehicleType.fromJson(autoRikshaw()..['capacity'] = '3').seats, 3);
      expect(VehicleType.fromJson(autoRikshaw()..['capacity'] = ' 10 ').seats, 10);
    });

    test('anything else shows nothing rather than something wrong', () {
      // '50km' is really in the live data - a range typed into the seats box.
      expect(VehicleType.fromJson(ooklaScooty()).seats, isNull);
      expect(VehicleType.fromJson(autoRikshaw()..['capacity'] = '').seats, isNull);
      expect(VehicleType.fromJson(autoRikshaw()..['capacity'] = '0').seats, isNull);
      expect(VehicleType.fromJson(autoRikshaw()..['capacity'] = '2+1 seater').seats, isNull);
    });
  });

  group('the second line of a vehicle row', () {
    test('duration and seats are joined', () {
      expect(VehicleDisplay.subtitle(duration: '12 mins', seats: '3 seats'), '12 mins · 3 seats');
    });

    test('whichever half is missing is left out, with no stray separator', () {
      expect(VehicleDisplay.subtitle(duration: '12 mins', seats: null), '12 mins');
      expect(VehicleDisplay.subtitle(duration: '', seats: '3 seats'), '3 seats');
      expect(VehicleDisplay.subtitle(duration: '   ', seats: null), '');
      expect(VehicleDisplay.subtitle(), '');
    });

    test('a vehicle that states no seats has no label', () {
      expect(VehicleDisplay.seatsLabel(null), isNull);
    });
  });

  group('the fare rule stays in one place', () {
    String read(String path) {
      final File file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing - this test is stale');
      return file.readAsStringSync();
    }

    /// Both screens quote a price, and each used to carry its own copy of the
    /// formula. A copy that drifts prices the same ride two ways, so neither
    /// file may spell the formula out again.
    const List<String> quotingControllers = <String>[
      'lib/controllers/cab_booking_controller.dart',
      'lib/controllers/intercity_home_controller.dart',
    ];

    test('both quoting screens go through VehicleFare', () {
      for (final String path in quotingControllers) {
        final String source = read(path);
        expect(source.contains('VehicleFare.meteredFare('), isTrue, reason: '$path does not use the shared fare');
        expect(source.contains('delivery_charges_per_km'), isFalse, reason: '$path spells the fare formula out again');
      }
    });

    test('the only charge arithmetic left is the shared one', () {
      expect(read('lib/utils/vehicle_fare.dart').contains('delivery_charges_per_km'), isTrue);
    });
  });

  group('a bidding rate the panel could once save as NaN', () {
    RideBiddingState requestFor(Object? vehicleType) => RideBiddingState.fromJson(<String, dynamic>{
          RideBiddingFields.enabled: true,
          RideBiddingFields.status: RideBiddingStatus.open,
          RideBiddingFields.distanceKm: 10,
          RideBiddingFields.offeredFare: 400,
          'vehicleType': vehicleType,
        });

    test('is no rate, so the global floor still applies', () {
      // `NaN <= 0` is false, so a NaN rate used to be taken for a real one and
      // the floor it produced was NaN - which no offer is ever below, so the
      // minimum-fare rule quietly stopped applying to that vehicle.
      final RideBiddingState request = requestFor(<String, dynamic>{'id': 'bike', 'biddingMinimumFarePerKm': double.nan});

      expect(request.vehicleRatePerKm, isNull);
    });

    test('a rate the admin really set is still used', () {
      expect(requestFor(<String, dynamic>{'id': 'bike', 'biddingMinimumFarePerKm': 25}).vehicleRatePerKm, 25);
      expect(requestFor(<String, dynamic>{'id': 'car'}).vehicleRatePerKm, isNull);
    });

    test('the floor a NaN rate produces is the global one, not NaN', () {
      const BiddingSettings settings = BiddingSettings(
        enabled: true,
        minimumFarePerKmEnabled: true,
        minimumFarePerKm: 50,
      );
      final RideBiddingState request = requestFor(<String, dynamic>{'id': 'bike', 'biddingMinimumFarePerKm': double.nan});

      final double floor = BiddingFareRules.minimumAllowedFare(
        settings: settings,
        distanceKm: request.distanceKm.toDouble(),
        currencyDecimals: 0,
        vehicleRatePerKm: request.vehicleRatePerKm,
      );

      expect(floor, 500);
    });
  });
}
