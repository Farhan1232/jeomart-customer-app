import 'package:customer/models/user_model.dart';

/// A person's mobile number as the other side of an order sees it.
///
/// Orders carry the number and the country code in separate fields, and a
/// driver's number is usually already stored with its code (`+92…`), so a
/// number that starts with `+` is shown as it is. Nothing is returned when
/// there is no number - the caller hides the line.
String contactPhoneText(UserModel? person) {
  final String number = (person?.phoneNumber ?? '').trim();
  if (number.isEmpty) return '';
  final String code = (person?.countryCode ?? '').trim();
  if (code.isEmpty || number.startsWith('+')) return number;
  return '$code $number';
}
