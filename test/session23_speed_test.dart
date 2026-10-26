import 'dart:async';
import 'dart:io';

import 'package:customer/utils/app_image_cache.dart';
import 'package:customer/utils/firestore_cache.dart';
import 'package:customer/utils/parallel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session 23 - the customer app's speed work.
///
/// The client reported the app loading slowly, reloading everything on the way
/// back out of a section, and hanging. Measured against the live project
/// (`your-firebase-project-id`) the cause was never the amount of data - 45 vendors, 628
/// products, 27 categories - it was the number of network round trips, how many
/// of them were repeated on every screen entry, and how much of the wait was a
/// fixed timer rather than the data actually arriving.
///
/// These tests pin the machinery that fixed it, and then pin the fixes
/// themselves at the source level so a later edit cannot quietly put the
/// sequential loops, the sleeps or the startup downloads back.
void main() {
  group('FirestoreCache', () {
    setUp(FirestoreCache.clear);

    test('a second read inside the TTL does not call the loader again', () async {
      int calls = 0;
      Future<List<String>> load() async {
        calls++;
        return <String>['a'];
      }

      expect(await FirestoreCache.remember('k', load), <String>['a']);
      expect(await FirestoreCache.remember('k', load), <String>['a']);
      expect(calls, 1);
    });

    test('concurrent callers share one load', () async {
      // This is the case that made re-entering a section cost two identical
      // `getZone()` round trips: the home controller and the dashboard
      // controller start in the same frame and both ask.
      int calls = 0;
      final Completer<List<String>> gate = Completer<List<String>>();
      Future<List<String>> load() {
        calls++;
        return gate.future;
      }

      final Future<List<String>> a = FirestoreCache.remember('k', load);
      final Future<List<String>> b = FirestoreCache.remember('k', load);
      gate.complete(<String>['x']);

      expect(await a, <String>['x']);
      expect(await b, <String>['x']);
      expect(calls, 1, reason: 'two callers in the same frame must make one request');
    });

    test('an empty result is held only briefly', () async {
      // Most FireStoreUtils helpers swallow their errors and return an empty
      // list, so an empty value may be a failed read. Pinning one for the full
      // TTL would turn a dropped packet into two minutes of an empty screen.
      expect(FirestoreCache.emptyTtl, lessThan(FirestoreCache.defaultTtl));

      await FirestoreCache.remember('empty', () async => <String>[]);
      await FirestoreCache.remember('full', () async => <String>['a']);
      expect(FirestoreCache.isFresh('empty'), isTrue);
      expect(FirestoreCache.isFresh('full'), isTrue);
    });

    test('a throwing loader is not cached', () async {
      int calls = 0;
      Future<String> load() async {
        calls++;
        throw StateError('no');
      }

      await expectLater(FirestoreCache.remember('k', load), throwsStateError);
      await expectLater(FirestoreCache.remember('k', load), throwsStateError);
      expect(calls, 2, reason: 'a failure must not be remembered');
    });

    test('invalidate drops the value', () async {
      int calls = 0;
      Future<String> load() async {
        calls++;
        return 'v$calls';
      }

      expect(await FirestoreCache.remember('k', load), 'v1');
      FirestoreCache.invalidate('k');
      expect(await FirestoreCache.remember('k', load), 'v2');
    });

    test('invalidating during a load stops that load being cached', () async {
      // The order-placement stock decrement is read-modify-write per cart line,
      // and two lines can be two variants of one product. If a read that
      // started before the write could install its pre-write value afterwards,
      // the next line would decrement from a stale quantity.
      final Completer<String> gate = Completer<String>();
      final Future<String> reading = FirestoreCache.remember('k', () => gate.future);

      FirestoreCache.invalidate('k'); // the write lands mid-read
      gate.complete('stale');
      expect(await reading, 'stale');

      expect(FirestoreCache.isFresh('k'), isFalse, reason: 'the pre-write value must not be installed after the write');
    });

    test('invalidatePrefix drops a whole family', () async {
      await FirestoreCache.remember('section:a:story', () async => <String>['s']);
      await FirestoreCache.remember('section:b:story', () async => <String>['s']);
      await FirestoreCache.remember('brands', () async => <String>['b']);

      FirestoreCache.invalidatePrefix('section:');

      expect(FirestoreCache.isFresh('section:a:story'), isFalse);
      expect(FirestoreCache.isFresh('section:b:story'), isFalse);
      expect(FirestoreCache.isFresh('brands'), isTrue);
    });
  });

  group('Parallel', () {
    test('results come back in the order asked, not the order answered', () async {
      // Load-bearing: several call sites feed a list that is then rendered in
      // order, or filtered by a per-row subscription rule.
      final List<int?> out = await Parallel.map<int, int>(<int>[1, 2, 3, 4, 5], (int i) async {
        await Future<void>.delayed(Duration(milliseconds: (6 - i) * 8));
        return i * 10;
      });
      expect(out, <int>[10, 20, 30, 40, 50]);
    });

    test('no more than `concurrency` reads are in flight at once', () async {
      int live = 0;
      int peak = 0;
      await Parallel.map<int, int>(List<int>.generate(20, (int i) => i), (int i) async {
        live++;
        peak = live > peak ? live : peak;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        live--;
        return i;
      }, concurrency: 4);
      expect(peak, lessThanOrEqualTo(4));
    });

    test('one failure does not lose the batch', () async {
      // `Future.wait` rejects the whole batch on the first error, which would
      // turn one unreadable document into an empty screen.
      final List<int?> out = await Parallel.map<int, int>(<int>[1, 2, 3], (int i) async {
        if (i == 2) throw StateError('bad row');
        return i;
      });
      expect(out, <int?>[1, null, 3]);
    });

    test('mapNotNull drops the failures', () async {
      final List<int> out = await Parallel.mapNotNull<int, int>(<int>[1, 2, 3], (int i) async {
        if (i == 2) return null;
        return i;
      });
      expect(out, <int>[1, 3]);
    });

    test('an empty input makes no work', () async {
      expect(await Parallel.map<int, int>(<int>[], (int i) async => i), isEmpty);
    });
  });

  group('AppImageCache', () {
    test('a zero max-age becomes a usable freshness', () {
      // Firebase Storage serves every image on this project with
      // `cache-control: private, max-age=0`, so flutter_cache_manager treated
      // all of them as stale on arrival and re-fetched roughly 4 MB of vendor
      // photographs on every entry to a section.
      final DateTime now = DateTime(2026, 9, 10, 12);
      final DateTime raised = AppImageCache.freshnessFor(now, now: now);
      expect(raised.isAfter(now.add(const Duration(days: 1))), isTrue);
    });

    test('a freshness the server really asked for is left alone', () {
      final DateTime now = DateTime(2026, 9, 10, 12);
      final DateTime serverSaid = now.add(const Duration(hours: 2));
      expect(AppImageCache.freshnessFor(serverSaid, now: now), serverSaid);
    });

    test('a past freshness is raised, not kept', () {
      final DateTime now = DateTime(2026, 9, 10, 12);
      final DateTime stale = now.subtract(const Duration(hours: 1));
      expect(AppImageCache.freshnessFor(stale, now: now).isAfter(now), isTrue);
    });
  });

  group('the fixes stay fixed', () {
    String read(String path) => File(path).readAsStringSync();

    test('no home screen hides its content behind a fixed sleep', () {
      // Four screens took their spinner down on a timer rather than on the
      // data: fast data waited anyway, and slow data showed an empty state and
      // then popped the content in underneath it.
      const List<String> controllers = <String>[
        'lib/controllers/food_home_controller.dart',
        'lib/controllers/home_e_commerce_controller.dart',
        'lib/controllers/dine_in_controller.dart',
        'lib/controllers/category_restaurant_controller.dart',
      ];
      for (final String path in controllers) {
        final String source = read(path);
        expect(
          RegExp(r'Future\.delayed\(\s*(const\s+)?Duration\(seconds:').hasMatch(source),
          isFalse,
          reason: '$path is back to sleeping instead of waiting for its data',
        );
        expect(source.contains('firstDelivery'), isTrue, reason: '$path should lift its spinner on the first delivery');
      }
    });

    test('startup does not download the privacy policy and terms', () {
      // 69.8 KB and 51.9 KB on live, opened as permanent listeners before the
      // first frame, for text reachable only from the profile menu.
      final String store = read('lib/service/fire_store_utils.dart');
      final int start = store.indexOf('static Future<void> getSettings()');
      expect(start, greaterThan(-1));
      final String body = store.substring(start, store.indexOf('\n  static ', start + 10));

      expect(body.contains('doc("privacyPolicy")'), isFalse);
      expect(body.contains('doc("termsAndConditions")'), isFalse);
    });

    test('the screen that shows the policy warms the fallback it replaced', () {
      final String screen = read('lib/screen_ui/multi_vendor_service/terms_and_condition/terms_and_condition_screen.dart');
      expect(screen.contains('Constant.privacyPolicy = _content'), isTrue);
      expect(screen.contains('Constant.termsAndConditions = _content'), isTrue);
    });

    test('the read-per-row loops are gone', () {
      // Each of these ran one Firestore read per row, awaited inside a `for`
      // loop, so the screen paid one network round trip per row in series.
      //
      // An `await` on the same call is fine - and expected - inside a
      // `Parallel` worker, where the whole point is that several of them are in
      // flight at once. What must not come back is the `await` sitting directly
      // in a `for` loop body, so that is what this looks for.
      const Map<String, String> sites = <String, String>{
        'lib/controllers/search_controller.dart': 'getProductByVendorId',
        'lib/controllers/restaurant_details_controller.dart': 'getVendorCategoryById',
        'lib/controllers/favourite_controller.dart': 'getVendorById',
        'lib/controllers/all_brand_product_controller.dart': 'getAllProducts',
        'lib/controllers/view_category_service_controller.dart': 'getAllProviderServiceByAuthorId',
      };

      /// Whether [call] is awaited within [window] lines of a `for`/`while`
      /// header, without a `Parallel.` call opening in between.
      bool awaitsInsideLoop(String source, String call, {int window = 8}) {
        final List<String> lines = source.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (!RegExp(r'\b(for|while)\s*\(').hasMatch(lines[i])) continue;
          for (int j = i + 1; j < lines.length && j <= i + window; j++) {
            if (lines[j].contains('Parallel.')) break;
            if (RegExp('await\\s+(FireStoreUtils\\.)?$call').hasMatch(lines[j])) return true;
          }
        }
        return false;
      }

      sites.forEach((String path, String call) {
        final String source = read(path);
        expect(source.contains('Parallel.'), isTrue, reason: '$path should fetch $call concurrently');
        expect(
          awaitsInsideLoop(source, call),
          isFalse,
          reason: '$path awaits $call inside a loop again - that is one round trip per row',
        );
      });
    });

    test('the restaurant screen asks for each category once', () {
      final String source = read('lib/controllers/restaurant_details_controller.dart');
      expect(source.contains('distinctCategoryIds'), isTrue);
    });

    test('every image goes through the app cache manager', () {
      // A site that misses this re-downloads its picture on every rebuild,
      // because the default manager obeys the server's max-age of zero.
      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String source = entity.readAsStringSync();
        for (final String token in <String>['CachedNetworkImage(', 'CachedNetworkImageProvider(']) {
          int at = source.indexOf(token);
          while (at >= 0) {
            // Look at the argument list only, not the whole file.
            final String head = source.substring(at, (at + 400).clamp(0, source.length));
            if (!head.contains('cacheManager')) offenders.add('${entity.path} :: $token');
            at = source.indexOf(token, at + 1);
          }
        }
      }
      expect(offenders, isEmpty, reason: 'these image sites bypass AppImageCache:\n  ${offenders.join('\n  ')}');
    });

    test('images are decoded at the size they are drawn', () {
      final String widget = read('lib/utils/network_image_widget.dart');
      expect(widget.contains('memCacheWidth'), isTrue);
      expect(widget.contains('devicePixelRatio'), isTrue);
    });

    test('the service list starts its reads together', () {
      final String source = read('lib/controllers/service_list_controller.dart');
      // The four reads are issued before any of them is awaited.
      final int currency = source.indexOf('FireStoreUtils.getCurrency()');
      final int zone = source.indexOf('getZone()');
      final int firstAwait = source.indexOf('await currencyReq');
      expect(currency, greaterThan(-1));
      expect(zone, greaterThan(-1));
      expect(firstAwait, greaterThan(zone), reason: 'the zone read must start before the currency is awaited');
    });
  });

  group('nothing can hang the screen for ever', () {
    String read(String path) => File(path).readAsStringSync();

    test('a loader that is never closed takes itself down', () {
      // showLoader is called from 114 places that then `await` something and
      // close the loader on the next line, mostly with no `try`. Any throw on
      // the awaited call skips the close and leaves a full-screen, tap-blocking
      // overlay up for the rest of the session - which is indistinguishable
      // from the app freezing.
      final String source = read('lib/themes/show_toast_dialog.dart');
      expect(source.contains('loaderWatchdog'), isTrue);
      expect(source.contains('Timer('), isTrue);
      expect(source.contains('_watchdog?.cancel()'), isTrue, reason: 'closeLoader must cancel the watchdog');
    });

    test('map, route and marker requests are bounded', () {
      // package:http has no default timeout: a socket that opens and stalls
      // blocks its await for as long as it lives. Every one of these is on a
      // screen-load path and every one of them is decoration, so giving up
      // beats waiting.
      const List<String> mapPaths = <String>[
        'lib/controllers/cab_booking_controller.dart',
        'lib/controllers/intercity_home_controller.dart',
        'lib/controllers/book_parcel_controller.dart',
        'lib/controllers/cab_order_details_controller.dart',
        'lib/controllers/live_tracking_controller.dart',
      ];
      for (final String path in mapPaths) {
        final String source = read(path);
        final Iterable<RegExpMatch> bare = RegExp(r'await http\.(get|post)\((url|Uri\.parse\(url\))\)(?!\s*\.timeout)').allMatches(source);
        expect(bare, isEmpty, reason: '$path has an unbounded route/map request');
      }
      expect(read('lib/constant/constant.dart').contains('mapRequestTimeout'), isTrue);
    });

    test('the route and geocode helpers fail quiet', () {
      // These run unawaited from onInit or a map callback, so anything they
      // throw lands nowhere - and the Google key on this project is refused, so
      // they throw on every ride.
      final String details = read('lib/controllers/cab_order_details_controller.dart');
      expect(details.contains('no Google route line'), isTrue);
      expect(details.contains('no OSM route line'), isTrue);
      for (final String path in <String>['lib/controllers/cab_booking_controller.dart', 'lib/controllers/intercity_home_controller.dart']) {
        expect(read(path).contains('reverse geocode failed'), isTrue, reason: '$path: searchPlaceNameGoogle must not throw into nothing');
      }
    });

    test('every controller cancels the streams it opens', () {
      // A GetX controller is rebuilt every time its route is pushed, so an
      // uncancelled listener means the fifth visit to a screen has five live
      // vendor streams all rewriting the same list.
      /// The text of the statement that `.listen(` at [at] belongs to.
      ///
      /// Line-based checking is not enough here: these calls are routinely
      /// written over several lines, so the `_subscriptions.add(` or the
      /// assignment that holds the subscription is usually not on the same line
      /// as the `.listen(`. Walking back to the start of the statement is what
      /// tells a held subscription from a dropped one.
      String statementBefore(String source, int at) {
        int start = at;
        while (start > 0) {
          final String c = source[start - 1];
          if (c == ';' || c == '{' || c == '}') break;
          start--;
        }
        return source.substring(start, at);
      }

      final List<String> offenders = <String>[];
      for (final FileSystemEntity entity in Directory('lib/controllers').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String source = entity.readAsStringSync();

        bool opensStream = false;
        int at = source.indexOf('.listen(');
        while (at >= 0) {
          final String statement = statementBefore(source, at);
          final String flat = statement.replaceAll('\n', ' ').trim();
          // Skip commented-out code.
          final bool commented = statement.split('\n').last.trimLeft().startsWith('//');
          if (!commented) {
            opensStream = true;
            final bool held = flat.contains('_subscriptions.add(') || RegExp(r'(^|\s)(_?\w+)\s*=\s*$|(^|\s)(final|var|return)\s').hasMatch('$flat ') || RegExp(r'\w+\s*=\s*[^=]*$').hasMatch(flat);
            if (!held) offenders.add('${entity.path} :: ${flat.length > 90 ? '${flat.substring(flat.length - 90)}...' : flat}');
          }
          at = source.indexOf('.listen(', at + 1);
        }
        if (opensStream && !source.contains('onClose()')) {
          offenders.add('${entity.path} :: opens a stream but has no onClose()');
        }
      }
      expect(offenders, isEmpty, reason: 'these listeners are never cancelled:\n  ${offenders.join('\n  ')}');
    });
  });

  group('favourites are paged', () {
    String read(String path) => File(path).readAsStringSync();

    final String controller = read('lib/controllers/favourite_controller.dart');
    final String screen = read('lib/screen_ui/multi_vendor_service/favourite_screens/favourite_screen.dart');
    final String store = read('lib/service/fire_store_utils.dart');

    test('both lists page instead of reading the whole set', () {
      expect(controller.contains('FirestorePaginator'), isTrue);
      expect(controller.contains('favouriteVendorQuery'), isTrue);
      expect(controller.contains('favouriteItemQuery'), isTrue);
    });

    test('the paginators are disposed with the controller', () {
      expect(controller.contains('vendorsPaginator?.dispose()'), isTrue);
      expect(controller.contains('itemsPaginator?.dispose()'), isTrue);
      expect(controller.contains('_vendorsWorker?.dispose()'), isTrue);
      expect(controller.contains('_itemsWorker?.dispose()'), isTrue);
    });

    test('the screen asks for the next page and can be pulled to refresh', () {
      expect(screen.contains('LoadMoreListener'), isTrue);
      expect(screen.contains('LoadMoreIndicator'), isTrue);
      expect(screen.contains('controller.loadMoreFavouriteVendors'), isTrue);
      expect(screen.contains('controller.loadMoreFavouriteItems'), isTrue);
      expect(screen.contains('controller.refreshFavouriteVendors'), isTrue);
      expect(screen.contains('controller.refreshFavouriteItems'), isTrue);
    });

    test('both row counts leave room for the load-more row', () {
      expect(screen.contains('controller.favouriteVendorList.length + (controller.hasMoreFavouriteVendors ? 1 : 0)'), isTrue);
      expect(screen.contains('controller.favouriteFoodList.length + (controller.hasMoreFavouriteItems ? 1 : 0)'), isTrue);
    });

    test('an empty tab can still be pulled to refresh', () {
      // A bare `Center` is not scrollable, so an empty tab used to be a dead
      // end - no pull-to-refresh and nothing for the load-more listener to see.
      expect(screen.contains('AlwaysScrollableScrollPhysics'), isTrue);
    });

    test('the favourite queries carry no orderBy', () {
      // An orderBy would need a new composite index and would drop every
      // favourite saved before that field existed.
      for (final String name in <String>['favouriteVendorQuery', 'favouriteItemQuery']) {
        final int start = store.indexOf('static Query<Map<String, dynamic>> $name');
        expect(start, greaterThan(-1), reason: '$name is missing');
        final String body = store.substring(start, store.indexOf('}', start));
        expect(body.contains('orderBy'), isFalse, reason: '$name must not order');
      }
    });
  });
}
