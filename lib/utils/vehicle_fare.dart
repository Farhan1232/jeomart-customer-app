import '../models/vehicle_type.dart';

/// The metered fare for one vehicle type over one distance.
///
/// Cab booking and intercity each carried their own copy of this, character
/// for character, so a vehicle priced correctly on one screen could be priced
/// differently on the other the moment either copy was touched. It is one
/// function now, and it is tested against the shapes the admin panel actually
/// stores rather than against the shape it is supposed to store.
class VehicleFare {
  /// The minimum charge while the trip is inside the vehicle's minimum
  /// distance, its per-km rate beyond that. Unchanged from what both screens
  /// have always computed.
  ///
  /// The result is always a finite amount. It could not be before: the panel
  /// saved an empty charge box as `NaN`, and `NaN` survived every step of this
  /// calculation to be offered to the customer as a price, because a
  /// comparison against `NaN` is false and a product with it is `NaN`. A
  /// vehicle with no usable charge is free rather than unpayable, which is how
  /// a vehicle with no charge configured at all has always behaved.
  static double meteredFare({required VehicleType vehicleType, required double distanceKm}) {
    final num withinKm = vehicleType.minimum_delivery_charges_within_km ?? 0;
    final double amount;
    if (distanceKm <= withinKm) {
      amount = (vehicleType.minimum_delivery_charges ?? 0).toDouble();
    } else {
      amount = (vehicleType.delivery_charges_per_km ?? 0).toDouble() * distanceKm;
    }
    return amount.isFinite ? amount : 0.0;
  }
}
