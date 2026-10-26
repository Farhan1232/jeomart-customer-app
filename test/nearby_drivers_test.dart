import 'package:flutter_test/flutter_test.dart';

import 'package:customer/utils/nearby_drivers.dart';

/// A driver document shaped like the ones the admin panel writes.
Map<String, dynamic> driverDoc({
  String role = 'driver',
  bool isActive = true,
  List<dynamic> serviceTypes = const <dynamic>['cab-service'],
  List<dynamic> sectionIds = const <dynamic>['sec1'],
  String vehicleId = 'veh-car',
  double lat = 31.5204,
  double lng = 74.3587,
  Object? inProgressOrderID,
  Object? orderRequestData,
  Object? ordercabRequestData,
  bool withLocation = true,
}) {
  return <String, dynamic>{
    'role': role,
    'isActive': isActive,
    'serviceTypes': serviceTypes,
    'sectionIds': sectionIds,
    'vehicleDetails': <String, dynamic>{
      'sec1': <String, dynamic>{'vehicleId': vehicleId, 'rideType': 'ride'},
    },
    if (withLocation) 'location': <String, dynamic>{'latitude': lat, 'longitude': lng},
    'inProgressOrderID': inProgressOrderID ?? <dynamic>[],
    'orderRequestData': orderRequestData ?? <dynamic>[],
    if (ordercabRequestData != null) 'ordercabRequestData': ordercabRequestData,
  };
}

bool visible(Map<String, dynamic> d, {String vehicleId = 'veh-car', double radiusKm = 8}) => NearbyDrivers.isVisible(
      d,
      sectionId: 'sec1',
      vehicleId: vehicleId,
      customerLat: 31.5204,
      customerLng: 74.3587,
      radiusKm: radiusKm,
    );

void main() {
  group('which vehicles the customer is shown', () {
    test('an available driver of the selected type is shown', () {
      expect(visible(driverDoc()), isTrue);
    });

    test('a driver of a DIFFERENT vehicle type is not shown', () {
      // The client's actual complaint: pick a bike, see cars.
      expect(visible(driverDoc(vehicleId: 'veh-bike')), isFalse);
      expect(visible(driverDoc(vehicleId: 'veh-bike'), vehicleId: 'veh-bike'), isTrue);
    });

    test('an inactive driver is not shown', () {
      expect(visible(driverDoc(isActive: false)), isFalse);
    });

    test('a driver from another section is not shown', () {
      expect(visible(driverDoc(sectionIds: const <dynamic>['other'])), isFalse);
    });

    test('a driver who does not do cab service is not shown', () {
      expect(visible(driverDoc(serviceTypes: const <dynamic>['parcel'])), isFalse);
    });

    test('a busy driver is not shown', () {
      expect(visible(driverDoc(inProgressOrderID: <dynamic>['ride1'])), isFalse);
      expect(visible(driverDoc(orderRequestData: <dynamic>['req1'])), isFalse);
      expect(visible(driverDoc(ordercabRequestData: <String, dynamic>{'id': 'x'})), isFalse);
    });

    test('a driver with no location cannot be drawn', () {
      expect(visible(driverDoc(withLocation: false)), isFalse);
    });

    test('a driver parked at 0,0 is not drawn in the Gulf of Guinea', () {
      // An unset location reads as 0,0 in these documents, which is a real
      // point in the ocean and would otherwise be plotted as a real vehicle.
      expect(visible(driverDoc(lat: 0, lng: 0)), isFalse);
    });

    test('a driver outside the display radius is not shown', () {
      // Kohat, ~370 km from Lahore.
      expect(visible(driverDoc(lat: 33.5869, lng: 71.4414)), isFalse);
    });

    test('the radius is honoured at its edge', () {
      // 0.05 degrees of latitude is 5.56 km.
      expect(visible(driverDoc(lat: 31.5704), radiusKm: 8), isTrue);
      expect(visible(driverDoc(lat: 31.5704), radiusKm: 4), isFalse);
    });

    test('a non-driver user is never shown', () {
      expect(visible(driverDoc(role: 'customer')), isFalse);
    });

    test('the marker carries the vehicle type that chose its icon', () {
      final NearbyDriver? m = NearbyDrivers.toMarker('d1', driverDoc(vehicleId: 'veh-bike'), sectionId: 'sec1');
      expect(m, isNotNull);
      expect(m!.vehicleId, 'veh-bike');
      expect(m.id, 'd1');
    });

    test('distance is real kilometres', () {
      expect(NearbyDrivers.distanceKm(0, 0, 0.1, 0), closeTo(11.12, 0.05));
    });
  });
}
