import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/zone_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Per-city sections and vehicle types.
///
/// The admin panel can tick the cities (published `zone` documents) a section,
/// a cab vehicle type or a rental vehicle type is offered in; they are saved as
/// `zoneIds`. Nothing ticked - and every document saved before this existed -
/// means every city, which is how the app has always behaved.
///
/// The customer's city is every zone that contains their chosen area: zones on
/// this project overlap ("Kohat" inside "Pakistan (Nationwide)"), so an item
/// for either of them is offered. When the area or the zones are not known the
/// list is left exactly as it was read.
class CityFilter {
  const CityFilter._();

  /// `zoneIds` as saved by the panel, or null when there is none.
  static List<String>? parseZoneIds(dynamic raw) {
    if (raw is! List) return null;
    final List<String> ids = raw.whereType<String>().where((String id) => id.isNotEmpty).toList();
    return ids;
  }

  /// The ids of the zones containing the point; null when it cannot be told.
  static Set<String>? zonesAt(List<ZoneModel>? zones, double? latitude, double? longitude) {
    if (zones == null || zones.isEmpty || latitude == null || longitude == null) return null;
    if (latitude == 0 && longitude == 0) return null;
    final Set<String> here = <String>{};
    for (final ZoneModel zone in zones) {
      final List<GeoPoint>? area = zone.area;
      if (zone.id == null || area == null || area.length < 3) continue;
      if (Constant.isPointInPolygon(LatLng(latitude, longitude), area)) here.add(zone.id!);
    }
    return here;
  }

  /// Is an item with these [zoneIds] offered where the customer is?
  static bool allows(List<String>? zoneIds, Set<String>? here) {
    if (zoneIds == null || zoneIds.isEmpty) return true;
    if (here == null) return true;
    return zoneIds.any(here.contains);
  }

  static List<T> keep<T>(List<T> items, List<String>? Function(T) zoneIdsOf, Set<String>? here) {
    if (here == null) return items;
    return items.where((T item) => allows(zoneIdsOf(item), here)).toList();
  }

  /// The zones of the customer's chosen area (or, before one is chosen, of the
  /// device position). Never throws; null = unknown = no filtering.
  static Future<Set<String>?> customerZones() async {
    try {
      final List<ZoneModel>? zones = await FireStoreUtils.getZone();
      double? latitude = Constant.selectedLocation.location?.latitude;
      double? longitude = Constant.selectedLocation.location?.longitude;
      if (latitude == null || longitude == null) {
        latitude = Constant.currentLocation?.latitude;
        longitude = Constant.currentLocation?.longitude;
      }
      return zonesAt(zones, latitude, longitude);
    } catch (e) {
      print('CityFilter.customerZones $e');
      return null;
    }
  }
}
