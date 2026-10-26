import 'dart:async';
import 'dart:developer';
import 'dart:convert';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/rating_model.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as osm;
import '../models/cab_order_model.dart';
import '../models/user_model.dart';
import '../service/fire_store_utils.dart';
import '../themes/app_them_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CabOrderDetailsController extends GetxController {
  Rx<CabOrderModel> cabOrder = CabOrderModel().obs;

  RxBool isLoading = false.obs;

  // Google Maps Data
  RxSet<gmap.Marker> googleMarkers = <gmap.Marker>{}.obs;
  RxSet<gmap.Polyline> googlePolylines = <gmap.Polyline>{}.obs;

  // OSM Data
  RxList<osm.LatLng> osmPolyline = <osm.LatLng>[].obs;

  final String googleApiKey = Constant.mapAPIKey;

  final Rx<UserModel> driverUser = UserModel().obs;
  Rx<RatingModel> ratingModel = RatingModel().obs;

  /// Follows the ride this screen was opened on.
  ///
  /// The screen used to draw the copy of the ride it was handed and never look
  /// again, so a booking opened from the list froze at whatever status it had
  /// when it was tapped: the driver accepting, starting or finishing the ride
  /// showed here only if the customer backed out and opened it a second time.
  /// One document, cancelled with the screen.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null) {
      cabOrder.value = args['cabOrderModel'] as CabOrderModel;
      calculateTotalAmount();
      _setMarkers();
      _getGoogleRoute();
      _getOsmRoute();
      _watchOrder();
    }
    fetchDriverDetails();
  }

  @override
  void onClose() {
    _orderSub?.cancel();
    super.onClose();
  }

  void _watchOrder() {
    final String id = cabOrder.value.id ?? '';
    if (id.isEmpty) return;
    _orderSub = FireStoreUtils.fireStore.collection(CollectionName.rides).doc(id).snapshots().listen((snapshot) {
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) return;
      final String? previousDriverId = cabOrder.value.driverId;
      cabOrder.value = CabOrderModel.fromJson(data);
      calculateTotalAmount();
      // The driver card is only re-read when the ride has actually found a
      // different driver - every other snapshot is a status change.
      if (cabOrder.value.driverId != previousDriverId) {
        fetchDriverDetails();
      }
    }, onError: (Object error) => log('cab order details listener error: $error'));
  }

  RxDouble subTotal = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble orderTaxAmount = 0.0.obs;
  RxDouble platformTaxAmount = 0.0.obs;

  String formatDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat("dd MMM yyyy, hh:mm a").format(dateTime);
  }

  Future<void> fetchDriverDetails() async {
    if (cabOrder.value.driverId != null) {
      // The driver's profile and the ride's review are independent reads that
      // were awaited one after the other. Both are started together and still
      // applied in the same order.
      final driverReq = FireStoreUtils.getUserProfile(cabOrder.value.driverId ?? '');
      final reviewReq = FireStoreUtils.getReviewsbyID(cabOrder.value.id.toString());
      unawaited(reviewReq.then<void>((_) {}, onError: (Object _) {}));

      await driverReq.then((value) {
        if (value != null) {
          driverUser.value = value;
        }
      });

      await reviewReq.then((value) {
        if (value != null) {
          ratingModel.value = value;
        }
      });
    }
  }

  void calculateTotalAmount() {
    taxAmount = 0.0.obs;
    discount = 0.0.obs;
    orderTaxAmount.value = 0.0;
    platformTaxAmount.value = 0.0;

    subTotal.value = double.parse(cabOrder.value.subTotal.toString());
    discount.value = double.parse(cabOrder.value.discount ?? '0.0');

    for (var taxElement in cabOrder.value.taxSetting ?? []) {
      orderTaxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: taxElement);
    }

    /// ---------------- PLATFORM TAX ----------------
    if (double.parse(cabOrder.value.platformFee ?? '0.0') > 0.0) {
      for (var taxElement in cabOrder.value.platformTax ?? []) {
        platformTaxAmount.value += Constant.calculateTax(amount: cabOrder.value.platformFee ?? '0.0', taxModel: taxElement);
      }
    }
    taxAmount.value = orderTaxAmount.value + platformTaxAmount.value;

    totalAmount.value = (subTotal.value - discount.value) + double.parse(cabOrder.value.platformFee ?? '0.0') + taxAmount.value;

    update();
  }

  void _setMarkers() {
    final sourceLat = cabOrder.value.sourceLocation!.latitude;
    final sourceLng = cabOrder.value.sourceLocation!.longitude;
    final destLat = cabOrder.value.destinationLocation!.latitude;
    final destLng = cabOrder.value.destinationLocation!.longitude;

    // ignore: invalid_use_of_protected_member
    googleMarkers.value = {
      gmap.Marker(markerId: const gmap.MarkerId('source'), position: gmap.LatLng(sourceLat!, sourceLng!), icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen)),
      gmap.Marker(markerId: const gmap.MarkerId('destination'), position: gmap.LatLng(destLat!, destLng!), icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueRed)),
    };
  }

  ///Google Directions API
  Future<void> _getGoogleRoute() async {
    final src = cabOrder.value.sourceLocation;
    final dest = cabOrder.value.destinationLocation;

    final url = "https://maps.googleapis.com/maps/api/directions/json?origin=${src!.latitude},${src.longitude}&destination=${dest!.latitude},${dest.longitude}&key=$googleApiKey";

    // Fails quiet on purpose. This runs unawaited from `onInit`, so anything
    // it throws lands nowhere - and the Google key on this project is refused
    // (billing is off), so it throws on every ride. The route line is
    // decoration: without it the fare, the addresses and the markers are
    // unaffected.
    try {
      final response = await http.get(Uri.parse(url)).timeout(Constant.mapRequestTimeout);
      final data = jsonDecode(response.body);

      if (data["routes"] != null && data["routes"].isNotEmpty) {
        final points = data["routes"][0]["overview_polyline"]["points"];
        final polylinePoints = PolylinePoints.decodePolyline(points);

        final polylineCoords = polylinePoints.map((p) => gmap.LatLng(p.latitude, p.longitude)).toList();

        // ignore: invalid_use_of_protected_member
        googlePolylines.value = {gmap.Polyline(polylineId: const gmap.PolylineId("google_route"), color: AppThemeData.onDemandDark100, width: 5, points: polylineCoords)};
      }
    } catch (e) {
      log('cab order details: no Google route line :: $e');
    }
  }

  /// OSM Route (OSRM API)
  Future<void> _getOsmRoute() async {
    final src = cabOrder.value.sourceLocation;
    final dest = cabOrder.value.destinationLocation;

    final url = "http://router.project-osrm.org/route/v1/driving/${src!.longitude},${src.latitude};${dest!.longitude},${dest.latitude}?overview=full&geometries=geojson";

    // Fails quiet, for the same reason as the Google route above.
    try {
      final response = await http.get(Uri.parse(url)).timeout(Constant.mapRequestTimeout);
      final data = jsonDecode(response.body);

      if (data["routes"] != null && data["routes"].isNotEmpty) {
        final coords = data["routes"][0]["geometry"]["coordinates"] as List<dynamic>;

        osmPolyline.value = coords.map((c) => osm.LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      }
    } catch (e) {
      log('cab order details: no OSM route line :: $e');
    }
  }
}
