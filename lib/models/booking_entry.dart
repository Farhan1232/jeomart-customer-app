import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/driver_trip_state.dart';
import 'cab_order_model.dart';
import 'driver_trip_model.dart';

/// The four tabs of **Ride History**, spelled once.
///
/// They were string literals in a map inside `MyCabBookingController`. They are
/// here now because a driver-posted trip has to land in one of them too, and
/// the rule that decides which is pure Dart that a test can run without
/// Firebase, GetX or a Flutter binding.
class BookingTab {
  static const String isNew = 'New';
  static const String onGoing = 'On Going';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  /// In the order the tab bar shows them.
  static const List<String> all = <String>[isNew, onGoing, completed, cancelled];

  /// Which ride statuses belong to each tab. Unchanged from what the screen
  /// has always used - filtering stays client-side, so the Firestore query,
  /// and therefore the index it needs, is exactly what it was.
  static const Map<String, List<String>> rideStatuses = <String, List<String>>{
    isNew: <String>['Order Placed', 'Driver Pending'],
    onGoing: <String>['Driver Accepted', 'Order Shipped', 'In Transit'],
    completed: <String>['Order Completed'],
    cancelled: <String>['Order Rejected', 'Order Cancelled', 'Driver Rejected'],
  };

  /// The tab a ride belongs in, or `null` for a status no tab claims.
  static String? forRideStatus(String? status) {
    for (final MapEntry<String, List<String>> entry in rideStatuses.entries) {
      if (entry.value.contains(status)) return entry.key;
    }
    return null;
  }

  /// The tab a **driver-posted trip** belongs in.
  ///
  /// A trip has no `Order Completed` of its own; it has
  /// [DriverTripStatus.completed], which the scheduled sweep in
  /// `driverTripsMaintenance.js` writes once a booked trip's departure time
  /// has passed. A trip this customer holds therefore sits in [onGoing] for
  /// exactly as long as the driver's own My Trips calls it *Booked*, and moves
  /// to [completed] at the same instant for both of them - the server decides,
  /// so the two apps cannot disagree about a trip's state.
  ///
  /// Before that script is deployed nothing writes `completed`, so this reads
  /// exactly as it always did.
  static String forTripStatus(String? status) {
    switch (status) {
      case DriverTripStatus.booked:
        return onGoing;
      case DriverTripStatus.completed:
        return completed;
      case DriverTripStatus.cancelled:
      case DriverTripStatus.expired:
        return cancelled;
      default:
        // Reserved trips are never `active` - the reservation transaction
        // flips the status in the same write - so this is only reachable for a
        // document written by something other than this app.
        //
        // It is also the reason a build shipped BEFORE the sweep cannot lose a
        // trip: an older app meets `completed` here, falls through, and lists
        // the booking under Pending rather than dropping it off the screen.
        return isNew;
    }
  }
}

/// One row of **Ride History**, whichever kind of booking produced it.
///
/// The client's rule, in their own words: *"when a bid is accepted OR when my
/// trip is accepted then all bookings goes to my bookings tab... My booking
/// section will be same for all kind of trips so nobody will get confused."*
///
/// Three things can be booked in this app and only two of them were ever
/// listed here:
///
/// * an ordinary metered ride - a `rides` document, listed;
/// * a ride won through bidding - also a `rides` document, whose `status` the
///   award transaction flips to `Driver Accepted`, so it was listed too;
/// * a full vehicle taken off a driver-posted trip - a `driver_trips`
///   document, a different collection that this screen never read. That is the
///   one the client watched vanish.
///
/// The fix is a merge at the point of display, not a write. Putting trips into
/// `rides` would hand author-less documents to the dispatcher and to every
/// existing ride query - the exact thing `driver_trips` was split out to avoid.
class BookingEntry {
  const BookingEntry.ride(CabOrderModel this.ride) : trip = null;

  const BookingEntry.trip(DriverTripModel this.trip) : ride = null;

  /// Set for an ordinary or bidding ride; null for a driver-posted trip.
  final CabOrderModel? ride;

  /// Set for a full vehicle booked off a driver-posted trip; null otherwise.
  final DriverTripModel? trip;

  bool get isTrip => trip != null;

  /// Stable identity, so a rebuild does not reorder equal rows.
  String get id => (isTrip ? trip!.id : ride!.id) ?? '';

  /// The tab this row belongs in, or `null` if none claims it.
  String? get tab => isTrip ? BookingTab.forTripStatus(trip!.status) : BookingTab.forRideStatus(ride!.status);

  /// What the merged list sorts on, newest first.
  ///
  /// A ride is ordered by the query's `createdAt`; a trip by the moment this
  /// customer took it, falling back to when it was posted. Both answer the same
  /// question - "when did this booking become mine?" - which is the only way
  /// two collections can be interleaved without one of them always winning.
  DateTime? get sortedOn {
    if (isTrip) {
      return (trip!.reservedAt ?? trip!.createdAt)?.toDate();
    }
    final Timestamp? stamp = ride!.createdAt ?? ride!.scheduleDateTime;
    return stamp?.toDate();
  }

  /// Merges rides and trips into one newest-first list for [tab].
  ///
  /// Rows with no date sort last rather than first: an unparseable timestamp
  /// must not push a real booking down the screen.
  static List<BookingEntry> merge({
    required Iterable<CabOrderModel> rides,
    required Iterable<DriverTripModel> trips,
    required String tab,
  }) {
    final List<BookingEntry> entries = <BookingEntry>[
      ...rides.map(BookingEntry.ride),
      ...trips.map(BookingEntry.trip),
    ].where((BookingEntry entry) => entry.tab == tab).toList();

    entries.sort((BookingEntry a, BookingEntry b) {
      final DateTime? left = a.sortedOn;
      final DateTime? right = b.sortedOn;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });

    return entries;
  }
}
