import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/zone_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Which delivery zone the customer's chosen area falls in.
///
/// Four controllers - food, dine-in, category and on-demand - each carried the
/// same loop, and the same defect inside it:
///
/// ```dart
/// for (int i = 0; i < value.length; i++) {
///   if (isPointInPolygon(here, value[i].area!)) {
///     Constant.selectedZone = value[i];  // the match
///     break;
///   } else {
///     Constant.selectedZone = value[i];  // ... and every miss, too
///   }
/// }
/// ```
///
/// The `else` assigns as well, so a customer whose area is in **no** zone ends
/// up with whichever zone happened to be last in the list - a different city,
/// silently. Every screen that follows then reads that zone: the store list is
/// filtered by it, and the *"store is not available in your area"* messages are
/// measured against it. That is the *"changes the customer's selected area"* in
/// the client's report, and it fires whenever one of those four home screens is
/// rebuilt - which is exactly what backing out of a message used to do.
///
/// Here a miss changes nothing the customer chose. Only [ZoneChoice.isAvailable]
/// says the area is not served, which is what the *Change Zone* prompt is for.
class ZoneChoice {
  const ZoneChoice(this.zone, {required this.isAvailable});

  /// The zone to use. Never a zone the customer's point is not inside, unless
  /// there was no zone at all before - see [ZoneSelection.choose].
  final ZoneModel? zone;

  /// Whether [zone] really contains the customer's area.
  final bool isAvailable;
}

class ZoneSelection {
  const ZoneSelection._();

  /// Picks the zone for [latitude]/[longitude] out of [zones].
  ///
  /// Returns `null` when there is nothing to decide - no zone documents at all -
  /// so the caller leaves what it already has, exactly as the old loop did with
  /// an empty list.
  ///
  /// [current] is the zone already in use. When the point matches nothing it is
  /// kept, because a customer who has chosen an area must not be moved out of it
  /// by a background refresh. Only when there is no current zone does a
  /// placeholder get picked - the first published zone - so that the screens
  /// which read `Constant.selectedZone!` still have something to read, which is
  /// the one reason the original `else` branch was not simply removed.
  static ZoneChoice? choose(
    List<ZoneModel>? zones, {
    required double? latitude,
    required double? longitude,
    ZoneModel? current,
  }) {
    if (zones == null || zones.isEmpty) return null;

    if (latitude != null && longitude != null) {
      // The zone already in use wins whenever it still contains the point.
      //
      // This project has two published zones over the same city - "Kohat" and
      // "Pakistan (Nationwide)" - and the old loop simply took the first match
      // in whatever order Firestore returned them. The store list is filtered by
      // the chosen zone, so a rebuild could quietly hand the customer a
      // different set of stores for the same address. Preferring what they
      // already had makes the choice stable.
      if (current != null && _contains(current, latitude, longitude)) {
        return ZoneChoice(current, isAvailable: true);
      }

      for (final ZoneModel zone in zones) {
        if (_contains(zone, latitude, longitude)) {
          return ZoneChoice(zone, isAvailable: true);
        }
      }
    }

    return ZoneChoice(current ?? zones.first, isAvailable: false);
  }

  static bool _contains(ZoneModel zone, double latitude, double longitude) {
    final List<GeoPoint>? area = zone.area;
    if (area == null || area.isEmpty) return false;
    return Constant.isPointInPolygon(LatLng(latitude, longitude), area);
  }

  /// Applies [choose] to the globals the app reads everywhere.
  static void apply(
    List<ZoneModel>? zones, {
    required double? latitude,
    required double? longitude,
  }) {
    final ZoneChoice? choice = choose(zones, latitude: latitude, longitude: longitude, current: Constant.selectedZone);
    if (choice == null) return;
    Constant.selectedZone = choice.zone;
    Constant.isZoneAvailable = choice.isAvailable;
  }
}
