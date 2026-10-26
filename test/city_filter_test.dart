import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/rental_vehicle_type.dart';
import 'package:customer/models/section_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/models/zone_model.dart';
import 'package:customer/utils/city_filter.dart';
import 'package:flutter_test/flutter_test.dart';

ZoneModel _zone(String id, double lat, double lng, double half) => ZoneModel(id: id, area: <GeoPoint>[
      GeoPoint(lat - half, lng - half),
      GeoPoint(lat - half, lng + half),
      GeoPoint(lat + half, lng + half),
      GeoPoint(lat + half, lng - half),
    ]);

void main() {
  // Kohat inside a nationwide zone, Lahore elsewhere - the overlap is real on this project.
  final List<ZoneModel> zones = <ZoneModel>[
    _zone('kohat', 33.58, 71.44, 0.3),
    _zone('pk', 30.0, 70.0, 8.0),
    _zone('lahore', 31.52, 74.35, 0.3),
  ];

  group('zonesAt', () {
    test('every zone containing the point', () {
      expect(CityFilter.zonesAt(zones, 33.58, 71.44), <String>{'kohat', 'pk'});
      expect(CityFilter.zonesAt(zones, 31.52, 74.35), <String>{'lahore', 'pk'});
    });
    test('outside every zone = empty, not unknown', () {
      expect(CityFilter.zonesAt(zones, 51.5, -0.1), <String>{});
    });
    test('unknown position or no zones = null', () {
      expect(CityFilter.zonesAt(zones, null, 71.0), isNull);
      expect(CityFilter.zonesAt(zones, 0, 0), isNull);
      expect(CityFilter.zonesAt(<ZoneModel>[], 33.58, 71.44), isNull);
      expect(CityFilter.zonesAt(null, 33.58, 71.44), isNull);
    });
  });

  group('allows', () {
    test('nothing ticked = every city (all existing documents)', () {
      expect(CityFilter.allows(null, <String>{'kohat'}), isTrue);
      expect(CityFilter.allows(<String>[], <String>{'kohat'}), isTrue);
      expect(CityFilter.allows(null, <String>{}), isTrue);
    });
    test('ticked city matches', () {
      expect(CityFilter.allows(<String>['kohat'], <String>{'kohat', 'pk'}), isTrue);
      expect(CityFilter.allows(<String>['pk'], <String>{'kohat', 'pk'}), isTrue);
    });
    test('other city is hidden', () {
      expect(CityFilter.allows(<String>['lahore'], <String>{'kohat', 'pk'}), isFalse);
      expect(CityFilter.allows(<String>['lahore'], <String>{}), isFalse);
    });
    test('unknown location shows everything (as before)', () {
      expect(CityFilter.allows(<String>['lahore'], null), isTrue);
    });
  });

  test('parseZoneIds', () {
    expect(CityFilter.parseZoneIds(null), isNull);
    expect(CityFilter.parseZoneIds('kohat'), isNull);
    expect(CityFilter.parseZoneIds(<dynamic>['a', 3, '', 'b']), <String>['a', 'b']);
  });

  test('keep filters sections and leaves the order alone', () {
    final List<SectionModel> sections = <SectionModel>[
      SectionModel.fromJson(<String, dynamic>{'platformFee': <String, dynamic>{}, 'id': 'food', 'name': 'Food'}),
      SectionModel.fromJson(<String, dynamic>{'platformFee': <String, dynamic>{}, 'id': 'cabLahore', 'zoneIds': <String>['lahore']}),
      SectionModel.fromJson(<String, dynamic>{'platformFee': <String, dynamic>{}, 'id': 'cabKohat', 'zoneIds': <String>['kohat']}),
      SectionModel.fromJson(<String, dynamic>{'platformFee': <String, dynamic>{}, 'id': 'parcel', 'zoneIds': <String>[]}),
    ];
    List<String?> ids(Set<String>? here) => CityFilter.keep(sections, (SectionModel s) => s.zoneIds, here).map((SectionModel s) => s.id).toList();
    expect(ids(<String>{'kohat', 'pk'}), <String>['food', 'cabKohat', 'parcel']);
    expect(ids(<String>{'lahore', 'pk'}), <String>['food', 'cabLahore', 'parcel']);
    expect(ids(null), <String>['food', 'cabLahore', 'cabKohat', 'parcel']);
  });

  test('vehicle types read zoneIds but never write it into a ride or booking', () {
    final VehicleType cab = VehicleType.fromJson(<String, dynamic>{'id': 'v1', 'name': 'Car', 'zoneIds': <String>['kohat']});
    expect(cab.zoneIds, <String>['kohat']);
    expect(cab.toJson().containsKey('zoneIds'), isFalse);
    final RentalVehicleType rental = RentalVehicleType.fromJson(<String, dynamic>{'id': 'r1', 'zoneIds': <String>['lahore']});
    expect(rental.zoneIds, <String>['lahore']);
    expect(rental.toJson().containsKey('zoneIds'), isFalse);
    final SectionModel section = SectionModel.fromJson(<String, dynamic>{'platformFee': <String, dynamic>{}, 'id': 's', 'zoneIds': <String>['pk']});
    expect(section.toJson().containsKey('zoneIds'), isFalse);
    expect(VehicleType.fromJson(<String, dynamic>{'id': 'old'}).zoneIds, isNull);
  });
}
