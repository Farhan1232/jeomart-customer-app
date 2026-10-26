import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/ride_author_privacy.dart';

/// Keeps the customer's private profile off a normal (non-bidding) ride.
///
/// The ride is written with only the [RideAuthorPrivacy] allowlist (name,
/// photo, rating, notification token). The phone number is added by this
/// customer's own app once the ride shows a driver has accepted it, so only
/// the booked driver ever receives it. Email, wallet balance, bank details,
/// saved addresses and location are never written to the ride.
class RideContactService {
  RideContactService._();

  /// Rides a contact write is already on its way for.
  static final Set<String> _inFlight = <String>{};

  /// Statuses at which a driver is booked on the ride.
  static const Set<String> _bookedStatuses = <String>{
    Constant.driverAccepted,
    Constant.orderShipped,
    Constant.orderInTransit,
  };

  /// Creates the ride document for a normal booking.
  static Future<void> placeSystemRide(CabOrderModel order) async {
    final Map<String, dynamic> ride = order.toJson();
    ride['author'] = RideAuthorPrivacy.forSystemRide(order.author?.toJson());
    await FireStoreUtils.fireStore.collection(CollectionName.rides).doc(order.id).set(ride);
  }

  /// Adds this customer's phone number to ride [rideId] once a driver has
  /// accepted it, if the ride does not already carry it.
  ///
  /// Called on every snapshot of the ride the customer is watching. It writes
  /// only when something is missing, so it is a no-op on almost every call,
  /// and it puts the number back if a later full-ride write from the driver's
  /// app cleared it.
  static void revealWhenBooked(String rideId, Map<String, dynamic> rideData, UserModel? customer) {
    if (customer == null || customer.id == null) return;
    if (!_bookedStatuses.contains(rideData['status'])) return;
    final String driverId = rideData['driverId']?.toString() ?? '';
    if (driverId.isEmpty) return;
    if (rideData['authorID']?.toString() != customer.id) return;

    final Map<String, dynamic> contact = RideAuthorPrivacy.contactFields(customer.toJson());
    if (contact.isEmpty) return;
    final Object? author = rideData['author'];
    if (!RideAuthorPrivacy.contactMissing(author is Map ? Map<String, dynamic>.from(author) : null, contact)) return;
    if (!_inFlight.add(rideId)) return;

    final Map<String, dynamic> patch = <String, dynamic>{
      for (final MapEntry<String, dynamic> entry in contact.entries) 'author.${entry.key}': entry.value,
    };
    FireStoreUtils.fireStore
        .collection(CollectionName.rides)
        .doc(rideId)
        .update(patch)
        .catchError((Object error) => log('revealWhenBooked: contact for $rideId not written :: $error'))
        .whenComplete(() => _inFlight.remove(rideId));
  }
}
