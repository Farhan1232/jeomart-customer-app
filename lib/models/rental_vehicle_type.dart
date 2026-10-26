import 'package:customer/utils/city_filter.dart';

class RentalVehicleType {
  String? rentalVehicleIcon;
  String? shortDescription;
  String? name;
  String? description;
  String? id;
  bool? isActive;
  String? supportedVehicle;
  String? capacity;

  /// Cities this vehicle type is offered in (admin panel); null/empty = all. Read only.
  List<String>? zoneIds;

  RentalVehicleType({this.rentalVehicleIcon, this.shortDescription, this.name, this.description, this.id, this.isActive, this.supportedVehicle, this.capacity});

  RentalVehicleType.fromJson(Map<String, dynamic> json) {
    rentalVehicleIcon = json['rental_vehicle_icon'];
    shortDescription = json['short_description'];
    name = json['name'];
    description = json['description'];
    id = json['id'];
    isActive = json['isActive'];
    supportedVehicle = json['supported_vehicle'];
    capacity = json['capacity'];
    zoneIds = CityFilter.parseZoneIds(json['zoneIds']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['rental_vehicle_icon'] = rentalVehicleIcon;
    data['short_description'] = shortDescription;
    data['name'] = name;
    data['description'] = description;
    data['id'] = id;
    data['isActive'] = isActive;
    data['supported_vehicle'] = supportedVehicle;
    data['capacity'] = capacity;
    return data;
  }
}
