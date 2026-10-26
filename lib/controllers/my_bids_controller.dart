import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/firestore_paginator.dart';
import 'package:customer/utils/ride_bidding_state.dart';
import 'package:get/get.dart';

/// The customer's own bidding section — "Choose Your Price".
///
/// The client asked for bidding to have its own place in the customer bottom
/// bar, "same like my trips for drivers", because it was only reachable from
/// the last sheet of the ordinary booking flow and nobody found it. This is
/// that section: the rides this customer named their own price on, in the same
/// shape the driver's My Trips uses — a paginated list with status tabs and one
/// action button that starts a new one.
///
/// It reads the **existing** `rides` collection. A bidding ride was always a
/// ride with extra fields on it; nothing new is written, and no ride that is
/// not a bidding ride is ever shown here.
class MyBidsController extends GetxController {
  RxBool isLoading = true.obs;

  /// The states a request can be grouped into.
  ///
  /// They are *groups* of `biddingStatus`, not raw statuses: a customer thinks
  /// in "still waiting", "got a driver" and "over", not in
  /// `pending_dispatch` / `no_drivers`. Two of the three are tabs here; see
  /// [tabKeys] for why [bookedTab] is not.
  static const String openTab = 'open';
  static const String bookedTab = 'booked';
  static const String closedTab = 'closed';

  /// The tabs the section shows. **Booked is deliberately not one of them.**
  ///
  /// The client: *"in bid section it will be good for bidding but when ride is
  /// accepted then it must go to my bookings tab... My booking section will be
  /// same for all kind of trips so nobody will get confused."* An accepted
  /// offer sets the ride's own `status` to `Driver Accepted`, which is already
  /// the On Going tab of Ride History, so a request that has found a driver is
  /// listed there and only there. [tabFor] still names it [bookedTab]; there is
  /// simply no tab here that matches, so it is not listed twice.
  final List<String> tabKeys = <String>[openTab, closedTab];

  RxString selectedTab = openTab.obs;

  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, CabOrderModel>? bidsPaginator;

  /// The bidding fields of each loaded ride, keyed by ride id, so the card can
  /// show the offer and the tab filter can group by state without re-parsing
  /// the document on every rebuild.
  final Map<String, RideBiddingState> _states = <String, RideBiddingState>{};

  List<CabOrderModel> get bids => bidsPaginator?.visibleItems ?? <CabOrderModel>[];

  bool get isLoadingMore => bidsPaginator?.isLoadingMore.value ?? false;

  bool get hasMore => bidsPaginator?.hasMore.value ?? false;

  bool get isSignedIn => FireStoreUtils.getCurrentUid().isNotEmpty;

  RideBiddingState stateFor(CabOrderModel ride) => _states[ride.id ?? ''] ?? const RideBiddingState();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    bidsPaginator?.dispose();
    super.onClose();
  }

  /// Which tab a ride belongs in.
  ///
  /// A request whose window has run out but whose `biddingStatus` the
  /// dispatcher has not flipped yet counts as closed here, so the Open tab
  /// never advertises a request drivers can no longer answer — the same
  /// treatment the driver's My Trips gives an expired-but-unswept trip.
  String tabFor(CabOrderModel ride) {
    final RideBiddingState state = stateFor(ride);
    final String status = state.status ?? '';

    if (status == RideBiddingStatus.accepted || status == RideBiddingStatus.booked) return bookedTab;
    if (status == RideBiddingStatus.expired || status == RideBiddingStatus.cancelled || status == RideBiddingStatus.noDrivers) {
      return closedTab;
    }
    // pending_dispatch and open are live only while the window is.
    if (state.isExpiredAt(DateTime.now())) return closedTab;
    return openTab;
  }

  /// Whether tapping this card should reopen the offer list.
  ///
  /// Only an open request has anything to go back to; a booked one is an
  /// ordinary ride from that point on and lives in Ride History.
  bool isLive(CabOrderModel ride) => tabFor(ride) == openTab;

  bool Function(CabOrderModel) _filterFor(String tab) => (CabOrderModel ride) => tabFor(ride) == tab;

  Future<void> selectTab(String tab) async {
    selectedTab.value = tab;
    await bidsPaginator?.applyFilter(_filterFor(tab));
  }

  Future<void> loadMore() async => bidsPaginator?.loadMore();

  Future<void> refreshBids() async => bidsPaginator?.refresh();

  Future<void> load() async {
    isLoading.value = true;
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty) {
      isLoading.value = false;
      return;
    }

    bidsPaginator?.dispose();
    final FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, CabOrderModel> paginator =
        FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, CabOrderModel>(
      // `authorID` + `createdAt DESC` is an index this project already has, and
      // the one the customer's ride history uses. Bidding rides are separated
      // out in the mapper rather than with a second `where`, so this screen
      // needs no index deployed before it works.
      source: FirestorePageSource(
        FireStoreUtils.fireStore
            .collection(CollectionName.rides)
            .where('authorID', isEqualTo: uid)
            .orderBy('createdAt', descending: true),
        live: true,
      ),
      mapper: (DocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic>? data = doc.data();
        if (data == null) return null;
        try {
          final RideBiddingState state = RideBiddingState.fromJson(data);
          if (!state.enabled) return null;
          final CabOrderModel ride = CabOrderModel.fromJson(data);
          _states[ride.id ?? doc.id] = state;
          return ride;
        } catch (error) {
          log('MyBidsController: skipping ride ${doc.id} :: $error');
          return null;
        }
      },
      pageSize: 20,
      // Most customers have far more ordinary rides than bidding ones, and the
      // tabs filter further still, so the first page can easily be all
      // non-matching rows. autoFillTarget keeps paging until the tab has
      // something in it instead of showing an empty list over a full history.
      autoFillTarget: 10,
      // ...but bounded harder than the other history screens, and deliberately.
      //
      // Their filter is a status tab over rows that all belong to the screen,
      // so they almost never page. This filter rejects every ordinary ride, so
      // a customer with a long history and no bidding rides would page the
      // default five times - 120 documents - on each visit, to show an empty
      // list. Two extra pages caps that at 60 and still fills the list for
      // anyone who actually uses bidding, whose requests are the newest rides
      // they have.
      autoFillMaxPages: 2,
      filter: _filterFor(selectedTab.value),
    );
    bidsPaginator = paginator;
    try {
      await paginator.refresh();
    } finally {
      // In a `finally` so a failure cannot leave the section spinning.
      isLoading.value = false;
    }
  }

  /// What the card shows as the amount: the fare the customer offered, falling
  /// back to the ride's own subtotal for a ride written before the offer was
  /// stored separately.
  String amountFor(CabOrderModel ride) {
    final num? offered = stateFor(ride).offeredFare;
    final String amount = (offered ?? double.tryParse(ride.subTotal ?? '') ?? 0).toString();
    return Constant.amountShow(amount: amount);
  }
}
