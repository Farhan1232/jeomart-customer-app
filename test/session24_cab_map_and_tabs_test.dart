import 'dart:io';

import 'package:customer/utils/map_start_location.dart';
import 'package:customer/widget/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 24 - the cab section: the map, and the bottom bar.
///
/// The client reported that opening the cab service and then City Ride or
/// Intercity left the map "not loading properly", and that the bottom bar was
/// slow. Three separate causes, none of them the map itself:
///
///  1. the map was not allowed to build until Firestore had answered;
///  2. the intercity map opened on a hardcoded field in Nebraska;
///  3. every tap on the bar destroyed the page it left and rebuilt the one it
///     went to, re-running that tab's whole startup.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// [source] with `//` comments removed.
  ///
  /// Every assertion below is about what the code *does*, and the comments
  /// explaining these fixes naturally quote the very things being asserted
  /// against - "it used to wait for getVehicleType()", "the old fallback was
  /// 41.4219057". Matching raw text would fail on the explanation rather than
  /// on the behaviour.
  String codeOnly(String source) {
    return source.split('\n').map((String line) {
      final int at = line.indexOf('//');
      return at < 0 ? line : line.substring(0, at);
    }).join('\n');
  }

  group('the map is built before the network is waited on', () {
    /// The body of `initData`, which is where the ordering lives.
    String initData(String path) {
      final String source = codeOnly(read(path));
      final int at = source.indexOf('Future<void> initData() async {');
      expect(at, greaterThan(-1), reason: '$path has no initData');
      return source.substring(at, source.indexOf('\n  }', at));
    }

    for (final String path in <String>[
      'lib/controllers/cab_booking_controller.dart',
      'lib/controllers/intercity_home_controller.dart',
    ]) {
      test('$path: the map start is resolved before the spinner lifts', () {
        final String body = initData(path);
        final int prepare = body.indexOf('_prepareMapStart()');
        final int lift = body.indexOf('isLoading.value = false');
        expect(prepare, greaterThan(-1), reason: 'must resolve a start location');
        expect(lift, greaterThan(prepare), reason: 'the map must have a coordinate before it is drawn');
      });

      test('$path: the spinner lifts before the vehicle types are fetched', () {
        // This is the fix. `getVehicleType()` is a Firestore round trip, and
        // the map used to wait behind it - so entering the section meant
        // watching a spinner before a single map tile was even requested.
        final String body = initData(path);
        final int lift = body.indexOf('isLoading.value = false');
        final int vehicles = body.indexOf('getVehicleType()');
        expect(vehicles, greaterThan(-1));
        expect(lift, lessThan(vehicles), reason: 'the map must not wait for the vehicle list');
      });
    }

    test('intercity no longer waits on popular destinations either', () {
      final String body = initData('lib/controllers/intercity_home_controller.dart');
      final int lift = body.indexOf('isLoading.value = false');
      final int destinations = body.indexOf('getPopularDestination()');
      expect(destinations, greaterThan(-1));
      expect(lift, lessThan(destinations));
    });

    test('the two reads intercity still makes are made together', () {
      final String body = initData('lib/controllers/intercity_home_controller.dart');
      expect(body.contains('Future.wait'), isTrue, reason: 'they are independent of each other');
    });
  });

  group('the intercity map opens somewhere real', () {
    final String controller = read('lib/controllers/intercity_home_controller.dart');
    final String screen = read('lib/screen_ui/cab_service_screens/intercity_home_screen.dart');

    test('the Nebraska coordinate is gone', () {
      // 41.4219057, -102.0840772 is a field in Nebraska, USA. It was the
      // screen's last resort, and nothing ever moved the map off it. The
      // comment left in its place still names it, which is why this reads
      // code only.
      final String code = codeOnly(screen);
      expect(code.contains('41.4219057'), isFalse);
      expect(code.contains('-102.0840772'), isFalse);
    });

    test('the screen opens on the resolved start', () {
      expect(screen.contains('controller.mapStart.value'), isTrue);
    });

    test('the controller can move the map once a real fix lands', () {
      // `initialCenter` is read once and never again, so arriving late is only
      // half the job - something has to tell the map to move.
      for (final String member in <String>['_prepareMapStart', 'refreshCurrentLocation', 'centreOnLocation', 'onGoogleMapCreated']) {
        expect(controller.contains(member), isTrue, reason: 'intercity is missing $member');
      }
      expect(screen.contains('controller.onGoogleMapCreated'), isTrue, reason: 'a camera move before onMapCreated throws');
    });

    test('the GPS fix is never awaited on the way to the first frame', () {
      // A high-accuracy fix takes seconds outdoors and tens of seconds indoors.
      expect(controller.contains('unawaited(refreshCurrentLocation())'), isTrue);
    });
  });

  group('a map with nothing known opens on a place, not the ocean', () {
    test('resolveMapStart honours the fallback it is given', () async {
      // The built-in last resort is 0.0001, 0.0001 - deliberately mid-ocean, so
      // that "we know nothing" is visible. On screen that is a flat blue tile,
      // which to a customer is indistinguishable from a map that failed to
      // load, and a first run lands there: nothing saved, no cached fix.
      final MapStartLocation kohat = const MapStartLocation(latitude: 33.5869, longitude: 71.4414, source: MapStartSource.saved);

      final MapStartLocation resolved = await resolveMapStart(
        store: MapStartLocationStore(read: (String _, {String defaultValue = ''}) => defaultValue, write: (String _, String __) async => true),
        lastKnown: () async => null,
        fallback: kohat,
      );

      expect(resolved.latitude, 33.5869);
      expect(resolved.longitude, 71.4414);
      expect(resolved.isReal, isTrue);
    });

    test('both cab controllers pass a real place as their fallback', () {
      for (final String path in <String>[
        'lib/controllers/cab_booking_controller.dart',
        'lib/controllers/intercity_home_controller.dart',
      ]) {
        final String source = read(path);
        expect(source.contains('fallback: _knownAreaFallback'), isTrue, reason: '$path still falls back to mid-ocean');
        expect(source.contains('Constant.selectedLocation.location'), isTrue, reason: '$path should prefer the address the customer picked');
      }
    });
  });

  group('LazyIndexedStack', () {
    /// How many times each tab's `State` was created.
    ///
    /// This, not the number of builder calls, is what the fix is about. A GetX
    /// page creates its controller in `initState`, so what matters is that the
    /// tab's element survives being switched away from - the builder closure
    /// running again is harmless as long as the State underneath it is reused.
    late List<int> inits;

    Widget harness(int index) {
      return MaterialApp(
        home: LazyIndexedStack(
          index: index,
          children: <WidgetBuilder>[
            for (int i = 0; i < 3; i++) (BuildContext _) => _CountingTab(index: i, onInit: () => inits[i]++),
          ],
        ),
      );
    }

    setUp(() => inits = <int>[0, 0, 0]);

    testWidgets('only the selected tab is created at first', (WidgetTester tester) async {
      // A plain IndexedStack would create all three, which on the cab bar means
      // starting six controllers and firing all their reads at once.
      await tester.pumpWidget(harness(0));
      expect(inits[0], 1);
      expect(inits[1], 0);
      expect(inits[2], 0);
    });

    testWidgets('a tab visited once is not recreated when you come back', (WidgetTester tester) async {
      await tester.pumpWidget(harness(0));
      await tester.pumpWidget(harness(1));
      await tester.pumpWidget(harness(0));

      expect(inits[0], 1, reason: 'returning to a tab must not re-run initState - that is what re-ran the controller');
      expect(inits[1], 1);
      expect(find.text('tab0'), findsOneWidget);
    });

    testWidgets('the page you left stays in the tree', (WidgetTester tester) async {
      // This is the whole point: a page removed from the tree takes its GetX
      // controller with it, and coming back runs onInit() again.
      await tester.pumpWidget(harness(0));
      await tester.pumpWidget(harness(1));

      expect(find.text('tab0', skipOffstage: false), findsOneWidget, reason: 'the previous tab must still be alive');
      expect(find.text('tab1'), findsOneWidget);
    });

    testWidgets('an index past the end does not throw', (WidgetTester tester) async {
      // The wallet tab appears and disappears with `walletSetting`, so the
      // remembered index can outlive the list it points into.
      await tester.pumpWidget(harness(2));
      await tester.pumpWidget(
        MaterialApp(
          home: LazyIndexedStack(index: 2, children: <WidgetBuilder>[(BuildContext _) => const Text('only')]),
        ),
      );
      expect(find.text('only'), findsOneWidget);
    });

    testWidgets('an empty page list renders nothing rather than throwing', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LazyIndexedStack(index: 0, children: <WidgetBuilder>[])));
      expect(tester.takeException(), isNull);
    });
  });

  group('every dashboard keeps its tabs alive', () {
    const List<String> dashboards = <String>[
      'lib/screen_ui/cab_service_screens/cab_dashboard_screen.dart',
      'lib/screen_ui/multi_vendor_service/dash_board_screens/dash_board_screen.dart',
      'lib/screen_ui/ecommarce/dash_board_e_commerce_screen.dart',
      'lib/screen_ui/parcel_service/parcel_dashboard_screen.dart',
      'lib/screen_ui/on_demand_service/on_demand_dashboard_screen.dart',
      'lib/screen_ui/rental_service/rental_dashboard_screen.dart',
    ];

    test('none of them swaps a single page in and out any more', () {
      for (final String path in dashboards) {
        final String source = read(path);
        expect(source.contains('LazyIndexedStack'), isTrue, reason: '$path still rebuilds its tabs');
        expect(
          RegExp(r'body:\s*controller\.pageList\[').hasMatch(source),
          isFalse,
          reason: '$path indexes pageList directly, which disposes the tab being left',
        );
      }
    });
  });

  group('back from the intercity map returns to the cab service screen', () {
    final String screen = read('lib/screen_ui/cab_service_screens/intercity_home_screen.dart');
    final String cab = read('lib/screen_ui/cab_service_screens/cab_booking_screen.dart');

    /// The back arrow's `onTap`, which is the whole of this behaviour.
    String backHandler(String source) {
      final int at = source.indexOf("bottomSheetType.value == \"vehicleSelection\"");
      expect(at, greaterThan(-1), reason: 'no back handler found');
      return source.substring(at, source.indexOf('child: Container(', at));
    }

    test('the normal back path pops, and reaches that branch first', () {
      // `Get.offAll(ServiceListScreen())` destroys every route and drops the
      // customer on the service grid - so choosing Intercity, looking at the
      // map and pressing back took you out of the cab section altogether
      // instead of back to the screen you came from.
      //
      // It is still there, deliberately, as the branch for a screen with an
      // empty stack behind it. What matters is that the ordinary case - there
      // *is* something to go back to - reaches `Get.back()` first.
      final String handler = codeOnly(backHandler(screen));
      final int pop = handler.indexOf('Get.back()');
      final int offAll = handler.indexOf('Get.offAll');

      expect(pop, greaterThan(-1), reason: 'back must pop');
      expect(offAll, greaterThan(pop), reason: 'resetting the stack must be the last resort, not the default');
    });

    test('it behaves the same way the cab booking screen always has', () {
      // The two screens are the same control doing the same job; only intercity
      // was wrong, in the same way it was wrong about Pay Now.
      expect(codeOnly(backHandler(cab)).contains('Get.offAll'), isFalse);
    });

    test('a screen with nothing to pop still has somewhere to go', () {
      // Opened from a notification this can be the root route, and popping the
      // last route leaves a black screen.
      final String handler = screen.substring(screen.indexOf('bottomSheetType.value == "vehicleSelection"'));
      expect(handler.contains('Navigator.canPop(context)'), isTrue);
      expect(handler.contains('Get.offAll(const ServiceListScreen())'), isTrue, reason: 'kept as the no-stack fallback');
    });
  });

  group('Ride History shows its rides before the payment plumbing', () {
    final String controller = read('lib/controllers/my_cab_booking_controller.dart');

    String fetchBody() {
      final String code = codeOnly(controller);
      final int at = code.indexOf('Future<void> fetchParcelData() async {');
      expect(at, greaterThan(-1));
      return code.substring(at, code.indexOf('\n  }', at));
    }

    test('the list is not held behind the profile and the gateway settings', () {
      // This screen never reads `userModel`, and the gateway models are only
      // touched once a customer taps to pay - but both were awaited before the
      // rides were allowed on screen: two Firestore round trips that have
      // nothing to do with the history being displayed.
      final String body = fetchBody();
      final int lift = body.indexOf('isLoading.value = false');
      final int rides = body.indexOf('paginator.refresh()');
      final int payNow = body.indexOf('await forThePayNowPath');

      expect(rides, greaterThan(-1));
      expect(lift, greaterThan(rides), reason: 'the rides must be loaded before the spinner lifts');
      expect(payNow, greaterThan(lift), reason: 'the payment plumbing must not hold the list up');
    });

    test('the two sources of a booking are still loaded together', () {
      expect(fetchBody().contains('Future.wait'), isTrue);
    });

    test('the payment plumbing is still awaited, not dropped', () {
      // Fire-and-forget would leave an unhandled error if the read failed.
      expect(fetchBody().contains('await forThePayNowPath'), isTrue);
    });
  });

  group('the cab config reads are not repeated', () {
    final String store = read('lib/service/fire_store_utils.dart');

    test('vehicle types and popular destinations are memoised per section', () {
      expect(store.contains("_sectionKey('vehicleType')"), isTrue);
      expect(store.contains("_sectionKey('popularDestinations')"), isTrue);
    });

    test('they are keyed per section, not globally', () {
      // Both queries carry `where(sectionId == ...)`, so a bare key would serve
      // the cab section's vehicles to the intercity section.
      final int at = store.indexOf("_sectionKey('vehicleType')");
      expect(at, greaterThan(-1));
      expect(store.substring(at - 200, at).contains('FirestoreCache.remember'), isTrue);
    });
  });
}

/// A tab that reports every time its State is created.
class _CountingTab extends StatefulWidget {
  const _CountingTab({required this.index, required this.onInit});

  final int index;
  final VoidCallback onInit;

  @override
  State<_CountingTab> createState() => _CountingTabState();
}

class _CountingTabState extends State<_CountingTab> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Text('tab${widget.index}');
}
