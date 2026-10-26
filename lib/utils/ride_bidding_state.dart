import 'package:cloud_firestore/cloud_firestore.dart';

/// The bidding lifecycle of a ride, stored on the **existing** `rides`
/// document rather than in a parallel collection.
///
/// The ride stays the single source of truth: `status` still moves through the
/// same strings the whole platform already understands
/// (`Order Placed` -> `Driver Accepted` -> ...), and these fields only describe
/// how the driver was found. A ride with no [enabledField] is a normal booking
/// and behaves exactly as it always has.
class RideBiddingStatus {
  /// Written by the customer. The dispatcher has not looked at it yet.
  static const String pendingDispatch = 'pending_dispatch';

  /// Fanned out to eligible drivers; offers are being collected.
  static const String open = 'open';

  /// A winner was chosen. `winningBidId` names them. The dispatcher moves the
  /// ride on to [booked] once it has confirmed the winner's own user document
  /// carries the ride, which is what makes the hand-off survive the driver's
  /// app being closed at the moment of acceptance.
  static const String accepted = 'accepted';

  /// Awarded and reconciled: the winning driver has the ride on
  /// `inProgressOrderID` and the normal ride flow owns it from here.
  static const String booked = 'booked';

  /// The window closed with no winner.
  static const String expired = 'expired';

  /// The customer cancelled before choosing.
  static const String cancelled = 'cancelled';

  /// No eligible driver could be found at all.
  static const String noDrivers = 'no_drivers';

  /// Whether a new offer may still be written against a ride in this state.
  static bool acceptsOffers(String? status) => status == open;

  /// Whether the ride has finished bidding one way or another.
  static bool isFinished(String? status) =>
      status == accepted || status == booked || status == expired || status == cancelled || status == noDrivers;
}

/// Field names on `rides/{rideId}`. Collected here so the Dart apps, the
/// dispatcher script, the security rules and the admin panel all spell them
/// the same way.
class RideBiddingFields {
  static const String enabled = 'biddingEnabled';
  static const String status = 'biddingStatus';
  static const String offeredFare = 'offeredFare';
  static const String minimumAllowedFare = 'minimumAllowedFare';
  static const String minFarePerKmAtRequest = 'minFarePerKmAtRequest';
  /// The trip distance as a **number**.
  ///
  /// `distance` on a ride has always been a string, and Firestore security
  /// rules cannot parse a string into a number - so the fare floor could not
  /// be enforced server-side without this. Written only on bidding rides.
  static const String distanceKm = 'biddingDistanceKm';
  static const String eligibleDriverIds = 'biddingEligibleDriverIds';
  static const String expiresAt = 'biddingExpiresAt';
  static const String dispatchedAt = 'biddingDispatchedAt';
  static const String winningBidId = 'winningBidId';
  static const String bidCount = 'biddingBidCount';
  static const String acceptedAt = 'biddingAcceptedAt';
}

/// A typed view over those fields, for reading a ride snapshot.
class RideBiddingState {
  const RideBiddingState({
    this.enabled = false,
    this.status,
    this.offeredFare,
    this.minimumAllowedFare = 0,
    this.distanceKm = 0,
    this.minFarePerKmAtRequest = 0,
    this.vehicleRatePerKm,
    this.eligibleDriverIds = const <String>[],
    this.expiresAt,
    this.winningBidId,
    this.bidCount = 0,
  });

  final bool enabled;
  final String? status;
  final num? offeredFare;
  final num minimumAllowedFare;
  final num distanceKm;
  final num minFarePerKmAtRequest;

  /// The selected vehicle type's own minimum fare per km, when it has one.
  ///
  /// Read from the ride's embedded `vehicleType`, not from
  /// [minFarePerKmAtRequest]: the floor is **recomputed** on every check rather
  /// than taken from a number the client wrote, so a request that claims no
  /// floor is still held to one. The vehicle only chooses *which* configured
  /// rate applies - it cannot invent one, and it cannot turn the rule off.
  final num? vehicleRatePerKm;

  final List<String> eligibleDriverIds;
  final Timestamp? expiresAt;
  final String? winningBidId;
  final num bidCount;

  factory RideBiddingState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RideBiddingState();
    return RideBiddingState(
      enabled: json[RideBiddingFields.enabled] == true,
      status: json[RideBiddingFields.status]?.toString(),
      offeredFare: _num(json[RideBiddingFields.offeredFare]),
      minimumAllowedFare: _num(json[RideBiddingFields.minimumAllowedFare]) ?? 0,
      distanceKm: _num(json[RideBiddingFields.distanceKm]) ?? _num(json['distance']) ?? 0,
      minFarePerKmAtRequest: _num(json[RideBiddingFields.minFarePerKmAtRequest]) ?? 0,
      vehicleRatePerKm: _vehicleRate(json['vehicleType']),
      eligibleDriverIds: json[RideBiddingFields.eligibleDriverIds] is List
          ? List<String>.from((json[RideBiddingFields.eligibleDriverIds] as List).map((e) => e.toString()))
          : const <String>[],
      expiresAt: json[RideBiddingFields.expiresAt] is Timestamp ? json[RideBiddingFields.expiresAt] as Timestamp : null,
      winningBidId: json[RideBiddingFields.winningBidId]?.toString(),
      bidCount: _num(json[RideBiddingFields.bidCount]) ?? 0,
    );
  }

  bool get acceptsOffers => enabled && RideBiddingStatus.acceptsOffers(status) && winningBidId == null;

  bool get isFinished => RideBiddingStatus.isFinished(status);

  bool isExpiredAt(DateTime now) {
    final Timestamp? deadline = expiresAt;
    if (deadline == null) return false;
    return now.isAfter(deadline.toDate());
  }

  static num? _num(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }

  /// `vehicleType.biddingMinimumFarePerKm` off the ride, when the admin has set
  /// one for that vehicle. Absent, zero or unreadable means the vehicle has no
  /// rate of its own and the global one applies.
  static num? _vehicleRate(Object? vehicleType) {
    if (vehicleType is! Map) return null;
    final num? rate = _num(vehicleType['biddingMinimumFarePerKm']);
    // `NaN <= 0` is false, so a NaN rate used to be treated as a real one and
    // the floor it produced was NaN - which no offer is ever below, quietly
    // turning the minimum-fare rule off for that vehicle. The panel can no
    // longer save one, but a document saved before it could still holds it.
    if (rate == null || !rate.isFinite || rate <= 0) return null;
    return rate;
  }
}
