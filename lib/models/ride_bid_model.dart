import 'package:cloud_firestore/cloud_firestore.dart';

/// The lifecycle of one driver's offer on one bidding ride.
///
/// Deterministic and explicit, as the brief requires. Only [pending] is live;
/// everything else is terminal.
class RideBidStatus {
  /// Submitted, waiting for the customer.
  static const String pending = 'pending';

  /// The customer picked this offer. Exactly one bid per ride ever reaches
  /// this state - the acceptance transaction is what guarantees it.
  static const String accepted = 'accepted';

  /// The customer rejected this specific offer.
  static const String rejected = 'rejected';

  /// The ride was won by someone else, cancelled, or the request expired.
  static const String closed = 'closed';

  /// The driver withdrew the offer.
  static const String withdrawn = 'withdrawn';

  /// Written by the trusted sweep when an offer breaks the minimum-fare rule.
  static const String voided = 'void';

  /// A bid in this state can still be accepted.
  static bool isLive(String? status) => status == pending;
}

/// Whether the driver took the customer's price or named their own.
class RideBidType {
  /// Driver accepted the customer's offered fare unchanged.
  static const String accept = 'accept';

  /// Driver named a different price.
  static const String counter = 'counter';
}

/// One driver's offer on one bidding ride.
///
/// Stored at `rides/{rideId}/bids/{driverId}`. **The document id is the driver
/// id on purpose**: it makes a second offer from the same driver an update of
/// the first rather than a new row, so a duplicate tap, a retry after a
/// timeout, or two devices signed in as the same driver cannot produce two
/// competing offers.
///
/// The driver-facing fields are denormalised onto the bid so the customer's
/// offer list renders from one subscription instead of one extra `users` read
/// per offer. None of them is contact information: a driver's phone number is
/// no more exposed here than the customer's is.
class RideBidModel {
  RideBidModel({
    this.id,
    this.rideId,
    this.driverId,
    this.customerId,
    this.amount,
    this.type,
    this.status,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.driverName,
    this.driverPhoto,
    this.driverRating,
    this.driverReviewsCount,
    this.driverCompletedTrips,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.airConditioning,
  });

  /// Subcollection name under `rides/{rideId}`.
  static const String collectionName = 'bids';

  String? id;
  String? rideId;
  String? driverId;
  String? customerId;

  /// The offered fare. Stored as a number so the floor can be compared in a
  /// security rule without parsing a string.
  num? amount;

  /// [RideBidType.accept] or [RideBidType.counter].
  String? type;

  /// One of the [RideBidStatus] constants.
  String? status;

  /// The driver's note to the customer, stored as the untranslated key so
  /// each side renders it in its own language.
  String? note;

  Timestamp? createdAt;
  Timestamp? updatedAt;
  Timestamp? expiresAt;

  String? driverName;
  String? driverPhoto;
  num? driverRating;
  num? driverReviewsCount;
  num? driverCompletedTrips;
  String? vehicleType;
  String? vehicleBrand;
  String? vehicleModel;
  String? vehiclePlate;

  /// `true` = AC, `false` = Non-AC, `null` = the driver has not stated it yet.
  /// Null is rendered as nothing rather than as "Non-AC", so an unset value is
  /// never shown to the customer as a claim about the vehicle.
  bool? airConditioning;

  RideBidModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    rideId = json['rideId'];
    driverId = json['driverId'];
    customerId = json['customerId'];
    amount = json['amount'] is num ? json['amount'] as num : num.tryParse(json['amount']?.toString() ?? '');
    type = json['type'];
    status = json['status'];
    note = json['note'];
    createdAt = json['createdAt'] is Timestamp ? json['createdAt'] as Timestamp : null;
    updatedAt = json['updatedAt'] is Timestamp ? json['updatedAt'] as Timestamp : null;
    expiresAt = json['expiresAt'] is Timestamp ? json['expiresAt'] as Timestamp : null;
    driverName = json['driverName'];
    driverPhoto = json['driverPhoto'];
    driverRating = json['driverRating'] is num ? json['driverRating'] as num : num.tryParse(json['driverRating']?.toString() ?? '');
    driverReviewsCount = json['driverReviewsCount'] is num ? json['driverReviewsCount'] as num : num.tryParse(json['driverReviewsCount']?.toString() ?? '');
    driverCompletedTrips =
        json['driverCompletedTrips'] is num ? json['driverCompletedTrips'] as num : num.tryParse(json['driverCompletedTrips']?.toString() ?? '');
    vehicleType = json['vehicleType'];
    vehicleBrand = json['vehicleBrand'];
    vehicleModel = json['vehicleModel'];
    vehiclePlate = json['vehiclePlate'];
    airConditioning = json['airConditioning'] is bool ? json['airConditioning'] as bool : null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'rideId': rideId,
        'driverId': driverId,
        'customerId': customerId,
        'amount': amount,
        'type': type,
        'status': status,
        'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'expiresAt': expiresAt,
        'driverName': driverName,
        'driverPhoto': driverPhoto,
        'driverRating': driverRating,
        'driverReviewsCount': driverReviewsCount,
        'driverCompletedTrips': driverCompletedTrips,
        'vehicleType': vehicleType,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate,
        'airConditioning': airConditioning,
      };

  /// "Brand Model" for the vehicle line of the offer card, blank when the
  /// driver has filled in neither.
  String get vehicleDescription => '${vehicleBrand ?? ''} ${vehicleModel ?? ''}'.trim();

  bool get isLive => RideBidStatus.isLive(status);

  /// Whether this offer has run past its own deadline. Checked on both sides
  /// so a stale card cannot be accepted while the sweep has not run yet.
  bool isExpiredAt(DateTime now) {
    final Timestamp? deadline = expiresAt;
    if (deadline == null) return false;
    return now.isAfter(deadline.toDate());
  }
}
