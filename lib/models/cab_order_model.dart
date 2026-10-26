import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/tax_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vehicle_type.dart';

class CabOrderModel {
  String? status;
  List<dynamic>? rejectedByDrivers;
  String? couponId;
  Timestamp? scheduleDateTime;
  String? duration;
  bool? roundTrip;
  bool? paymentStatus;
  String? discount;
  String? destinationLocationName;
  String? authorID;
  Timestamp? createdAt;
  DestinationLocation? destinationLocation;
  String? adminCommissionType;
  String? sourceLocationName;
  String? rideType;
  Timestamp? triggerDelevery;
  String? id;
  String? adminCommission;
  String? couponCode;
  Timestamp? scheduleReturnDateTime;
  String? sectionId;
  String? tipAmount;
  String? distance;
  String? vehicleId;
  String? paymentMethod;
  VehicleType? vehicleType;
  String? otpCode;
  DestinationLocation? sourceLocation;
  UserModel? author;
  UserModel? driver;
  String? driverId;
  String? subTotal;
  String? platformFee;
  List<TaxModel>? taxSetting;
  List<TaxModel>? platformTax;

  CabOrderModel({
    this.status,
    this.rejectedByDrivers,
    this.scheduleDateTime,
    this.duration,
    this.roundTrip,
    this.paymentStatus,
    this.discount,
    this.destinationLocationName,
    this.authorID,
    this.createdAt,
    this.destinationLocation,
    this.adminCommissionType,
    this.sourceLocationName,
    this.rideType,
    this.triggerDelevery,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.couponId,
    this.scheduleReturnDateTime,
    this.sectionId,
    this.tipAmount,
    this.distance,
    this.vehicleId,
    this.paymentMethod,
    this.vehicleType,
    this.otpCode,
    this.sourceLocation,
    this.author,
    this.subTotal,
    this.driver,
    this.driverId,
    this.platformFee,
    this.taxSetting,
    this.platformTax,
  });

  CabOrderModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    couponId = json['couponId'];
    scheduleDateTime = json['scheduleDateTime'];
    duration = json['duration'];
    roundTrip = json['roundTrip'];
    paymentStatus = json['paymentStatus'];
    discount = json['discount'] == null ? "0.0" : json['discount'].toString();
    destinationLocationName = json['destinationLocationName'];
    authorID = json['authorID'];
    createdAt = json['createdAt'];
    destinationLocation = json['destinationLocation'] != null ? DestinationLocation.fromJson(json['destinationLocation']) : null;
    adminCommissionType = json['adminCommissionType'];
    sourceLocationName = json['sourceLocationName'];
    rideType = json['rideType'];
    triggerDelevery = json['trigger_delevery'];
    id = json['id'];
    adminCommission = json['adminCommission'];
    couponCode = json['couponCode'];
    scheduleReturnDateTime = json['scheduleReturnDateTime'];
    sectionId = json['sectionId'];
    tipAmount = json['tip_amount'];
    distance = json['distance'];
    vehicleId = json['vehicleId'];
    paymentMethod = json['paymentMethod'];
    vehicleType = json['vehicleType'] != null ? VehicleType.fromJson(json['vehicleType']) : null;
    otpCode = json['otpCode'];
    sourceLocation = json['sourceLocation'] != null ? DestinationLocation.fromJson(json['sourceLocation']) : null;
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    subTotal = json['subTotal'];
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    driverId = json['driverId'];
    platformFee = json['platformFee'];
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    if (json['platformTax'] != null) {
      platformTax = <TaxModel>[];
      json['platformTax'].forEach((v) {
        platformTax!.add(TaxModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    // if (rejectedByDrivers != null) {
    //   data['rejectedByDrivers'] = rejectedByDrivers!.map((v) => v.toJson()).toList();
    // }
    if (rejectedByDrivers != null) {
      data['rejectedByDrivers'] = rejectedByDrivers;
    }
    data['couponId'] = couponId;
    data['scheduleDateTime'] = scheduleDateTime;
    data['duration'] = duration;
    data['roundTrip'] = roundTrip;
    data['paymentStatus'] = paymentStatus;
    data['discount'] = discount;
    data['destinationLocationName'] = destinationLocationName;
    data['authorID'] = authorID;
    data['createdAt'] = createdAt;
    if (destinationLocation != null) {
      data['destinationLocation'] = destinationLocation!.toJson();
    }
    data['adminCommissionType'] = adminCommissionType;
    data['sourceLocationName'] = sourceLocationName;
    data['rideType'] = rideType;
    data['trigger_delevery'] = triggerDelevery!;
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['scheduleReturnDateTime'] = scheduleReturnDateTime;
    data['sectionId'] = sectionId;
    data['tip_amount'] = tipAmount;
    data['distance'] = distance;
    data['vehicleId'] = vehicleId;
    data['paymentMethod'] = paymentMethod;
    data['driverId'] = driverId;
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }

    if (vehicleType != null) {
      data['vehicleType'] = vehicleType!.toJson();
    }
    data['otpCode'] = otpCode;
    if (sourceLocation != null) {
      data['sourceLocation'] = sourceLocation!.toJson();
    }
    if (author != null) {
      data['author'] = author!.toJson();
    }
    data['subTotal'] = subTotal;
    data['platformFee'] = platformFee;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    if (platformTax != null) {
      data['platformTax'] = platformTax!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class DestinationLocation {
  double? longitude;
  double? latitude;

  DestinationLocation({this.longitude, this.latitude});

  DestinationLocation.fromJson(Map<String, dynamic> json) {
    longitude = json['longitude'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['longitude'] = longitude;
    data['latitude'] = latitude;
    return data;
  }
}
