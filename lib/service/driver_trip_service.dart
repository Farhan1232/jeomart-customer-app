import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/driver_trip_ledger.dart';
import 'package:customer/utils/driver_trip_state.dart';
import 'package:customer/utils/trip_transaction.dart';
import 'package:get/get.dart';

/// The customer side of driver-created trips.
///
/// Reads the `driver_trips` collection the driver app writes, and books the
/// whole vehicle through one transaction so two customers cannot both take it.
class DriverTripService {
  static FirebaseFirestore get _fireStore => FireStoreUtils.fireStore;

  static DriverTripLedger get ledger =>
      DriverTripLedger(FirestoreTripTransactionRunner(_fireStore), tripsCollection: CollectionName.driverTrips);

  /// Active trips in the customer's current section, newest first.
  ///
  /// "New trips from drivers will show up and old trips will go down" is the
  /// client's requirement, and this is where it is satisfied: the ordering is
  /// `createdAt` descending **in the query**, so the newest page is the first
  /// page and the paginator never has to hold, let alone sort, the whole
  /// collection.
  ///
  /// The visibility window is deliberately **not** an inequality filter here.
  /// Firestore requires the first `orderBy` to be the inequality field, so
  /// `where(visibilityExpiresAt > now)` would force the list to be sorted by
  /// expiry instead of by newest. Expiry is therefore a status the maintenance
  /// sweep writes, plus the client-side guard in
  /// `DriverTripModel.isVisibleAt`, which covers the minute between a window
  /// closing and the sweep noticing.
  static Query<Map<String, dynamic>> availableTripsQuery() {
    return _fireStore
        .collection(CollectionName.driverTrips)
        .where(DriverTripFields.sectionId, isEqualTo: Constant.sectionConstantModel?.id)
        .where(DriverTripFields.status, isEqualTo: DriverTripStatus.active)
        .orderBy(DriverTripFields.createdAt, descending: true);
  }

  /// The trips this customer has taken the vehicle on.
  ///
  /// Deliberately **one equality filter and no `orderBy`**. Firestore serves an
  /// equality on a single field from the automatic index it maintains for every
  /// field, so this query works the moment the app is installed - no composite
  /// index has to be deployed first, and the tab cannot come back empty with
  /// `FAILED_PRECONDITION` on a project where the index is still building.
  ///
  /// Newest-first is applied in Dart instead, in
  /// `AvailableTripsController.myBookings`. A customer's own bookings are a
  /// short list, so sorting them locally costs nothing; the browsing list,
  /// which can be long, keeps its indexed `createdAt` ordering.
  static Query<Map<String, dynamic>> myBookedTripsQuery(String customerId) {
    return _fireStore
        .collection(CollectionName.driverTrips)
        .where(DriverTripFields.reservedBy, isEqualTo: customerId);
  }

  /// The posting driver's public profile, for the phone number and the chat
  /// token on a trip this customer has booked.
  ///
  /// Read live rather than copied onto the trip at booking time, for two
  /// reasons: a driver who changes their number is still reachable, and the
  /// bookings that already exist in the project - made before this screen did -
  /// get a phone number without any migration.
  static Future<UserModel?> driverProfile(String driverId) async {
    if (driverId.isEmpty) return null;
    try {
      return await FireStoreUtils.getUserProfile(driverId);
    } catch (error) {
      log('DriverTripService.driverProfile failed :: $error');
      return null;
    }
  }

  /// One trip, live, so a card the customer is looking at reflects somebody
  /// else taking the vehicle.
  static Stream<DriverTripModel?> tripStream(String tripId) {
    return _fireStore
        .collection(CollectionName.driverTrips)
        .doc(tripId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists ? DriverTripModel.fromJson(doc.data()!) : null);
  }

  /// Books the whole vehicle for the signed-in customer.
  ///
  /// The contact block is written to the trip's `reservation` subcollection in
  /// the same transaction. That is the moment the customer hands their phone
  /// number over, and it is handed to the one driver whose trip it is - the
  /// trip document every other customer can read never carries it, which is
  /// the same shaping the bidding feature uses for a ride author.
  static Future<ReserveTripResult> reserveTrip(DriverTripModel trip) async {
    final UserModel? customer = await _signedInCustomer();
    final String customerId = customer?.id ?? FireStoreUtils.getCurrentUid();
    if (customer == null || customerId.isEmpty) return ReserveTripResult.tripGone;

    return ledger.reserveTrip(
      tripId: trip.id ?? '',
      customerId: customerId,
      customerName: customer.fullName().trim(),
      customerPhoto: customer.profilePictureURL ?? '',
      reservation: TripReservationModel(
        customerName: customer.fullName().trim(),
        customerPhoto: customer.profilePictureURL ?? '',
        phoneNumber: customer.phoneNumber ?? '',
        countryCode: customer.countryCode ?? '',
        email: customer.email ?? '',
        fcmToken: customer.fcmToken ?? '',
      ),
      now: DateTime.now(),
    );
  }

  /// The signed-in customer, read if it is not in memory yet.
  ///
  /// `Constant.userModel` is populated at launch, but it is populated
  /// asynchronously, and a booking must not depend on that having finished.
  /// Reading the profile here costs one cached document lookup and turns the
  /// old failure - a booking refused with "This trip is no longer available"
  /// because the profile had not arrived - back into a booking.
  static Future<UserModel?> _signedInCustomer() async {
    final UserModel? inMemory = Constant.userModel;
    if (inMemory != null) return inMemory;

    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty) return null;
    try {
      final UserModel? loaded = await FireStoreUtils.getUserProfile(uid);
      if (loaded != null) Constant.userModel = loaded;
      return loaded;
    } catch (error) {
      log('DriverTripService._signedInCustomer failed :: $error');
      return null;
    }
  }

  /// Tells the driver their vehicle has been booked.
  ///
  /// Uses the project's existing device-to-device FCM helper with explicit
  /// text, the same way the bidding feature does, rather than a
  /// `notifications/{type}` document - creating those rows would mean writing
  /// to the client's production Firestore.
  static Future<void> notifyDriverOfReservation(DriverTripModel trip) async {
    final String token = trip.driverFcmToken ?? '';
    if (token.isEmpty) return;
    try {
      await SendNotification.sendOneNotification(
        token: token,
        title: 'Trip booked'.tr,
        body: 'A customer booked your full vehicle trip.'.tr,
        payload: <String, dynamic>{'type': Constant.tripReservedNotification, 'tripId': trip.id ?? ''},
      );
    } catch (error) {
      log('DriverTripService.notifyDriverOfReservation failed :: $error');
    }
  }
}
