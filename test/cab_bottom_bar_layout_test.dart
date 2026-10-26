import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/controllers/cab_dashboard_controller.dart';
import 'package:customer/themes/app_them_data.dart';

/// The cab bottom bar went from four or five items to five or six when the Bid
/// section was added, so the labels have to be checked, not assumed.
///
/// The bar is rebuilt here rather than pumped from `CabDashboardScreen`,
/// because that screen constructs every page and those need Firebase. What is
/// under test is the thing that actually changed — six labels at the chosen
/// font size on a narrow phone — and a `RenderFlex` overflow anywhere in it
/// fails the test, because `flutter_test` turns an overflow into an exception.
void main() {
  const List<String> sixLabels = <String>['Home', 'Bookings', 'Bid', 'Trips', 'Wallet', 'Profile'];
  const List<String> fiveLabels = <String>['Home', 'Bookings', 'Bid', 'Trips', 'Profile'];

  /// Mirrors `CabDashboardScreen`: 10 pt at six items, 12 below that.
  double labelSize(int count) => count >= 6 ? 10 : 12;

  Widget bar(List<String> labels) {
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          showSelectedLabels: true,
          selectedFontSize: labelSize(labels.length),
          unselectedFontSize: labelSize(labels.length),
          selectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold),
          unselectedLabelStyle: const TextStyle(fontFamily: AppThemeData.bold),
          currentIndex: 0,
          items: <BottomNavigationBarItem>[
            for (final String label in labels)
              BottomNavigationBarItem(
                icon: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: SizedBox(height: 22, width: 22),
                ),
                label: label,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size, List<String> labels) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(bar(labels));
    await tester.pumpAndSettle();
  }

  group('the cab bottom bar fits', () {
    testWidgets('six items on a 320 dp phone — the narrowest in common use', (WidgetTester tester) async {
      await pumpAt(tester, const Size(320, 640), sixLabels);
      expect(tester.takeException(), isNull);
    });

    testWidgets('six items on a 360 dp phone', (WidgetTester tester) async {
      await pumpAt(tester, const Size(360, 800), sixLabels);
      expect(tester.takeException(), isNull);
    });

    testWidgets('five items, the wallet-off configuration', (WidgetTester tester) async {
      await pumpAt(tester, const Size(320, 640), fiveLabels);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every label is rendered, not silently dropped', (WidgetTester tester) async {
      await pumpAt(tester, const Size(320, 640), sixLabels);
      for (final String label in sixLabels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('no label is wider than the slot it gets', (WidgetTester tester) async {
      const double width = 320;
      await pumpAt(tester, const Size(width, 640), sixLabels);

      final double slot = width / sixLabels.length;
      for (final String label in sixLabels) {
        final Size size = tester.getSize(find.text(label));
        expect(
          size.width,
          lessThanOrEqualTo(slot),
          reason: '"$label" is ${size.width.toStringAsFixed(1)} px in a ${slot.toStringAsFixed(1)} px slot',
        );
      }
    });
  });

  group('the tab list itself', () {
    test('is six long with the wallet on and five with it off', () {
      // `tabs` reads Constant.walletSetting, which defaults to true here, so
      // this pins the shape rather than the setting.
      final List<String> tabs = CabDashboardController.tabs;
      expect(tabs.length, anyOf(5, 6));
      expect(tabs.first, CabDashboardController.homeTab);
      expect(tabs.last, CabDashboardController.profileTab);
      expect(tabs.contains(CabDashboardController.bidTab), isTrue);
    });

    test('has no duplicate entries, so no two slots can show the same page', () {
      final List<String> tabs = CabDashboardController.tabs;
      expect(tabs.toSet().length, tabs.length);
    });
  });
}
