import 'package:cloud_firestore/cloud_firestore.dart';

class RentalPackageModel {
  String? id;
  String? vehicleTypeId;
  String? description;
  String? ordering;
  bool? published;
  String? extraKmFare;
  String? includedHours;
  String? extraMinuteFare;
  String? baseFare;
  Timestamp? createdAt;
  String? name;
  String? includedDistance;

  RentalPackageModel(
      {this.id,
        this.vehicleTypeId,
        this.description,
        this.ordering,
        this.published,
        this.extraKmFare,
        this.includedHours,
        this.extraMinuteFare,
        this.baseFare,
        this.createdAt,
        this.name,
        this.includedDistance});

  RentalPackageModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    vehicleTypeId = json['vehicleTypeId'];
    description = json['description'];
    ordering = json['ordering'];
    published = json['published'];
    extraKmFare = json['extraKmFare'];
    includedHours = json['includedHours'];
    extraMinuteFare = json['extraMinuteFare'];
    baseFare = json['baseFare'];
    createdAt = json['createdAt'];
    name = json['name'];
    includedDistance = json['includedDistance'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['vehicleTypeId'] = vehicleTypeId;
    data['description'] = description;
    data['ordering'] = ordering;
    data['published'] = published;
    data['extraKmFare'] = extraKmFare;
    data['includedHours'] = includedHours;
    data['extraMinuteFare'] = extraMinuteFare;
    data['baseFare'] = baseFare;
    data['createdAt'] = createdAt;
    data['name'] = name;
    data['includedDistance'] = includedDistance;
    return data;
  }
}
