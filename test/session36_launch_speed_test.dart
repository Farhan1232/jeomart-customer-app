import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Session 36 - the launch.
///
/// A signed-in launch used to pay, one after the other: the server's copy of
/// seven settings documents (129.5 KB of it `globalSettings`), then a round trip
/// for `maintenance_settings`, then another for the customer's `users`
/// document. These pin the shape that removes the queue without changing a
/// single decision the splash makes.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Source with comment lines dropped, so a comment quoting old code is not
  /// mistaken for the code.
  String code(String source) => source
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  String bodyOf(String source, String signature) {
    final int start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature is missing');
    final int end = source.indexOf('\n  static ', start + signature.length);
    return source.substring(start, end == -1 ? source.length : end);
  }

  group('the splash', () {
    test('starts its two reads before the settings wait, not after it', () {
      final String source = code(read('lib/controllers/splash_controller.dart'));
      final int boot = source.indexOf('Future<void> _boot() async {');
      final int maintenance = source.indexOf('_maintenanceRead = FireStoreUtils.isMaintenanceMode();', boot);
      final int login = source.indexOf('_loginRead = FireStoreUtils.isLogin();', boot);
      final int settingsWait = source.indexOf('GlobalSettingController.settingsReady', boot);

      expect(boot, greaterThan(-1));
      expect(maintenance, greaterThan(boot));
      expect(login, greaterThan(boot));
      expect(maintenance, lessThan(settingsWait));
      expect(login, lessThan(settingsWait));
    });

    test('still decides maintenance first and sign-in second', () {
      final String source = code(read('lib/controllers/splash_controller.dart'));
      final int redirect = source.indexOf('Future<void> redirectScreen() async {');
      final int maintenance = source.indexOf('if (await maintenanceRead == true) {', redirect);
      final int login = source.indexOf('bool isLogin = await (loginRead ?? FireStoreUtils.isLogin());', redirect);

      expect(redirect, greaterThan(-1));
      expect(maintenance, greaterThan(redirect));
      expect(login, greaterThan(maintenance));
      // An early read answers one redirect only; a second call reads again.
      expect(source, contains('_maintenanceRead = null;'));
      expect(source, contains('_loginRead = null;'));
    });
  });

  group('settings', () {
    test('each document is applied from the device first and still read from the server', () {
      final String store = code(read('lib/service/fire_store_utils.dart'));
      final String helper = bodyOf(store, 'static Future<void> _loadSettingsDoc(');

      expect(helper, contains('GetOptions(source: Source.cache)'));
      expect(helper, contains('_settingsDoc(documentId)'),
          reason: 'the server copy must still be requested on every launch');
      expect(helper, contains('if (!servedFromDevice) await fromServer;'),
          reason: 'a first launch has nothing on the device and must wait for the server');
      expect(helper, contains('if (!servedFromDevice) applySafely(null);'),
          reason: 'a failed server read must not undo a device copy that was applied');
    });

    test('all seven documents go through it, and none is awaited in series', () {
      final String body = bodyOf(code(read('lib/service/fire_store_utils.dart')), 'static Future<void> getSettings()');

      for (final String id in <String>['vendor', 'globalSettings', 'cashbackOffer', 'DriverNearBy', 'story', 'emailSetting', 'specialDiscountOffer']) {
        expect(body, contains("_loadSettingsDoc('$id',"), reason: 'settings/$id');
      }
      expect(RegExp(r'await \w+Req;').hasMatch(body), isFalse);
      expect(body, contains('await Future.wait(<Future<void>>['));
    });

    test('the "not there" defaults are kept', () {
      final String body = bodyOf(code(read('lib/service/fire_store_utils.dart')), 'static Future<void> getSettings()');

      expect(body, contains('Constant.isSubscriptionModelApplied = false;'));
      expect(body, contains('Constant.isCashbackActive = false;'));
      expect(body, contains('Constant.storyEnable = false;'));
      expect(body, contains('Constant.specialDiscountOffer = false;'));
    });
  });
}
