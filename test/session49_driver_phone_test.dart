import 'dart:io';

import 'package:customer/models/user_model.dart';
import 'package:customer/utils/contact_phone.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 49 - once a driver is on the order, the customer sees the driver's
/// mobile number under the driver's name.
void main() {
  String read(String path) => File(path).readAsStringSync();

  String code(String source) => source.split('\n').where((String line) => !line.trimLeft().startsWith('//')).join('\n');

  group('the number shown', () {
    test('a driver number already carrying its code is shown as it is', () {
      expect(contactPhoneText(UserModel(phoneNumber: '+923001234567')), '+923001234567');
    });

    test('a number stored apart from its code is shown together with it', () {
      expect(contactPhoneText(UserModel(countryCode: '+92', phoneNumber: '3001234567')), '+92 3001234567');
    });

    test('no code - the number alone', () {
      expect(contactPhoneText(UserModel(phoneNumber: '3001234567')), '3001234567');
      expect(contactPhoneText(UserModel(countryCode: ' ', phoneNumber: ' 3001234567 ')), '3001234567');
    });

    test('no number - nothing, so the line is hidden', () {
      expect(contactPhoneText(UserModel(countryCode: '+92', phoneNumber: '')), '');
      expect(contactPhoneText(UserModel(countryCode: '+92')), '');
      expect(contactPhoneText(null), '');
    });
  });

  group('where it is shown', () {
    final String screen = code(read('lib/screen_ui/multi_vendor_service/order_list_screen/order_details_screen.dart'));

    test('under the driver\'s name, above the email, and only there', () {
      expect('contactPhoneText('.allMatches(screen).length, 2, reason: 'one visibility check and one Text, nothing more');

      final int name = screen.indexOf('controller.orderModel.value.driver!.fullName().toString()');
      final int phone = screen.indexOf('contactPhoneText(controller.orderModel.value.driver)');
      final int email = screen.indexOf('controller.orderModel.value.driver!.email.toString()');
      expect(name, greaterThan(-1));
      expect(phone, greaterThan(name), reason: 'under the name');
      expect(phone, lessThan(email), reason: 'above the email, which stays');
    });

    test('the driver box keeps its name, email, call and chat buttons', () {
      expect(screen, contains('controller.orderModel.value.driver!.email.toString()'));
      expect(screen, contains('Constant.makePhoneCall(controller.orderModel.value.driver!.phoneNumber.toString());'));
    });
  });
}
