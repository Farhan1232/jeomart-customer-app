// Does block 3 sit above the fold?
//
// `CabHomeScreen` cannot be pumped directly - its GetX controller opens
// Firestore listeners - so this rebuilds the cab home body from the same
// widgets and the same constants and measures it. The real EssentialSans faces
// are loaded first, because the default test font is fixed-width and would
// wrap the card subtitles into far more lines than the app ever shows.
//
// The client's report: photographs were added to blocks 1 and 2, the blocks
// grew, and block 3's text ended up below the fold.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const double kPhotoHeight = 64;   // _CardPhoto.height
const double kCardPadding = 10;   // blocks 1 and 2

Future<void> loadAppFont() async {
  final FontLoader loader = FontLoader('EssentialSans');
  for (final String f in <String>['regular', 'medium', 'semi_bold', 'bold']) {
    final File file = File('assets/fonts/essential_sans_$f.otf');
    if (file.existsSync()) {
      loader.addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
    }
  }
  await loader.load();
}

Widget card({required double width, required String title, required String subtitle}) {
  return Container(
    width: width,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all()),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: kPhotoHeight, width: double.infinity),
        Padding(
          padding: const EdgeInsets.all(kCardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontFamily: 'EssentialSans', fontSize: 16, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(fontFamily: 'EssentialSans', fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget harness(Size size) {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: <Widget>[
            Container(height: 42, width: 42, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('Name', style: TextStyle(fontFamily: 'EssentialSans', fontSize: 12)),
              Text('Address', maxLines: 1, style: TextStyle(fontFamily: 'EssentialSans', fontSize: 18)),
            ])),
          ]),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: SizedBox(height: 22, width: 22), label: 'Home'),
          BottomNavigationBarItem(icon: SizedBox(height: 22, width: 22), label: 'Bookings'),
          BottomNavigationBarItem(icon: SizedBox(height: 22, width: 22), label: 'My Price'),
          BottomNavigationBarItem(icon: SizedBox(height: 22, width: 22), label: 'Trips'),
          BottomNavigationBarItem(icon: SizedBox(height: 22, width: 22), label: 'Wallet'),
          BottomNavigationBarItem(icon: SizedBox(height: 22, width: 22), label: 'Profile'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // CabDefaultBanner
            const Column(children: <Widget>[SizedBox(height: 20), SizedBox(height: 150, width: double.infinity)]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              const SizedBox(height: 20),
              const Text('Where are you going for?', style: TextStyle(fontFamily: 'EssentialSans', fontSize: 18)),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                card(width: size.width * 0.40, title: 'Ride', subtitle: 'City rides, 24x7 availability'),
                const SizedBox(width: 20),
                card(width: size.width * 0.44, title: 'Intercity/Outstation', subtitle: 'Long trips, prepaid options'),
              ]),
              const SizedBox(height: 30),
              Row(key: const Key('block3'), children: <Widget>[
                const Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text('Every Ride. Every Driver. Verified.', style: TextStyle(fontFamily: 'EssentialSans', fontSize: 22, fontWeight: FontWeight.w700)),
                  Text('All drivers go through ID checks and background verification for your safety.',
                      style: TextStyle(fontFamily: 'EssentialSans', fontSize: 14)),
                ])),
                const Expanded(child: SizedBox(height: 118)),
              ]),
            ]),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // Sizes that must fit without scrolling: a standard phone, and the smallest
  // screen still shipping on new hardware.
  for (final Size size in <Size>[const Size(412, 915), const Size(360, 780)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: block 3 is above the fold', (WidgetTester tester) async {
      await loadAppFont();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(size));
      await tester.pumpAndSettle();

      final Rect viewport = tester.getRect(find.byType(SingleChildScrollView));
      final Rect block3 = tester.getRect(find.byKey(const Key('block3')));
      debugPrint('${size.width.toInt()}x${size.height.toInt()}  viewport=${viewport.height.toStringAsFixed(0)}  '
          'block3.bottom=${block3.bottom.toStringAsFixed(0)}  fold=${viewport.bottom.toStringAsFixed(0)}  '
          'headroom=${(viewport.bottom - block3.bottom).toStringAsFixed(0)}px');

      expect(block3.bottom, lessThanOrEqualTo(viewport.bottom),
          reason: 'block 3 must end above the fold - it is ${(block3.bottom - viewport.bottom).toStringAsFixed(0)}px below');
    });
  }

  // 360x640 is a 2014-era screen. It does not fit, and cannot without cutting
  // the banner or the gaps between the blocks, which are outside blocks 1 and
  // 2. What matters there is that the page scrolls cleanly rather than
  // overflowing, so nothing is clipped.
  testWidgets('360x640: scrolls cleanly, nothing clipped', (WidgetTester tester) async {
    await loadAppFont();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(const Size(360, 640)));
    await tester.pumpAndSettle();

    // A RenderFlex overflow would have been thrown by now.
    expect(tester.takeException(), isNull);

    final Rect viewport = tester.getRect(find.byType(SingleChildScrollView));
    final Rect before = tester.getRect(find.byKey(const Key('block3')));
    debugPrint('360x640  block3 sits ${(before.bottom - viewport.bottom).toStringAsFixed(0)}px below the fold; scrolling to it');

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    final Rect after = tester.getRect(find.byKey(const Key('block3')));
    expect(after.bottom, lessThan(before.bottom), reason: 'the page must scroll');
    expect(after.bottom, lessThanOrEqualTo(viewport.bottom), reason: 'block 3 must be reachable');
  });
}
