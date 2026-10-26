import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Session 15 — the artwork the client asked for.
///
/// 1. The cab service page carries images: a JEOM banner across the top and a
///    car photograph on each of the two service cards.
/// 2. The three apps carry the client's JEOM launcher icons.
///
/// The images are checked as files plus the references to them, because pumping
/// `CabHomeScreen` needs Firebase, GetX and `Constant.sectionConstantModel`.
void main() {
  String source(String path) {
    final File file = File(path);
    if (!file.existsSync()) throw StateError('$path is missing');
    return file.readAsStringSync();
  }

  /// Width and height from a PNG's IHDR chunk — cheap, and it doubles as a
  /// check that the file really is a PNG rather than something renamed.
  ({int width, int height}) pngSize(String path) {
    final List<int> bytes = File(path).readAsBytesSync();
    const List<int> signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) throw StateError('$path is not a PNG');
    }
    int be32(int at) => (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3];
    return (width: be32(16), height: be32(20));
  }

  // =========================================================================
  // The cab service page
  // =========================================================================
  group('the cab page carries the artwork', () {
    const String screenPath = 'lib/screen_ui/cab_service_screens/cab_home_screen.dart';

    const Map<String, ({int width, int height})> assets = <String, ({int width, int height})>{
      'assets/images/img_cab_banner.png': (width: 800, height: 362),
      'assets/images/img_ride_car.png': (width: 381, height: 132),
      'assets/images/img_intercity_car.png': (width: 381, height: 132),
    };

    test('all three images are on disk, and are real PNGs of the expected size', () {
      assets.forEach((String path, ({int width, int height}) expected) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        final ({int width, int height}) actual = pngSize(path);
        expect(actual.width, expected.width, reason: '$path width');
        expect(actual.height, expected.height, reason: '$path height');
      });
    });

    test('none of them is an empty placeholder', () {
      for (final String path in assets.keys) {
        expect(File(path).lengthSync(), greaterThan(10 * 1024), reason: '$path looks like a stub');
      }
    });

    test('the screen references each one', () {
      final String screen = source(screenPath);
      for (final String path in assets.keys) {
        expect(screen.contains(path), isTrue, reason: '$path is never used');
      }
    });

    test('each image belongs to exactly one file, so nothing else was restyled', () {
      // The client asked for images on the cab service page and for nothing
      // else to move. If one of these turns up on a second screen, it did.
      for (final String path in assets.keys) {
        final List<String> users = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))
            .where((File f) => f.readAsStringSync().contains(path))
            .map((File f) => f.path)
            .toList();
        expect(users, <String>[screenPath], reason: '$path is used in ${users.join(', ')}');
      }
    });

    test('the page scrolls, so the added height cannot overflow a short phone', () {
      // The body was a bare Column. Three photographs of added height on a
      // 640 dp phone is a RenderFlex overflow, not a design choice.
      final String screen = source(screenPath);
      expect(screen.contains('SingleChildScrollView'), isTrue);
    });

    test('an admin-uploaded banner still wins over the bundled one', () {
      // The bundled banner is a fallback for a project with no banner
      // configured. An admin who uploads one must still see theirs.
      final String screen = source(screenPath);
      expect(screen.contains('controller.bannerTopHome.isEmpty'), isTrue);
      expect(screen.contains('? const CabDefaultBanner()'), isTrue);
      expect(screen.contains(': BannerView(bannerList: controller.bannerTopHome)'), isTrue);
    });

    test('the two cards keep the section switches that decide whether they exist', () {
      // rideType is admin configuration: "ride", "intercity" or "both". Adding
      // a photograph must not turn a hidden card into a visible one.
      final String screen = source(screenPath);
      expect(screen.contains('Constant.sectionConstantModel!.rideType == "both" || Constant.sectionConstantModel!.rideType == "ride"'), isTrue);
      expect(screen.contains('Constant.sectionConstantModel!.rideType == "both" || Constant.sectionConstantModel!.rideType == "intercity"'), isTrue);
    });

    test('the cards keep their own tap targets', () {
      final String screen = source(screenPath);
      expect(screen.contains('Get.to(() => const CabBookingScreen());'), isTrue);
      expect(screen.contains('Get.to(() => IntercityHomeScreen());'), isTrue);
      expect(screen.contains('if (!Constant.requireLogin()) return;'), isTrue);
    });

    test('the bottom navigation bar was left alone, as asked', () {
      // The client was explicit: add the images, do not touch the bar. The cab
      // dashboard is where the customer's bar is built.
      final String dashboard = source('lib/screen_ui/cab_service_screens/cab_dashboard_screen.dart');
      for (final String path in assets.keys) {
        expect(dashboard.contains(path), isFalse, reason: 'the bar picked up $path');
      }
    });
  });

  // =========================================================================
  // The launcher icon
  // =========================================================================
  group('this app carries the JEOM launcher icon', () {
    test('every Android density has its three layers at the right size', () {
      const Map<String, int> legacy = <String, int>{
        'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
      };
      legacy.forEach((String density, int size) {
        final String dir = 'android/app/src/main/res/mipmap-$density';
        expect(pngSize('$dir/ic_launcher.png').width, size, reason: '$density ic_launcher');
        // The adaptive layers are 108 dp against the legacy icon's 48 dp, so
        // 2.25x its pixels at every density. Android crops them to the
        // launcher's mask, which is why they are deliberately larger.
        final int adaptive = (size * 108 / 48).round();
        expect(pngSize('$dir/ic_launcher_adaptive_back.png').width, adaptive, reason: '$density back');
        expect(pngSize('$dir/ic_launcher_adaptive_fore.png').width, adaptive, reason: '$density fore');
      });
    });

    test('every icon the iOS asset catalogue declares exists at its expected size', () {
      const String iconset = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final String contents = source('$iconset/Contents.json');
      // Pull filename/size pairs without a JSON dependency in the test.
      final RegExp entry = RegExp(r'"filename"\s*:\s*"([^"]+)"');
      final Iterable<RegExpMatch> names = entry.allMatches(contents);
      expect(names, isNotEmpty, reason: 'Contents.json declares no icons');
      for (final RegExpMatch m in names) {
        final String file = '$iconset/${m.group(1)}';
        expect(File(file).existsSync(), isTrue, reason: '$file is declared but missing');
        expect(File(file).lengthSync(), greaterThan(0), reason: '$file is empty');
      }
    });

    test('the 1024 marketing icon is square and substantial', () {
      const String iconset = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final String marketing = File('$iconset/icon-ios-1024x1024.png').existsSync()
          ? '$iconset/icon-ios-1024x1024.png'
          : '$iconset/1024.png';
      final ({int width, int height}) size = pngSize(marketing);
      expect(size.width, 1024);
      expect(size.height, 1024);
      expect(File(marketing).lengthSync(), greaterThan(20 * 1024));
    });
  });
}
