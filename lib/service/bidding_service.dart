import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/ride_bid_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/send_notification.dart';
import 'package:customer/utils/bidding_fare_rules.dart';
import 'package:customer/utils/bidding_settings.dart';
import 'package:customer/utils/ride_author_privacy.dart';
import 'package:customer/utils/ride_bid_ledger.dart';
import 'package:customer/utils/ride_bidding_state.dart';
import 'package:get/get.dart';

/// The customer side of the bidding / counter-offer feature.
///
/// Everything here is additive: when `settings/biddingSettings.enabled` is
/// false nothing in this file is ever called, and the normal taxi booking flow
/// runs unchanged.
class BiddingService {
  static FirebaseFirestore get _fireStore => FireStoreUtils.fireStore;

  static RideBidLedger get ledger => RideBidLedger(FirestoreBidTransactionRunner(_fireStore), ridesCollection: CollectionName.rides);

  static int get currencyDecimals => Constant.currencyModel?.decimal ?? 2;

  /// The trip length in **kilometres**, whatever unit the app is configured to
  /// display. `Constant.distanceType` is "Miles" on some deployments and the
  /// admin rate is per kilometre, so this conversion is what keeps the floor
  /// correct on those installs.
  static double tripDistanceKm(double distanceInAppUnits) =>
      BiddingFareRules.toKilometres(distanceInAppUnits, Constant.distanceType);

  /// `applicableRatePerKm x rideDistanceKm`, or 0 when the rule is off. Takes
  /// the trip length in the app's display unit and converts it.
  ///
  /// [vehicleType] is what makes the floor follow the vehicle: a motorcycle
  /// with its own `biddingMinimumFarePerKm` is held to that rather than to the
  /// one global rate, which is what produced a minimum above the metered price
  /// on the client's own booking.
  static double minimumAllowedFare(double distanceInAppUnits, {VehicleType? vehicleType}) => BiddingFareRules.minimumAllowedFare(
        settings: Constant.biddingSettings,
        distanceKm: tripDistanceKm(distanceInAppUnits),
        currencyDecimals: currencyDecimals,
        vehicleRatePerKm: vehicleType?.biddingMinimumFarePerKm,
      );

  /// The rate per km in force for [vehicleType], stored on the request so
  /// every later check - the driver's counter offer, the acceptance
  /// transaction, the dispatcher sweep - uses the floor the customer was shown
  /// rather than whatever the settings happen to say by then.
  static num applicableRatePerKm(VehicleType? vehicleType) {
    if (!Constant.biddingSettings.enabled || !Constant.biddingSettings.minimumFarePerKmEnabled) return 0;
    return BiddingFareRules.rateFor(
      settings: Constant.biddingSettings,
      vehicleRatePerKm: vehicleType?.biddingMinimumFarePerKm,
    );
  }

  /// Client-side check, for immediate feedback while the customer types. The
  /// same rule is re-checked inside the acceptance transaction and, once the
  /// rules in `docs/firebase_changes.md` are deployed, in Firestore itself -
  /// a modified client cannot get under the floor by skipping this.
  static FareCheckResult checkFare({required double? amount, required double distanceInAppUnits, VehicleType? vehicleType}) => BiddingFareRules.check(
        amount: amount,
        settings: Constant.biddingSettings,
        distanceKm: tripDistanceKm(distanceInAppUnits),
        currencyDecimals: currencyDecimals,
        vehicleRatePerKm: vehicleType?.biddingMinimumFarePerKm,
      );

  /// Creates a ride that is open for offers.
  ///
  /// The ride is written to the **existing** `rides` collection with the same
  /// `status` the normal flow uses, plus the bidding fields. The one
  /// difference in what is stored is the author: while offers are being
  /// collected the customer's phone number, country code and email are simply
  /// not written, because every eligible driver can read this document.
  static Future<bool> placeBiddingRide({
    required CabOrderModel orderModel,
    required double offeredFare,
    required UserModel customer,
  }) async {
    final BiddingSettings settings = Constant.biddingSettings;
    if (!settings.enabled) {
      log('placeBiddingRide called while bidding is disabled - refusing');
      return false;
    }

    // `distance` on the ride stays in the app's display unit, exactly as the
    // normal booking flow has always written it. `biddingDistanceKm` is the
    // normalised copy that the fare floor, the dispatcher and the security
    // rules all read, so none of them has to know what unit this install uses.
    final double distanceInAppUnits = double.tryParse(orderModel.distance ?? '') ?? 0.0;
    final double distanceKm = tripDistanceKm(distanceInAppUnits);
    // The floor follows the vehicle the customer picked. `ratePerKm` is stored
    // on the request alongside it, so the driver's app, the acceptance
    // transaction and the dispatcher all apply this vehicle's rate rather than
    // re-deriving a global one that may not be the one the customer was shown.
    final num ratePerKm = applicableRatePerKm(orderModel.vehicleType);
    final double minimum = BiddingFareRules.minimumAllowedFare(
      settings: settings,
      distanceKm: distanceKm,
      currencyDecimals: currencyDecimals,
      vehicleRatePerKm: orderModel.vehicleType?.biddingMinimumFarePerKm,
    );

    // Withhold contact details, and the pickup OTP, for as long as competing
    // drivers can read this document.
    final Map<String, dynamic> ride = RideAuthorPrivacy.redactRide(orderModel.toJson(), author: customer.toJson());
    ride[RideBiddingFields.enabled] = true;
    ride[RideBiddingFields.status] = RideBiddingStatus.pendingDispatch;
    ride[RideBiddingFields.offeredFare] = offeredFare;
    ride[RideBiddingFields.minimumAllowedFare] = minimum;
    ride[RideBiddingFields.distanceKm] = distanceKm;
    ride[RideBiddingFields.minFarePerKmAtRequest] = ratePerKm;
    ride[RideBiddingFields.eligibleDriverIds] = <String>[];
    ride[RideBiddingFields.winningBidId] = null;
    ride[RideBiddingFields.bidCount] = 0;
    ride[RideBiddingFields.expiresAt] = Timestamp.fromDate(DateTime.now().add(Duration(minutes: settings.bidExpiryMinutes)));

    try {
      await _fireStore.collection(CollectionName.rides).doc(orderModel.id).set(ride);
      return true;
    } catch (e, s) {
      log('placeBiddingRide failed: $e\n$s');
      return false;
    }
  }

  /// Puts an expired or driverless request back in front of drivers, with a
  /// fresh window. Nothing else about the ride changes.
  static Future<bool> resendRequest({required String rideId}) async {
    final BiddingSettings settings = Constant.biddingSettings;
    try {
      await _fireStore.collection(CollectionName.rides).doc(rideId).update(<String, dynamic>{
        RideBiddingFields.status: RideBiddingStatus.pendingDispatch,
        RideBiddingFields.eligibleDriverIds: <String>[],
        RideBiddingFields.expiresAt: Timestamp.fromDate(DateTime.now().add(Duration(minutes: settings.bidExpiryMinutes))),
      });
      return true;
    } catch (e) {
      log('resendRequest failed: $e');
      return false;
    }
  }

  /// Live offers for one ride, newest response first.
  ///
  /// One subscription over a subcollection that is capped by
  /// `maxDriversPerRequest`, so the customer's screen updates without a manual
  /// refresh and without a query over anything global.
  static Stream<List<RideBidModel>> bidsStream(String rideId) {
    return _fireStore
        .collection(CollectionName.rides)
        .doc(rideId)
        .collection(RideBidModel.collectionName)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) =>
            snapshot.docs.map((doc) => RideBidModel.fromJson(doc.data())).toList());
  }

  /// Accepts one offer.
  ///
  /// [liveBids] is what the customer's list currently shows; the losing offers
  /// among them are closed inside the same transaction as the award.
  static Future<AcceptBidResult> acceptOffer({
    required String rideId,
    required RideBidModel winning,
    required List<RideBidModel> liveBids,
    required UserModel customer,
  }) async {
    final String driverId = winning.driverId ?? '';
    if (driverId.isEmpty) return AcceptBidResult.bidGone;

    // Read the winner's profile before the transaction: the booked ride stores
    // the same `driver` snapshot a normal driver-side accept has always
    // stored, so every downstream screen keeps working unchanged.
    final UserModel? driver = await FireStoreUtils.getUserProfile(driverId, forceRefresh: true);

    final Map<String, dynamic> award = <String, dynamic>{
      'status': Constant.driverAccepted,
      'driverId': driverId,
      if (driver != null) 'driver': driver.toJson(),
      'subTotal': winning.amount?.toString(),
      // The pickup OTP is minted here, for the winner only, in the same
      // transaction that reveals the contact details. An open request never
      // carried one.
      'otpCode': newOtpCode(),
    };

    final List<String> losers = liveBids
        .where((RideBidModel bid) => bid.driverId != null && bid.driverId != driverId && bid.isLive)
        .map((RideBidModel bid) => bid.driverId!)
        .toList();

    AcceptBidResult result;
    try {
      result = await ledger.acceptBid(
        rideId: rideId,
        winningDriverId: driverId,
        losingDriverIds: losers,
        rideAwardPatch: award,
        contactPatch: RideAuthorPrivacy.contactPatch(customer.toJson()),
        settings: Constant.biddingSettings,
        now: DateTime.now(),
        currencyDecimals: currencyDecimals,
      );
    } catch (e, s) {
      log('acceptOffer transaction failed: $e\n$s');
      return AcceptBidResult.notOpen;
    }

    if (result == AcceptBidResult.ok) {
      unawaited(_notifyDriver(
        driver?.fcmToken,
        title: 'Offer accepted'.tr,
        body: 'The customer accepted your offer. Head to the pickup point.'.tr,
        payload: <String, dynamic>{'rideId': rideId, 'type': Constant.bidOfferAcceptedNotification},
      ));
      for (final RideBidModel loser in liveBids) {
        if (loser.driverId == driverId || !loser.isLive) continue;
        unawaited(_notifyDriverById(
          loser.driverId,
          title: 'Ride no longer available'.tr,
          body: 'Another driver was selected for this ride.'.tr,
          payload: <String, dynamic>{'rideId': rideId, 'type': Constant.bidRequestClosedNotification},
        ));
      }
    }
    return result;
  }

  /// Turns one offer down. The request stays open for the others.
  static Future<RejectBidResult> rejectOffer({required String rideId, required RideBidModel bid}) async {
    final String driverId = bid.driverId ?? '';
    if (driverId.isEmpty) return RejectBidResult.bidGone;

    RejectBidResult result;
    try {
      result = await ledger.rejectBid(rideId: rideId, driverId: driverId, now: DateTime.now());
    } catch (e) {
      log('rejectOffer transaction failed: $e');
      return RejectBidResult.bidNotPending;
    }
    if (result == RejectBidResult.ok) {
      unawaited(_notifyDriverById(
        driverId,
        title: 'Offer declined'.tr,
        body: 'The customer declined your offer.'.tr,
        payload: <String, dynamic>{'rideId': rideId, 'type': Constant.bidOfferRejectedNotification},
      ));
    }
    return result;
  }

  /// Cancels the whole request and closes every open offer with it, so no
  /// bidding record is left active for a ride nobody is going to take.
  static Future<bool> cancelRequest({
    required String rideId,
    required List<RideBidModel> liveBids,
    required Map<String, dynamic> ridePatch,
  }) async {
    final List<String> open = liveBids.where((RideBidModel b) => b.isLive && b.driverId != null).map((RideBidModel b) => b.driverId!).toList();
    try {
      final bool done = await ledger.cancelRequest(
        rideId: rideId,
        openDriverIds: open,
        ridePatch: ridePatch,
        now: DateTime.now(),
      );
      if (done) {
        for (final String driverId in open) {
          unawaited(_notifyDriverById(
            driverId,
            title: 'Ride cancelled'.tr,
            body: 'The customer cancelled this ride request.'.tr,
            payload: <String, dynamic>{'rideId': rideId, 'type': Constant.bidRequestClosedNotification},
          ));
        }
      }
      return done;
    } catch (e) {
      log('cancelRequest transaction failed: $e');
      return false;
    }
  }

  /// A fresh 4-digit pickup code, generated the same way `placeOrder()` has
  /// always generated it.
  static String newOtpCode() => (math.Random.secure().nextInt(9000) + 1000).toString();

  static Future<void> _notifyDriverById(String? driverId, {required String title, required String body, required Map<String, dynamic> payload}) async {
    if (driverId == null || driverId.isEmpty) return;
    final UserModel? driver = await FireStoreUtils.getUserProfile(driverId);
    await _notifyDriver(driver?.fcmToken, title: title, body: body, payload: payload);
  }

  static Future<void> _notifyDriver(String? token, {required String title, required String body, required Map<String, dynamic> payload}) async {
    if (token == null || token.isEmpty) return;
    try {
      await SendNotification.sendOneNotification(token: token, title: title, body: body, payload: payload);
    } catch (e) {
      log('bidding notification failed: $e');
    }
  }

  /// Local `unawaited`, so a best-effort notification never blocks or breaks
  /// the write that already succeeded.
  static void unawaited(Future<void> future) {
    future.catchError((Object error) => log('bidding side-effect failed: $error'));
  }
}
