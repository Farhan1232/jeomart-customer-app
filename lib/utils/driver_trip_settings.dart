import 'dart:math' as math;

/// Global configuration for driver-created trips, read from
/// `settings/driverTripsSettings`.
///
/// Two settings, and both were asked for:
///
/// > Give the trip a time for that time the trip will be shown and from admin
/// > panel we can edit that time also.
///
/// > it must be setup from admin panel to bidding and driver posted trips all
///
/// - a **time**, [visibilityHours], and a **distance**, [radiusKm].
///
/// The unit is **hours**, and the admin panel says so next to the field. Hours
/// rather than days because the useful values sit either side of a day - a
/// morning trip advertised for 6 hours, an intercity run advertised for 3 days
/// - and one unit that covers both reads better than a days box that has to
/// accept fractions.
///
/// A missing, empty or unreadable document falls back to [defaultVisibilityHours]
/// and to *no* distance limit, rather than to zero and to a zero-kilometre
/// radius, so a settings outage cannot make every trip invisible the moment it
/// is published.
class DriverTripSettings {
  const DriverTripSettings({
    this.visibilityHours = defaultVisibilityHours,
    this.radiusKm = defaultRadiusKm,
    this.openToAllDrivers = defaultOpenToAllDrivers,
  });

  /// The settings document id inside the existing `settings` collection.
  static const String documentId = 'driverTripsSettings';

  /// 24 hours. Matches the default the admin panel writes on its first save.
  static const int defaultVisibilityHours = 24;

  /// No distance limit. A trip is shown wherever in the section it starts,
  /// which is how the feature behaved before the radius existed - so an
  /// admin who never opens the field sees no change.
  static const double defaultRadiusKm = 0;

  /// **Off.** My Trips stays behind the per-driver grant unless an admin
  /// deliberately turns this on.
  ///
  /// The default is what an absent, empty or unreadable settings document
  /// falls back to, and it is `false` on purpose. This file's rule is that a
  /// settings outage must never make the feature disappear *or silently widen
  /// access*; of the two, defaulting open is the one that cannot be undone -
  /// drivers would start posting trips the admin never authorised, and taking
  /// the permission back afterwards does not un-post them.
  static const bool defaultOpenToAllDrivers = false;

  /// The ceiling the admin panel enforces too. Past this a radius is not a
  /// filter any more, and a typo should not be able to hide every trip.
  static const double maxRadiusKm = 500;

  /// One hour to thirty days. The upper bound exists so a typo cannot pin a
  /// trip to the customer's list for a year.
  static const int minVisibilityHours = 1;
  static const int maxVisibilityHours = 720;

  /// How long a newly published trip stays in the customer's Available Trips
  /// list.
  final int visibilityHours;

  /// How far from the customer a trip may START and still be listed, in
  /// kilometres. **0 means no limit**, which is both the default and what
  /// an unreadable settings document falls back to: a settings outage must
  /// not empty the customer's list.
  final double radiusKm;

  /// Whether **every** driver may post trips, rather than only those holding
  /// an admin-issued `myTripsAccess` grant.
  ///
  /// One global switch, so the client can run the feature either way without
  /// another build. Per-driver grants keep working whichever way it is set:
  /// this widens access, it never narrows it, so turning the switch back off
  /// leaves every driver the admin granted individually exactly as they were.
  final bool openToAllDrivers;

  /// The fallback configuration.
  static const DriverTripSettings defaults = DriverTripSettings();

  factory DriverTripSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final num? raw = _readNum(json['tripVisibilityHours']);
    final num? rawRadius = _readNum(json['tripRadiusKm']);
    final double radiusKm =
        rawRadius == null || rawRadius <= 0 ? defaultRadiusKm : rawRadius.toDouble().clamp(0, maxRadiusKm);
    final bool openToAllDrivers = _readBool(json['tripOpenToAllDrivers']);
    if (raw == null) return DriverTripSettings(radiusKm: radiusKm, openToAllDrivers: openToAllDrivers);
    return DriverTripSettings(
      visibilityHours: raw.round().clamp(minVisibilityHours, maxVisibilityHours),
      radiusKm: radiusKm,
      openToAllDrivers: openToAllDrivers,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tripVisibilityHours': visibilityHours,
        'tripRadiusKm': radiusKm,
        'tripOpenToAllDrivers': openToAllDrivers,
      };

  /// Whether the radius actually filters anything. Kept next to the field
  /// so no caller has to remember that 0 is the open setting.
  bool get hasRadius => radiusKm > 0;

  /// Whether a trip starting at ([tripLat], [tripLng]) is close enough to a
  /// customer at ([fromLat], [fromLng]) to be listed.
  ///
  /// Permissive at every edge, and deliberately so - a radius exists to
  /// shorten a long list, never to be the reason a customer sees nothing:
  ///
  /// * no radius set -> every trip;
  /// * customer location not known yet (permission still being asked for,
  ///   or a fix that has not arrived) -> every trip;
  /// * trip posted without coordinates -> shown, because the trip itself is
  ///   real and only its map pin is missing.
  ///
  /// The comparison is `<=`, so a trip exactly on the boundary is included.
  bool includesTrip({double? fromLat, double? fromLng, double? tripLat, double? tripLng}) {
    if (!hasRadius) return true;
    if (fromLat == null || fromLng == null) return true;
    if (tripLat == null || tripLng == null) return true;
    return distanceKm(fromLat, fromLng, tripLat, tripLng) <= radiusKm;
  }

  /// Great-circle distance in kilometres.
  ///
  /// Written out here rather than taken from Geolocator so the radius rule is
  /// a pure function the tests can exercise without a platform channel, and
  /// so the driver and customer apps compute it identically.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0088;
    final double dLat = _radians(lat2 - lat1);
    final double dLon = _radians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  static num? _readNum(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }

  /// Deliberately strict, and the opposite of [_readNum]'s permissiveness.
  ///
  /// Only a real `true`, the number 1, or the strings "true" / "1" open the
  /// feature up. The admin panel writes a boolean; every other shape - a
  /// missing field, `null`, an empty string, a typo - is a value nobody chose,
  /// and a value nobody chose must not grant a permission.
  static bool _readBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw == 1;
    if (raw is String) {
      final String value = raw.trim().toLowerCase();
      return value == 'true' || value == '1';
    }
    return defaultOpenToAllDrivers;
  }
}
