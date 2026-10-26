import 'package:cloud_firestore/cloud_firestore.dart';

/// The lifecycle of a driver-created intercity / local **full vehicle** trip.
///
/// A trip is not a ride. It lives in its own `driver_trips` collection so that
/// nothing about a normal taxi booking becomes ambiguous: `rides` documents are
/// created by a customer, dispatched by `cabScheduleRide.js` and carry fare,
/// tax, commission and payment fields that a driver-advertised trip does not
/// have. Overloading `rides` would put author-less documents in front of the
/// dispatcher and in every existing ride query.
class DriverTripStatus {
  /// Published and visible to customers.
  static const String active = 'active';

  /// A customer has taken the whole vehicle. Exactly one customer ever
  /// reaches this state per trip - the reservation transaction guarantees it.
  static const String booked = 'booked';

  /// The visibility window closed, or the departure time passed, without a
  /// reservation. Kept as history rather than deleted.
  static const String expired = 'expired';

  /// The driver withdrew the trip.
  static const String cancelled = 'cancelled';

  /// A booked trip whose departure time has passed: it ran, and it is history.
  ///
  /// Written by **one** writer, the scheduled sweep in
  /// `driverTripsMaintenance.js`, on the server clock - for the same reason
  /// `expired` is. "Has this trip happened yet?" must not be answered from a
  /// phone whose clock the driver sets, and a customer and a driver looking at
  /// the same trip have to get the same answer.
  ///
  /// Neither app ever writes it. Until that script is deployed no document
  /// carries this value, so adding the constant changes nothing about a trip
  /// that exists today.
  static const String completed = 'completed';

  /// Statuses a customer may still reserve.
  static bool acceptsReservation(String? status) => status == active;

  /// Whether the trip is done, one way or another.
  ///
  /// `completed` joins `expired` and `cancelled` here, which is what stops the
  /// driver's card offering Call and Chat for a journey that already ran.
  static bool isFinished(String? status) => status == expired || status == cancelled || status == completed;

  /// The full set, in the order the driver's own list shows them.
  static const List<String> all = <String>[active, booked, completed, expired, cancelled];
}

/// Who ended a trip.
class DriverTripCancelledBy {
  static const String driver = 'driver';
  static const String admin = 'admin';
}

/// Field names on `driver_trips/{tripId}`.
///
/// Collected here so the two Flutter apps, the maintenance script and the
/// admin panel all spell them the same way, exactly as
/// `RideBiddingFields` does for the bidding feature.
class DriverTripFields {
  static const String id = 'id';
  static const String driverId = 'driverId';
  static const String sectionId = 'sectionId';
  static const String status = 'status';

  static const String fromAddress = 'fromAddress';
  static const String fromLocation = 'fromLocation';
  static const String toAddress = 'toAddress';
  static const String toLocation = 'toLocation';

  /// Departure date **and** time, as one instant. The form collects them
  /// separately because the client asked for a Date field and a Time field,
  /// but storing one timestamp keeps ordering and expiry unambiguous.
  static const String tripDateTime = 'tripDateTime';

  static const String note = 'note';

  /// The price of the **whole vehicle**. There is deliberately no seat count
  /// and no per-seat price anywhere in this feature.
  static const String fullVehiclePrice = 'fullVehiclePrice';

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  /// When the trip stops being shown to customers. Calculated at publish time
  /// from the admin's global setting, so changing the setting later does not
  /// retroactively re-open or close trips already posted.
  static const String visibilityExpiresAt = 'visibilityExpiresAt';

  /// The setting in force when the trip was published, for audit.
  static const String visibilityHours = 'visibilityHours';

  static const String reservedBy = 'reservedBy';
  static const String reservedByName = 'reservedByName';
  static const String reservedByPhoto = 'reservedByPhoto';
  static const String reservedAt = 'reservedAt';

  static const String cancelledAt = 'cancelledAt';
  static const String cancelledBy = 'cancelledBy';
  static const String expiredAt = 'expiredAt';

  /// When the sweep decided a booked trip had run. Stamped alongside the
  /// `completed` status and never written by either app.
  static const String completedAt = 'completedAt';
}

/// The collection this feature owns, and the subcollection that holds the
/// reserving customer's contact details.
class DriverTripCollections {
  static const String trips = 'driver_trips';

  /// `driver_trips/{tripId}/reservation/{customerId}`.
  ///
  /// The contact block lives here rather than on the trip for the same reason
  /// a bidding request carries no `author.phoneNumber`: the trip document is
  /// what every browsing customer reads, and a phone number does not belong
  /// in it. The driver reads this one document once the trip is theirs.
  static const String reservation = 'reservation';
}

/// A point on the map, in the shape this project already uses for
/// `sourceLocation` / `destinationLocation` on a ride.
class TripLocation {
  const TripLocation({this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  static TripLocation? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? lat = json['latitude'];
    final Object? lng = json['longitude'];
    final double? latitude = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    final double? longitude = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');
    if (latitude == null || longitude == null) return null;
    return TripLocation(latitude: latitude, longitude: longitude);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'latitude': latitude, 'longitude': longitude};

  bool get isSet => latitude != null && longitude != null;
}

/// Why a trip could not be published.
///
/// One enum shared by the form, the service and the tests, so the screen and
/// the write path can never disagree about what "valid" means.
enum TripValidationError {
  fromRequired,
  toRequired,
  sameFromAndTo,
  dateRequired,
  timeRequired,
  dateInPast,
  noteTooLong,
  priceRequired,
  priceNotPositive,
}

/// The rules the Post a Trip form enforces.
///
/// Deliberately pure: no Firestore, no widgets, so the driver app's tests can
/// run them directly.
class DriverTripValidation {
  /// The note is a short message to customers, not a description field.
  static const int maxNoteLength = 200;

  /// How close two points may be before From and To count as the same place.
  /// 50 m absorbs the difference between two taps on the same building
  /// without letting a genuine short hop be rejected.
  static const double sameLocationMetres = 50;

  static List<TripValidationError> validate({
    required String fromAddress,
    required TripLocation? fromLocation,
    required String toAddress,
    required TripLocation? toLocation,
    required DateTime? date,
    required DateTime? time,
    required String note,
    required String price,
    required DateTime now,
  }) {
    final List<TripValidationError> errors = <TripValidationError>[];

    if (fromAddress.trim().isEmpty || fromLocation == null || !fromLocation.isSet) {
      errors.add(TripValidationError.fromRequired);
    }
    if (toAddress.trim().isEmpty || toLocation == null || !toLocation.isSet) {
      errors.add(TripValidationError.toRequired);
    }
    if (errors.isEmpty && isSamePlace(fromAddress, fromLocation, toAddress, toLocation)) {
      errors.add(TripValidationError.sameFromAndTo);
    }

    if (date == null) {
      errors.add(TripValidationError.dateRequired);
    }
    if (time == null) {
      errors.add(TripValidationError.timeRequired);
    }
    if (date != null && time != null) {
      final DateTime departure = combine(date, time);
      if (!departure.isAfter(now)) errors.add(TripValidationError.dateInPast);
    }

    if (note.trim().length > maxNoteLength) errors.add(TripValidationError.noteTooLong);

    final String trimmedPrice = price.trim();
    if (trimmedPrice.isEmpty) {
      errors.add(TripValidationError.priceRequired);
    } else {
      final double? amount = double.tryParse(trimmedPrice);
      if (amount == null || !amount.isFinite || amount <= 0) {
        errors.add(TripValidationError.priceNotPositive);
      }
    }

    return errors;
  }

  /// Date from one picker, time from the other, as one departure instant.
  static DateTime combine(DateTime date, DateTime time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  /// From and To are the same place when the coordinates are within
  /// [sameLocationMetres], or - when coordinates are missing - when the
  /// addresses match apart from case and surrounding whitespace.
  static bool isSamePlace(String fromAddress, TripLocation? from, String toAddress, TripLocation? to) {
    if (from != null && from.isSet && to != null && to.isSet) {
      return metresBetween(from, to) < sameLocationMetres;
    }
    return fromAddress.trim().toLowerCase() == toAddress.trim().toLowerCase();
  }

  /// Straight-line distance, equirectangular approximation. Only ever used to
  /// answer "are these the same spot?", where a few metres of error is
  /// irrelevant.
  static double metresBetween(TripLocation a, TripLocation b) {
    const double earthRadius = 6371000;
    final double lat1 = (a.latitude ?? 0) * 3.141592653589793 / 180;
    final double lat2 = (b.latitude ?? 0) * 3.141592653589793 / 180;
    final double dLat = lat2 - lat1;
    final double dLng = ((b.longitude ?? 0) - (a.longitude ?? 0)) * 3.141592653589793 / 180;
    final double x = dLng * _cos((lat1 + lat2) / 2);
    return earthRadius * _sqrt(dLat * dLat + x * x);
  }

  static double _cos(double radians) {
    // Small, dependency-free cosine: 8 terms of the Taylor series is exact to
    // better than 1e-9 over the range latitudes can take.
    double reduced = radians;
    double term = 1;
    double sum = 1;
    for (int n = 1; n <= 8; n++) {
      term = -term * reduced * reduced / ((2 * n - 1) * (2 * n));
      sum += term;
    }
    return sum;
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value;
    for (int i = 0; i < 24; i++) {
      guess = 0.5 * (guess + value / guess);
    }
    return guess;
  }
}

/// Runtime view of the visibility window.
class DriverTripVisibility {
  /// The instant a trip published now should stop being listed.
  static Timestamp expiryFor({required DateTime createdAt, required int visibilityHours}) =>
      Timestamp.fromDate(createdAt.add(Duration(hours: visibilityHours)));

  /// Whether a trip should still be shown to customers.
  ///
  /// A trip drops out of the active list for either of two reasons: the
  /// admin-configured visibility window closed, or the departure time itself
  /// has passed. The second one matters because a trip posted with a long
  /// window but a departure two hours away is stale the moment it leaves.
  static bool isVisibleAt(DateTime now, {Timestamp? visibilityExpiresAt, Timestamp? tripDateTime}) {
    if (visibilityExpiresAt != null && !now.isBefore(visibilityExpiresAt.toDate())) return false;
    if (tripDateTime != null && !now.isBefore(tripDateTime.toDate())) return false;
    return true;
  }
}
