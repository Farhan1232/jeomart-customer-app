import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/driver_trip_service.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/firestore_paginator.dart';
import 'package:get/get.dart';

/// The full-vehicle trips this customer has taken, as a feed a screen can own.
///
/// It used to live inside `AvailableTripsController`, as the second tab of the
/// Trips section. The client asked for one place instead:
///
/// > *"My booking section will be same for all kind of trips so nobody will get
/// > confused. Only to place bid or to see trips that sections will work."*
///
/// So the list moved into Ride History and the paging, the driver-profile cache
/// and the newest-first ordering moved with it, unchanged. Pulling them out
/// into a class rather than copying them is what keeps the two sections from
/// drifting apart the way the bottom bar's two hand-written lists once did.
class BookedTripsFeed {
  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, DriverTripModel>? _paginator;

  /// The posting driver's profile per booked trip, for the phone number and the
  /// chat token. Keyed by driver id, so two trips from the same driver are one
  /// read.
  final RxMap<String, UserModel> drivers = <String, UserModel>{}.obs;

  final RxBool isLoading = false.obs;

  final Set<String> _driversRequested = <String>{};

  Worker? _worker;

  /// Guards a second call - a tab tap on top of the initial load - from
  /// starting two paginators over the same query.
  bool _loading = false;

  bool _disposed = false;

  /// This customer's booked trips, newest first.
  ///
  /// Sorted here rather than in the query: see
  /// `DriverTripService.myBookedTripsQuery` for why that query deliberately
  /// carries no `orderBy`.
  List<DriverTripModel> get trips {
    final List<DriverTripModel> list = List<DriverTripModel>.from(_paginator?.visibleItems ?? <DriverTripModel>[]);
    list.sort((DriverTripModel a, DriverTripModel b) {
      final DateTime? left = a.reservedAt?.toDate() ?? a.createdAt?.toDate();
      final DateTime? right = b.reservedAt?.toDate() ?? b.createdAt?.toDate();
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return list;
  }

  bool get hasMore => _paginator?.hasMore.value ?? false;

  bool get isLoadingMore => _paginator?.isLoadingMore.value ?? false;

  bool get isStarted => _paginator != null;

  UserModel? driverFor(DriverTripModel trip) => drivers[trip.driverId ?? ''];

  /// Starts the feed for the signed-in customer. Safe to call more than once.
  Future<void> load() async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (uid.isEmpty || _loading || _disposed) return;
    _loading = true;

    isLoading.value = true;
    _paginator?.dispose();
    final FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, DriverTripModel> paginator =
        FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, DriverTripModel>(
      source: FirestorePageSource(DriverTripService.myBookedTripsQuery(uid), live: true),
      mapper: (DocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic>? data = doc.data();
        if (data == null) return null;
        try {
          return DriverTripModel.fromJson(data);
        } catch (error) {
          log('BookedTripsFeed: skipping booking ${doc.id} :: $error');
          return null;
        }
      },
      // One page holds every booking a customer realistically has. The query
      // has no `orderBy`, so a 20-row page was 20 bookings in document-id
      // order - not the newest - and a new booking usually landed on a later
      // page, outside the live listener, and never appeared. A short tab
      // cannot scroll, so the later pages were never asked for either.
      pageSize: 200,
    );
    _paginator = paginator;
    _worker?.dispose();
    _worker = ever<List<DriverTripModel>>(paginator.items, (_) => loadDrivers());
    try {
      await paginator.refresh();
      await loadDrivers();
    } finally {
      // In a `finally` so a failure anywhere above cannot leave the screen
      // spinning for the rest of the session.
      isLoading.value = false;
      _loading = false;
    }
  }

  Future<void> loadMore() async => _paginator?.loadMore();

  Future<void> refresh() async {
    if (_paginator == null) {
      await load();
      return;
    }
    await _paginator?.refresh();
    await loadDrivers();
  }

  /// Pulls the posting driver's profile for each booked trip, once per driver.
  Future<void> loadDrivers() async {
    final List<String> pending = <String>[];
    for (final DriverTripModel trip in _paginator?.items ?? <DriverTripModel>[]) {
      final String driverId = (trip.driverId ?? '').trim();
      if (driverId.isEmpty || _driversRequested.contains(driverId)) continue;
      _driversRequested.add(driverId);
      pending.add(driverId);
    }
    if (pending.isEmpty) return;

    final List<UserModel?> loaded = await Future.wait(pending.map(DriverTripService.driverProfile));
    final Map<String, UserModel> found = <String, UserModel>{};
    for (int i = 0; i < pending.length; i++) {
      final UserModel? driver = loaded[i];
      if (driver != null) found[pending[i]] = driver;
    }
    if (found.isNotEmpty && !_disposed) drivers.addAll(found);
  }

  void dispose() {
    _disposed = true;
    _worker?.dispose();
    _worker = null;
    _paginator?.dispose();
    _paginator = null;
  }
}
