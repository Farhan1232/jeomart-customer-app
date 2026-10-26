import 'package:customer/utils/safe_pop.dart';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' as maths;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/coupon_model.dart';
import 'package:customer/models/payment_model/cod_setting_model.dart';
import 'package:customer/models/payment_model/flutter_wave_model.dart';
import 'package:customer/models/payment_model/mercado_pago_model.dart';
import 'package:customer/models/payment_model/mid_trans.dart';
import 'package:customer/models/payment_model/orange_money.dart';
import 'package:customer/models/payment_model/pay_fast_model.dart';
import 'package:customer/models/payment_model/pay_stack_model.dart';
import 'package:customer/models/payment_model/paypal_model.dart';
import 'package:customer/models/payment_model/paytm_model.dart';
import 'package:customer/models/payment_model/razorpay_model.dart';
import 'package:customer/models/payment_model/stripe_model.dart';
import 'package:customer/models/payment_model/wallet_setting_model.dart';
import 'package:customer/models/payment_model/xendit.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/utils/vehicle_fare.dart';
import 'package:customer/utils/nearby_drivers.dart';
import 'package:customer/models/wallet_transaction_model.dart';
import 'package:customer/payment/mercado_pago_screen.dart';
import 'package:customer/payment/pay_fast_screen.dart';
import 'package:customer/payment/get_paytm_txt_token.dart';
import 'package:customer/payment/midtrans_screen.dart';
import 'package:customer/payment/orange_pay_screen.dart';
import 'package:customer/payment/paystack/pay_stack_screen.dart';
import 'package:customer/payment/paystack/pay_stack_url_model.dart';
import 'package:customer/payment/paystack/paystack_url_genrater.dart';
import 'package:customer/payment/stripe_failed_model.dart';
import 'package:customer/payment/xendit_model.dart';
import 'package:customer/payment/xendit_screen.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/models/ride_bid_model.dart';
import 'package:customer/service/bidding_service.dart';
import 'package:customer/service/ride_contact_service.dart';
import 'package:customer/utils/bidding_fare_rules.dart';
import 'package:customer/utils/ride_bid_ledger.dart';
import 'package:customer/utils/ride_bidding_state.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/map_start_location.dart';
import 'package:customer/utils/nearby_place_address.dart';
import 'package:customer/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import '../themes/app_them_data.dart';
import 'package:customer/utils/app_image_cache.dart';
import 'package:customer/utils/city_filter.dart';

class CabBookingController extends GetxController {
  /// The route this controller's screen was pushed as, captured before
  /// anything can be pushed on top of it. See [SafePop].
  final String _ownRoute = SafePop.currentRoute();

  /// Firestore listeners held by this controller.
  ///
  /// These used to be opened inline: every `users` snapshot opened a new ride
  /// listener, and every ride status change opened a new driver listener, so
  /// during a single ride the listeners piled up and none were cancelled when
  /// the screen closed.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;

  /// Periodic refresh of the section's available cab drivers, used to draw the
  /// real vehicles near the customer while they are still choosing. Held so it
  /// can be cancelled in onClose - a timer left running on a screen the
  /// customer has left keeps costing reads. See [listenForNearbyDrivers].
  Timer? _nearbyPollTimer;

  /// The drivers currently drawn, keyed by uid, so a position update moves a
  /// marker instead of adding a second one.
  final RxMap<String, NearbyDriver> nearbyDrivers = <String, NearbyDriver>{}.obs;

  /// One BitmapDescriptor per vehicle type id, built on demand from that type's
  /// own `vehicleIcon`. Cached because building a descriptor decodes an image,
  /// and the map rebuilds on every driver position update.
  final Map<String, BitmapDescriptor> _vehicleIcons = <String, BitmapDescriptor>{};

  /// Live offers on the ride currently being bid on. Only ever opened for a
  /// bidding ride, and cancelled with the screen like every other listener
  /// here.
  StreamSubscription<List<RideBidModel>>? _bidsSub;

  @override
  void onClose() {
    _userSub?.cancel();
    _rideSub?.cancel();
    _driverSub?.cancel();
    _nearbyPollTimer?.cancel();
    _nearbyGeneration++;
    _nearbyFetch = null;
    _nearbyLifecycle?.dispose();
    _nearbyLifecycle = null;
    _bidsSub?.cancel();
    super.onClose();
  }

  late GoogleMapController mapController;
  final flutterMap.MapController mapOsmController = flutterMap.MapController();

  final Rx<TextEditingController> sourceTextEditController = TextEditingController().obs;
  final Rx<TextEditingController> destinationTextEditController = TextEditingController().obs;

  final Rx<TextEditingController> couponCodeTextEditController = TextEditingController().obs;

  final Rx<Location> currentLocation = Location().obs;

  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxList<flutterMap.Marker> osmMarker = <flutterMap.Marker>[].obs;
  final RxList<latlong.LatLng> routePoints = <latlong.LatLng>[].obs;

  /// Where the map opens.
  ///
  /// Resolved in [initData] **before** `isLoading` goes false, so by the time
  /// the map widget is first built it already has a real coordinate.
  /// `FlutterMap.initialCenter` and `GoogleMap.initialCameraPosition` are read
  /// once and never again, which is why this cannot be left to arrive later:
  /// the map used to open on a hardcoded point in Nebraska and stay there.
  final Rx<latlong.LatLng> mapStart = const latlong.LatLng(0.0001, 0.0001).obs;

  /// Set once Google's controller exists. `mapController` is `late`, so
  /// touching it before `onMapCreated` throws.
  bool _googleMapReady = false;

  MapStartLocationStore get _mapStore => MapStartLocationStore(
        read: Preferences.getString,
        write: Preferences.setString,
      );

  /// The camera default was Ahmedabad, India. It is now whatever
  /// [_prepareMapStart] resolved, so the two map types open in the same place.
  final Rx<LatLng> currentPosition = LatLng(23.0225, 72.5714).obs;

  final Rx<LatLng> departureLatLong = const LatLng(0.0, 0.0).obs;
  final Rx<LatLng> destinationLatLong = const LatLng(0.0, 0.0).obs;
  final Rx<latlong.LatLng> departureLatLongOsm = latlong.LatLng(0.0, 0.0).obs;
  final Rx<latlong.LatLng> destinationLatLongOsm = latlong.LatLng(0.0, 0.0).obs;

  final RxBool isLoading = true.obs;

  final RxDouble distance = 0.0.obs;
  final RxString duration = ''.obs;

  BitmapDescriptor? departureIcon, destinationIcon, taxiIcon, stopIcon;
  Widget? departureIconOsm, destinationIconOsm, taxiIconOsm, stopIconOsm;

  RxList<VehicleType> vehicleTypes = <VehicleType>[].obs;
  Rx<VehicleType> selectedVehicleType = VehicleType().obs;

  Rx<UserModel> userModel = UserModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;
  Rx<CabOrderModel> currentOrder = CabOrderModel().obs;

  final RxString selectedPaymentMethod = ''.obs;
  final RxString bottomSheetType = 'location'.obs;

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;

  bool isOsmMapReady = false;

  Rx<CouponModel> selectedCouponModel = CouponModel().obs;

  // ---------------------------------------------------------------------
  // Bidding / counter-offer state.
  //
  // Every field below is inert while `settings/biddingSettings.enabled` is
  // false: nothing reads them, no listener is opened, and no bidding document
  // is written.
  // ---------------------------------------------------------------------

  /// What the customer is willing to pay, typed on the confirm sheet.
  final Rx<TextEditingController> offeredFareTextEditController = TextEditingController().obs;

  /// Offers received on the open bidding ride, newest last.
  final RxList<RideBidModel> bidOffers = <RideBidModel>[].obs;

  /// The bidding fields of the ride currently on screen.
  final Rx<RideBiddingState> biddingState = const RideBiddingState().obs;

  /// Set while an accept / reject / cancel transaction is in flight, so a
  /// second tap on the same card cannot start a second one.
  final RxString bidActionInFlight = ''.obs;

  /// Whether this booking is a **bid** rather than a normal metered ride.
  ///
  /// Set by [CabBookingScreen] from the entry point the customer used: Ride on
  /// the home screen books normally, Place a Bid in the Bid section bids. It is
  /// deliberately a plain field and not an observable - it is written from a
  /// build, and an observable written there would schedule a rebuild from
  /// inside one.
  ///
  /// Nothing in the ordinary booking path reads it, so with it false the flow
  /// is exactly the one that shipped before bidding existed.
  bool bidMode = false;

  /// True when the customer is booking, or watching, a bidding ride.
  bool get isBiddingRide => Constant.isBiddingEnabled && biddingState.value.enabled;

  /// `ratePerKm x distance`, or 0 when the minimum-fare rule is off.
  ///
  /// Follows the selected vehicle: a motorcycle with its own rate is not held
  /// to a car's floor.
  double get minimumAllowedFare =>
      BiddingService.minimumAllowedFare(distance.value, vehicleType: selectedVehicleType.value);

  /// Only the offers still waiting for the customer's decision.
  List<RideBidModel> get liveOffers => bidOffers.where((RideBidModel bid) => bid.isLive).toList();

  /// True when the request is over without a driver: the window closed, or the
  /// dispatcher found nobody eligible. Both need the same "send again" action.
  bool get biddingEndedWithoutDriver {
    final RideBiddingState state = biddingState.value;
    if (state.status == RideBiddingStatus.expired || state.status == RideBiddingStatus.noDrivers) return true;
    return state.status == RideBiddingStatus.open && state.isExpiredAt(DateTime.now());
  }

  @override
  void onInit() {
    super.onInit();
    initData();
  }

  Future<void> initData() async {
    if (Constant.selectedMapType == 'osm') {
      mapOsmController;
    }
    // Everything the **map** needs, and nothing else.
    //
    // `_prepareMapStart` never touches the network - it reads this session's
    // position, then the one saved last run, then the platform's cached
    // last-known fix. `setIcons` loads four bundled assets. Both settle in
    // milliseconds.
    await _prepareMapStart();
    await setIcons();

    // The map is drawn from here. It used to wait for `getVehicleType()` as
    // well - a Firestore round trip - so entering this section meant watching a
    // spinner until the vehicle list came back before a single map tile was
    // even requested. The vehicle list is not on the map's critical path: the
    // strip that shows it is inside the same reactive builder and fills itself
    // in when `vehicleTypes` changes, and every read of `selectedVehicleType`
    // already copes with the empty value it starts at.
    isLoading.value = false;

    await getVehicleType();
  }

  RxList<CouponModel> cabCouponList = <CouponModel>[].obs;
  /// Gives the map a real coordinate to open on, without waiting for GPS.
  ///
  /// Nothing here requests a fix: it uses what this session already holds, then
  /// what was saved last run, then the platform's cached last-known position -
  /// all of which return immediately. The real fix is then requested in the
  /// background and the map is moved to it when it lands.
  /// Where the map opens when this device has no position of its own yet.
  ///
  /// [resolveMapStart]'s own last resort is a deliberate mid-ocean sentinel -
  /// useful as a signal that nothing is known, but on screen it is a flat blue
  /// tile, which to a customer is indistinguishable from a map that failed to
  /// load. That is the state a first run lands in: nothing saved from a
  /// previous session, and the platform holding no cached fix.
  ///
  /// The app already knows somewhere real for this customer - the delivery
  /// address they picked, or the guest default the splash screen sets. Opening
  /// there shows a map of a plausible place while the GPS fix is still coming,
  /// and `refreshCurrentLocation()` moves it the moment the fix lands.
  MapStartLocation get _knownAreaFallback {
    final double? lat = Constant.selectedLocation.location?.latitude;
    final double? lng = Constant.selectedLocation.location?.longitude;
    if (MapStartLocationStore.isUsable(lat, lng)) {
      return MapStartLocation(latitude: lat!, longitude: lng!, source: MapStartSource.saved);
    }
    final UserLocation? guest = Constant.defaultGuestLocation.location;
    if (guest != null && MapStartLocationStore.isUsable(guest.latitude, guest.longitude)) {
      return MapStartLocation(latitude: guest.latitude!, longitude: guest.longitude!, source: MapStartSource.saved);
    }
    return const MapStartLocation(latitude: 0.0001, longitude: 0.0001, source: MapStartSource.fallback);
  }

  Future<void> _prepareMapStart() async {
    final MapStartLocation start = await resolveMapStart(
      store: _mapStore,
      liveLatitude: Constant.currentLocation?.latitude,
      liveLongitude: Constant.currentLocation?.longitude,
      lastKnown: Geolocator.getLastKnownPosition,
      fallback: _knownAreaFallback,
    );

    mapStart.value = latlong.LatLng(start.latitude, start.longitude);
    if (start.isReal) {
      currentPosition.value = LatLng(start.latitude, start.longitude);
    }

    // Not awaited: a GPS fix can take tens of seconds on a cold start and the
    // map must not wait for it. `_prepareMapStart` has already given the first
    // frame something real to draw.
    unawaited(refreshCurrentLocation());
  }

  /// Requests a real fix, remembers it, and moves the map onto it.
  Future<void> refreshCurrentLocation({bool recentre = true}) async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: geo.LocationAccuracy.high),
      );
      Constant.currentLocation = position;
      await _mapStore.remember(position.latitude, position.longitude);
      if (recentre) centreOnLocation(position.latitude, position.longitude);
    } catch (error) {
      // No permission, no signal, or the screen closed. The map keeps whatever
      // it opened on; this is an improvement path, not a required one.
      log('refreshCurrentLocation failed :: $error');
    }
  }

  /// Moves whichever map type is active onto [lat]/[lng] and drops the pickup
  /// pin there.
  ///
  /// This is the half `initialCenter` cannot do: the map is already built by
  /// the time a real fix arrives, so it has to be told to move.
  void centreOnLocation(double lat, double lng, {double zoom = 16}) {
    if (!MapStartLocationStore.isUsable(lat, lng)) return;
    mapStart.value = latlong.LatLng(lat, lng);
    currentPosition.value = LatLng(lat, lng);

    if (Constant.selectedMapType == 'osm') {
      try {
        mapOsmController.move(latlong.LatLng(lat, lng), zoom);
      } catch (error) {
        log('centreOnLocation (osm) failed :: $error');
      }
    } else if (_googleMapReady) {
      try {
        mapController.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom));
      } catch (error) {
        log('centreOnLocation (google) failed :: $error');
      }
    }

    // Only while the customer has not already chosen a pickup themselves.
    if (bottomSheetType.value == 'location' && departureLatLong.value.latitude == 0.0) {
      setDepartureMarker(lat, lng);
      if (Constant.selectedMapType == 'osm') {
        searchPlaceNameOSM();
      } else {
        searchPlaceNameGoogle();
      }
    }
  }

  /// Called from the screen's `onMapCreated`, so a camera move issued before
  /// Google's controller exists is skipped rather than throwing.
  void onGoogleMapCreated(GoogleMapController created) {
    mapController = created;
    _googleMapReady = true;
    final Position? known = Constant.currentLocation;
    if (known != null) centreOnLocation(known.latitude, known.longitude);
  }


  Future<void> getVehicleType() async {
    // Only the vehicle types offered in the customer's city (admin panel).
    final vehicleList = CityFilter.keep(await FireStoreUtils.getVehicleType(), (VehicleType v) => v.zoneIds, await CityFilter.customerZones());
    vehicleTypes.value = vehicleList;
    if (vehicleTypes.isNotEmpty) {
      selectedVehicleType.value = vehicleTypes.first;
    }

    // Draw the real vehicles of the selected type, and redraw whenever the
    // customer switches type - picking Bike must replace the cars on the map
    // with bikes, which is the whole point of the feature.
    listenForNearbyDrivers();
    ever<VehicleType>(selectedVehicleType, (_) {
      listenForNearbyDrivers();
      // Only when this booking is a bid, and only once a route exists -
      // priming against a zero distance quotes the base charge as if it were
      // the whole fare, which then fails its own minimum check a sheet later.
      if (bidMode && distance.value > 0) primeOfferedFare();
    });

    // Close the free-vehicle listener for the duration of a ride and open it
    // again afterwards - see [_rideInProgressSheets].
    bool poolWasRelevant = _ridePoolIsRelevant;
    ever<String>(bottomSheetType, (_) {
      final bool relevant = _ridePoolIsRelevant;
      if (relevant == poolWasRelevant) return;
      poolWasRelevant = relevant;
      listenForNearbyDrivers();
    });

    // The route is fetched over the network, so the distance usually lands
    // *after* the customer is already looking at the vehicle sheet. This is
    // what fills the offer box, and it is a worker rather than a line in the
    // sheet's builder on purpose: setting the text of a TextEditingController
    // a TextField is listening to rebuilds that field, and doing it from
    // inside a build is a framework error the customer sees.
    ever<double>(distance, (double km) {
      if (bidMode && km > 0) primeOfferedFare();
    });

    await getPaymentSettings();

    _userSub?.cancel();
    _userSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((userSnapshot) async {
      if (!userSnapshot.exists) return;

      userModel.value = UserModel.fromJson(userSnapshot.data()!);
      await _followInProgressRide();
    });

    final coupons = await FireStoreUtils.getCabCoupon();
    cabCouponList.value = coupons;
  }

  /// The in-progress list this screen has already resolved, and the ride it
  /// resolved it to.
  ///
  /// Both exist to stop the ride listener being rebuilt for nothing. All of
  /// this used to live inside the customer's own `users` listener and run in
  /// full on **every** snapshot of that document: a `get()` per in-progress
  /// booking - each a network round trip, each awaited - and then
  /// `_rideSub.cancel()` followed by a fresh subscription. So an unrelated
  /// write to the customer's profile threw away the one listener that reports
  /// "your driver accepted" and waited on a round trip to open its
  /// replacement, and any ride update that landed in that gap was only seen
  /// when the new listener's first snapshot arrived. Nothing is re-resolved
  /// now unless the set of in-progress bookings has actually changed.
  String? _resolvedInProgressKey;
  String? _watchedRideId;

  /// The driver [_driverSub] is following, for the same reason.
  String? _watchedDriverId;

  Future<void> _followInProgressRide() async {
    final List<dynamic> inProgress = userModel.value.inProgressOrderID ?? <dynamic>[];
    final String key = inProgress.join(',');
    // The same bookings as last time means the same answer as last time -
    // including "none of these is a ride this screen owns", which is the case
    // that used to cost a `get()` per booking on every profile write. The only
    // thing that reopens the question is the listener failing, and its
    // `onError` clears this for exactly that reason.
    if (key == _resolvedInProgressKey) return;
    _resolvedInProgressKey = key;

    if (inProgress.isEmpty) {
      await _stopWatchingRide();
      bottomSheetType.value = 'location';
      if (Constant.currentLocation != null) {
        setDepartureMarker(Constant.currentLocation!.latitude, Constant.currentLocation!.longitude);
        searchPlaceNameOSM();
      }
      return;
    }

    // The ride to follow is the one that is still going. This used to take
    // `inProgress.first` whatever the check below had found, so a ride the
    // admin deleted, or one that ended Order Rejected, sitting first in the
    // list was followed instead of the new booking - and the customer stayed
    // on "Waiting for driver" after their driver had accepted.
    String? activeRideId;
    String? firstRideId;
    final List<String> deletedIds = <String>[];
    final List<String> endedIds = <String>[];
    for (final dynamic entry in inProgress) {
      final String id = entry.toString();
      final rideDoc = await FireStoreUtils.fireStore.collection(CollectionName.rides).doc(id).get();

      if (!rideDoc.exists) {
        // Only a server answer says a ride is gone; a cache miss does not.
        if (!rideDoc.metadata.isFromCache) deletedIds.add(id);
        continue;
      }
      if ((rideDoc.data()?['rideType'] ?? '').toString().toLowerCase() != "ride") continue;
      firstRideId ??= id;
      if (_endedRideStatuses.contains(rideDoc.data()?['status'])) {
        endedIds.add(id);
      } else {
        activeRideId ??= id;
      }
    }

    // Deleted rides always come off the list. Ended ones only once a newer ride
    // is under way: with nothing else going, the ended ride is still what this
    // screen shows (an expired bid's "send again", for one), exactly as before.
    final List<String> dropIds = <String>[...deletedIds, if (activeRideId != null) ...endedIds];
    if (dropIds.isNotEmpty) unawaited(_dropRidesFromProfile(dropIds));

    final String? validRideId = activeRideId ?? firstRideId;

    // Nothing in the list is a ride this screen owns - a parcel or an
    // intercity booking, say. The old code subscribed to `doc(null)` here,
    // which is a generated id that never exists and therefore never reported
    // anything; not subscribing at all is the same thing without the listener.
    if (validRideId == null) {
      await _stopWatchingRide();
      return;
    }

    if (validRideId == _watchedRideId && _rideSub != null) return;

    await _rideSub?.cancel();
    _watchedRideId = validRideId;
    final String rideId = validRideId;
    _rideSub = FireStoreUtils.fireStore.collection(CollectionName.rides).doc(rideId).snapshots().listen(
      (rideSnapshot) => _onRideSnapshot(rideId, rideSnapshot),
      // An error ends a Firestore subscription for good. Now that this one is
      // opened once per ride rather than once per snapshot of the customer's
      // own document, nothing else would put it back - so forgetting what it
      // was following is what lets the next profile snapshot open a new one.
      onError: (Object error) {
        log('ride listener for $rideId failed :: $error');
        _watchedRideId = null;
        _resolvedInProgressKey = null;
        _rideSub?.cancel();
        _rideSub = null;
      },
    );
  }

  /// Ride statuses after which nothing more happens on the ride.
  static const Set<String> _endedRideStatuses = <String>{Constant.orderRejected, Constant.orderCancelled, Constant.orderCompleted};

  /// Takes rides that are over or gone off the customer's in-progress list.
  ///
  /// One field update, not a save of the whole profile, so nothing else on the
  /// document can be put back from this screen's copy.
  Future<void> _dropRidesFromProfile(List<String> rideIds) async {
    try {
      await FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).update(<String, dynamic>{
        'inProgressOrderID': FieldValue.arrayRemove(rideIds),
      });
    } catch (error) {
      log('could not drop ended rides ${rideIds.join(', ')} :: $error');
    }
  }

  Future<void> _stopWatchingRide() async {
    await _rideSub?.cancel();
    _rideSub = null;
    _watchedRideId = null;
    await _driverSub?.cancel();
    _driverSub = null;
    _watchedDriverId = null;
  }

  /// One snapshot of the ride this customer is on.
  ///
  /// Deliberately synchronous up to the point every sheet is chosen: the whole
  /// value of this listener is that the moment the driver's app writes
  /// `Driver Accepted`, this screen says so.
  void _onRideSnapshot(String rideId, DocumentSnapshot<Map<String, dynamic>> rideSnapshot) {
    if (!rideSnapshot.exists) return;

    final rideData = rideSnapshot.data()!;
    currentOrder.value = CabOrderModel.fromJson(rideData);
    final status = currentOrder.value.status;
    RideContactService.revealWhenBooked(rideId, rideData, userModel.value);

    if (status == Constant.driverAccepted || status == Constant.orderInTransit) {
      final String? driverId = currentOrder.value.driverId;
      // Only when it is a different driver. This used to be cancelled and
      // reopened on every snapshot of the ride, which threw away the live
      // position of the driver on their way to the pickup each time the ride
      // changed at all.
      if (driverId != null && driverId.isNotEmpty && (driverId != _watchedDriverId || _driverSub == null)) {
        _driverSub?.cancel();
        _watchedDriverId = driverId;
        _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(driverId).snapshots().listen((event) {
          if (event.exists && event.data() != null) {
            UserModel driverModel0 = UserModel.fromJson(event.data()!);
            driverModel.value = driverModel0;
            unawaited(updateDriverRoute(driverModel0));
          }
        });
      } else if (driverId != null && driverId.isNotEmpty && driverModel.value.id == driverId && driverModel.value.location != null) {
        // Already following this driver, so the ride itself changed - most
        // importantly Driver Accepted -> In Transit. The driver's app writes
        // only the ride when the trip starts, and its own position only every
        // `driverLocationUpdate` metres, so waiting for the driver's document
        // left the old driver-to-pickup line on screen and no route to the
        // destination. Redraw from the last known position now; the route key
        // makes this a no-op unless the ride or its status really changed.
        unawaited(updateDriverRoute(driverModel.value));
      }
    }

    // Bidding rides carry extra fields on the same document. While the
    // request is still collecting offers the customer watches the offer
    // list instead of the "waiting for driver" spinner; once a driver is
    // booked the ride is an ordinary booked ride again and every branch
    // below runs exactly as it always has.
    biddingState.value = RideBiddingState.fromJson(rideData);
    if (biddingState.value.enabled) {
      _watchBids(rideId);
      final String? winner = biddingState.value.winningBidId;
      final bool awarded = winner != null && winner.isNotEmpty;
      final bool abandoned = status == Constant.orderCancelled || status == Constant.orderRejected;
      // Until a driver is actually booked the customer stays on the offer
      // list - including when the window expired or no driver was
      // eligible, because those are the states where they need the
      // "send again" button rather than a spinner.
      if (!awarded && !abandoned) {
        bottomSheetType.value = 'bidOffers';
        return;
      }
    }

    if (status == Constant.orderPlaced || status == Constant.driverPending || status == Constant.driverRejected || (status == Constant.orderAccepted && currentOrder.value.driverId == null)) {
      bottomSheetType.value = 'waitingForDriver';
    } else if (status == Constant.driverAccepted || status == Constant.orderInTransit) {
      bottomSheetType.value = 'driverDetails';
      sourceTextEditController.value.text = currentOrder.value.sourceLocationName ?? '';
      destinationTextEditController.value.text = currentOrder.value.destinationLocationName ?? '';
      selectedPaymentMethod.value = currentOrder.value.paymentMethod ?? '';
      calculateTotalAmountAfterAccept();
    } else if (status == Constant.orderCompleted) {
      userModel.value.inProgressOrderID?.remove(rideId);
      unawaited(FireStoreUtils.updateUser(userModel.value));
      bottomSheetType.value = 'location';
      // Only if the ride screen is still the screen on top - see
      // [SafePop]. Opening chat or the driver's profile from here used to
      // mean the ride completing closed *that* instead.
      SafePop.popIfCurrent(_ownRoute);
    }
  }


  /// Live map markers for the real, available vehicles of the selected type.
  ///
  /// The query is the section-wide "active cab driver" one the dispatcher also
  /// runs; the per-vehicle and per-distance filtering is done in
  /// [NearbyDrivers.isVisible] on the client. That split is deliberate:
  /// Firestore cannot filter on `vehicleDetails.<sectionId>.vehicleId` without
  /// a composite index per section, and it cannot filter on distance at all.
  ///
  /// If anything needed is missing - no location fix, no section, no chosen
  /// vehicle - the map simply shows no vehicles. It never invents one.
  /// The sheets the customer sees once a ride exists.
  ///
  /// On any of them the map is showing *their* driver, and
  /// [updateRouteMarkers] clears the marker set outright - so the free-vehicle
  /// pool is not on screen and nothing is drawn from it. The listener behind it
  /// is every active cab driver on the platform, each of whom writes their
  /// document as they move, so leaving it open through a ride meant a steady
  /// stream of snapshots - and a marker rebuild apiece - competing with the one
  /// listener that actually matters then: the ride's.
  static const Set<String> _rideInProgressSheets = <String>{'waitingForDriver', 'driverDetails', 'bidOffers'};

  bool get _ridePoolIsRelevant => !_rideInProgressSheets.contains(bottomSheetType.value);

  /// What the nearby-vehicle markers were last drawn from, so an update that
  /// moves nobody visibly does not rebuild them.
  String _nearbySignature = '';

  /// How often the free-vehicle pool is re-read while the customer is choosing.
  ///
  /// This used to be a live `snapshots()` listener over the whole query, and
  /// that listener is what Play reported as ANRs ("Input dispatching timed
  /// out", Dart GC frames on the main thread). The query has no server-side
  /// distance filter (Firestore cannot do that) and returns whole `users`
  /// documents, and on Android the plugin hands Dart *every* document of the
  /// result again on *every* write by *any* active cab driver on the platform.
  /// Since Flutter 3.29 Dart runs on the Android main thread, so a busy minute
  /// of driver writes became a decode-and-collect storm right where touches
  /// are answered. Reading the same query once per interval decodes the pool
  /// once per interval, however many drivers write in between. Drivers only
  /// write their position every `driverLocationUpdate` metres anyway, so the
  /// markers move the same way they did.
  ///
  /// 20 s rather than 10 s: each read still decodes every active cab driver's
  /// whole `users` document on the main thread (the documents carry no
  /// geohash, so the server cannot narrow them to this customer's area), and
  /// that cost grows with the driver pool. Play still reported ANRs after the
  /// 10 s version shipped.
  static const Duration _nearbyPollInterval = Duration(seconds: 20);

  /// The read the current poll repeats, kept so a return to the foreground can
  /// refresh straight away instead of waiting out the interval.
  Future<void> Function()? _nearbyFetch;

  /// Pauses the poll while the app is in the background. The timer used to
  /// keep reading and decoding the whole driver pool for a map nobody could
  /// see, and Android then answered the next touch late.
  AppLifecycleListener? _nearbyLifecycle;
  bool _appInForeground = true;

  void _watchLifecycleForNearbyPoll() {
    _nearbyLifecycle ??= AppLifecycleListener(
      onStateChange: (AppLifecycleState state) {
        final bool foreground = state == AppLifecycleState.resumed;
        if (foreground == _appInForeground) return;
        _appInForeground = foreground;
        if (foreground && _nearbyPollTimer != null) {
          final Future<void> Function()? fetch = _nearbyFetch;
          if (fetch != null) unawaited(fetch());
        }
      },
    );
  }

  /// Bumped whenever the pool is re-targeted or closed, so a read that was
  /// already in flight for an earlier vehicle type / section / sheet can never
  /// draw its drivers over the current ones.
  int _nearbyGeneration = 0;
  bool _nearbyFetchInFlight = false;

  Future<void> listenForNearbyDrivers() async {
    _nearbyPollTimer?.cancel();
    _nearbyPollTimer = null;
    _nearbyFetch = null;
    final int generation = ++_nearbyGeneration;
    nearbyDrivers.clear();
    _nearbySignature = '';

    if (!_ridePoolIsRelevant) {
      updateNearbyDriverMarkers();
      return;
    }

    final String sectionId = Constant.sectionConstantModel?.id ?? '';
    final String vehicleId = selectedVehicleType.value.id ?? '';
    final Position? me = Constant.currentLocation;
    if (sectionId.isEmpty || vehicleId.isEmpty || me == null) {
      updateNearbyDriverMarkers();
      return;
    }

    Future<void> fetch() async {
      // A slow read is never stacked on top of another one.
      if (_nearbyFetchInFlight) return;
      // Nothing is drawn while the app is in the background.
      if (!_appInForeground) return;
      _nearbyFetchInFlight = true;
      try {
        final QuerySnapshot<Map<String, dynamic>> snapshot = await FireStoreUtils.fireStore
            .collection(CollectionName.users)
            .where('role', isEqualTo: 'driver')
            .where('serviceTypes', arrayContains: 'cab-service')
            .where('isActive', isEqualTo: true)
            .get();
        if (generation != _nearbyGeneration) return;
        _processNearbySnapshot(snapshot, sectionId: sectionId, vehicleId: vehicleId, me: me);
      } catch (error) {
        if (generation != _nearbyGeneration) return;
        log('listenForNearbyDrivers failed :: $error');
        nearbyDrivers.clear();
        _nearbySignature = '';
        updateNearbyDriverMarkers();
      } finally {
        _nearbyFetchInFlight = false;
      }
    }

    // Once straight away, as the listener's first snapshot was, then on the
    // interval until the pool is re-targeted or the screen closes.
    _nearbyFetchInFlight = false;
    _watchLifecycleForNearbyPoll();
    _nearbyFetch = fetch;
    unawaited(fetch());
    _nearbyPollTimer = Timer.periodic(_nearbyPollInterval, (_) => fetch());
  }

  /// Exactly the processing a snapshot of the nearby-driver query always did -
  /// only now run once per [_nearbyPollInterval] instead of once per write.
  void _processNearbySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required String sectionId,
    required String vehicleId,
    required Position me,
  }) {
    final Map<String, NearbyDriver> found = <String, NearbyDriver>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      if (!NearbyDrivers.isVisible(
        data,
        sectionId: sectionId,
        vehicleId: vehicleId,
        customerLat: me.latitude,
        customerLng: me.longitude,
      )) {
        continue;
      }
      final NearbyDriver? marker = NearbyDrivers.toMarker(doc.id, data, sectionId: sectionId);
      if (marker != null) found[doc.id] = marker;
    }

    // A snapshot of this query arrives whenever *any* active cab driver on
    // the platform writes their document. Most of those move nobody this
    // customer can see, and rebuilding every marker for one of them is the
    // work that made the booking map stutter.
    final String signature = _signatureFor(found);
    if (signature == _nearbySignature) return;
    _nearbySignature = signature;

    nearbyDrivers
      ..clear()
      ..addAll(found);
    updateNearbyDriverMarkers();
  }

  /// What the visible pool looks like, to about ten metres. Sorted, so the
  /// order Firestore happens to deliver documents in cannot make an unchanged
  /// pool look changed.
  String _signatureFor(Map<String, NearbyDriver> found) {
    final List<String> parts = found.values
        .map((NearbyDriver d) =>
            '${d.id}:${d.latitude.toStringAsFixed(4)},${d.longitude.toStringAsFixed(4)}:${d.rotation.round()}:${d.vehicleId}')
        .toList()
      ..sort();
    return parts.join('|');
  }

  /// The icon for a vehicle type, from that type's own `vehicleIcon`.
  ///
  /// Falls back to the section marker and then to the bundled cab image, which
  /// is what the app did for every vehicle before this. **Until an icon is
  /// uploaded against each vehicle type in the Admin Panel (Vehicle Type ->
  /// edit -> icon) a bike and a car still share the fallback image** - the code
  /// can only draw the picture it is given.
  Future<BitmapDescriptor> iconForVehicle(String vehicleId) async {
    final BitmapDescriptor? cached = _vehicleIcons[vehicleId];
    if (cached != null) return cached;

    String? url;
    for (final VehicleType type in vehicleTypes) {
      if (type.id == vehicleId) {
        url = type.vehicleIcon;
        break;
      }
    }
    url ??= Constant.sectionConstantModel?.markerIcon;

    Uint8List bytes;
    try {
      bytes = (url != null && url.isNotEmpty)
          ? await Constant().getBytesFromUrl(url, width: 120)
          : await Constant().getBytesFromAsset('assets/images/ic_cab.png', 60);
    } catch (error) {
      log('iconForVehicle fell back for $vehicleId :: $error');
      bytes = await Constant().getBytesFromAsset('assets/images/ic_cab.png', 60);
    }

    final BitmapDescriptor descriptor = BitmapDescriptor.fromBytes(bytes);
    _vehicleIcons[vehicleId] = descriptor;
    return descriptor;
  }

  /// Redraws the nearby-vehicle markers, leaving every other marker alone.
  ///
  /// The markers are built first and swapped in with one assignment. Removing
  /// them and then adding one per vehicle, with an icon lookup awaited between
  /// adds, notified the map - and the whole booking screen around it - once per
  /// change, so a single snapshot of the vehicle pool rebuilt the screen
  /// several times.
  Future<void> updateNearbyDriverMarkers() async {
    final List<Marker> nearby = <Marker>[];
    for (final NearbyDriver driver in nearbyDrivers.values.toList()) {
      final BitmapDescriptor icon = await iconForVehicle(driver.vehicleId);
      nearby.add(
        Marker(
          markerId: MarkerId('nearby_${driver.id}'),
          position: LatLng(driver.latitude, driver.longitude),
          icon: icon,
          rotation: driver.rotation,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 1,
        ),
      );
    }

    final Set<Marker> next = markers.where((Marker m) => !m.markerId.value.startsWith('nearby_')).toSet()..addAll(nearby);
    markers.assignAll(next);
  }

  /// The route and markers this screen last drew for the booked driver.
  ///
  /// Every snapshot of the driver's document used to redraw the whole thing:
  /// a routing request over the network, then two asset decodes and a full
  /// marker rebuild. That document is written on every location update, so
  /// following a driver to the pickup meant a routing call per update against
  /// the same public server - which is precisely the load that makes it answer
  /// slowly. Three decimal places is about a hundred metres; below that the
  /// line being drawn is the same line.
  String? _driverRouteKey;

  Future<void> updateDriverRoute(UserModel driverModel) async {
    try {
      final order = currentOrder.value;

      final driverLat = driverModel.location!.latitude ?? 0.0;
      final driverLng = driverModel.location!.longitude ?? 0.0;

      if (driverLat == 0.0 || driverLng == 0.0) return;

      final String routeKey = '${order.id}|${order.status}|${driverLat.toStringAsFixed(3)},${driverLng.toStringAsFixed(3)}';
      if (routeKey == _driverRouteKey) return;
      _driverRouteKey = routeKey;

      // Get pickup and destination
      final pickupLat = order.sourceLocation?.latitude ?? 0.0;
      final pickupLng = order.sourceLocation?.longitude ?? 0.0;
      final destLat = order.destinationLocation?.latitude ?? 0.0;
      final destLng = order.destinationLocation?.longitude ?? 0.0;

      if (Constant.selectedMapType == 'osm') {
        /// For OpenStreetMap
        routePoints.clear();

        if (order.status == Constant.driverAccepted) {
          // DRIVER → PICKUP
          await fetchRouteWithWaypoints([latlong.LatLng(driverLat, driverLng), latlong.LatLng(pickupLat, pickupLng)]);
        } else if (order.status == Constant.orderInTransit) {
          // PICKUP → DESTINATION
          await fetchRouteWithWaypoints([latlong.LatLng(driverLat, driverLng), latlong.LatLng(destLat, destLng)]);
        }
        updateRouteMarkers(driverModel);
      } else {
        /// For Google Maps
        if (order.status == Constant.driverAccepted) {
          await fetchGoogleRouteBetween(LatLng(driverLat, driverLng), LatLng(pickupLat, pickupLng));
        } else if (order.status == Constant.orderInTransit) {
          await fetchGoogleRouteBetween(LatLng(driverLat, driverLng), LatLng(destLat, destLng));
        }
        updateRouteMarkers(driverModel);
      }
    } catch (e) {
      print("Error in updateDriverRoute: $e");
    }
  }

  Future<void> updateRouteMarkers(UserModel driverModel) async {
    try {
      final order = currentOrder.value;
      if (order.driver == null || driverModel.location == null) return;

      final driverLat = driverModel.location!.latitude ?? 0.0;
      final driverLng = driverModel.location!.longitude ?? 0.0;
      final pickupLat = order.sourceLocation?.latitude ?? 0.0;
      final pickupLng = order.sourceLocation?.longitude ?? 0.0;
      final destLat = order.destinationLocation?.latitude ?? 0.0;
      final destLng = order.destinationLocation?.longitude ?? 0.0;

      markers.clear();
      osmMarker.clear();

      // Two bundled images that never change. They were decoded and turned
      // into a BitmapDescriptor again on every redraw of this map.
      if (departureIcon == null) {
        departureIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/location_black3x.png', 50));
      }
      if (destinationIcon == null) {
        destinationIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/location_orange3x.png', 50));
      }

      // The driver on the way is drawn as the vehicle they are actually
      // driving, taken from the ride's own vehicle type rather than one icon
      // for the whole section - so a booked bike shows a bike. Falls back to
      // the section marker and then to the bundled cab image, exactly as
      // before, when that vehicle type has no icon uploaded.
      taxiIcon = await iconForVehicle(order.vehicleType?.id ?? order.vehicleId ?? '');

      if (Constant.selectedMapType == 'osm') {
        if (order.status == Constant.driverAccepted) {
          osmMarker.addAll([
            flutterMap.Marker(point: latlong.LatLng(pickupLat, pickupLng), width: 40, height: 40, child: Image.asset('assets/images/location_black3x.png', width: 40)),
            flutterMap.Marker(
              point: latlong.LatLng(driverLat, driverLng),
              width: 45,
              height: 45,
              rotate: true,
              child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                width: 50,
                height: 50,
                imageUrl: Constant.sectionConstantModel!.markerIcon.toString(),
                placeholder: (context, url) => Constant.loader(),
                errorWidget: (context, url, error) => SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ]);
        } else if (order.status == Constant.orderInTransit) {
          osmMarker.addAll([
            flutterMap.Marker(point: latlong.LatLng(destLat, destLng), width: 40, height: 40, child: Image.asset('assets/images/location_orange3x.png', width: 40)),
            flutterMap.Marker(
              point: latlong.LatLng(driverLat, driverLng),
              width: 45,
              height: 45,
              rotate: true,
              child: CachedNetworkImage(cacheManager: AppImageCache.manager, 
                width: 50,
                height: 50,
                imageUrl: Constant.sectionConstantModel!.markerIcon.toString(),
                placeholder: (context, url) => Constant.loader(),
                errorWidget: (context, url, error) => SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          ]);
        }
      } else {
        if (order.status == Constant.driverAccepted) {
          markers.addAll([
            Marker(
              markerId: const MarkerId("pickup"),
              position: LatLng(pickupLat, pickupLng),
              infoWindow: InfoWindow(title: "Pickup Location".tr),
              icon: departureIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
            Marker(markerId: const MarkerId("driver"), position: LatLng(driverLat, driverLng), infoWindow: InfoWindow(title: "Driver at Pickup".tr), icon: taxiIcon ?? BitmapDescriptor.defaultMarker),
          ]);
        } else if (order.status == Constant.orderInTransit) {
          markers.addAll([
            Marker(
              markerId: const MarkerId("destination"),
              position: LatLng(destLat, destLng),
              infoWindow: InfoWindow(title: "Destination Location".tr),
              icon: destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
            Marker(markerId: const MarkerId("driver"), position: LatLng(driverLat, driverLng), infoWindow: InfoWindow(title: "Driver Location".tr), icon: taxiIcon ?? BitmapDescriptor.defaultMarker),
          ]);
        }
      }

      update();
    } catch (e) {
      print("❌ Error in updateRouteMarkers: $e");
    }
  }

  Future<void> fetchGoogleRouteBetween(LatLng originPoint, LatLng destPoint) async {
    final origin = '${originPoint.latitude},${originPoint.longitude}';
    final destination = '${destPoint.latitude},${destPoint.longitude}';
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination'
      '&mode=driving&key=${Constant.mapAPIKey}',
    );

    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final encodedPolyline = route['overview_polyline']['points'];
        final decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);
        final coordinates = decodedPoints.map((e) => LatLng(e.latitude, e.longitude)).toList();

        addPolyLine(coordinates);

        // Distance + duration update
        final leg = route['legs'][0];
        final totalDistance = leg['distance']['value'] / 1000.0;
        final totalDuration = leg['duration']['value'] / 60.0;

        distance.value = totalDistance;
        duration.value = '${totalDuration.toStringAsFixed(0)} min';
      } else {
        print('Google Directions API error: ${data['status']}');
      }
    } catch (e) {
      print("Error fetching driver route: $e");
    }
  }

  void calculateTotalAmountAfterAccept() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    subTotal.value = double.parse(currentOrder.value.subTotal.toString());
    discount.value = double.parse(currentOrder.value.discount ?? '0.0');
    orderTaxAmount.value = 0.0;
    platformTaxAmount.value = 0.0;

    for (var taxElement in Constant.orderProductTaxList ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

    /// ---------------- PLATFORM TAX ----------------
    if (double.parse(Constant.platformFeeModel?.fee ?? '0.0') > 0.0) {
      for (var taxElement in Constant.platformTaxList ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: Constant.platformFeeModel?.fee ?? '0.0', taxModel: taxElement);
      }
    }
    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;

    totalAmount.value = (subTotal.value - discount.value) + double.parse(Constant.platformFeeModel?.fee ?? '0.0') + taxAmount.value;
    update();
  }

  void calculateTotalAmount() {
    subTotal = 0.0.obs;
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    totalAmount = 0.0.obs;
    platformTaxAmount.value = 0.0;
    orderTaxAmount.value = 0.0;
    subTotal.value = getAmount(selectedVehicleType.value);

    if (selectedCouponModel.value.id != null) {
      discount.value = Constant.calculateDiscount(amount: subTotal.value.toString(), offerModel: selectedCouponModel.value);
    }

    for (var taxElement in Constant.orderProductTaxList ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

    /// ---------------- PLATFORM TAX ----------------
    if (double.parse(Constant.platformFeeModel?.fee ?? '0.0') > 0.0) {
      for (var taxElement in Constant.platformTaxList ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: Constant.platformFeeModel?.fee ?? '0.0', taxModel: taxElement);
      }
    }
    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;

    totalAmount.value = (subTotal.value - discount.value) + double.parse(Constant.platformFeeModel?.fee ?? '0.0') + taxAmount.value;

    update();
  }

  Future<void> completeOrder() async {
    if (selectedPaymentMethod.value == PaymentGateway.cod.name) {
      // Cash is settled with the driver, who confirms it on their own screen
      // before the ride can be completed - so there is nothing to charge here
      // and nothing to close.
      //
      // This used to pop twice. `Pay Now` on this screen opens neither a sheet
      // nor a payment page, so both pops landed on real screens and threw the
      // customer out to the service list in the middle of their ride, which is
      // the "everything vanishes" the client reported. The gateway branch
      // below still pops once, because there its payment page is what closes.
      currentOrder.value.paymentMethod = selectedPaymentMethod.value;
      await FireStoreUtils.cabOrderPlace(currentOrder.value).then((value) {
        ShowToastDialog.showToast("Please pay the fare to your driver in cash".tr);
      });
    } else {
      currentOrder.value.paymentStatus = true;
      currentOrder.value.paymentMethod = selectedPaymentMethod.value;
      userModel.value.inProgressOrderID ??= [];
      userModel.value.inProgressOrderID!.clear();
      await FireStoreUtils.updateUser(userModel.value);

      if (selectedPaymentMethod.value == PaymentGateway.wallet.name) {
        WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: double.parse(totalAmount.toString()),
          date: Timestamp.now(),
          paymentMethod: PaymentGateway.wallet.name,
          transactionUser: "customer",
          userId: FireStoreUtils.getCurrentUid(),
          isTopup: false,
          orderId: currentOrder.value.id,
          note: "Cab Amount debited",
          paymentStatus: "success",
          serviceType: Constant.parcelServiceType,
        );

        await FireStoreUtils.setWalletTransaction(transactionModel).then((value) async {
          if (value == true) {
            await FireStoreUtils.updateUserWallet(amount: "-${totalAmount.value.toString()}", userId: FireStoreUtils.getCurrentUid());
          }
        });
      }

      await FireStoreUtils.cabOrderPlace(currentOrder.value).then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        // Closes the payment UI only if it is still open - see [SafePop].
        SafePop.popUnlessCurrent(_ownRoute);
      });
    }
  }

  /// Builds the ride document the booking screen has always built.
  ///
  /// Extracted from `placeOrder()` unchanged so the bidding flow writes the
  /// very same ride shape rather than a second, drifting copy of it.
  CabOrderModel buildOrderModel() {
    DestinationLocation sourceLocation = DestinationLocation(
      latitude: Constant.selectedMapType == 'osm' ? departureLatLongOsm.value.latitude : departureLatLong.value.latitude,
      longitude: Constant.selectedMapType == 'osm' ? departureLatLongOsm.value.longitude : departureLatLong.value.longitude,
    );

    DestinationLocation destinationLocation = DestinationLocation(
      latitude: Constant.selectedMapType == 'osm' ? destinationLatLongOsm.value.latitude : destinationLatLong.value.latitude,
      longitude: Constant.selectedMapType == 'osm' ? destinationLatLongOsm.value.longitude : destinationLatLong.value.longitude,
    );

    CabOrderModel orderModel = CabOrderModel();
    orderModel.id = const Uuid().v4();
    orderModel.distance = distance.value.toString();
    orderModel.duration = duration.value;
    orderModel.vehicleId = selectedVehicleType.value.id;
    orderModel.vehicleType = selectedVehicleType.value;
    orderModel.authorID = FireStoreUtils.getCurrentUid();
    orderModel.sourceLocationName = sourceTextEditController.value.text;
    orderModel.destinationLocationName = destinationTextEditController.value.text;

    orderModel.sourceLocation = sourceLocation;
    orderModel.destinationLocation = destinationLocation;
    orderModel.author = userModel.value;
    orderModel.subTotal = subTotal.value.toString();
    orderModel.discount = discount.value.toString();
    orderModel.couponCode = selectedCouponModel.value.code;
    orderModel.couponId = selectedCouponModel.value.id;
    orderModel.adminCommissionType =
        Constant.sectionConstantModel!.adminCommision != null && Constant.sectionConstantModel!.adminCommision!.isEnabled == true
            ? Constant.sectionConstantModel!.adminCommision!.commissionType.toString()
            : null;
    orderModel.adminCommission =
        Constant.sectionConstantModel!.adminCommision != null && Constant.sectionConstantModel!.adminCommision!.isEnabled == true
            ? Constant.sectionConstantModel!.adminCommision!.amount.toString()
            : null;
    orderModel.couponCode = couponCodeTextEditController.value.text;
    orderModel.paymentMethod = selectedPaymentMethod.value;
    orderModel.paymentStatus = false;
    orderModel.triggerDelevery = Timestamp.now();
    orderModel.tipAmount = "0.0";
    orderModel.scheduleReturnDateTime = Timestamp.now();
    orderModel.rideType = 'ride';
    orderModel.roundTrip = false;
    orderModel.sectionId = Constant.sectionConstantModel!.id;
    orderModel.createdAt = Timestamp.now();
    orderModel.otpCode = (maths.Random().nextInt(9000) + 1000).toString(); // Generate a 4-digit OTP
    orderModel.status = Constant.orderPlaced;
    orderModel.scheduleDateTime = Timestamp.now();
    orderModel.taxSetting = Constant.orderProductTaxList;
    orderModel.platformFee = Constant.platformFeeModel?.fee;
    orderModel.platformTax = Constant.platformTaxList;
    return orderModel;
  }

  Future<void> placeOrder() async {
    final CabOrderModel orderModel = buildOrderModel();
    log("Order Model : ${orderModel.toJson()}");
    ShowToastDialog.showLoader("Please wait".tr);

    try {
      await RideContactService.placeSystemRide(orderModel);
    } catch (error) {
      ShowToastDialog.closeLoader();
      log('placeOrder: the ride could not be created :: $error');
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }

    // Not awaited: the confirmation e-mail is an SMTP connection made from the
    // phone, and a mail server that does not answer must not hold a booking
    // open behind a blocking loader. It is still sent.
    unawaited(FireStoreUtils.sendCabBookEmail(orderModel: orderModel));

    try {
      // A user document that has never held a ride has no list to append to, and
      // the bare `!` threw there. Same guard the bidding path already had.
      userModel.value.inProgressOrderID ??= [];
      userModel.value.inProgressOrderID!.add(orderModel.id);
      await FireStoreUtils.updateUser(userModel.value);
    } catch (error) {
      log('placeOrder: recording the ride on the profile failed :: $error');
    }

    ShowToastDialog.closeLoader();
    bottomSheetType.value = 'waitingForDriver';
  }

  double getAmount(VehicleType vehicleType) {
    return VehicleFare.meteredFare(vehicleType: vehicleType, distanceKm: distance.value);
  }

  void setDepartureMarker(double lat, double long) {
    if (Constant.selectedMapType == 'osm') {
      _setOsmMarker(lat, long, isDeparture: true);
    } else {
      _setGoogleMarker(lat, long, isDeparture: true);
    }
  }

  void setDestinationMarker(double lat, double lng) {
    if (Constant.selectedMapType == 'osm') {
      _setOsmMarker(lat, lng, isDeparture: false);
    } else {
      _setGoogleMarker(lat, lng, isDeparture: false);
    }
  }

  void setStopMarker(double lat, double lng, int index) {
    if (Constant.selectedMapType == 'osm') {
      // Add new stop marker without clearing
      osmMarker.add(flutterMap.Marker(point: latlong.LatLng(lat, lng), width: 40, height: 40, child: stopIconOsm!));

      getDirections(isStopMarker: true);
    } else {
      final markerId = MarkerId('Stop $index');

      markers.removeWhere((marker) => marker.markerId == markerId);
      markers.add(Marker(markerId: markerId, infoWindow: InfoWindow(title: '${'Stop'.tr} ${String.fromCharCode(index + 65)}'), position: LatLng(lat, lng), icon: stopIcon!));

      getDirections();
    }
  }

  void _setOsmMarker(double lat, double lng, {required bool isDeparture}) {
    final marker = flutterMap.Marker(point: latlong.LatLng(lat, lng), width: 40, height: 40, child: isDeparture ? departureIconOsm! : destinationIconOsm!);
    if (isDeparture) {
      departureLatLongOsm.value = latlong.LatLng(lat, lng);
    } else {
      destinationLatLongOsm.value = latlong.LatLng(lat, lng);
    }
    osmMarker.add(marker);
    if (departureLatLongOsm.value.latitude != 0 && destinationLatLongOsm.value.latitude != 0) {
      getDirections();
      animateToSource(lat, lng);
    }
  }

  void _setGoogleMarker(double lat, double lng, {required bool isDeparture}) {
    final LatLng pos = LatLng(lat, lng);
    final markerId = MarkerId(isDeparture ? 'Departure' : 'Destination');
    final icon = isDeparture ? departureIcon! : destinationIcon!;
    final title = isDeparture ? 'Departure'.tr : 'Destination'.tr;

    if (isDeparture) {
      departureLatLong.value = pos;
    } else {
      destinationLatLong.value = pos;
    }

    // Remove only the matching departure/destination marker
    markers.removeWhere((marker) => marker.markerId == markerId);

    // Add new marker
    markers.add(Marker(markerId: markerId, position: pos, icon: icon, infoWindow: InfoWindow(title: title)));

    mapController.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));

    if (departureLatLong.value.latitude != 0 && destinationLatLong.value.latitude != 0) {
      getDirections();
    } else {
      mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lng), zoom: 14)));
    }
  }

  Future<void> getDirections({bool isStopMarker = false}) async {
    if (Constant.selectedMapType == 'osm') {
      final wayPoints = <latlong.LatLng>[];

      // Only add valid source
      if (departureLatLongOsm.value.latitude != 0.0 && departureLatLongOsm.value.longitude != 0.0) {
        wayPoints.add(departureLatLongOsm.value);
      }

      // Only add valid destination
      if (destinationLatLongOsm.value.latitude != 0.0 && destinationLatLongOsm.value.longitude != 0.0) {
        wayPoints.add(destinationLatLongOsm.value);
      }

      if (!isStopMarker) osmMarker.clear();

      // Add source marker
      if (departureLatLongOsm.value.latitude != 0.0 && departureLatLongOsm.value.longitude != 0.0) {
        osmMarker.add(flutterMap.Marker(point: departureLatLongOsm.value, width: 40, height: 40, child: departureIconOsm!));
      }

      // Add destination marker
      if (destinationLatLongOsm.value.latitude != 0.0 && destinationLatLongOsm.value.longitude != 0.0) {
        osmMarker.add(flutterMap.Marker(point: destinationLatLongOsm.value, width: 40, height: 40, child: destinationIconOsm!));
      }

      if (wayPoints.length >= 2) {
        await fetchRouteWithWaypoints(wayPoints);
      }
    } else {
      // Google Maps path
      fetchGoogleRouteWithWaypoints();
    }
  }

  Future<void> fetchGoogleRouteWithWaypoints() async {
    if (departureLatLong.value.latitude == 0.0 || destinationLatLong.value.latitude == 0.0) return;

    final origin = '${departureLatLong.value.latitude},${departureLatLong.value.longitude}';
    final destination = '${destinationLatLong.value.latitude},${destinationLatLong.value.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination'
      '&mode=driving&key=${Constant.mapAPIKey}',
    );

    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final legs = route['legs'] as List;

        // Polyline
        final encodedPolyline = route['overview_polyline']['points'];
        final decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);
        final coordinates = decodedPoints.map((e) => LatLng(e.latitude, e.longitude)).toList();

        addPolyLine(coordinates);

        // Distance & Duration
        num totalDistance = 0;
        num totalDuration = 0;
        for (var leg in legs) {
          totalDistance += leg['distance']['value']!; // meters
          totalDuration += leg['duration']['value']!; // seconds
        }

        // Convert distance to KM or Miles
        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = totalDistance / 1000.0;
        } else {
          distance.value = totalDistance / 1609.34;
        }

        // Format duration
        final hours = totalDuration ~/ 3600;
        final minutes = ((totalDuration % 3600) / 60).round();
        duration.value = '${hours}h ${minutes}m';
      } else {
        print('Google Directions API Error: ${data['status']}');
      }
    } catch (e) {
      print("Google route fetch error: $e");
    }
  }

  Future<void> fetchRouteWithWaypoints(List<latlong.LatLng> points) async {
    final coordinates = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson');

    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final geometry = decoded['routes'][0]['geometry']['coordinates'] as List;
        final dist = decoded['routes'][0]['distance'];
        final dur = decoded['routes'][0]['duration'];

        routePoints.clear();
        routePoints.addAll(geometry.map((coord) => latlong.LatLng(coord[1], coord[0])));

        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = dist / 1000.00;
        } else {
          distance.value = dist / 1609.34;
        }

        final hours = dur ~/ 3600;
        final minutes = ((dur % 3600) / 60).round();
        duration.value = '${hours}h ${minutes}m';

        // Zoom to fit polyline after drawing
        zoomToPolylineOSM();
      } else {
        print("Failed to get route: ${response.body}");
      }
    } catch (e) {
      print("Route fetch error: $e");
    }
  }

  void zoomToPolylineOSM() {
    if (routePoints.isEmpty) return;
    // LatLngBounds requires at least two points
    final bounds = flutterMap.LatLngBounds(routePoints.first, routePoints.first);
    for (final point in routePoints) {
      bounds.extend(point);
    }
    final center = bounds.center;
    // Calculate zoom level to fit all points
    double zoom = getBoundsZoomLevel(bounds);
    mapOsmController.move(center, zoom);
  }

  double getBoundsZoomLevel(flutterMap.LatLngBounds bounds) {
    // Simple heuristic: zoom out for larger bounds
    final latDiff = (bounds.northEast.latitude - bounds.southWest.latitude).abs();
    final lngDiff = (bounds.northEast.longitude - bounds.southWest.longitude).abs();
    double maxDiff = math.max(latDiff, lngDiff);
    if (maxDiff < 0.005) return 18.0;
    if (maxDiff < 0.01) return 16.0;
    if (maxDiff < 0.05) return 14.0;
    if (maxDiff < 0.1) return 12.0;
    if (maxDiff < 0.5) return 10.0;
    return 8.0;
  }

  void addPolyLine(List<LatLng> points) {
    final id = const PolylineId("poly");
    final polyline = Polyline(polylineId: id, color: AppThemeData.primary300, points: points, width: 6, geodesic: true);
    polyLines[id] = polyline;

    if (points.length >= 2) {
      // Zoom to fit all polyline points
      updateCameraLocationToFitPolyline(points, mapController);
    }
  }

  Future<void> updateCameraLocationToFitPolyline(List<LatLng> points, GoogleMapController? mapController) async {
    if (mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 50);
    await checkCameraLocation(cameraUpdate, mapController);
  }

  Future<void> animateToSource(double lat, double long) async {
    final hasBothCoords = departureLatLongOsm.value.latitude != 0.0 && destinationLatLongOsm.value.latitude != 0.0;

    if (hasBothCoords) {
      await calculateZoomLevel(source: departureLatLongOsm.value, destination: destinationLatLongOsm.value);
    } else {
      mapOsmController.move(latlong.LatLng(lat, long), 10);
    }
  }

  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;

  Future<void> calculateZoomLevel({required latlong.LatLng source, required latlong.LatLng destination, double paddingFraction = 0.001}) async {
    final bounds = flutterMap.LatLngBounds.fromPoints([source, destination]);
    final screenSize = Size(Get.width, Get.height * 0.5);
    const double worldDimension = 256.0;
    const double maxZoom = 10.0;

    double latToRad(double lat) => math.log((1 + math.sin(lat * math.pi / 180)) / (1 - math.sin(lat * math.pi / 180))) / 2;

    double computeZoom(double screenPx, double worldPx, double fraction) => math.log(screenPx / worldPx / fraction) / math.ln2;

    final north = bounds.northEast.latitude;
    final south = bounds.southWest.latitude;
    final east = bounds.northEast.longitude;
    final west = bounds.southWest.longitude;

    final latDelta = (north - south).abs();
    final lngDelta = (east - west).abs();

    final center = bounds.center;

    if (latDelta < 1e-6 || lngDelta < 1e-6) {
      mapOsmController.move(center, maxZoom);
    } else {
      final latFraction = (latToRad(north) - latToRad(south)) / math.pi;
      final lngFraction = ((east - west + 360) % 360) / 360;

      final latZoom = computeZoom(screenSize.height, worldDimension, latFraction + paddingFraction);
      final lngZoom = computeZoom(screenSize.width, worldDimension, lngFraction + paddingFraction);

      final zoomLevel = math.min(latZoom, lngZoom).clamp(0.0, maxZoom);
      mapOsmController.move(center, zoomLevel);
    }
  }

  Future<void> updateCameraLocation(LatLng source, LatLng destination, GoogleMapController? mapController) async {
    if (mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(math.min(source.latitude, destination.latitude), math.min(source.longitude, destination.longitude)),
      northeast: LatLng(math.max(source.latitude, destination.latitude), math.max(source.longitude, destination.longitude)),
    );

    final cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 90);
    await checkCameraLocation(cameraUpdate, mapController);
  }

  Future<void> checkCameraLocation(CameraUpdate cameraUpdate, GoogleMapController mapController) async {
    await mapController.animateCamera(cameraUpdate);
    final l1 = await mapController.getVisibleRegion();
    final l2 = await mapController.getVisibleRegion();

    if (l1.southwest.latitude == -90 || l2.southwest.latitude == -90) {
      await checkCameraLocation(cameraUpdate, mapController);
    }
  }

  Future<void> setIcons() async {
    try {
      if (Constant.selectedMapType == 'osm') {
        departureIconOsm = Image.asset("assets/icons/pickup.png", width: 30, height: 30);
        destinationIconOsm = Image.asset("assets/icons/dropoff.png", width: 30, height: 30);
        taxiIconOsm = Image.asset("assets/icons/ic_taxi.png", width: 30, height: 30);
        stopIconOsm = Image.asset("assets/icons/location.png", width: 26, height: 26);
      } else {
        const config = ImageConfiguration(size: Size(48, 48));
        departureIcon = await BitmapDescriptor.fromAssetImage(config, "assets/icons/pickup.png");
        destinationIcon = await BitmapDescriptor.fromAssetImage(config, "assets/icons/dropoff.png");
        taxiIcon = await BitmapDescriptor.fromAssetImage(config, "assets/icons/ic_taxi.png");
        stopIcon = await BitmapDescriptor.fromAssetImage(config, "assets/icons/location.png");
      }
    } catch (e) {
      print('Error loading icons: $e');
    }
  }

  void clearMapDataIfLocationsRemoved() {
    final isSourceEmpty = departureLatLongOsm.value.latitude == 0.0 && departureLatLongOsm.value.longitude == 0.0;
    final isDestinationEmpty = destinationLatLongOsm.value.latitude == 0.0 && destinationLatLongOsm.value.longitude == 0.0;

    if (isSourceEmpty || isDestinationEmpty) {
      // Clear polylines
      polyLines.clear();

      // Clear OSM markers (if using OSM)
      osmMarker.clear();

      // Clear Google markers (if using Google Maps)
      markers.clear();

      // Clear route points (optional)
      routePoints.clear();

      // Reset distance and duration values
      distance.value = 0.0;
      duration.value = '';
    }
  }

  void removeSource() {
    // Clear departure location and related data
    departureLatLongOsm.value = latlong.LatLng(0.0, 0.0);
    departureLatLong.value = const LatLng(0.0, 0.0);
    sourceTextEditController.value.clear();

    // Remove marker
    if (Constant.selectedMapType == 'osm') {
      osmMarker.removeWhere((marker) => marker.point == departureLatLongOsm.value);
    } else {
      markers.removeWhere((marker) => marker.markerId.value == 'Departure');
    }

    // Clear polylines and route info if needed
    clearMapDataIfLocationsRemoved();
    update();
  }

  void removeDestination() {
    destinationLatLongOsm.value = latlong.LatLng(0.0, 0.0);
    destinationLatLong.value = const LatLng(0.0, 0.0);
    destinationTextEditController.value.clear();

    if (Constant.selectedMapType == 'osm') {
      osmMarker.removeWhere((marker) => marker.point == destinationLatLongOsm.value);
    } else {
      markers.removeWhere((marker) => marker.markerId.value == 'Destination');
    }

    clearMapDataIfLocationsRemoved();
    update();
  }


  /// Puts the nearest named place in front of a pickup or destination whose
  /// street has no name in OpenStreetMap ("Kohat, Tehsil Kohat, ..." becomes
  /// "Near KDA PARK, Kohat, ..."). See [NearbyPlaceAddress]. Only applied while
  /// the same point and the same text are still selected.
  Future<void> addNearbyPlace({required bool pickup, required double lat, required double lng, String? placeName}) async {
    final TextEditingController field = pickup ? sourceTextEditController.value : destinationTextEditController.value;
    final String before = field.text;
    final String better = await NearbyPlaceAddress.describe(lat, lng, before, placeName: placeName);
    if (better == before) return;
    final latlong.LatLng now = pickup ? departureLatLongOsm.value : destinationLatLongOsm.value;
    if (now.latitude != lat || now.longitude != lng || field.text != before) return;
    field.text = better;
  }

  Future<void> searchPlaceNameOSM() async {
    final double pickupLat = departureLatLongOsm.value.latitude;
    final double pickupLng = departureLatLongOsm.value.longitude;
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${departureLatLongOsm.value.latitude}&lon=${departureLatLongOsm.value.longitude}&format=json');

    final response = await http.get(url, headers: {'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)'});

    if (response.statusCode == 200) {
      log("response.body :: ${response.body}");
      Map<String, dynamic> data = json.decode(response.body);
      sourceTextEditController.value.text = data['display_name'] ?? '';
      unawaited(addNearbyPlace(pickup: true, lat: pickupLat, lng: pickupLng, placeName: data['name']?.toString() ?? ''));
    }
  }

  Future<void> searchPlaceNameGoogle() async {
    final lat = departureLatLong.value.latitude;
    final lng = departureLatLong.value.longitude;

    final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${Constant.mapAPIKey}');

    // Reverse geocoding for the pickup field. Fails quiet: this runs unawaited
    // from a map callback, the Google key on this project is refused, and the
    // field keeps whatever the customer or the map picker already put in it.
    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            final formattedAddress = results[0]['formatted_address'];
            sourceTextEditController.value.text = formattedAddress;
          }
        } else {
          log("Google API Error: ${data['status']}");
        }
      } else {
        log("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      log('reverse geocode failed, keeping the current address :: $e');
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  Rx<WalletSettingModel> walletSettingModel = WalletSettingModel().obs;
  Rx<CodSettingModel> cashOnDeliverySettingModel = CodSettingModel().obs;
  Rx<PayFastModel> payFastModel = PayFastModel().obs;
  Rx<MercadoPagoModel> mercadoPagoModel = MercadoPagoModel().obs;
  Rx<PayPalModel> payPalModel = PayPalModel().obs;
  Rx<StripeModel> stripeModel = StripeModel().obs;
  Rx<FlutterWaveModel> flutterWaveModel = FlutterWaveModel().obs;
  Rx<PayStackModel> payStackModel = PayStackModel().obs;
  Rx<PaytmModel> paytmModel = PaytmModel().obs;
  Rx<RazorPayModel> razorPayModel = RazorPayModel().obs;

  Rx<MidTrans> midTransModel = MidTrans().obs;
  Rx<OrangeMoney> orangeMoneyModel = OrangeMoney().obs;
  Rx<Xendit> xenditModel = Xendit().obs;

  Future<void> getPaymentSettings() async {
    await FireStoreUtils.getPaymentSettingsData().then((value) {
      stripeModel.value = StripeModel.fromJson(jsonDecode(Preferences.getString(Preferences.stripeSettings)));
      payPalModel.value = PayPalModel.fromJson(jsonDecode(Preferences.getString(Preferences.paypalSettings)));
      payStackModel.value = PayStackModel.fromJson(jsonDecode(Preferences.getString(Preferences.payStack)));
      mercadoPagoModel.value = MercadoPagoModel.fromJson(jsonDecode(Preferences.getString(Preferences.mercadoPago)));
      flutterWaveModel.value = FlutterWaveModel.fromJson(jsonDecode(Preferences.getString(Preferences.flutterWave)));
      paytmModel.value = PaytmModel.fromJson(jsonDecode(Preferences.getString(Preferences.paytmSettings)));
      payFastModel.value = PayFastModel.fromJson(jsonDecode(Preferences.getString(Preferences.payFastSettings)));
      razorPayModel.value = RazorPayModel.fromJson(jsonDecode(Preferences.getString(Preferences.razorpaySettings)));
      midTransModel.value = MidTrans.fromJson(jsonDecode(Preferences.getString(Preferences.midTransSettings)));
      orangeMoneyModel.value = OrangeMoney.fromJson(jsonDecode(Preferences.getString(Preferences.orangeMoneySettings)));
      xenditModel.value = Xendit.fromJson(jsonDecode(Preferences.getString(Preferences.xenditSettings)));
      walletSettingModel.value = WalletSettingModel.fromJson(jsonDecode(Preferences.getString(Preferences.walletSettings)));
      cashOnDeliverySettingModel.value = CodSettingModel.fromJson(jsonDecode(Preferences.getString(Preferences.codSettings)));

      if (walletSettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.wallet.name;
      } else if (cashOnDeliverySettingModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.cod.name;
      } else if (stripeModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.stripe.name;
      } else if (payPalModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.paypal.name;
      } else if (payStackModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payStack.name;
      } else if (mercadoPagoModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.mercadoPago.name;
      } else if (flutterWaveModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.flutterWave.name;
      } else if (payFastModel.value.isEnable == true) {
        selectedPaymentMethod.value = PaymentGateway.payFast.name;
      } else if (razorPayModel.value.isEnabled == true) {
        selectedPaymentMethod.value = PaymentGateway.razorpay.name;
      } else if (midTransModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.midTrans.name;
      } else if (orangeMoneyModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.orangeMoney.name;
      } else if (xenditModel.value.enable == true) {
        selectedPaymentMethod.value = PaymentGateway.xendit.name;
      }
      Stripe.publishableKey = stripeModel.value.clientpublishableKey.toString();
      Stripe.merchantIdentifier = 'JEOM';
      Stripe.instance.applySettings();
      setRef();

      razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
      razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWaller);
      razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    });
  }

  // Strip
  Future<void> stripeMakePayment({required String amount}) async {
    log(double.parse(amount).toStringAsFixed(0));
    try {
      Map<String, dynamic>? paymentIntentData = await createStripeIntent(amount: amount);
      log("stripe Responce====>$paymentIntentData");
      if (paymentIntentData!.containsKey("error")) {
        // Closes the payment UI only if it is still open - see [SafePop].
        SafePop.popUnlessCurrent(_ownRoute);
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentData['client_secret'],
            allowsDelayedPaymentMethods: false,
            googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: true, currencyCode: "USD"),
            customFlow: true,
            style: ThemeMode.system,
            appearance: PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: AppThemeData.primary300)),
            merchantDisplayName: 'GoRide',
          ),
        );
        displayStripePaymentSheet(amount: amount);
      }
    } catch (e, s) {
      log("$e \n$s");
      ShowToastDialog.showToast("exception:$e \n$s");
    }
  }

  Future<void> displayStripePaymentSheet({required String amount}) async {
    try {
      await Stripe.instance.presentPaymentSheet().then((value) {
        ShowToastDialog.showToast("Payment successfully".tr);
        completeOrder();
      });
    } on StripeException catch (e) {
      var lo1 = jsonEncode(e);
      var lo2 = jsonDecode(lo1);
      StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
      ShowToastDialog.showToast(lom.error.message);
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }
  }

  Future createStripeIntent({required String amount}) async {
    try {
      Map<String, dynamic> body = {
        'amount': ((double.parse(amount) * 100).round()).toString(),
        'currency': "USD",
        'payment_method_types[]': 'card',
        "description": "Strip Payment",
        "shipping[name]": userModel.value.fullName(),
        "shipping[address][line1]": "510 Townsend St",
        "shipping[address][postal_code]": "98140",
        "shipping[address][city]": "San Francisco",
        "shipping[address][state]": "CA",
        "shipping[address][country]": "US",
      };
      var stripeSecret = stripeModel.value.stripeSecret;
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {'Authorization': 'Bearer $stripeSecret', 'Content-Type': 'application/x-www-form-urlencoded'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      log(e.toString());
    }
  }

  //mercadoo
  Future<Null> mercadoPagoMakePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final headers = {'Authorization': 'Bearer ${mercadoPagoModel.value.accessToken}', 'Content-Type': 'application/json'};

    final body = jsonEncode({
      "items": [
        {
          "title": "Test",
          "description": "Test Payment",
          "quantity": 1,
          "currency_id": "BRL", // or your preferred currency
          "unit_price": double.parse(amount),
        },
      ],
      "payer": {"email": userModel.value.email},
      "back_urls": {"failure": "${Constant.globalUrl}payment/failure", "pending": "${Constant.globalUrl}payment/pending", "success": "${Constant.globalUrl}payment/success"},
      "auto_return": "approved",
      // Automatically return after payment is approved
    });

    final response = await http.post(Uri.parse("https://api.mercadopago.com/checkout/preferences"), headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['init_point']))!.then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          completeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      print('Error creating preference: ${response.body}');
      return null;
    }
  }

  //Paypal
  void paypalPaymentSheet(String amount, context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (BuildContext context) => UsePaypal(
              sandboxMode: payPalModel.value.isLive == true ? false : true,
              clientId: payPalModel.value.paypalClient ?? '',
              secretKey: payPalModel.value.paypalSecret ?? '',
              returnURL: "com.parkme://paypalpay",
              cancelURL: "com.parkme://paypalpay",
              transactions: [
                {
                  "amount": {
                    "total": amount,
                    "currency": "USD",
                    "details": {"subtotal": amount},
                  },
                },
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (Map params) async {
                completeOrder();
                ShowToastDialog.showToast("Payment Successful!!".tr);
              },
              onError: (error) {
                // Closes the payment UI only if it is still open - see [SafePop].
                SafePop.popUnlessCurrent(_ownRoute);
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
              onCancel: (params) {
                // Closes the payment UI only if it is still open - see [SafePop].
                SafePop.popUnlessCurrent(_ownRoute);
                ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
              },
            ),
      ),
    );
  }

  ///PayStack Payment Method
  Future<void> payStackPayment(String totalAmount) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await PayStackURLGen.payStackURLGen(
      amount: (double.parse(totalAmount) * 100).round().toString(),
      currency: "ZAR",
      secretKey: payStackModel.value.secretKey.toString(),
      userModel: userModel.value,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel payStackModel0 = value;
        ShowToastDialog.closeLoader();
        Get.to(
          PayStackScreen(
            secretKey: payStackModel.value.secretKey.toString(),
            callBackUrl: payStackModel.value.callbackURL.toString(),
            initialURl: payStackModel0.data.authorizationUrl,
            amount: totalAmount,
            reference: payStackModel0.data.reference,
          ),
        )!.then((value) {
          if (value) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            completeOrder();
          } else {
            ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
          }
        });
      } else {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      }
    });
  }

  //flutter wave Payment Method
  Future<Null> flutterWaveInitiatePayment({required BuildContext context, required String amount}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {'Authorization': 'Bearer ${flutterWaveModel.value.secretKey}', 'Content-Type': 'application/json'};

    final body = jsonEncode({
      "tx_ref": _ref,
      "amount": amount,
      "currency": "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      "payment_options": "ussd, card, barter, payattitude",
      "customer": {
        "email": userModel.value.email.toString(),
        "phonenumber": userModel.value.phoneNumber, // Add a real phone number
        "name": userModel.value.fullName(), // Add a real customer name
      },
      "customizations": {"title": "Payment for Services", "description": "Payment for XYZ services"},
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      ShowToastDialog.closeLoader();
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!.then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          completeOrder();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!".tr);
        }
      });
    } else {
      ShowToastDialog.closeLoader();
      print('Payment initialization failed: ${response.body}');
      return null;
    }
  }

  String? _ref;

  void setRef() {
    maths.Random numRef = maths.Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      _ref = "AndroidRef$year$refNumber";
    } else if (Platform.isIOS) {
      _ref = "IOSRef$year$refNumber";
    }
  }

  // payFast
  void payFastPayment({required BuildContext context, required String amount}) {
    ShowToastDialog.showLoader("Please wait".tr);
    PayStackURLGen.getPayHTML(payFastSettingData: payFastModel.value, amount: amount.toString(), userModel: userModel.value).then((String? value) async {
      ShowToastDialog.closeLoader();
      bool isDone = await Get.to(PayFastScreen(htmlData: value!, payFastSettingData: payFastModel.value));
      if (isDone) {
        // Closes the payment UI only if it is still open - see [SafePop].
        SafePop.popUnlessCurrent(_ownRoute);
        ShowToastDialog.showToast("Payment successfully".tr);
        completeOrder();
      } else {
        // Closes the payment UI only if it is still open - see [SafePop].
        SafePop.popUnlessCurrent(_ownRoute);
        ShowToastDialog.showToast("Payment Failed".tr);
      }
    });
  }

  ///Paytm payment function
  Future<void> getPaytmCheckSum(context, {required double amount}) async {
    // final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    // String getChecksum = "${Constant.globalUrl}payments/getpaytmchecksum";
    //
    // final response = await http.post(
    //   Uri.parse(getChecksum),
    //   headers: {},
    //   body: {"mid": paytmModel.value.paytmMID.toString(), "order_id": orderId, "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString()},
    // );
    //
    // final data = jsonDecode(response.body);
    // await verifyCheckSum(checkSum: data["code"], amount: amount, orderId: orderId).then((value) {
    //   initiatePayment(amount: amount, orderId: orderId).then((value) {
    //     String callback = "";
    //     if (paytmModel.value.isSandboxEnabled == true) {
    //       callback = "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    //     } else {
    //       callback = "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    //     }
    //
    //     GetPaymentTxtTokenModel result = value;
    //     startTransaction(context, txnTokenBy: result.body.txnToken, orderId: orderId, amount: amount, callBackURL: callback, isStaging: paytmModel.value.isSandboxEnabled);
    //   });
    // });
  }

  Future<void> startTransaction(context, {required String txnTokenBy, required orderId, required double amount, required callBackURL, required isStaging}) async {
    // try {
    //   var response = AllInOneSdk.startTransaction(
    //     paytmModel.value.paytmMID.toString(),
    //     orderId,
    //     amount.toString(),
    //     txnTokenBy,
    //     callBackURL,
    //     isStaging,
    //     true,
    //     true,
    //   );
    //
    //   response.then((value) {
    //     if (value!["RESPMSG"] == "Txn Success") {
    //       print("txt done!!");
    //       ShowToastDialog.showToast("Payment Successful!!");
    //       completeOrder();
    //     }
    //   }).catchError((onError) {
    //     if (onError is PlatformException) {
    //       Get.back();
    //
    //       ShowToastDialog.showToast(onError.message.toString());
    //     } else {
    //       log("======>>2");
    //       Get.back();
    //       ShowToastDialog.showToast(onError.message.toString());
    //     }
    //   });
    // } catch (err) {
    //   Get.back();
    //   ShowToastDialog.showToast(err.toString());
    // }
  }

  Future verifyCheckSum({required String checkSum, required double amount, required orderId}) async {
    String getChecksum = "${Constant.globalUrl}payments/validatechecksum";
    final response = await http.post(
      Uri.parse(getChecksum),
      headers: {},
      body: {"mid": paytmModel.value.paytmMID.toString(), "order_id": orderId, "key_secret": paytmModel.value.pAYTMMERCHANTKEY.toString(), "checksum_value": checkSum},
    );
    final data = jsonDecode(response.body);
    return data['status'];
  }

  Future<GetPaymentTxtTokenModel> initiatePayment({required double amount, required orderId}) async {
    String initiateURL = "${Constant.globalUrl}payments/initiatepaytmpayment";
    String callback = "";
    if (paytmModel.value.isSandboxEnabled == true) {
      callback = "${callback}https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    } else {
      callback = "${callback}https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    }
    final response = await http.post(
      Uri.parse(initiateURL),
      headers: {},
      body: {
        "mid": paytmModel.value.paytmMID,
        "order_id": orderId,
        "key_secret": paytmModel.value.pAYTMMERCHANTKEY,
        "amount": amount.toString(),
        "currency": "INR",
        "callback_url": callback,
        "custId": FireStoreUtils.getCurrentUid(),
        "issandbox": paytmModel.value.isSandboxEnabled == true ? "1" : "2",
      },
    );
    log(response.body);
    final data = jsonDecode(response.body);
    if (data["body"]["txnToken"] == null || data["body"]["txnToken"].toString().isEmpty) {
      // Closes the payment UI only if it is still open - see [SafePop].
      SafePop.popUnlessCurrent(_ownRoute);
      ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
    }
    return GetPaymentTxtTokenModel.fromJson(data);
  }

  ///RazorPay payment function
  final Razorpay razorPay = Razorpay();

  void openCheckout({required amount, required orderId}) async {
    var options = {
      'key': razorPayModel.value.razorpayKey,
      'amount': amount * 100,
      'name': 'JEOM',
      'order_id': orderId,
      "currency": "INR",
      'description': 'wallet Topup',
      'retry': {'enabled': true, 'max_count': 1},
      'send_sms_hash': true,
      'prefill': {'contact': userModel.value.phoneNumber, 'email': userModel.value.email},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      razorPay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void handlePaymentSuccess(PaymentSuccessResponse response) {
    // Closes the payment UI only if it is still open - see [SafePop].
    SafePop.popUnlessCurrent(_ownRoute);
    ShowToastDialog.showToast("Payment Successful!!".tr);
    completeOrder();
  }

  void handleExternalWaller(ExternalWalletResponse response) {
    // Closes the payment UI only if it is still open - see [SafePop].
    SafePop.popUnlessCurrent(_ownRoute);
    ShowToastDialog.showToast("Payment Processing!! via".tr);
  }

  void handlePaymentError(PaymentFailureResponse response) {
    // Closes the payment UI only if it is still open - see [SafePop].
    SafePop.popUnlessCurrent(_ownRoute);
    ShowToastDialog.showToast("Payment Failed!!".tr);
  }

  bool isCurrentDateInRange(DateTime startDate, DateTime endDate) {
    final currentDate = DateTime.now();
    return currentDate.isAfter(startDate) && currentDate.isBefore(endDate);
  }

  //Midtrans payment
  Future<void> midtransMakePayment({required String amount, required BuildContext context}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await createPaymentLink(amount: amount).then((url) {
      ShowToastDialog.closeLoader();
      if (url != '') {
        Get.to(() => MidtransScreen(initialURl: url))!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            completeOrder();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<String> createPaymentLink({required var amount}) async {
    var ordersId = const Uuid().v1();
    final url = Uri.parse(midTransModel.value.isSandbox! ? 'https://api.sandbox.midtrans.com/v1/payment-links' : 'https://api.midtrans.com/v1/payment-links');

    final response = await http.post(
      url,
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': generateBasicAuthHeader(midTransModel.value.serverKey!)},
      body: jsonEncode({
        'transaction_details': {'order_id': ordersId, 'gross_amount': double.parse(amount.toString()).toInt()},
        'usage_limit': 2,
        "callbacks": {"finish": "https://www.google.com?merchant_order_id=$ordersId"},
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData['payment_url'];
    } else {
      ShowToastDialog.showToast("something went wrong, please contact admin.".tr);
      return '';
    }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }

  //Orangepay payment
  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  Future<void> orangeMakePayment({required String amount, required BuildContext context}) async {
    ShowToastDialog.showLoader("Please wait".tr);
    reset();
    var id = const Uuid().v4();
    var paymentURL = await fetchToken(context: context, orderId: id, amount: amount, currency: 'USD');
    ShowToastDialog.closeLoader();
    if (paymentURL.toString() != '') {
      Get.to(() => OrangeMoneyScreen(initialURl: paymentURL, accessToken: accessToken, amount: amount, orangePay: orangeMoneyModel.value, orderId: orderId, payToken: payToken))!.then((value) {
        if (value == true) {
          ShowToastDialog.showToast("Payment Successful!!".tr);
          completeOrder();
          ();
        }
      });
    } else {
      ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
    }
  }

  Future fetchToken({required String orderId, required String currency, required BuildContext context, required String amount}) async {
    String apiUrl = 'https://api.orange.com/oauth/v3/token';
    Map<String, String> requestBody = {'grant_type': 'client_credentials'};

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{'Authorization': "Basic ${orangeMoneyModel.value.auth!}", 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json'},
      body: requestBody,
    );

    // Handle the response

    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = jsonDecode(response.body);

      accessToken = responseData['access_token'];
      // ignore: use_build_context_synchronously
      return await webpayment(context: context, amountData: amount, currency: currency, orderIdData: orderId);
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  Future webpayment({required String orderIdData, required BuildContext context, required String currency, required String amountData}) async {
    orderId = orderIdData;
    amount = amountData;
    String apiUrl = orangeMoneyModel.value.isSandbox! == true ? 'https://api.orange.com/orange-money-webpay/dev/v1/webpayment' : 'https://api.orange.com/orange-money-webpay/cm/v1/webpayment';
    Map<String, String> requestBody = {
      "merchant_key": orangeMoneyModel.value.merchantKey ?? '',
      "currency": orangeMoneyModel.value.isSandbox == true ? "OUV" : currency,
      "order_id": orderId,
      "amount": amount,
      "reference": 'Y-Note Test',
      "lang": "en",
      "return_url": orangeMoneyModel.value.returnUrl!.toString(),
      "cancel_url": orangeMoneyModel.value.cancelUrl!.toString(),
      "notif_url": orangeMoneyModel.value.notifUrl!.toString(),
    };

    var response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode(requestBody),
    );

    // Handle the response
    if (response.statusCode == 201) {
      Map<String, dynamic> responseData = jsonDecode(response.body);
      if (responseData['message'] == 'OK') {
        payToken = responseData['pay_token'];
        return responseData['payment_url'];
      } else {
        return '';
      }
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
      return '';
    }
  }

  static void reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
  }

  //XenditPayment
  Future<void> xenditPayment(context, amount) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await createXenditInvoice(amount: amount).then((model) {
      ShowToastDialog.closeLoader();
      if (model.id != null) {
        Get.to(() => XenditScreen(initialURl: model.invoiceUrl ?? '', transId: model.id ?? '', apiKey: xenditModel.value.apiKey!.toString()))!.then((value) {
          if (value == true) {
            ShowToastDialog.showToast("Payment Successful!!".tr);
            completeOrder();
            ();
          } else {
            ShowToastDialog.showToast("Payment Unsuccessful!!".tr);
          }
        });
      }
    });
  }

  Future<XenditModel> createXenditInvoice({required var amount}) async {
    const url = 'https://api.xendit.co/v2/invoices';
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': generateBasicAuthHeader(xenditModel.value.apiKey!.toString()),
      // 'Cookie': '__cf_bm=yERkrx3xDITyFGiou0bbKY1bi7xEwovHNwxV1vCNbVc-1724155511-1.0.1.1-jekyYQmPCwY6vIJ524K0V6_CEw6O.dAwOmQnHtwmaXO_MfTrdnmZMka0KZvjukQgXu5B.K_6FJm47SGOPeWviQ',
    };

    final body = jsonEncode({
      'external_id': const Uuid().v1(),
      'amount': amount,
      'payer_email': 'customer@domain.com',
      'description': 'Test - VA Successful invoice payment',
      'currency': 'IDR', //IDR, PHP, THB, VND, MYR
    });

    try {
      final response = await http.post(Uri.parse(url), headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        XenditModel model = XenditModel.fromJson(jsonDecode(response.body));
        return model;
      } else {
        return XenditModel();
      }
    } catch (e) {
      return XenditModel();
    }
  }

  // =====================================================================
  // Bidding / counter-offer
  //
  // None of this runs while the global bidding switch is off.
  // =====================================================================

  /// Subscribes to the offers on [rideId], once.
  void _watchBids(String rideId) {
    if (_watchedBidRideId == rideId) return;
    _watchedBidRideId = rideId;
    _bidsSub?.cancel();
    _bidsSub = BiddingService.bidsStream(rideId).listen((List<RideBidModel> offers) {
      bidOffers.value = offers;
    }, onError: (Object error) {
      log('bid offers listener error: $error');
    });
  }

  String? _watchedBidRideId;

  /// Suggests the metered price as the starting offer, so the customer types
  /// over a sensible number instead of an empty box. Never below the
  /// minimum-fare floor when that rule is on.
  void primeOfferedFare() {
    final double metered = getAmount(selectedVehicleType.value);
    final double floor = minimumAllowedFare;
    final double suggested = metered > floor ? metered : floor;
    offeredFareTextEditController.value.text = BiddingFareRules.roundToCurrency(suggested, BiddingService.currencyDecimals).toStringAsFixed(BiddingService.currencyDecimals);
  }

  /// Validates what the customer typed. Returns null when it is acceptable,
  /// otherwise the message to show.
  String? validateOfferedFare() {
    final double? amount = BiddingFareRules.parseAmount(offeredFareTextEditController.value.text);
    switch (BiddingService.checkFare(amount: amount, distanceInAppUnits: distance.value, vehicleType: selectedVehicleType.value)) {
      case FareCheckResult.ok:
        return null;
      case FareCheckResult.notANumber:
        return 'Enter the fare you want to offer'.tr;
      case FareCheckResult.notPositive:
        return 'The offered fare must be greater than zero'.tr;
      case FareCheckResult.belowMinimum:
        return '${'The minimum fare for this trip is'.tr} ${Constant.amountShow(amount: minimumAllowedFare.toString())}';
    }
  }

  /// Creates the bidding ride and switches the sheet to the offer list.
  Future<void> placeBiddingOrder() async {
    final String? problem = validateOfferedFare();
    if (problem != null) {
      ShowToastDialog.showToast(problem);
      return;
    }
    final double offeredFare = BiddingFareRules.parseAmount(offeredFareTextEditController.value.text)!;

    final CabOrderModel orderModel = buildOrderModel();
    // The agreed price is what the customer offered, and a bidding ride does
    // not also take a coupon: the customer already named their own price.
    orderModel.subTotal = offeredFare.toString();
    orderModel.discount = "0.0";
    orderModel.couponCode = null;
    orderModel.couponId = null;

    ShowToastDialog.showLoader("Please wait".tr);
    final bool placed = await BiddingService.placeBiddingRide(
      orderModel: orderModel,
      offeredFare: offeredFare,
      customer: userModel.value,
    );
    if (!placed) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }

    // Same as the metered booking above: the request exists from here on, so
    // the e-mail is sent without the customer waiting for it, and recording the
    // request on the profile cannot undo it.
    unawaited(FireStoreUtils.sendCabBookEmail(orderModel: orderModel));

    try {
      userModel.value.inProgressOrderID ??= [];
      userModel.value.inProgressOrderID!.add(orderModel.id);
      await FireStoreUtils.updateUser(userModel.value);
    } catch (error) {
      log('placeBiddingOrder: recording the request on the profile failed :: $error');
    }

    ShowToastDialog.closeLoader();

    currentOrder.value = orderModel;
    bottomSheetType.value = 'bidOffers';
  }

  /// Accepts one driver's offer. The winner is decided in a Firestore
  /// transaction, so two taps - here, or here and on another device - can
  /// still only produce one booked driver.
  Future<void> acceptOffer(RideBidModel bid) async {
    final String rideId = currentOrder.value.id ?? '';
    if (rideId.isEmpty || bidActionInFlight.value.isNotEmpty) return;
    bidActionInFlight.value = bid.driverId ?? '';
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final AcceptBidResult result = await BiddingService.acceptOffer(
        rideId: rideId,
        winning: bid,
        liveBids: bidOffers.toList(),
        customer: userModel.value,
      );
      ShowToastDialog.closeLoader();
      switch (result) {
        case AcceptBidResult.ok:
          ShowToastDialog.showToast("Driver booked".tr);
          break;
        case AcceptBidResult.alreadyAwarded:
          ShowToastDialog.showToast("This ride already has a driver".tr);
          break;
        case AcceptBidResult.bidGone:
        case AcceptBidResult.bidNotPending:
          ShowToastDialog.showToast("This offer is no longer available".tr);
          break;
        case AcceptBidResult.bidExpired:
          ShowToastDialog.showToast("This offer has expired".tr);
          break;
        case AcceptBidResult.belowMinimum:
          ShowToastDialog.showToast("${'The minimum fare for this trip is'.tr} ${Constant.amountShow(amount: minimumAllowedFare.toString())}");
          break;
        case AcceptBidResult.rideGone:
        case AcceptBidResult.notOpen:
          ShowToastDialog.showToast("This ride request is no longer open".tr);
          break;
      }
    } finally {
      bidActionInFlight.value = '';
    }
  }

  /// Declines one offer, leaving the request open for the others.
  Future<void> rejectOffer(RideBidModel bid) async {
    final String rideId = currentOrder.value.id ?? '';
    if (rideId.isEmpty || bidActionInFlight.value.isNotEmpty) return;
    bidActionInFlight.value = bid.driverId ?? '';
    try {
      final RejectBidResult result = await BiddingService.rejectOffer(rideId: rideId, bid: bid);
      if (result == RejectBidResult.alreadyAwarded) {
        ShowToastDialog.showToast("This ride already has a driver".tr);
      } else if (result != RejectBidResult.ok) {
        ShowToastDialog.showToast("This offer is no longer available".tr);
      }
    } finally {
      bidActionInFlight.value = '';
    }
  }

  /// Cancels the bidding request and closes every offer on it, so nothing is
  /// left active for a ride that will not happen.
  Future<void> cancelBiddingRequest() async {
    final String rideId = currentOrder.value.id ?? '';
    if (rideId.isEmpty || bidActionInFlight.value.isNotEmpty) return;
    bidActionInFlight.value = rideId;
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final bool done = await BiddingService.cancelRequest(
        rideId: rideId,
        liveBids: bidOffers.toList(),
        ridePatch: <String, dynamic>{'status': Constant.orderRejected},
      );
      ShowToastDialog.closeLoader();
      if (!done) {
        ShowToastDialog.showToast("This ride already has a driver".tr);
        return;
      }
      await _clearAfterBiddingCancel();
      ShowToastDialog.showToast("Ride cancelled successfully".tr);
    } finally {
      bidActionInFlight.value = '';
    }
  }

  /// Sends an expired or unanswered request back out to drivers.
  Future<void> resendBiddingRequest() async {
    final String rideId = currentOrder.value.id ?? '';
    if (rideId.isEmpty) return;
    ShowToastDialog.showLoader("Please wait".tr);
    final bool ok = await BiddingService.resendRequest(rideId: rideId);
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast(ok ? "Request sent to drivers again".tr : "Something went wrong. Please try again.".tr);
  }

  Future<void> _clearAfterBiddingCancel() async {
    await _bidsSub?.cancel();
    _bidsSub = null;
    _watchedBidRideId = null;
    bidOffers.clear();
    biddingState.value = const RideBiddingState();
    bottomSheetType.value = "";
    polyLines.clear();
    markers.clear();
    osmMarker.clear();
    routePoints.clear();
    sourceTextEditController.value.clear();
    destinationTextEditController.value.clear();
    offeredFareTextEditController.value.clear();
    departureLatLong.value = const LatLng(0.0, 0.0);
    destinationLatLong.value = const LatLng(0.0, 0.0);
    departureLatLongOsm.value = latlong.LatLng(0.0, 0.0);
    destinationLatLongOsm.value = latlong.LatLng(0.0, 0.0);
    userModel.value.inProgressOrderID = [];
    await FireStoreUtils.updateUser(userModel.value);
    currentOrder.value = CabOrderModel();
  }
}
