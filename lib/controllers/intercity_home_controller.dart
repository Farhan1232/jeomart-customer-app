import 'package:customer/utils/safe_pop.dart';
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
import 'package:customer/models/popular_destination.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vehicle_type.dart';
import 'package:customer/utils/vehicle_fare.dart';
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
import 'package:customer/service/ride_contact_service.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/map_start_location.dart';
import 'package:customer/utils/nearby_place_address.dart';
import 'package:customer/utils/preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator/geolocator.dart' as geo;
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

class IntercityHomeController extends GetxController {
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

  /// The in-progress list the profile listener last resolved, and the ride and
  /// driver it is following, so neither listener is rebuilt for nothing - see
  /// [getVehicleType].
  String? _resolvedInProgressKey;
  String? _watchedRideId;
  String? _watchedDriverId;

  @override
  void onClose() {
    _userSub?.cancel();
    _rideSub?.cancel();
    _driverSub?.cancel();
    super.onClose();
  }

  RxList<PopularDestination> popularDestination = <PopularDestination>[].obs;

  late GoogleMapController mapController;
  final flutterMap.MapController mapOsmController = flutterMap.MapController();

  /// Where the map opens.
  ///
  /// Resolved in [initData] **before** `isLoading` goes false, so by the time
  /// the map widget is first built it already has a real coordinate.
  /// `FlutterMap.initialCenter` and `GoogleMap.initialCameraPosition` are read
  /// once and never again, which is why this cannot be left to arrive later:
  /// this screen used to open on `41.4219057, -102.0840772` - a field in
  /// Nebraska - and stay there, because nothing ever told it to move.
  ///
  /// The cab booking screen was given this in Session 20. Intercity was not.
  final Rx<latlong.LatLng> mapStart = const latlong.LatLng(0.0001, 0.0001).obs;

  /// Set once Google's controller exists. `mapController` is `late`, so
  /// touching it before `onMapCreated` throws.
  bool _googleMapReady = false;

  MapStartLocationStore get _mapStore => MapStartLocationStore(
        read: Preferences.getString,
        write: Preferences.setString,
      );

  final Rx<TextEditingController> sourceTextEditController = TextEditingController().obs;
  final Rx<TextEditingController> destinationTextEditController = TextEditingController().obs;

  final Rx<TextEditingController> couponCodeTextEditController = TextEditingController().obs;

  final Rx<Location> currentLocation = Location().obs;

  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxList<flutterMap.Marker> osmMarker = <flutterMap.Marker>[].obs;
  final RxList<latlong.LatLng> routePoints = <latlong.LatLng>[].obs;

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

  RxList<TaxModel> taxList = <TaxModel>[].obs;
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

  @override
  void onInit() {
    super.onInit();
    initData();
  }

  Future<void> initData() async {
    if (Constant.selectedMapType == 'osm') {
      mapOsmController;
    }

    // Everything the **map** needs, and nothing else - see the same change in
    // `CabBookingController.initData`. Neither of these touches the network.
    await _prepareMapStart();
    await setIcons();

    // The map is drawn from here. It used to wait for the popular destinations
    // **and** the vehicle types **and**, inside `getVehicleType`, the payment
    // settings - three Firestore round trips in series before a single map tile
    // was requested. None of them is on the map's critical path; each fills its
    // own strip in when it lands, through the same reactive builder.
    isLoading.value = false;

    await Future.wait(<Future<void>>[
      FireStoreUtils.getPopularDestination().then((value) {
        popularDestination.value = value;
      }),
      getVehicleType(),
    ]);
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

  /// Moves whichever map type is active onto [lat]/[lng].
  ///
  /// This is the half `initialCenter` cannot do: the map is already built by
  /// the time a real fix arrives, so it has to be told to move.
  void centreOnLocation(double lat, double lng, {double zoom = 14}) {
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

    await getPaymentSettings();

    _userSub?.cancel();
    _userSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((userSnapshot) async {
      if (!userSnapshot.exists) return;

      userModel.value = UserModel.fromJson(userSnapshot.data()!);

      if (userModel.value.inProgressOrderID != null && userModel.value.inProgressOrderID!.isNotEmpty) {
        // The same bookings as last time resolve to the same ride as last time.
        // All of this used to run in full on every snapshot of the customer's
        // own document: a `get()` per in-progress booking, then the ride
        // listener cancelled and opened again - so an unrelated profile write
        // threw away the listener that reports "your driver accepted" and
        // waited on round trips to replace it. The cab ride screen has worked
        // this way since Session 31.
        final String inProgressKey = userModel.value.inProgressOrderID!.join(',');
        if (inProgressKey == _resolvedInProgressKey) return;

        String? validRideId;

        for (String id in userModel.value.inProgressOrderID!) {
          final rideDoc = await FireStoreUtils.fireStore.collection(CollectionName.rides).doc(id).get();

          if (rideDoc.exists && (rideDoc.data()?['rideType'] ?? '').toString().toLowerCase() == "intercity") {
            validRideId = userModel.value.inProgressOrderID!.first!;
            break;
          }
        }
        // Recorded only once resolved, so a read that failed is tried again on
        // the next snapshot, as it always was.
        _resolvedInProgressKey = inProgressKey;

        // Already following this ride.
        if (validRideId != null && validRideId == _watchedRideId && _rideSub != null) return;

        _rideSub?.cancel();
        _rideSub = null;
        _watchedRideId = validRideId;
        // Nothing in the list is an intercity ride. The old code listened to
        // `doc(null)` here - a generated id that never exists - which is the
        // same as not listening.
        if (validRideId == null) return;
        final String rideId = validRideId;

        _rideSub = FireStoreUtils.fireStore.collection(CollectionName.rides).doc(rideId).snapshots().listen((rideSnapshot) async {
          if (!rideSnapshot.exists) return;

          final rideData = rideSnapshot.data()!;
          currentOrder.value = CabOrderModel.fromJson(rideData);
          final status = currentOrder.value.status;
          RideContactService.revealWhenBooked(rideId, rideData, userModel.value);

          if (status == Constant.driverAccepted || status == Constant.orderInTransit) {
            final String? driverId = currentOrder.value.driverId;
            if (driverId == null || driverId.isEmpty) {
              // As above: the old `doc(null)` listener never reported anything.
              _driverSub?.cancel();
              _driverSub = null;
              _watchedDriverId = null;
            } else if (driverId != _watchedDriverId || _driverSub == null) {
              // Only for a different driver. It used to be cancelled and opened
              // again on every snapshot of the ride.
              _driverSub?.cancel();
              _watchedDriverId = driverId;
              _driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(driverId).snapshots().listen((event) async {
                if (event.exists && event.data() != null) {
                  UserModel driverModel0 = UserModel.fromJson(event.data()!);
                  driverModel.value = driverModel0;
                  await updateDriverRoute(driverModel0);
                }
              });
            } else if (driverModel.value.id == driverId) {
              // Same driver, so the listener stays open. Reopening it used to
              // redraw the route for the ride's new state from its first
              // snapshot; that redraw is asked for here instead.
              unawaited(updateDriverRoute(driverModel.value));
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
            await FireStoreUtils.updateUser(userModel.value);
            bottomSheetType.value = 'location';
            // Only if the intercity screen is still the screen on top - see
            // [SafePop].
            SafePop.popIfCurrent(_ownRoute);
          }
        }, onError: (Object error) {
          // An error ends a Firestore subscription for good. Forgetting what it
          // followed is what lets the next profile snapshot open a new one.
          log('intercity ride listener for $rideId failed :: $error');
          _watchedRideId = null;
          _resolvedInProgressKey = null;
          _rideSub?.cancel();
          _rideSub = null;
        });
      } else {
        _resolvedInProgressKey = null;
        bottomSheetType.value = 'location';
        if (Constant.currentLocation != null) {
          setDepartureMarker(Constant.currentLocation!.latitude, Constant.currentLocation!.longitude);
          searchPlaceNameOSM();
        }
      }
    });

    final coupons = await FireStoreUtils.getCabCoupon();
    cabCouponList.value = coupons;
  }

  /// The route this screen last fetched for the booked driver - see
  /// [updateDriverRoute].
  String? _driverRouteKey;

  Future<void> updateDriverRoute(UserModel driverModel) async {
    try {
      final order = currentOrder.value;

      final driverLat = driverModel.location!.latitude ?? 0.0;
      final driverLng = driverModel.location!.longitude ?? 0.0;

      if (driverLat == 0.0 || driverLng == 0.0) return;

      // The route is fetched again only when it can have changed: another
      // ride, another status, or the driver about a hundred metres further on -
      // the key the cab ride screen uses. Every snapshot of the driver's
      // document used to cost a routing request, and that document is written
      // on every location update. The markers are still redrawn every time.
      final String routeKey = '${order.id}|${order.status}|${driverLat.toStringAsFixed(3)},${driverLng.toStringAsFixed(3)}';
      final bool fetchRoute = routeKey != _driverRouteKey;
      _driverRouteKey = routeKey;

      // Get pickup and destination
      final pickupLat = order.sourceLocation?.latitude ?? 0.0;
      final pickupLng = order.sourceLocation?.longitude ?? 0.0;
      final destLat = order.destinationLocation?.latitude ?? 0.0;
      final destLng = order.destinationLocation?.longitude ?? 0.0;

      if (Constant.selectedMapType == 'osm') {
        /// For OpenStreetMap
        if (fetchRoute) {
          routePoints.clear();

          if (order.status == Constant.driverAccepted) {
            // DRIVER → PICKUP
            await fetchRouteWithWaypoints([latlong.LatLng(driverLat, driverLng), latlong.LatLng(pickupLat, pickupLng)]);
          } else if (order.status == Constant.orderInTransit) {
            // PICKUP → DESTINATION
            await fetchRouteWithWaypoints([latlong.LatLng(pickupLat, pickupLng), latlong.LatLng(destLat, destLng)]);
          }
          // No route came back: the next snapshot asks again, as it used to.
          if (routePoints.isEmpty) _driverRouteKey = null;
        }
        updateRouteMarkers(driverModel);
      } else {
        /// For Google Maps
        if (fetchRoute) {
          if (order.status == Constant.driverAccepted) {
            await fetchGoogleRouteBetween(LatLng(driverLat, driverLng), LatLng(pickupLat, pickupLng));
          } else if (order.status == Constant.orderInTransit) {
            await fetchGoogleRouteBetween(LatLng(pickupLat, pickupLng), LatLng(destLat, destLng));
          }
          if (polyLines.isEmpty) _driverRouteKey = null;
        }
        updateRouteMarkers(driverModel);
      }
    } catch (e) {
      print("Error in updateDriverRoute: $e");
    }
  }

  BitmapDescriptor? _routeDepartureIcon, _routeDestinationIcon, _routeTaxiIcon;
  String? _routeTaxiIconSource;

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

      // Two bundled images and the section's marker, none of which change
      // between redraws. They were decoded - and the marker downloaded - again
      // on every redraw, which is every update of the driver's position. Kept
      // apart from [departureIcon]/[destinationIcon], which the booking map
      // sets to different pictures, and assigned to them exactly as before.
      _routeDepartureIcon ??= BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/location_black3x.png', 50));
      _routeDestinationIcon ??= BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/location_orange3x.png', 50));
      final String markerIcon = Constant.sectionConstantModel?.markerIcon ?? '';
      if (_routeTaxiIcon == null || _routeTaxiIconSource != markerIcon) {
        final driverBytesRaw = markerIcon.isNotEmpty ? await Constant().getBytesFromUrl(markerIcon, width: 120) : await Constant().getBytesFromAsset('assets/images/ic_cab.png', 50);
        _routeTaxiIcon = BitmapDescriptor.fromBytes(driverBytesRaw);
        _routeTaxiIconSource = markerIcon;
      }

      departureIcon = _routeDepartureIcon;
      destinationIcon = _routeDestinationIcon;
      taxiIcon = _routeTaxiIcon;

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
    orderTaxAmount.value = 0.0;
    platformTaxAmount.value = 0.0;
    subTotal.value = double.parse(currentOrder.value.subTotal.toString());
    discount.value = double.parse(currentOrder.value.discount ?? '0.0');

    for (var taxElement in Constant.orderProductTaxList ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

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
    taxAmount.value = 0.0;
    subTotal.value = getAmount(selectedVehicleType.value);

    for (var taxElement in Constant.orderProductTaxList ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

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
      // The same fix Session 21 made to `CabBookingController.completeOrder()`,
      // which was never applied to the intercity flow - so "Pay Now" on an
      // intercity ride still did it.
      //
      // Cash is settled with the driver, who confirms it on their own screen
      // before the ride can be completed, so there is nothing to charge here
      // and nothing to close. This used to pop **twice**, and `Pay Now` on this
      // screen opens neither a bottom sheet nor a payment page - so both pops
      // landed on real screens and threw the customer out to the service list
      // in the middle of their ride. That is the "everything vanishes" the
      // client reported.
      //
      // The gateway branch below still pops once, because there its payment
      // page is what closes.
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
          note: "Cab Amount debited".tr,
          paymentStatus: "success".tr,
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

  Future<void> placeOrder() async {
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

    orderModel.taxSetting = Constant.orderProductTaxList;
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
    orderModel.rideType = 'intercity';
    orderModel.roundTrip = false;
    orderModel.sectionId = Constant.sectionConstantModel!.id;
    orderModel.createdAt = Timestamp.now();
    orderModel.otpCode = (maths.Random().nextInt(9000) + 1000).toString(); // Generate a 4-digit OTP
    orderModel.status = Constant.orderPlaced;
    orderModel.scheduleDateTime = Timestamp.now();
    log("Order Model : ${orderModel.toJson()}");
    ShowToastDialog.showLoader("Please wait".tr);

    // Only the trip document decides whether the booking happened. Everything
    // after it is bookkeeping, and bookkeeping used to be able to lose the
    // booking outright:
    //
    //  * `inProgressOrderID!` - the list is null on a customer whose profile
    //    has never held a ride, and on one whose profile has not arrived yet.
    //    The bare `!` threw *after* the trip was written and *before* the
    //    loader came down, so the trip existed, the customer was left looking
    //    at a stuck "Please wait" and the screen never moved on to
    //    "waiting for driver". The ride booking screen was given this same
    //    guard in Session 11; this copy never was.
    //  * the confirmation e-mail is an SMTP connection made from the phone.
    //    Awaiting it put a mail server's timeout in the middle of a booking.
    try {
      await RideContactService.placeSystemRide(orderModel);
    } catch (error) {
      ShowToastDialog.closeLoader();
      log('intercity placeOrder: the trip could not be created :: $error');
      ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
      return;
    }

    unawaited(FireStoreUtils.sendCabBookEmail(orderModel: orderModel));

    try {
      userModel.value.inProgressOrderID ??= [];
      userModel.value.inProgressOrderID!.add(orderModel.id);
      await FireStoreUtils.updateUser(userModel.value);
    } catch (error) {
      log('intercity placeOrder: recording the trip on the profile failed :: $error');
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
      markers.add(Marker(markerId: markerId, infoWindow: InfoWindow(title: 'Stop ${String.fromCharCode(index + 65)}'), position: LatLng(lat, lng), icon: stopIcon!));

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
}
