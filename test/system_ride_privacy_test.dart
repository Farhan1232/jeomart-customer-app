import 'dart:io';

import 'package:customer/models/user_model.dart';
import 'package:customer/utils/ride_author_privacy.dart';
import 'package:flutter_test/flutter_test.dart';

/// A normal (non-bidding) ride must not carry the customer's private profile.
void main() {
  final Map<String, dynamic> customer = UserModel(
    id: 'c1',
    firstName: 'Ali',
    lastName: 'Khan',
    email: 'ali@example.com',
    countryCode: '+92',
    phoneNumber: '3001234567',
    walletAmount: 5000,
    fcmToken: 'token',
    role: 'customer',
  ).toJson()
    ..['shippingAddress'] = <dynamic>[
      <String, dynamic>{'address': 'House 1, Street 2'},
    ]
    ..['location'] = <String, dynamic>{'latitude': 31.5, 'longitude': 74.3}
    ..['userBankDetails'] = <String, dynamic>{'accountNumber': '123'};

  test('the booked ride carries only name, photo, rating and token', () {
    final Map<String, dynamic> author = RideAuthorPrivacy.forSystemRide(customer);
    expect(RideAuthorPrivacy.leaksContact(author), isFalse);
    for (final String key in <String>['phoneNumber', 'email', 'wallet_amount', 'location', 'userBankDetails', 'inProgressOrderID']) {
      expect(author.containsKey(key), isFalse, reason: key);
    }
    expect(author['shippingAddress'], isEmpty);
    expect(author['firstName'], 'Ali');
    expect(author['fcmToken'], 'token');
  });

  test('after acceptance only the phone number is added, never the email', () {
    final Map<String, dynamic> contact = RideAuthorPrivacy.contactFields(customer);
    expect(contact.keys.toSet(), <String>{'phoneNumber', 'countryCode'});
    expect(contact.containsKey('email'), isFalse);
    expect(RideAuthorPrivacy.contactMissing(RideAuthorPrivacy.forSystemRide(customer), contact), isTrue);
    expect(RideAuthorPrivacy.contactMissing(<String, dynamic>{...RideAuthorPrivacy.forSystemRide(customer), ...contact}, contact), isFalse);
  });

  test('both normal booking screens write through the private path', () {
    for (final String path in <String>['lib/controllers/cab_booking_controller.dart', 'lib/controllers/intercity_home_controller.dart']) {
      final String source = File(path).readAsStringSync();
      expect(source, contains('RideContactService.placeSystemRide(orderModel)'), reason: path);
      expect(source, isNot(contains('FireStoreUtils.cabOrderPlace(orderModel)')), reason: path);
      expect(source, contains('RideContactService.revealWhenBooked(rideId, rideData, userModel.value)'), reason: path);
    }
  });
}
