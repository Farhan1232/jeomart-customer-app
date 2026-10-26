import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Session 28 - the three customer-app defects the client reported on 10 Sep:
/// a trip that could not be booked, a chat whose back button left a blank grey
/// page, and a banner tap that froze the app until it was restarted.
void main() {
  String read(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing - this test is stale');
    return file.readAsStringSync();
  }

  List<File> libDartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();

  /// Source with its comment lines dropped, so a comment quoting the old code
  /// - and `banner_tap.dart` deliberately does quote it - is not mistaken for
  /// the old code still being there.
  String code(String source) => source
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  group('booking a driver\'s full-vehicle trip', () {
    test('the signed-in customer reaches memory on the read, not on the write', () {
      final String source = read('lib/controllers/splash_controller.dart');

      final int assign = source.indexOf('Constant.userModel = userModel;');
      final int write = source.indexOf('unawaited(FireStoreUtils.updateUser(userModel));');

      expect(assign, greaterThan(-1),
          reason: 'the splash must publish the profile it just read');
      expect(write, greaterThan(-1));
      expect(assign, lessThan(write),
          reason: 'a session whose token write never lands must still know who is signed in - '
              'that is what refused every booking with "This trip is no longer available"');
    });

    test('a reservation loads the profile rather than reporting the trip gone', () {
      final String source = read('lib/service/driver_trip_service.dart');

      expect(source, contains('final UserModel? customer = await _signedInCustomer();'));
      expect(source, contains('static Future<UserModel?> _signedInCustomer() async {'),
          reason: 'the booking must not depend on Constant.userModel having arrived');
      expect(source, contains('await FireStoreUtils.getUserProfile(uid)'));
    });
  });

  group('the chat back button', () {
    test('the dashboard cannot be handed a tab that is not on its bar', () {
      final String source = read('lib/screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart');

      // `BottomNavigationBar` indexes one animation controller per item with
      // `currentIndex`, so a value past the end throws while the bar is built,
      // and a throw during build is a bare grey page in a release build.
      expect(source, contains('controller.selectedIndex.value.clamp(0, tabCount - 1)'));
      expect(source, contains('currentIndex: selectedTab,'));
      expect(source.contains('currentIndex: controller.selectedIndex.value,'), isFalse,
          reason: 'the raw index must not reach the bar');
    });

    test('a chat notification never names a dashboard tab at all', () {
      final String source = read('lib/utils/notification_service.dart');

      // Session 28 fixed the literal `4` on a four-tab bar. Session 30 removed
      // the reason it was there: the notification no longer replaces the
      // customer's screen with the multi-vendor dashboard, so there is no tab
      // for it to choose. See session30_client_defects_test.dart.
      expect(source.contains('dashBoardScreen.selectedIndex.value = 4;'), isFalse,
          reason: 'the bar is four tabs long with the wallet off, so 4 named a tab that did not exist');
      expect(source.contains('selectedIndex.value ='), isFalse,
          reason: 'a notification must not move the dashboard the customer is not on');
    });

    test('a dashboard built before a section is chosen does not throw', () {
      final String source = read('lib/controllers/dash_board_controller.dart');

      expect(source, contains('Constant.sectionConstantModel?.theme == "theme_2"'),
          reason: 'a notification can create this controller before a section exists');
    });
  });

  test('opening the chat on an order cannot strand the loader either', () {
    // The same shape as the banner defect, on the three chat buttons of an
    // order: a blocking loader, then `restaurantUser!.vendorID` two lines
    // before the `closeLoader()` that would have taken it down.
    final String screen = read('lib/screen_ui/multi_vendor_service/order_list_screen/order_details_screen.dart');
    expect(screen.contains('restaurantUser!.vendorID'), isFalse);
    expect('OrderChat.openWith'.allMatches(screen).length, 3,
        reason: 'two restaurant buttons and one driver button');

    final String helper = code(read('lib/utils/order_chat.dart'));
    expect('} finally {'.allMatches(helper).length, 2);
    expect('ShowToastDialog.closeLoader();'.allMatches(helper).length, 2);
    expect(helper.contains('restaurantUser!'), isFalse);
  });

  group('tapping an advertising banner', () {
    test('every carousel goes through the one guarded handler', () {
      final List<String> offenders = <String>[];
      for (final File file in libDartFiles()) {
        // The line that froze the app: a blocking loader, then a bang on the
        // very next statement, with no `closeLoader` in between.
        final String source = code(file.readAsStringSync());
        if (source.contains('vendorModel!.zoneId == Constant.selectedZone!.id')) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'a deleted store or an unset zone must not strand the loader over the screen');
    });

    test('there are six carousels and all of them call openBanner', () {
      int callSites = 0;
      for (final File file in libDartFiles()) {
        callSites += 'await openBanner(bannerModel);'.allMatches(file.readAsStringSync()).length;
      }

      expect(callSites, 6,
          reason: 'the two food-home carousels, the second theme, dine-in and the two e-commerce ones');
    });

    test('the handler always takes the loader down and never bangs', () {
      final String source = code(read('lib/utils/banner_tap.dart'));

      expect('ShowToastDialog.closeLoader();'.allMatches(source).length, 2,
          reason: 'one per branch that opens a loader, and both in a finally');
      expect('} finally {'.allMatches(source).length, 2);
      expect(source.contains('vendorModel!'), isFalse);
      expect(source.contains('Constant.selectedZone!'), isFalse);
      expect(source, contains('if (!uri.hasScheme) uri = Uri.parse(\'https://\$trimmed\');'),
          reason: 'a link banner typed without a scheme is what the client uses for ads');
    });
  });
}
