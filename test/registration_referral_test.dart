import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:customer/utils/registration_field_visibility.dart';

/// Session 4: "Hide Referral Code from registration page - Customer App".
///
/// The requirement has two halves that pull against each other: the field must
/// go, and nothing referral-related may break. So these tests cover both the
/// decision the sign-up path now makes about a missing code, and the fact that
/// the referral feature itself is still there.
void main() {
  /// Reads a source file. Deliberately throws rather than calling `expect`,
  /// because group bodies run at declaration time, outside any test.
  String read(String path) {
    final File file = File(path);
    if (!file.existsSync()) throw StateError('$path is missing - this test\'s file list is stale');
    return file.readAsStringSync();
  }

  group('the referral code the sign-up path sees', () {
    test('the field is hidden', () {
      expect(RegistrationFieldVisibility.showReferralCode, isFalse);
    });

    test('is empty whatever the (now unreachable) controller holds', () {
      // A stale controller value must not be able to reach Firestore through a
      // field the customer can no longer see.
      expect(RegistrationFieldVisibility.referralCodeFrom(''), '');
      expect(RegistrationFieldVisibility.referralCodeFrom('ABC123'), '');
      expect(RegistrationFieldVisibility.referralCodeFrom('   '), '');
      expect(RegistrationFieldVisibility.referralCodeFrom(null), '');
    });

    test('an empty answer is what "no referrer" has always meant', () {
      // Registration already supported a blank field; hiding it just makes that
      // the only case. This is the invariant the sign-up controller relies on
      // when it skips the lookup.
      expect(RegistrationFieldVisibility.referralCodeFrom(null).isEmpty, isTrue);
    });
  });

  group('registration still works without the field', () {
    final String controller = read('lib/controllers/sign_up_controller.dart');

    test('the sign-up path never queries Firestore for an empty code', () {
      // The old code called getReferralUserByCode(<text>) unconditionally, so
      // with the field hidden it would have queried referralCode == "" on every
      // signup: a wasted read that could mis-attribute a referral if a
      // malformed legacy document exists.
      expect(controller.contains('getReferralUserByCode(referralCodeEditingController'), isFalse);
      expect(controller.contains('if (referralCode.isNotEmpty)'), isTrue);
    });

    test('both sign-up branches still create the account\'s own referral document', () {
      // Email/password and social/mobile signup are separate code paths; both
      // must still write referral/{uid}, or Refer a Friend would be empty for
      // every account created after this change.
      expect('addReferralRecord()'.allMatches(controller).length, greaterThanOrEqualTo(3));
      expect(controller.contains('FireStoreUtils.referralAdd('), isTrue);
      expect(controller.contains('referralCode: Constant.getReferralCode()'), isTrue);
    });

    test('validation is skipped rather than failed when no code is supplied', () {
      // "Referral code is Invalid" must not be reachable for a customer who was
      // never offered the field.
      final int guardIndex = controller.indexOf('if (referralCode.isEmpty)');
      final int toastIndex = controller.indexOf('Referral code is Invalid');
      expect(guardIndex, greaterThan(-1));
      expect(toastIndex, greaterThan(guardIndex), reason: 'the empty-code short circuit must come first');
    });
  });

  group('nothing referral-related is deleted', () {
    test('the model and the collection name survive', () {
      expect(File('lib/models/referral_model.dart').existsSync(), isTrue);
      expect(read('lib/constant/collection_name.dart').contains('referral'), isTrue);
    });

    test('Refer a Friend still shows the customer their own code', () {
      final String screen = read('lib/screen_ui/multi_vendor_service/refer_friend_screen/refer_friend_screen.dart');
      expect(screen.contains('referralModel.value.referralCode'), isTrue);
    });

    test('the backend helpers are retained for existing data', () {
      final String utils = read('lib/service/fire_store_utils.dart');
      expect(utils.contains('getReferralUserByCode'), isTrue);
      expect(utils.contains('checkReferralCodeValidOrNot'), isTrue);
      expect(utils.contains('referralAdd'), isTrue);
    });
  });

  group('the field is gone from the registration form', () {
    final String screen = read('lib/screen_ui/auth_screens/sign_up_screen.dart');

    test('the input is behind the visibility flag', () {
      expect(screen.contains('RegistrationFieldVisibility.showReferralCode'), isTrue);
      final int guardIndex = screen.indexOf('RegistrationFieldVisibility.showReferralCode');
      final int fieldIndex = screen.indexOf('"Referral Code".tr');
      expect(fieldIndex, greaterThan(guardIndex), reason: 'the field must sit inside the guard');
    });

    test('there is exactly one referral input in the whole app', () {
      // If a second registration entry point ever grows one, this fails rather
      // than quietly shipping a field the client asked to remove.
      int inputs = 0;
      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.contains('/lang/')) continue;
        if (entity.readAsStringSync().contains('hintText: "Enter referral code"')) inputs++;
      }
      expect(inputs, 1);
    });
  });
}
