import 'bidding_settings.dart';

/// Why an offered fare was refused. `ok` is the only value that lets a bid be
/// written.
enum FareCheckResult {
  ok,

  /// The text the user typed is not a number.
  notANumber,

  /// Zero or negative.
  notPositive,

  /// Below `ratePerKm x distance`, while the minimum-fare switch is on.
  belowMinimum,
}

/// The minimum-fare-per-km rule, kept as plain Dart with no Firestore and no
/// Flutter import so both apps share it byte for byte and it can be unit
/// tested directly.
///
/// The rule, exactly as briefed:
///
///     minimumAllowedFare = configuredRatePerKm x rideDistanceKm
///     50 x 10 KM = 500
///
/// and it applies to **both** the customer's initial offer and a driver's
/// counter-offer.
class BiddingFareRules {
  /// Comparison slack, one hundredth of the smallest displayable unit.
  ///
  /// `50 * 10.0` is not always exactly `500` in binary floating point, and an
  /// offer typed as exactly the minimum must not be rejected for being a
  /// fraction of a cent short.
  static double epsilonFor(int currencyDecimals) {
    final int decimals = currencyDecimals.clamp(0, 6);
    double unit = 1;
    for (int i = 0; i < decimals; i++) {
      unit /= 10;
    }
    return unit / 100;
  }

  /// Rounds a fare the way the rest of the app displays money: to the active
  /// currency's decimal places, half away from zero.
  ///
  /// `Constant.amountShow()` renders with `toStringAsFixed(currency.decimal)`,
  /// so a floor that is rounded the same way can never be displayed as a
  /// number the validator then rejects.
  static double roundToCurrency(num amount, int currencyDecimals) {
    final int decimals = currencyDecimals.clamp(0, 6);
    double factor = 1;
    for (int i = 0; i < decimals; i++) {
      factor *= 10;
    }
    final double scaled = amount.toDouble() * factor;
    // `.round()` in Dart is half away from zero, which is what the currency
    // rounding elsewhere in the project does.
    return scaled.round() / factor;
  }

  /// The rate per km that actually applies to a trip.
  ///
  /// The global rate in `settings/biddingSettings` is the default. A vehicle
  /// type may carry its own `biddingMinimumFarePerKm`, and when it does, that
  /// is what applies.
  ///
  /// This exists because one global rate is wrong the moment a platform
  /// carries more than one kind of vehicle: the client reported a PKR 742
  /// minimum on a trip whose metered price was PKR 445, because a motorcycle
  /// was being held to a car's floor. A rate of 0, or a missing one, means the
  /// vehicle has no rate of its own and the global one stands - so nothing
  /// changes for a platform that never sets one.
  static num rateFor({required BiddingSettings settings, num? vehicleRatePerKm}) {
    final num? perVehicle = vehicleRatePerKm;
    if (perVehicle != null && perVehicle > 0) return perVehicle;
    return settings.minimumFarePerKm;
  }

  /// `applicableRatePerKm x rideDistanceKm`, rounded for display.
  ///
  /// Returns 0 when the floor does not apply, which callers read as "no
  /// minimum": there is then no lower bound beyond the fare being positive.
  ///
  /// [vehicleRatePerKm] is the selected vehicle type's own rate, when it has
  /// one.
  ///
  /// The floor is always **recomputed** from [settings]: the switches decide
  /// whether there is a floor at all, and the vehicle only decides which
  /// configured rate applies. Nothing here trusts a number stored on the
  /// request, so a request that claims no floor is still held to one.
  static double minimumAllowedFare({
    required BiddingSettings settings,
    required double distanceKm,
    int currencyDecimals = 2,
    num? vehicleRatePerKm,
  }) {
    if (!distanceKm.isFinite || distanceKm <= 0) return 0;
    if (!settings.enabled || !settings.minimumFarePerKmEnabled) return 0;
    final num rate = rateFor(settings: settings, vehicleRatePerKm: vehicleRatePerKm);
    if (rate <= 0) return 0;
    return roundToCurrency(rate * distanceKm, currencyDecimals);
  }

  /// Validates one offered fare - the customer's initial bid or a driver's
  /// counter-offer, the rule is the same for both.
  static FareCheckResult check({
    required double? amount,
    required BiddingSettings settings,
    required double distanceKm,
    int currencyDecimals = 2,
    num? vehicleRatePerKm,
  }) {
    if (amount == null || !amount.isFinite) return FareCheckResult.notANumber;
    if (amount <= 0) return FareCheckResult.notPositive;

    final double minimum = minimumAllowedFare(
      settings: settings,
      distanceKm: distanceKm,
      currencyDecimals: currencyDecimals,
      vehicleRatePerKm: vehicleRatePerKm,
    );
    if (minimum > 0 && amount < minimum - epsilonFor(currencyDecimals)) {
      return FareCheckResult.belowMinimum;
    }
    return FareCheckResult.ok;
  }

  /// Kilometres in one mile. The apps express a trip in whichever unit
  /// `settings/DriverNearBy.distanceType` selects, but the admin setting is a
  /// rate **per kilometre**, so a miles deployment has to be converted before
  /// the rule is applied. Without this a 10-mile trip would be charged the
  /// floor for 10 km instead of 16.09 km.
  static const double kmPerMile = 1.60934;

  /// Converts a trip length expressed in the app's configured unit into
  /// kilometres. Anything that is not "miles" is already kilometres, which
  /// matches how `Constant.distanceType` is read everywhere else (default
  /// "km", admin writes "Km" or "Miles").
  static double toKilometres(double distance, String? distanceType) {
    if (!distance.isFinite || distance <= 0) return 0;
    return (distanceType ?? '').trim().toLowerCase() == 'miles' ? distance * kmPerMile : distance;
  }

  /// Parses what the user typed. Accepts the grouping and decimal characters
  /// a phone keypad produces; rejects anything else rather than guessing.
  static double? parseAmount(String? text) {
    if (text == null) return null;
    final String cleaned = text.trim().replaceAll(',', '.').replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
