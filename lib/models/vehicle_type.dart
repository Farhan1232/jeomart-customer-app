import 'package:customer/utils/city_filter.dart';

class VehicleType {
  String? shortDescription;
  String? vehicleIcon;
  String? name;
  String? description;
  String? id;
  bool? isActive;
  String? capacity;
  String? supportedVehicle;
  num? delivery_charges_per_km;
  num? minimum_delivery_charges;
  num? minimum_delivery_charges_within_km;

  /// This vehicle type's own minimum bidding fare per km.
  ///
  /// Optional. `null` or `0` means the vehicle has no rate of its own and the
  /// global `settings/biddingSettings.minimumFarePerKm` applies, which is
  /// exactly how every vehicle behaved before this field existed. A motorcycle
  /// gets a lower floor than a car by being given one here.
  num? biddingMinimumFarePerKm;

  /// Cities this vehicle type is offered in (admin panel); null/empty = all. Read only.
  List<String>? zoneIds;

  VehicleType(
      {this.shortDescription,
      this.vehicleIcon,
      this.name,
      this.description,
      this.id,
      this.isActive,
      this.capacity,
      this.delivery_charges_per_km,
      this.minimum_delivery_charges,
      this.minimum_delivery_charges_within_km,
      this.biddingMinimumFarePerKm,
      this.supportedVehicle});

  /// Reads one `vehicle_type` document.
  ///
  /// Every field goes through a coercion below rather than being assigned
  /// straight across. The reason is that this collection is filled in by hand
  /// from the admin panel, and a document the admin considers saved can hold a
  /// shape this class used to reject: a `capacity` saved as a number rather
  /// than a string threw on assignment, and the throw was swallowed by the
  /// `try` in `getVehicleType()`, so the only symptom was the new vehicle
  /// never appearing in the app at all. Nothing here can throw now, so a
  /// vehicle the admin added is always offered.
  VehicleType.fromJson(Map<String, dynamic> json) {
    shortDescription = _text(json['short_description']);
    vehicleIcon = _text(json['vehicle_icon']);
    name = _text(json['name']);
    description = _text(json['description']);
    id = _text(json['id']);
    isActive = _flag(json['isActive']);
    capacity = _text(json['capacity']);
    delivery_charges_per_km = _money(json['delivery_charges_per_km']);
    minimum_delivery_charges = _money(json['minimum_delivery_charges']);
    minimum_delivery_charges_within_km = _money(json['minimum_delivery_charges_within_km']);
    biddingMinimumFarePerKm = _rate(json['biddingMinimumFarePerKm']);
    supportedVehicle = _text(json['supported_vehicle']);
    zoneIds = CityFilter.parseZoneIds(json['zoneIds']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['short_description'] = shortDescription;
    data['vehicle_icon'] = vehicleIcon;
    data['name'] = name;
    data['description'] = description;
    data['id'] = id;
    data['isActive'] = isActive;
    data['capacity'] = capacity;
    data['supported_vehicle'] = supportedVehicle;
    data['delivery_charges_per_km'] = delivery_charges_per_km;
    data['minimum_delivery_charges'] = minimum_delivery_charges;
    data['minimum_delivery_charges_within_km'] = minimum_delivery_charges_within_km;
    // Only written when it has been set, so an app round-trip can never add a
    // zero rate to a vehicle the admin never configured.
    if (biddingMinimumFarePerKm != null) data['biddingMinimumFarePerKm'] = biddingMinimumFarePerKm;
    return data;
  }

  /// How many people this vehicle seats, when the panel's free-text `capacity`
  /// box holds a plain count.
  ///
  /// It is free text, so the live data holds `"3"`, `"10"` and one `"50km"`
  /// that was typed into the wrong box. Anything that is not a positive whole
  /// number is `null` and the caller shows nothing, which is better than
  /// showing a range in place of a seat count.
  int? get seats {
    final String? raw = capacity?.trim();
    if (raw == null || raw.isEmpty) return null;
    final int? parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// A fare field, normalised to a finite number.
  ///
  /// The panel saves these three with `parseInt()`, and `parseInt('')` is
  /// `NaN` - so a vehicle saved with a charge box left empty stored a real
  /// `NaN` in Firestore. `NaN` then propagated all the way to the customer,
  /// where the price read `NaN` and the button offered to charge it, because
  /// every comparison against `NaN` is false and every product with it is
  /// `NaN`. A missing or unusable charge is 0 here, which is how a vehicle
  /// with nothing configured has always behaved.
  static num _money(Object? raw) {
    final num? value = _number(raw);
    if (value == null || !value.isFinite) return 0;
    return value;
  }

  /// The panel writes this as a number; older hand-edited documents in this
  /// project store numbers as strings, so both are accepted - the same
  /// defensive read `BiddingSettings` uses. A non-finite rate is no rate.
  static num? _rate(Object? raw) {
    final num? value = _number(raw);
    if (value == null || !value.isFinite) return null;
    return value;
  }

  static num? _number(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.trim());
    return null;
  }

  /// A text field as the panel might have stored it, never as a type error.
  static String? _text(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    return raw.toString();
  }

  static bool? _flag(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final String value = raw.trim().toLowerCase();
      if (value == 'true' || value == '1') return true;
      if (value == 'false' || value == '0') return false;
    }
    return null;
  }
}
