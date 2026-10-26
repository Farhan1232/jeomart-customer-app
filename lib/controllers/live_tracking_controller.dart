import 'package:customer/utils/safe_pop.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:convert';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as location;
import 'package:flutter_map/flutter_map.dart' as flutterMap;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

class LiveTrackingController extends GetxController {
  /// The route this controller's screen was pushed as, captured before
  /// anything can be pushed on top of it. See [SafePop].
  final String _ownRoute = SafePop.currentRoute();

  GoogleMapController? mapController;
  final flutterMap.MapController osmMapController = flutterMap.MapController();

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<UserModel> driverUserModel = UserModel().obs;
  RxBool isLoading = true.obs;

  Rx<location.LatLng> source = location.LatLng(0, 0).obs;
  Rx<location.LatLng> destination = location.LatLng(0, 0).obs;
  Rx<location.LatLng> driverCurrent = location.LatLng(0, 0).obs;

  RxList<location.LatLng> routePoints = <location.LatLng>[].obs;
  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  RxList<flutterMap.Marker> osmMarkers = <flutterMap.Marker>[].obs;

  BitmapDescriptor? pickupIcon;
  BitmapDescriptor? dropoffIcon;
  BitmapDescriptor? driverIcon;

  PolylinePoints polylinePoints = PolylinePoints(apiKey: Constant.mapAPIKey);

  StreamSubscription? orderSub;
  StreamSubscription? driverSub;

  @override
  void onInit() {
    super.onInit();
    addMarkerIcons();
    getArguments();
  }

  @override
  void onClose() {
    orderSub?.cancel();
    driverSub?.cancel();
    super.onClose();
  }

  Future<void> getArguments() async {
    final args = Get.arguments;
    if (args == null) return;

    orderModel.value = args['orderModel'];

    orderSub = FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).doc(orderModel.value.id).snapshots().listen((orderSnap) {
      if (orderSnap.data() == null) return;
      orderModel.value = OrderModel.fromJson(orderSnap.data()!);

      if (orderModel.value.driverID != null) {
        driverSub?.cancel();
        driverSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(orderModel.value.driverID).snapshots().listen((driverSnap) async {
          if (driverSnap.data() == null) return;
          driverUserModel.value = UserModel.fromJson(driverSnap.data()!);
          await updateLiveTracking();
        });
      }

      if (orderModel.value.status == Constant.orderCompleted) {
        // Only if live tracking is still the screen on top - see [SafePop].
        SafePop.popIfCurrent(_ownRoute);
      }
    });

    isLoading.value = false;
  }

  Future<void> updateLiveTracking() async {
    driverCurrent.value = location.LatLng(driverUserModel.value.location?.latitude ?? 0.0, driverUserModel.value.location?.longitude ?? 0.0);

    source.value = location.LatLng(orderModel.value.vendor?.latitude ?? 0.0, orderModel.value.vendor?.longitude ?? 0.0);

    destination.value = location.LatLng(orderModel.value.address?.location?.latitude ?? 0.0, orderModel.value.address?.location?.longitude ?? 0.0);

    if (orderModel.value.status == Constant.orderPlaced || orderModel.value.status == Constant.orderAccepted) {
      await showDriverToRestaurantRoute();
    } else if (orderModel.value.status == Constant.orderShipped || orderModel.value.status == Constant.orderInTransit) {
      await showDriverToCustomerRoute();
    }
  }

  Future<void> showDriverToRestaurantRoute() async {
    clearOldData();
    if (Constant.selectedMapType == 'osm') {
      await fetchRoute(driverCurrent.value, source.value);
      addOsmMarkers(showPickup: true, showDrop: false);
      animateToOSMLocation(driverCurrent.value);
    } else {
      await getPolyline(
        sourceLatitude: driverCurrent.value.latitude,
        sourceLongitude: driverCurrent.value.longitude,
        destinationLatitude: source.value.latitude,
        destinationLongitude: source.value.longitude,
        showPickup: true,
        showDrop: false,
      );
    }
  }

  Future<void> showDriverToCustomerRoute() async {
    clearOldData();
    if (Constant.selectedMapType == 'osm') {
      await fetchRoute(driverCurrent.value, destination.value);
      addOsmMarkers(showPickup: false, showDrop: true);
      animateToOSMLocation(driverCurrent.value);
    } else {
      await getPolyline(
        sourceLatitude: driverCurrent.value.latitude,
        sourceLongitude: driverCurrent.value.longitude,
        destinationLatitude: destination.value.latitude,
        destinationLongitude: destination.value.longitude,
        showPickup: false,
        showDrop: true,
      );
    }
  }

  void clearOldData() {
    markers.clear();
    polyLines.clear();
    routePoints.clear();
  }

  Future<void> fetchRoute(location.LatLng source, location.LatLng destination) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
    );
    // Bounded and guarded: this is the live-tracking screen, so a stalled
    // socket here is a customer watching a map that never finishes drawing
    // while their order is out for delivery. The route line is decoration - the
    // driver marker and the order status come from Firestore listeners and are
    // unaffected by giving up on it.
    try {
      final response = await http.get(url).timeout(Constant.mapRequestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'];
        if (routes is List && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'];
          routePoints.value = coords.map<location.LatLng>((c) => location.LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        }
      }
    } catch (e) {
      log('live tracking: no route line :: $e');
    }
  }

  void animateToOSMLocation(location.LatLng loc) {
    osmMapController.move(loc, 15);
  }

  void addOsmMarkers({bool showPickup = false, bool showDrop = false}) {
    final List<flutterMap.Marker> tempMarkers = [
      // Driver Marker
      flutterMap.Marker(point: driverCurrent.value, width: 40, height: 40, child: Image.asset('assets/images/food_delivery.png')),
    ];

    if (showPickup) {
      tempMarkers.add(flutterMap.Marker(point: source.value, width: 40, height: 40, child: Image.asset('assets/images/pickup.png')));
    }

    if (showDrop) {
      tempMarkers.add(flutterMap.Marker(point: destination.value, width: 40, height: 40, child: Image.asset('assets/images/dropoff.png')));
    }

    osmMarkers.value = tempMarkers;
  }

  Future<void> getPolyline({
    required double sourceLatitude,
    required double sourceLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    bool showPickup = false,
    bool showDrop = false,
  }) async {
    List<LatLng> polylineCoordinates = [];

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(origin: PointLatLng(sourceLatitude, sourceLongitude), destination: PointLatLng(destinationLatitude, destinationLongitude), mode: TravelMode.driving),
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates = result.points.map((e) => LatLng(e.latitude, e.longitude)).toList();
    }

    addGoogleMarkers(showPickup: showPickup, showDrop: showDrop);
    _addPolyLine(polylineCoordinates);
  }

  void addGoogleMarkers({bool showPickup = false, bool showDrop = false}) {
    markers.clear();

    // Always show driver marker
    if (driverUserModel.value.location != null && driverIcon != null) {
      addMarker(
        id: "Driver",
        latitude: driverUserModel.value.location?.latitude ?? 0.0,
        longitude: driverUserModel.value.location?.longitude ?? 0.0,
        descriptor: driverIcon!,
        rotation: (driverUserModel.value.rotation ?? 0).toDouble(),
      );
    }

    if (showPickup && orderModel.value.vendor?.latitude != null && pickupIcon != null) {
      addMarker(id: "Pickup", latitude: orderModel.value.vendor!.latitude ?? 0.0, longitude: orderModel.value.vendor!.longitude ?? 0.0, descriptor: pickupIcon!, rotation: 0.0);
    } else if (showDrop && orderModel.value.address?.location?.latitude != null && dropoffIcon != null) {
      addMarker(
        id: "Drop",
        latitude: orderModel.value.address!.location!.latitude ?? 0.0,
        longitude: orderModel.value.address!.location!.longitude ?? 0.0,
        descriptor: dropoffIcon!,
        rotation: 0.0,
      );
    }
  }

  void addMarker({required String id, required double latitude, required double longitude, required BitmapDescriptor descriptor, required double rotation}) {
    MarkerId markerId = MarkerId(id);
    markers[markerId] = Marker(markerId: markerId, icon: descriptor, position: LatLng(latitude, longitude), rotation: rotation, anchor: const Offset(0.5, 0.5));
  }

  Future<void> addMarkerIcons() async {
    if (Constant.selectedMapType == 'osm') return;

    pickupIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/pickup.png', 100));
    dropoffIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/dropoff.png', 100));
    driverIcon = BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/food_delivery.png', 100));
  }

  Future<void> _addPolyLine(List<LatLng> polylineCoordinates) async {
    if (polylineCoordinates.isEmpty) return;

    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(polylineId: id, color: Colors.blue, width: 5, points: polylineCoordinates);

    polyLines[id] = polyline;
    await updateCameraBounds(polylineCoordinates);
  }

  Future<void> updateCameraBounds(List<LatLng> points) async {
    if (mapController == null || points.isEmpty) return;

    double minLat = points.map((e) => e.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = points.map((e) => e.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = points.map((e) => e.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = points.map((e) => e.longitude).reduce((a, b) => a > b ? a : b);

    LatLngBounds bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));

    await mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }
}
