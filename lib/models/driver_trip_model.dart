import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/driver_trip_state.dart';

/// One driver-created intercity / local **full vehicle** trip.
///
/// Stored at `driver_trips/{tripId}`.
///
/// The driver-facing card fields are denormalised onto the trip for the same
/// reason `RideBidModel` denormalises them onto a bid: the customer's list is
/// then one subscription instead of one extra `users` read per row, which is
/// exactly the N+1 the Session 1 audit set out to remove. None of them is
/// contact information - the reserving customer's phone number lives in the
/// `reservation` subcollection, and the driver's own phone number is not here
/// at all.
class DriverTripModel {
  DriverTripModel({
    this.id,
    this.driverId,
    this.sectionId,
    this.status,
    this.fromAddress,
    this.fromLocation,
    this.toAddress,
    this.toLocation,
    this.tripDateTime,
    this.note,
    this.fullVehiclePrice,
    this.createdAt,
    this.updatedAt,
    this.visibilityExpiresAt,
    this.visibilityHours,
    this.driverName,
    this.driverPhoto,
    this.driverRating,
    this.driverReviewsCount,
    this.driverCompletedTrips,
    this.driverFcmToken,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.airConditioning,
    this.reservedBy,
    this.reservedByName,
    this.reservedByPhoto,
    this.reservedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.expiredAt,
  });

  String? id;
  String? driverId;
  String? sectionId;

  /// One of the [DriverTripStatus] constants.
  String? status;

  String? fromAddress;
  TripLocation? fromLocation;
  String? toAddress;
  TripLocation? toLocation;

  /// Departure date and time as one instant.
  Timestamp? tripDateTime;

  /// The driver's short note to customers.
  String? note;

  /// The price of the whole vehicle. A number, not a string, so it can be
  /// compared and sorted without parsing.
  num? fullVehiclePrice;

  Timestamp? createdAt;
  Timestamp? updatedAt;
  Timestamp? visibilityExpiresAt;
  num? visibilityHours;

  String? driverName;
  String? driverPhoto;
  num? driverRating;
  num? driverReviewsCount;
  num? driverCompletedTrips;

  /// So the customer's app can tell the driver about a reservation through the
  /// project's existing device-to-device FCM path. A rotating device handle,
  /// not contact information - the same field, for the same reason, that a
  /// redacted bidding author keeps.
  String? driverFcmToken;

  String? vehicleType;
  String? vehicleBrand;
  String? vehicleModel;
  String? vehiclePlate;

  /// `true` = AC, `false` = Non-AC, `null` = the driver has not stated it.
  /// Null renders as nothing rather than as a "Non-AC" claim about a vehicle
  /// nobody has described, which is how the bidding offer card treats it too.
  bool? airConditioning;

  String? reservedBy;
  String? reservedByName;
  String? reservedByPhoto;
  Timestamp? reservedAt;

  Timestamp? cancelledAt;
  String? cancelledBy;
  Timestamp? expiredAt;

  DriverTripModel.fromJson(Map<String, dynamic> json) {
    id = json[DriverTripFields.id]?.toString();
    driverId = json[DriverTripFields.driverId]?.toString();
    sectionId = json[DriverTripFields.sectionId]?.toString();
    status = json[DriverTripFields.status]?.toString();
    fromAddress = json[DriverTripFields.fromAddress]?.toString();
    fromLocation = TripLocation.fromJson(json[DriverTripFields.fromLocation]);
    toAddress = json[DriverTripFields.toAddress]?.toString();
    toLocation = TripLocation.fromJson(json[DriverTripFields.toLocation]);
    tripDateTime = _timestamp(json[DriverTripFields.tripDateTime]);
    note = json[DriverTripFields.note]?.toString();
    fullVehiclePrice = _number(json[DriverTripFields.fullVehiclePrice]);
    createdAt = _timestamp(json[DriverTripFields.createdAt]);
    updatedAt = _timestamp(json[DriverTripFields.updatedAt]);
    visibilityExpiresAt = _timestamp(json[DriverTripFields.visibilityExpiresAt]);
    visibilityHours = _number(json[DriverTripFields.visibilityHours]);
    driverName = json['driverName']?.toString();
    driverPhoto = json['driverPhoto']?.toString();
    driverRating = _number(json['driverRating']);
    driverReviewsCount = _number(json['driverReviewsCount']);
    driverCompletedTrips = _number(json['driverCompletedTrips']);
    driverFcmToken = json['driverFcmToken']?.toString();
    vehicleType = json['vehicleType']?.toString();
    vehicleBrand = json['vehicleBrand']?.toString();
    vehicleModel = json['vehicleModel']?.toString();
    vehiclePlate = json['vehiclePlate']?.toString();
    airConditioning = json['airConditioning'] is bool ? json['airConditioning'] as bool : null;
    reservedBy = json[DriverTripFields.reservedBy]?.toString();
    reservedByName = json[DriverTripFields.reservedByName]?.toString();
    reservedByPhoto = json[DriverTripFields.reservedByPhoto]?.toString();
    reservedAt = _timestamp(json[DriverTripFields.reservedAt]);
    cancelledAt = _timestamp(json[DriverTripFields.cancelledAt]);
    cancelledBy = json[DriverTripFields.cancelledBy]?.toString();
    expiredAt = _timestamp(json[DriverTripFields.expiredAt]);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        DriverTripFields.id: id,
        DriverTripFields.driverId: driverId,
        DriverTripFields.sectionId: sectionId,
        DriverTripFields.status: status,
        DriverTripFields.fromAddress: fromAddress,
        DriverTripFields.fromLocation: fromLocation?.toJson(),
        DriverTripFields.toAddress: toAddress,
        DriverTripFields.toLocation: toLocation?.toJson(),
        DriverTripFields.tripDateTime: tripDateTime,
        DriverTripFields.note: note,
        DriverTripFields.fullVehiclePrice: fullVehiclePrice,
        DriverTripFields.createdAt: createdAt,
        DriverTripFields.updatedAt: updatedAt,
        DriverTripFields.visibilityExpiresAt: visibilityExpiresAt,
        DriverTripFields.visibilityHours: visibilityHours,
        'driverName': driverName,
        'driverPhoto': driverPhoto,
        'driverRating': driverRating,
        'driverReviewsCount': driverReviewsCount,
        'driverCompletedTrips': driverCompletedTrips,
        'driverFcmToken': driverFcmToken,
        'vehicleType': vehicleType,
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate,
        'airConditioning': airConditioning,
        DriverTripFields.reservedBy: reservedBy,
        DriverTripFields.reservedByName: reservedByName,
        DriverTripFields.reservedByPhoto: reservedByPhoto,
        DriverTripFields.reservedAt: reservedAt,
        DriverTripFields.cancelledAt: cancelledAt,
        DriverTripFields.cancelledBy: cancelledBy,
        DriverTripFields.expiredAt: expiredAt,
      };

  /// "Brand Model" for the vehicle line, blank when the driver has filled in
  /// neither.
  String get vehicleDescription => '${vehicleBrand ?? ''} ${vehicleModel ?? ''}'.trim();

  bool get isActive => status == DriverTripStatus.active;

  bool get isBooked => status == DriverTripStatus.booked;

  bool get hasReservation => (reservedBy ?? '').isNotEmpty;

  /// Whether a customer browsing right now should still see this trip.
  ///
  /// The Firestore query already filters on `status == active`; this is the
  /// client-side guard that covers the gap between a trip's window closing and
  /// the next run of the maintenance sweep that flips its status.
  bool isVisibleAt(DateTime now) {
    if (!isActive) return false;
    return DriverTripVisibility.isVisibleAt(now, visibilityExpiresAt: visibilityExpiresAt, tripDateTime: tripDateTime);
  }

  /// Re-runs the Post a Trip rules against the built document.
  ///
  /// The form checks these before the driver can press Publish; the write path
  /// checks them again on the model it is about to send, so a malformed trip
  /// cannot reach Firestore through a code path that skipped the form.
  List<TripValidationError> validationErrorsAt(DateTime now) {
    final DateTime? departure = tripDateTime?.toDate();
    return DriverTripValidation.validate(
      fromAddress: fromAddress ?? '',
      fromLocation: fromLocation,
      toAddress: toAddress ?? '',
      toLocation: toLocation,
      date: departure,
      time: departure,
      note: note ?? '',
      price: (fullVehiclePrice ?? 0).toString(),
      now: now,
    );
  }

  /// The status a customer or the driver should be shown, which is [status]
  /// except while an active trip is sitting past its window waiting for the
  /// sweep.
  String effectiveStatusAt(DateTime now) {
    if (isActive && !isVisibleAt(now)) return DriverTripStatus.expired;
    return status ?? DriverTripStatus.active;
  }

  static Timestamp? _timestamp(Object? raw) {
    if (raw is Timestamp) return raw;
    if (raw is DateTime) return Timestamp.fromDate(raw);
    return null;
  }

  static num? _number(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }
}

/// The reserving customer's contact block, at
/// `driver_trips/{tripId}/reservation/{customerId}`.
///
/// Written by the customer's own reservation transaction, so the customer is
/// the one handing their details over, and only once they have taken the trip.
/// It is a separate document rather than fields on the trip because the trip
/// is what every browsing customer reads.
class TripReservationModel {
  TripReservationModel({
    this.id,
    this.tripId,
    this.customerId,
    this.customerName,
    this.customerPhoto,
    this.phoneNumber,
    this.countryCode,
    this.email,
    this.fcmToken,
    this.createdAt,
  });

  String? id;
  String? tripId;
  String? customerId;
  String? customerName;
  String? customerPhoto;
  String? phoneNumber;
  String? countryCode;
  String? email;
  String? fcmToken;
  Timestamp? createdAt;

  TripReservationModel.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    tripId = json['tripId']?.toString();
    customerId = json['customerId']?.toString();
    customerName = json['customerName']?.toString();
    customerPhoto = json['customerPhoto']?.toString();
    phoneNumber = json['phoneNumber']?.toString();
    countryCode = json['countryCode']?.toString();
    email = json['email']?.toString();
    fcmToken = json['fcmToken']?.toString();
    createdAt = json['createdAt'] is Timestamp ? json['createdAt'] as Timestamp : null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'tripId': tripId,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhoto': customerPhoto,
        'phoneNumber': phoneNumber,
        'countryCode': countryCode,
        'email': email,
        'fcmToken': fcmToken,
        'createdAt': createdAt,
      };

  /// Dialable number, the way every other screen in these apps builds one.
  String get fullPhoneNumber => '${countryCode ?? ''}${phoneNumber ?? ''}';
}
