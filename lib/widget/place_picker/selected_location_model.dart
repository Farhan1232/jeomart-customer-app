import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SelectedLocationModel {
  Placemark? address;
  LatLng? latLng;

  SelectedLocationModel({this.address,this.latLng});

  SelectedLocationModel.fromJson(Map<String, dynamic> json) {
    address = json['address'];
    latLng = json['latLng'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['address'] = address;
    data['latLng'] = latLng;
    return data;
  }
}
