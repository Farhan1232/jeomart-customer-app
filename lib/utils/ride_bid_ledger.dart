import 'package:cloud_firestore/cloud_firestore.dart';

import 'bidding_fare_rules.dart';
import 'bidding_settings.dart';
import '../models/ride_bid_model.dart';
import 'ride_bidding_state.dart';

/// A document as seen from inside a bidding transaction.
abstract class BidDocument {
  bool get exists;

  Map<String, dynamic>? get data;
}

/// The reads and writes a bidding transaction body may perform.
///
/// Firestore requires every read to happen before the first write, so bodies
/// here always [get] first and then [set] / [update].
abstract class BidTransactionContext {
  Future<BidDocument> get(String path);

  void set(String path, Map<String, dynamic> data, {bool merge = true});

  void update(String path, Map<String, dynamic> data);
}

/// Runs one bidding transaction.
///
/// The contract the implementation must honour is Firestore's: if any document
/// read by the body changed before the writes landed, the whole body is run
/// again against the newer values. That replay is the entire reason only one
/// driver can win a ride, so it is modelled explicitly here and exercised by
/// the tests with a fake that really does replay.
abstract class BidTransactionRunner {
  Future<T> run<T>(Future<T> Function(BidTransactionContext ctx) body);
}

/// Firestore-backed [BidTransactionRunner].
class FirestoreBidTransactionRunner implements BidTransactionRunner {
  FirestoreBidTransactionRunner(this.fireStore);

  final FirebaseFirestore fireStore;

  @override
  Future<T> run<T>(Future<T> Function(BidTransactionContext ctx) body) {
    return fireStore.runTransaction<T>((Transaction transaction) async {
      final ctx = _FirestoreBidTransactionContext(fireStore, transaction);
      final T result = await body(ctx);
      ctx.flush();
      return result;
    });
  }
}

class _FirestoreBidTransactionContext implements BidTransactionContext {
  _FirestoreBidTransactionContext(this._fireStore, this._transaction);

  final FirebaseFirestore _fireStore;
  final Transaction _transaction;

  /// Writes are queued rather than applied immediately so that a body which
  /// reads after its first write still works: everything is flushed once the
  /// body has finished, which keeps Firestore's reads-before-writes rule.
  final List<void Function()> _pending = <void Function()>[];

  DocumentReference<Map<String, dynamic>> _ref(String path) => _fireStore.doc(path);

  @override
  Future<BidDocument> get(String path) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _transaction.get(_ref(path));
    return _FirestoreBidDocument(snapshot);
  }

  @override
  void set(String path, Map<String, dynamic> data, {bool merge = true}) {
    _pending.add(() => _transaction.set(_ref(path), data, SetOptions(merge: merge)));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    _pending.add(() => _transaction.update(_ref(path), data));
  }

  void flush() {
    for (final void Function() write in _pending) {
      write();
    }
    _pending.clear();
  }
}

class _FirestoreBidDocument implements BidDocument {
  _FirestoreBidDocument(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;

  @override
  bool get exists => _snapshot.exists;

  @override
  Map<String, dynamic>? get data => _snapshot.data();
}

/// Why a driver's offer was not written.
enum SubmitBidResult {
  ok,
  rideGone,
  notOpen,
  requestExpired,
  notEligible,
  invalidAmount,
  belowMinimum,
}

/// Why an acceptance did not go through.
enum AcceptBidResult {
  ok,

  /// The ride document is gone.
  rideGone,

  /// The ride is no longer collecting offers - cancelled, expired, or the
  /// customer already accepted on another device.
  notOpen,

  /// Someone already won. This is the state a second, racing acceptance ends
  /// in, and it is why a ride can never have two winners.
  alreadyAwarded,

  /// The offer document is gone.
  bidGone,

  /// The offer was withdrawn, closed, voided or already handled.
  bidNotPending,

  /// The offer sat on screen past its own deadline.
  bidExpired,

  /// The offer breaks the minimum-fare-per-km rule.
  belowMinimum,
}

/// Why a rejection did not go through.
enum RejectBidResult { ok, bidGone, bidNotPending, alreadyAwarded }

/// Every write that decides a bidding ride, in one place and inside a
/// transaction.
///
/// The brief's critical requirement is that when the customer accepts one
/// driver's offer, that driver wins, the ride becomes booked, every competing
/// offer closes, and no second driver can win - enforced at the database, not
/// in the UI. That is [acceptBid]: it re-reads the ride and the chosen offer
/// inside the transaction and refuses unless the ride is still open and
/// unawarded, so two customers' devices tapping Accept at the same moment
/// leave exactly one winner in Firestore.
class RideBidLedger {
  RideBidLedger(this.runner, {this.ridesCollection = 'rides'});

  final BidTransactionRunner runner;
  final String ridesCollection;

  String ridePath(String rideId) => '$ridesCollection/$rideId';

  String bidPath(String rideId, String driverId) => '$ridesCollection/$rideId/${RideBidModel.collectionName}/$driverId';

  /// Writes (or replaces) one driver's offer.
  ///
  /// The bid document id is the driver id, so a duplicate tap updates the same
  /// row instead of creating a second offer. The ride's offer counter is
  /// written in the same transaction on purpose: it puts the ride document in
  /// the write set of both this and [acceptBid], which is what makes a
  /// last-instant offer and an acceptance serialise against each other instead
  /// of both succeeding.
  Future<SubmitBidResult> submitBid({
    required RideBidModel bid,
    required BiddingSettings settings,
    required DateTime now,
    int currencyDecimals = 2,
  }) {
    final String rideId = bid.rideId ?? '';
    final String driverId = bid.driverId ?? '';
    if (rideId.isEmpty || driverId.isEmpty) return Future<SubmitBidResult>.value(SubmitBidResult.rideGone);

    return runner.run<SubmitBidResult>((BidTransactionContext ctx) async {
      final BidDocument rideDoc = await ctx.get(ridePath(rideId));
      final BidDocument bidDoc = await ctx.get(bidPath(rideId, driverId));

      if (!rideDoc.exists) return SubmitBidResult.rideGone;

      final Map<String, dynamic> ride = rideDoc.data ?? <String, dynamic>{};
      final RideBiddingState state = RideBiddingState.fromJson(ride);

      if (!state.acceptsOffers) return SubmitBidResult.notOpen;
      if (state.isExpiredAt(now)) return SubmitBidResult.requestExpired;
      if (!state.eligibleDriverIds.contains(driverId)) return SubmitBidResult.notEligible;

      final double? amount = bid.amount?.toDouble();
      final double distanceKm = state.distanceKm.toDouble();
      // The floor is recomputed here, from the settings, exactly as it always
      // was - a request that stored no floor is still held to one. The only
      // thing the ride contributes is *which* configured rate applies: a
      // motorcycle with its own rate is not held to a car's.
      final FareCheckResult check = BiddingFareRules.check(
        amount: amount,
        settings: settings,
        distanceKm: distanceKm,
        currencyDecimals: currencyDecimals,
        vehicleRatePerKm: state.vehicleRatePerKm,
      );
      if (check == FareCheckResult.notANumber || check == FareCheckResult.notPositive) {
        return SubmitBidResult.invalidAmount;
      }
      if (check == FareCheckResult.belowMinimum) return SubmitBidResult.belowMinimum;

      final Timestamp nowStamp = Timestamp.fromDate(now);
      // A re-offer keeps the moment the driver first responded, so the
      // customer's list does not reshuffle when a driver edits a price.
      final Map<String, dynamic>? existingBid = bidDoc.exists ? bidDoc.data : null;
      final Object? existingCreatedAt = existingBid == null ? null : existingBid['createdAt'];
      final Map<String, dynamic> payload = bid.toJson()
        ..['id'] = driverId
        ..['status'] = RideBidStatus.pending
        ..['updatedAt'] = nowStamp
        ..['expiresAt'] = state.expiresAt
        ..['createdAt'] = existingCreatedAt ?? nowStamp;

      ctx.set(bidPath(rideId, driverId), payload);
      ctx.update(ridePath(rideId), <String, dynamic>{
        RideBiddingFields.bidCount: bidDoc.exists ? state.bidCount : state.bidCount + 1,
      });
      return SubmitBidResult.ok;
    });
  }

  /// The driver takes their offer back off the table.
  Future<bool> withdrawBid({required String rideId, required String driverId, required DateTime now}) {
    return runner.run<bool>((BidTransactionContext ctx) async {
      final BidDocument bidDoc = await ctx.get(bidPath(rideId, driverId));
      if (!bidDoc.exists) return false;
      if (!RideBidStatus.isLive(bidDoc.data?['status']?.toString())) return false;
      ctx.update(bidPath(rideId, driverId), <String, dynamic>{
        'status': RideBidStatus.withdrawn,
        'updatedAt': Timestamp.fromDate(now),
      });
      return true;
    });
  }

  /// Accepts one offer and closes every other one, atomically.
  ///
  /// [losingDriverIds] are the other offers the customer's live list knows
  /// about; they are closed inside the same transaction, so from any other
  /// reader's point of view the ride becomes booked and the competing offers
  /// become unavailable in the same instant. An offer written after the
  /// customer's list was last delivered cannot slip through either: this
  /// transaction writes the ride document, so that driver's own submit
  /// transaction re-runs and then finds the ride closed.
  ///
  /// [contactPatch] carries the customer's contact details, which are withheld
  /// from the ride document while bidding is open and revealed here, at the
  /// moment of acceptance, by the customer themselves.
  Future<AcceptBidResult> acceptBid({
    required String rideId,
    required String winningDriverId,
    required List<String> losingDriverIds,
    required Map<String, dynamic> rideAwardPatch,
    required Map<String, dynamic> contactPatch,
    required BiddingSettings settings,
    required DateTime now,
    int currencyDecimals = 2,
  }) {
    return runner.run<AcceptBidResult>((BidTransactionContext ctx) async {
      final BidDocument rideDoc = await ctx.get(ridePath(rideId));
      final BidDocument bidDoc = await ctx.get(bidPath(rideId, winningDriverId));

      if (!rideDoc.exists) return AcceptBidResult.rideGone;
      if (!bidDoc.exists) return AcceptBidResult.bidGone;

      final Map<String, dynamic> ride = rideDoc.data ?? <String, dynamic>{};
      final RideBiddingState state = RideBiddingState.fromJson(ride);

      // Read the award first: a ride that already has a winner must report
      // that, not the generic "not open", so the losing tap can say why.
      if (state.winningBidId != null && state.winningBidId!.isNotEmpty) {
        return state.winningBidId == winningDriverId ? AcceptBidResult.ok : AcceptBidResult.alreadyAwarded;
      }
      if (!RideBiddingStatus.acceptsOffers(state.status)) return AcceptBidResult.notOpen;

      final RideBidModel bid = RideBidModel.fromJson(bidDoc.data ?? <String, dynamic>{});
      if (!bid.isLive) return AcceptBidResult.bidNotPending;
      if (bid.isExpiredAt(now)) return AcceptBidResult.bidExpired;

      final double distanceKm = state.distanceKm.toDouble();
      final FareCheckResult check = BiddingFareRules.check(
        amount: bid.amount?.toDouble(),
        settings: settings,
        distanceKm: distanceKm,
        currencyDecimals: currencyDecimals,
        vehicleRatePerKm: state.vehicleRatePerKm,
      );
      if (check == FareCheckResult.belowMinimum) return AcceptBidResult.belowMinimum;
      if (check != FareCheckResult.ok) return AcceptBidResult.belowMinimum;

      final Timestamp nowStamp = Timestamp.fromDate(now);

      ctx.update(ridePath(rideId), <String, dynamic>{
        ...rideAwardPatch,
        ...contactPatch,
        RideBiddingFields.status: RideBiddingStatus.accepted,
        RideBiddingFields.winningBidId: winningDriverId,
        RideBiddingFields.acceptedAt: nowStamp,
        // The winner is the only driver left on the request, so every other
        // driver's live query drops it immediately.
        RideBiddingFields.eligibleDriverIds: <String>[winningDriverId],
      });

      ctx.update(bidPath(rideId, winningDriverId), <String, dynamic>{
        'status': RideBidStatus.accepted,
        'updatedAt': nowStamp,
      });

      for (final String loser in losingDriverIds) {
        if (loser == winningDriverId || loser.isEmpty) continue;
        ctx.update(bidPath(rideId, loser), <String, dynamic>{
          'status': RideBidStatus.closed,
          'updatedAt': nowStamp,
        });
      }

      return AcceptBidResult.ok;
    });
  }

  /// The customer turns one offer down without ending the request.
  Future<RejectBidResult> rejectBid({
    required String rideId,
    required String driverId,
    required DateTime now,
  }) {
    return runner.run<RejectBidResult>((BidTransactionContext ctx) async {
      final BidDocument rideDoc = await ctx.get(ridePath(rideId));
      final BidDocument bidDoc = await ctx.get(bidPath(rideId, driverId));

      if (!bidDoc.exists) return RejectBidResult.bidGone;

      final RideBiddingState state = RideBiddingState.fromJson(rideDoc.data);
      if (state.winningBidId != null && state.winningBidId!.isNotEmpty) {
        return RejectBidResult.alreadyAwarded;
      }
      if (!RideBidStatus.isLive(bidDoc.data?['status']?.toString())) {
        return RejectBidResult.bidNotPending;
      }

      ctx.update(bidPath(rideId, driverId), <String, dynamic>{
        'status': RideBidStatus.rejected,
        'updatedAt': Timestamp.fromDate(now),
      });
      return RejectBidResult.ok;
    });
  }

  /// The customer cancels the whole request. Closes the ride's bidding state
  /// and every offer the customer's list knows about, so nothing is left
  /// orphaned and live.
  Future<bool> cancelRequest({
    required String rideId,
    required List<String> openDriverIds,
    required Map<String, dynamic> ridePatch,
    required DateTime now,
  }) {
    return runner.run<bool>((BidTransactionContext ctx) async {
      final BidDocument rideDoc = await ctx.get(ridePath(rideId));
      if (!rideDoc.exists) return false;

      final RideBiddingState state = RideBiddingState.fromJson(rideDoc.data);
      if (state.winningBidId != null && state.winningBidId!.isNotEmpty) {
        // Already booked - cancelling is the normal ride-cancel path, not this.
        return false;
      }

      final Timestamp nowStamp = Timestamp.fromDate(now);
      ctx.update(ridePath(rideId), <String, dynamic>{
        ...ridePatch,
        RideBiddingFields.status: RideBiddingStatus.cancelled,
        RideBiddingFields.eligibleDriverIds: <String>[],
      });
      for (final String driverId in openDriverIds) {
        if (driverId.isEmpty) continue;
        ctx.update(bidPath(rideId, driverId), <String, dynamic>{
          'status': RideBidStatus.closed,
          'updatedAt': nowStamp,
        });
      }
      return true;
    });
  }
}
