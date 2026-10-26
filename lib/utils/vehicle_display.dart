import 'package:get/get.dart';

/// How a vehicle type presents itself on the "Select Your Vehicle Type" sheet.
///
/// The sheet has always shown a name, a distance and a price, which is enough
/// while every vehicle in the list is a car. It stops being enough once the
/// admin adds a motorcycle, an auto rickshaw and a ten-seater to the same
/// section: those differ mainly in how many people they carry, and the sheet
/// was the one place a customer chooses between them while showing nothing
/// about it.
///
/// The seat count is appended to the trip duration rather than given a line of
/// its own, so the row keeps the height it has today.
class VehicleDisplay {
  /// Between the duration and the seat count. A middle dot, with the spaces
  /// that go with it.
  static const String separator = ' · ';

  /// Joins the parts of the second line, skipping whatever is missing.
  ///
  /// Both halves are optional and often are: the duration is empty until a
  /// route has been measured, and a vehicle whose `capacity` is not a plain
  /// count contributes no seats. With neither, the line is empty and reads
  /// exactly as it did before.
  static String subtitle({String? duration, String? seats}) {
    final List<String> parts = <String>[];
    for (final String? part in <String?>[duration, seats]) {
      final String value = (part ?? '').trim();
      if (value.isNotEmpty) parts.add(value);
    }
    return parts.join(separator);
  }

  /// The translated seat count, or null when the vehicle does not state one.
  ///
  /// [seats] is `VehicleType.seats`, which is already null for a capacity the
  /// panel's free-text box holds in some other form.
  static String? seatsLabel(int? seats) {
    if (seats == null) return null;
    if (seats == 1) return 'seat_count_one'.tr;
    return 'seat_count_other'.trParams(<String, String>{'count': '$seats'});
  }
}
