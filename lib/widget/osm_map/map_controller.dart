import 'dart:convert';
import 'package:customer/widget/osm_map/place_model.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../constant/constant.dart';
import '../../utils/utils.dart';
import 'package:latlong2/latlong.dart';

class OSMMapController extends GetxController {
  final mapController = MapController();
  // Store only one picked place instead of multiple
  var pickedPlace = Rxn<PlaceModel>(); // Use Rxn to hold a nullable value
  var searchResults = [].obs;

  Future<void> searchPlace(String query) async {
    if (query.length < 3) {
      searchResults.clear();
      return;
    }

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=10');

    final response = await http.get(url, headers: {
      'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      searchResults.value = data;
    }
  }

  void selectSearchResult(Map<String, dynamic> place) {
    final lat = double.parse(place['lat']);
    final lon = double.parse(place['lon']);
    final address = place['display_name'];

    // Store only the selected place
    pickedPlace.value = PlaceModel(
      coordinates: LatLng(lat, lon),
      address: address,
    );
    searchResults.clear();
  }

  void addLatLngOnly(LatLng coords) async {
    final address = await _getAddressFromLatLng(coords);
    pickedPlace.value = PlaceModel(coordinates: coords, address: address);
  }

  Future<String> _getAddressFromLatLng(LatLng coords) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${coords.latitude}&lon=${coords.longitude}&format=json');

    final response = await http.get(url, headers: {
      'User-Agent': 'FlutterMapApp/1.0 (menil.siddhiinfosoft@gmail.com)',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['display_name'] ?? 'Unknown location';
    } else {
      return 'Unknown location';
    }
  }

  void clearAll() {
    pickedPlace.value = null; // Clear the selected place
  }

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    getCurrentLocation();
  }

  /// Where the picker opens before a GPS fix arrives: the position this
  /// session already holds, else the customer's selected address, else the
  /// app's guest default. It used to open on the middle of India.
  LatLng get startCenter {
    final current = Constant.currentLocation;
    if (_usable(current?.latitude, current?.longitude)) return LatLng(current!.latitude, current.longitude);
    final selected = Constant.selectedLocation.location;
    if (_usable(selected?.latitude, selected?.longitude)) return LatLng(selected!.latitude!, selected.longitude!);
    final guest = Constant.defaultGuestLocation.location;
    if (_usable(guest?.latitude, guest?.longitude)) return LatLng(guest!.latitude!, guest.longitude!);
    return const LatLng(33.5869, 71.4414);
  }

  static bool _usable(double? lat, double? lng) =>
      lat != null && lng != null && lat.isFinite && lng.isFinite && !(lat == 0 && lng == 0);

  bool _mapReady = false;

  /// The GPS fix, kept until the map is ready to be moved onto it.
  LatLng? _lastFix;

  /// Called by the map once it is drawn. A fix that arrived before then could
  /// not move it, so it is applied here.
  void onMapReady() {
    _mapReady = true;
    final LatLng? target = pickedPlace.value?.coordinates ?? _lastFix;
    if (target != null) _moveTo(target);
  }

  void _moveTo(LatLng latlng) {
    if (!_mapReady) return;
    try {
      mapController.move(latlng, mapController.camera.zoom);
    } catch (_) {
      // The map went away under us; nothing to move.
    }
  }

  Future<void> getCurrentLocation() async {
    Position? location;
    try {
      location = await Utils.getCurrentLocation();
    } catch (_) {
      location = null;
    }
    // No fix (no permission, GPS off, timed out): stay where the map opened
    // rather than dropping a pin at 0,0 in the ocean.
    if (location == null || !_usable(location.latitude, location.longitude)) return;
    final LatLng latlng = LatLng(location.latitude, location.longitude);
    _lastFix = latlng;
    addLatLngOnly(latlng);
    _moveTo(latlng);
  }
}
