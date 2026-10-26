import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_dashboard_controller.dart';
import 'package:customer/models/booking_entry.dart';
import 'package:customer/models/driver_trip_model.dart';
import 'package:customer/service/driver_trip_service.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/driver_trip_ledger.dart';
import 'package:customer/utils/driver_trip_settings.dart';
import 'package:customer/utils/firestore_paginator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Available Trips - the trips drivers have posted, newest first.
///
/// Paginated with Session 1's `FirestorePaginator`: the query carries the
/// ordering, the first page stays live so a trip posted while the customer is
/// looking appears straight away, and older pages load on scroll. The whole
/// collection is never downloaded and nothing is sorted in Dart.
///
/// It used to own a second list as well - the trips this customer had booked -
/// because a booked trip leaves the browsing query and had nowhere else to go.
/// It now has somewhere else to go: Ride History lists it beside every other
/// booking, through `BookedTripsFeed`, and this controller is back to the one
/// job its name describes.
class AvailableTripsController extends GetxController {
  RxBool isLoading = true.obs;

  FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, DriverTripModel>? tripsPaginator;

  /// The trip whose reservation is currently being written, so a second tap on
  /// the same card - or on another card - cannot start a second transaction.
  RxString bookingInFlight = ''.obs;

  List<DriverTripModel> get trips => tripsPaginator?.visibleItems ?? <DriverTripModel>[];

  bool get isLoadingMore => tripsPaginator?.isLoadingMore.value ?? false;

  bool get hasMoreTrips => tripsPaginator?.hasMore.value ?? false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    tripsPaginator?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;

    tripsPaginator?.dispose();
    final FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, DriverTripModel> paginator =
        FirestorePaginator<DocumentSnapshot<Map<String, dynamic>>, DriverTripModel>(
      source: FirestorePageSource(DriverTripService.availableTripsQuery(), live: true),
      mapper: (DocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic>? data = doc.data();
        if (data == null) return null;
        try {
          return DriverTripModel.fromJson(data);
        } catch (error) {
          log('AvailableTripsController: skipping trip ${doc.id} :: $error');
          return null;
        }
      },
      pageSize: 20,
      // A trip whose window has closed but whose status the sweep has not
      // flipped yet is hidden here; autoFillTarget keeps paging so the list
      // does not look empty because the first page was all stale rows. The
      // radius is applied in the same place and for the same reason - both are
      // client-side because Firestore will not take a second inequality
      // alongside the `createdAt` ordering the newest-first list depends on.
      autoFillTarget: 10,
      filter: (DriverTripModel trip) => trip.isVisibleAt(DateTime.now()) && isWithinRadius(trip),
    );
    tripsPaginator = paginator;
    await paginator.refresh();

    isLoading.value = false;
  }

  Future<void> loadMoreTrips() async => tripsPaginator?.loadMore();

  Future<void> refreshTrips() async => tripsPaginator?.refresh();

  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  /// Whether [trip] starts close enough to the customer to be listed.
  ///
  /// `settings/driverTripsSettings.tripRadiusKm` is the admin's answer to
  /// "how many kilometer will be selected for it". It is deliberately
  /// permissive at both ends:
  ///
  /// * a radius of 0 - the default, and what an unreadable settings document
  ///   falls back to - lists every trip in the section, which is exactly how
  ///   the tab behaved before the radius existed;
  /// * a customer whose location is not known yet, or a trip posted without
  ///   coordinates, is **not** filtered out. A radius is there to shorten a
  ///   long list, and it must never be the reason a customer sees nothing at
  ///   all while location permission is still being asked for.
  bool isWithinRadius(DriverTripModel trip) {
    final DriverTripSettings settings = Constant.driverTripSettings;
    if (!settings.hasRadius) return true;

    final Position? me = Constant.currentLocation;
    if (me == null) return true;

    return settings.includesTrip(
      fromLat: me.latitude,
      fromLng: me.longitude,
      tripLat: trip.fromLocation?.latitude,
      tripLng: trip.fromLocation?.longitude,
    );
  }

  /// Takes the whole vehicle.
  ///
  /// Whatever the UI thinks, the transaction is what decides: a customer who
  /// taps a card that somebody else has just booked gets
  /// [ReserveTripResult.alreadyReserved] and is told so, and no second
  /// reservation is written.
  Future<void> bookTrip(DriverTripModel trip) async {
    final String tripId = trip.id ?? '';
    if (tripId.isEmpty || bookingInFlight.value.isNotEmpty) return;

    bookingInFlight.value = tripId;
    ShowToastDialog.showLoader("Please wait".tr);

    // The reservation, and nothing else, decides what the customer is told.
    //
    // This used to be one `try` around the whole method - the transaction, the
    // driver's notification, the list refresh and the tab switch. Anything that
    // threw *after* the vehicle was already booked was reported as
    // "Something went wrong. Please try again.", so a booking that had gone
    // through looked like a failure; tapping again then answered "Another
    // customer has already booked this trip", which is that same customer's own
    // reservation. Everything after the transaction is housekeeping now, and
    // housekeeping is not allowed to contradict the booking.
    ReserveTripResult? result;
    try {
      result = await DriverTripService.reserveTrip(trip);
    } catch (error) {
      log('AvailableTripsController.bookTrip failed :: $error');
    } finally {
      ShowToastDialog.closeLoader();
      bookingInFlight.value = '';
    }

    if (result == null) {
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }

    bool booked = false;
    switch (result) {
      case ReserveTripResult.ok:
        ShowToastDialog.showToast("Trip booked".tr);
        booked = true;
        break;
      case ReserveTripResult.alreadyReserved:
        ShowToastDialog.showToast("Another customer has already booked this trip".tr);
        break;
      case ReserveTripResult.notActive:
        ShowToastDialog.showToast("This trip is no longer available".tr);
        break;
      case ReserveTripResult.expired:
        ShowToastDialog.showToast("This trip has expired".tr);
        break;
      case ReserveTripResult.tripGone:
        ShowToastDialog.showToast("This trip is no longer available".tr);
        break;
      case ReserveTripResult.ownTrip:
        ShowToastDialog.showToast("This trip is no longer available".tr);
        break;
    }

    if (booked) {
      // Sent, but not waited for. The push is a token exchange and an HTTP
      // post, and the tab switch below used to sit behind it; the customer has
      // already been told the trip is booked.
      unawaited(() async {
        try {
          await DriverTripService.notifyDriverOfReservation(trip);
        } catch (error) {
          log('AvailableTripsController.bookTrip: notifying the driver failed :: $error');
        }
      }());
    }

    try {
      await tripsPaginator?.refresh();
    } catch (error) {
      log('AvailableTripsController.bookTrip: refreshing the list failed :: $error');
    }

    // Last, and only once the browsing list has been put straight: switching
    // tabs takes this screen off the tree, and with it this controller. The
    // trip has just left the browsing list - its status is no longer
    // `active` - so the customer is moved to the tab that now holds it
    // rather than watching it disappear. That tab is Ride History, the one
    // place every kind of booking ends up.
    if (booked) CabDashboardController.openBookings(bookingTab: BookingTab.onGoing);
  }
}
