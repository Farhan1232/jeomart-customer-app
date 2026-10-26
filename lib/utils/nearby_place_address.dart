import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Makes a vague OpenStreetMap address precise enough for a driver.
///
/// The streets of whole neighbourhoods - KDA Kohat among them - carry no name
/// in OpenStreetMap, so Nominatim's reverse lookup answers with the nearest
/// *unnamed* road and the address starts at the city: "Kohat, Tehsil Kohat,
/// ...". The pin is exact; only the text tells the driver nothing.
///
/// When that happens this asks Nominatim's POI layer for the nearest named
/// place and puts it in front: "Near KDA PARK, Kohat, Tehsil Kohat, ...".
/// An address that already has a name is returned untouched, and every failure
/// returns the address exactly as it was - this only ever adds detail.
class NearbyPlaceAddress {
  static const String _userAgent = 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)';

  /// A named place further away than this would mislead more than help.
  static const double maxDistanceMetres = 1000;

  static const Duration _timeout = Duration(seconds: 6);

  /// [address] with the nearest named place in front of it, when the place at
  /// [lat]/[lng] has no name of its own.
  ///
  /// [placeName] is the `name` Nominatim already returned for this point, when
  /// the caller has it; otherwise it is looked up here.
  static Future<String> describe(double lat, double lng, String address, {String? placeName}) async {
    if (address.trim().isEmpty || (lat == 0 && lng == 0)) return address;
    try {
      String? name = placeName;
      if (name == null) {
        final Map<String, dynamic>? here = await _reverse(lat, lng, poi: false);
        if (here == null) return address;
        name = here['name']?.toString() ?? '';
      }
      if (name.trim().isNotEmpty) return address;

      final Map<String, dynamic>? poi = await _reverse(lat, lng, poi: true);
      if (poi == null) return address;
      final String label = _label(poi);
      if (label.isEmpty || address.startsWith(label)) return address;

      final double? poiLat = double.tryParse(poi['lat']?.toString() ?? '');
      final double? poiLng = double.tryParse(poi['lon']?.toString() ?? '');
      if (poiLat == null || poiLng == null || metresBetween(lat, lng, poiLat, poiLng) > maxDistanceMetres) {
        return address;
      }
      return 'Near $label, $address';
    } catch (error) {
      log('NearbyPlaceAddress.describe failed :: $error');
      return address;
    }
  }

  /// The place's own name, or else its first address part (e.g. "Street 5").
  static String _label(Map<String, dynamic> poi) {
    final String name = poi['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final Object? details = poi['address'];
    if (details is Map) {
      for (final String key in const <String>['road', 'neighbourhood', 'suburb', 'quarter', 'residential']) {
        final String value = details[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  static Future<Map<String, dynamic>?> _reverse(double lat, double lng, {required bool poi}) async {
    final Uri url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1'
        '${poi ? '&layer=poi&zoom=18' : ''}');
    final http.Response response = await http.get(url, headers: {'User-Agent': _userAgent}).timeout(_timeout);
    if (response.statusCode != 200) return null;
    final Object? data = json.decode(response.body);
    if (data is! Map<String, dynamic> || data.containsKey('error')) return null;
    return data;
  }

  static double metresBetween(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLng = (lng2 - lng1) * math.pi / 180;
    final double x = dLng * math.cos((lat1 + lat2) / 2 * math.pi / 180);
    return earthRadius * math.sqrt(dLat * dLat + x * x);
  }
}
