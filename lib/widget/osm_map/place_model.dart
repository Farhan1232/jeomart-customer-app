import 'package:latlong2/latlong.dart';

class PlaceModel {
  final LatLng coordinates;
  final String address;

  PlaceModel({required this.coordinates, required this.address});

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(coordinates: LatLng(json['lat'], json['lng']), address: json['address']);
  }

  Map<String, dynamic> toJson() {
    return {'lat': coordinates.latitude, 'lng': coordinates.longitude, 'address': address};
  }

  @override
  String toString() {
    return 'Place(lat: ${coordinates.latitude}, lng: ${coordinates.longitude}, address: $address)';
  }
}
