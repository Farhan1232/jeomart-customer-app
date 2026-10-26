import 'dart:math' as math;

/// One available driver, reduced to what a map marker needs.
class NearbyDriver {
  const NearbyDriver({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.vehicleId,
    this.rotation = 0,
  });

  final String id;
  final double latitude;
  final double longitude;

  /// The vehicle type this driver is signed up with, in this section. It is
  /// what decides which icon the marker gets and whether the marker is shown
  /// at all for the customer's current selection.
  final String vehicleId;

  /// Heading, when the driver document carries one. 0 is a safe default: an
  /// unrotated marker is wrong-looking at worst, never misleading.
  final double rotation;
}

/// Which drivers a customer may be shown on the booking map.
///
/// The rules here are deliberately the **same ones `cabBiddingDispatch.js`
/// applies** when it decides who receives a request. That matters more than it
/// looks: a map that shows vehicles the dispatcher would never contact is
/// exactly the "dummy" behaviour the client objected to. A driver drawn here
/// is a driver who would actually be sent the ride.
///
/// Not mirrored, on purpose:
///
/// * the **wallet** check - the customer has no business knowing a driver's
///   balance, and it is re-checked server-side anyway;
/// * the **zone polygon** - the zone is already implied by the customer being
///   able to book at all, and a client-side polygon test per driver per map
///   frame is not worth the battery.
///
/// Both of those can only ever make the real fan-out *smaller* than what is
/// drawn, never larger, so the map never promises a vehicle that cannot come.
class NearbyDrivers {
  const NearbyDrivers._();

  /// Drivers are drawn within this many kilometres of the customer.
  ///
  /// This is a **display** radius, not the dispatch radius: it decides what is
  /// worth putting on a map the customer is looking at. The dispatch radius
  /// lives in `settings/biddingSettings.notifyRadiusKm` and is enforced on the
  /// server, where it cannot be edited by a modified client.
  static const double defaultDisplayRadiusKm = 8;

  /// Whether [driver] should appear on the map for [vehicleId].
  ///
  /// [driver] is a raw `users` document. Every field is read defensively
  /// because these documents are hand-edited in the admin panel and older rows
  /// store numbers as strings.
  static bool isVisible(
    Map<String, dynamic> driver, {
    required String sectionId,
    required String vehicleId,
    required double customerLat,
    required double customerLng,
    double radiusKm = defaultDisplayRadiusKm,
  }) {
    if (_str(driver['role']) != 'driver') return false;
    if (driver['isActive'] != true) return false;

    final List<dynamic> serviceTypes = driver['serviceTypes'] is List ? driver['serviceTypes'] as List<dynamic> : const <dynamic>[];
    if (!serviceTypes.map(_str).contains('cab-service')) return false;

    final List<dynamic> sectionIds = driver['sectionIds'] is List ? driver['sectionIds'] as List<dynamic> : const <dynamic>[];
    if (!sectionIds.map(_str).contains(sectionId)) return false;

    // ── The vehicle type. This is the whole point of the feature: a customer
    //    who has selected a bike is shown bikes, not every car in the city.
    final Map<String, dynamic>? vehicleDetails =
        driver['vehicleDetails'] is Map ? Map<String, dynamic>.from(driver['vehicleDetails'] as Map) : null;
    final Map<String, dynamic>? sectionVehicle =
        vehicleDetails != null && vehicleDetails[sectionId] is Map ? Map<String, dynamic>.from(vehicleDetails[sectionId] as Map) : null;
    if (sectionVehicle == null) return false;
    if (_str(sectionVehicle['vehicleId']) != vehicleId) return false;

    // ── Busy drivers are not available, so they are not drawn.
    if (driver['ordercabRequestData'] != null) return false;
    if (_isNonEmptyList(driver['inProgressOrderID'])) return false;
    if (_isNonEmptyList(driver['orderRequestData'])) return false;

    final Map<String, dynamic>? location =
        driver['location'] is Map ? Map<String, dynamic>.from(driver['location'] as Map) : null;
    final double? lat = _num(location?['latitude'])?.toDouble();
    final double? lng = _num(location?['longitude'])?.toDouble();
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;

    return distanceKm(customerLat, customerLng, lat, lng) <= radiusKm;
  }

  /// Builds the marker model for a driver that has passed [isVisible].
  static NearbyDriver? toMarker(String id, Map<String, dynamic> driver, {required String sectionId}) {
    final Map<String, dynamic>? location =
        driver['location'] is Map ? Map<String, dynamic>.from(driver['location'] as Map) : null;
    final double? lat = _num(location?['latitude'])?.toDouble();
    final double? lng = _num(location?['longitude'])?.toDouble();
    if (lat == null || lng == null) return null;

    final Map<String, dynamic>? vehicleDetails =
        driver['vehicleDetails'] is Map ? Map<String, dynamic>.from(driver['vehicleDetails'] as Map) : null;
    final Map<String, dynamic>? sectionVehicle =
        vehicleDetails != null && vehicleDetails[sectionId] is Map ? Map<String, dynamic>.from(vehicleDetails[sectionId] as Map) : null;

    return NearbyDriver(
      id: id,
      latitude: lat,
      longitude: lng,
      vehicleId: _str(sectionVehicle?['vehicleId']),
      rotation: _num(driver['rotation'])?.toDouble() ?? 0,
    );
  }

  /// Great-circle distance in kilometres.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0088;
    final double dLat = _radians(lat2 - lat1);
    final double dLon = _radians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  static String _str(Object? raw) => raw?.toString().trim() ?? '';

  static num? _num(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }

  static bool _isNonEmptyList(Object? raw) => raw is List && raw.isNotEmpty;
}
