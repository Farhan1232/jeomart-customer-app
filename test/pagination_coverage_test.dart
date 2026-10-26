import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pagination coverage for the customer app.
///
/// The client's report was that pagination "is not working" and that there is
/// "nothing here". Most of the app was already paged; the vendor review list
/// was the one screen still reading its whole collection into an RxList, so it
/// is wired to the same paginator as the rest here.
///
/// The second group is the part worth keeping: it walks every list screen in
/// the app and fails if one grows a Firestore-backed `ListView.builder` with no
/// paging around it. Coverage that is only asserted once tends not to stay
/// true - the paginated screens were correct after session 8 too, and a screen
/// added later would have slipped straight past a hand-written list of names.
void main() {
  group('the vendor review list is paged', () {
    final String screen = File('lib/screen_ui/multi_vendor_service/review_list_screen/review_list_screen.dart').readAsStringSync();
    final String controller = File('lib/controllers/review_list_controller.dart').readAsStringSync();
    final String store = File('lib/service/fire_store_utils.dart').readAsStringSync();

    test('the controller pages instead of loading everything', () {
      expect(controller.contains('FirestorePaginator'), isTrue);
      expect(controller.contains('FirestorePageSource'), isTrue);
      expect(controller.contains('vendorReviewsQuery'), isTrue);
    });

    test('the paginator is disposed with the controller', () {
      expect(controller.contains('reviewsPaginator?.dispose()'), isTrue);
      expect(controller.contains('_paginatorWorker?.dispose()'), isTrue);
    });

    test('the screen asks for the next page and can be pulled to refresh', () {
      expect(screen.contains('LoadMoreListener'), isTrue);
      expect(screen.contains('LoadMoreIndicator'), isTrue);
      expect(screen.contains('RefreshIndicator'), isTrue);
      expect(screen.contains('controller.loadMoreReviews'), isTrue);
      expect(screen.contains('controller.refreshReviews'), isTrue);
    });

    test('the row count leaves room for the load-more row', () {
      expect(screen.contains('controller.ratingList.length + (controller.hasMoreReviews ? 1 : 0)'), isTrue);
    });

    test('the query carries no orderBy', () {
      // An orderBy here would need a new composite index, and - because
      // Firestore drops documents that lack the ordering field - would hide
      // every review written before that field existed.
      final int start = store.indexOf('static Query<Map<String, dynamic>> vendorReviewsQuery');
      expect(start, greaterThan(-1));
      final String body = store.substring(start, store.indexOf('}', start));
      expect(body.contains('orderBy'), isFalse);
    });
  });

  group('no list screen reads a whole collection', () {
    /// Screens whose list is Firestore-backed but deliberately not paged.
    ///
    /// Each entry is a decision, not a shrug - a screen only belongs here when
    /// the whole set is genuinely needed, or when the gap is known and has not
    /// been approved for a fix yet.
    const Map<String, String> exempt = <String, String>{
      // The wallet totals are derived from the entire transaction history, so
      // this one list is deliberately not paged. See the session 1 notes.
      'lib/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart':
          'paged, but also derives totals',

      // Live ride state, not a history list: the lists these build are map
      // markers, vehicle types, the current ride's bid offers and coupons, and
      // the Firestore reads behind them are single-document listeners on the
      // ride and its driver. There is no collection here to page.
      'lib/screen_ui/cab_service_screens/cab_booking_screen.dart': 'live ride state',
      'lib/screen_ui/cab_service_screens/intercity_home_screen.dart': 'live ride state',
    };

    // Session 19's finding C-2 - the favourites screen reading its whole set -
    // is fixed, so its exemption is gone. Both favourite lists are paged by
    // `FirestorePaginator` now; `session23_speed_test.dart` holds the detail.

    /// Screens whose list is a **bounded configuration set**, where showing all
    /// of it is the feature.
    ///
    /// These are separated from `exempt` on purpose. A category strip that
    /// paged would be a bug, not a fix: the customer is meant to see every
    /// category. Measured against the live project each of these is small and
    /// stays small, because the admin - not the customer - creates the rows.
    ///
    /// | collection | live rows |
    /// |---|---|
    /// | sections | 16 |
    /// | vendor_categories | 27 |
    /// | vehicle_type | 17 |
    /// | brands | 17 |
    /// | banner_items | 26 |
    /// | coupons | 28 |
    /// | advertisements | 34 |
    /// | provider_categories | 7 |
    /// | parcel_categories | 12 |
    /// | rental_packages | 13 |
    /// | on_boarding | 15 |
    ///
    /// A screen belongs here only if its list is admin-authored. Anything the
    /// *customer* accumulates - orders, rides, bookings, favourites, wallet
    /// rows, reviews, chats - grows without bound and must page.
    const Set<String> boundedConfigLists = <String>{
      'lib/screen_ui/service_home_screen/service_list_screen.dart',
      'lib/screen_ui/multi_vendor_service/home_screen/home_screen.dart',
      'lib/screen_ui/multi_vendor_service/home_screen/home_screen_two.dart',
      'lib/screen_ui/multi_vendor_service/home_screen/view_all_category_screen.dart',
      'lib/screen_ui/multi_vendor_service/home_screen/category_restaurant_screen.dart',
      'lib/screen_ui/multi_vendor_service/home_screen/restaurant_list_screen.dart',
      'lib/screen_ui/multi_vendor_service/search_screen/search_screen.dart',
      'lib/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart',
      'lib/screen_ui/multi_vendor_service/cart_screen/cart_screen.dart',
      'lib/screen_ui/multi_vendor_service/cart_screen/coupon_list_screen.dart',
      'lib/screen_ui/multi_vendor_service/cashback_screen/cashback_offers_list.dart',
      'lib/screen_ui/multi_vendor_service/advertisement_screens/all_advertisement_screen.dart',
      'lib/screen_ui/multi_vendor_service/gift_card/gift_card_screen.dart',
      'lib/screen_ui/multi_vendor_service/gift_card/history_gift_card.dart',
      'lib/screen_ui/multi_vendor_service/dine_in_screeen/dine_in_screen.dart',
      'lib/screen_ui/multi_vendor_service/dine_in_screeen/dine_in_details_screen.dart',
      'lib/screen_ui/multi_vendor_service/dine_in_screeen/dine_in_restaurant_list_screen.dart',
      'lib/screen_ui/multi_vendor_service/dine_in_screeen/book_table_screen.dart',
      'lib/screen_ui/multi_vendor_service/dine_in_screeen/view_all_category_dine_in_screen.dart',
      'lib/screen_ui/multi_vendor_service/dine_in_booking/dine_in_booking_screen.dart',
      'lib/screen_ui/multi_vendor_service/order_list_screen/order_details_screen.dart',
      'lib/screen_ui/multi_vendor_service/rate_us_screen/rate_product_screen.dart',
      'lib/screen_ui/ecommarce/home_e_commerce_screen.dart',
      'lib/screen_ui/ecommarce/all_brand_product_screen.dart',
      'lib/screen_ui/ecommarce/all_category_product_screen.dart',
      'lib/screen_ui/location_enable_screens/address_list_screen.dart',
      'lib/screen_ui/cab_service_screens/cab_home_screen.dart',
      'lib/screen_ui/cab_service_screens/cab_coupon_code_screen.dart',
      'lib/screen_ui/parcel_service/home_parcel_screen.dart',
      'lib/screen_ui/parcel_service/parcel_coupon_screen.dart',
      'lib/screen_ui/parcel_service/parcel_order_details.dart',
      'lib/screen_ui/rental_service/rental_home_screen.dart',
      'lib/screen_ui/rental_service/rental_coupon_screen.dart',
      'lib/screen_ui/on_demand_service/on_demand_home_screen.dart',
      'lib/screen_ui/on_demand_service/on_demand_category_screen.dart',
      'lib/screen_ui/on_demand_service/on_demand_details_screen.dart',
      'lib/screen_ui/on_demand_service/on_demand_booking_screen.dart',
      'lib/screen_ui/on_demand_service/on_demand_order_details_screen.dart',
      'lib/screen_ui/on_demand_service/provider_screen.dart',
      'lib/screen_ui/on_demand_service/favourite_ondemand_screen.dart',
      'lib/screen_ui/on_demand_service/view_all_popular_service_screen.dart',
      'lib/screen_ui/on_demand_service/view_category_service_screen.dart',
    };

    /// Maps every `GetxController` subclass to the file that declares it, so a
    /// screen can be judged together with the controller that feeds it.
    Map<String, String> controllerSources(Map<String, String> sources) {
      final Map<String, String> byName = <String, String>{};
      final RegExp declaration = RegExp(r'class\s+(\w+)\s+extends\s+GetxController');
      sources.forEach((String path, String source) {
        for (final RegExpMatch match in declaration.allMatches(source)) {
          byName[match.group(1)!] = path;
        }
      });
      return byName;
    }

    test('every Firestore-backed list screen pages', () {
      // Read the whole package once; the checks below all work off this.
      final Map<String, String> sources = <String, String>{};
      for (final FileSystemEntity entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        sources[entity.path] = entity.readAsStringSync();
      }
      final Map<String, String> controllers = controllerSources(sources);

      const List<String> lazyLists = <String>[
        'ListView.builder',
        'ListView.separated',
        'GridView.builder',
      ];
      const List<String> pagingMarkers = <String>[
        'LoadMoreListener',
        'FirestorePaginator',
        'FirestorePagination', // the bundled package widget
      ];

      final List<String> offenders = <String>[];
      final RegExp controllerReference = RegExp(r'\b(\w+Controller)\b');

      sources.forEach((String path, String screen) {
        if (exempt.containsKey(path)) return;
        if (boundedConfigLists.contains(path)) return;
        if (!lazyLists.any(screen.contains)) return;

        // The screen AND every controller it names are judged as one unit.
        //
        // This is the whole point of the rewrite. The old version asked
        // whether the *screen file* contained `.get()` or `.snapshots()`, and
        // skipped it when it did not - but every screen here delegates its
        // fetching to a controller, so almost nothing was ever examined. On a
        // 9-screen app it reported "1 paged, 0 unpaged" and would have waved
        // through any new screen that loaded a whole collection.
        final List<String> unit = <String>[screen];
        for (final RegExpMatch match in controllerReference.allMatches(screen)) {
          final String? source = controllers[match.group(1)];
          if (source != null) unit.add(sources[source]!);
        }

        // A screen reaches Firestore whether it says `.get()` itself or - far
        // more often in this app - hands the job to `FireStoreUtils`.
        //
        // The narrower test that looked only for the literal `.get()` and
        // `.snapshots()` waved through every screen whose controller delegates,
        // which is nearly all of them: the search screen loaded all 628
        // products this way and was never examined. Counting a `FireStoreUtils.`
        // call as a read is what closes that.
        final bool readsFirestore = unit.any(
          (String s) => s.contains('.snapshots()') || s.contains('.get()') || s.contains('FireStoreUtils.'),
        );
        if (!readsFirestore) return;

        final bool paged = unit.any((String s) => pagingMarkers.any(s.contains));
        if (!paged) offenders.add(path);
      });

      expect(
        offenders,
        isEmpty,
        reason: 'these list screens reach Firestore without paging:\n  '
            '${offenders.join('\n  ')}\n'
            'Either page the list, or add it to `exempt` with the reason.',
      );
    });

    test('the exempt list has no stale entries', () {
      // An exemption that outlives the screen it describes is a lie the next
      // person has to disprove.
      for (final String path in exempt.keys) {
        expect(File(path).existsSync(), isTrue, reason: '$path no longer exists; drop it from `exempt`');
      }
      for (final String path in boundedConfigLists) {
        expect(File(path).existsSync(), isTrue, reason: '$path no longer exists; drop it from `boundedConfigLists`');
      }
    });

    test('nothing the customer accumulates is treated as bounded config', () {
      // The distinction the two lists rest on: an admin-authored list may be
      // shown whole, a customer-accumulated one may not. This catches the
      // mistake of parking a growing history in `boundedConfigLists` to make
      // the check above go quiet.
      const List<String> customerHistoryScreens = <String>[
        'lib/screen_ui/multi_vendor_service/order_list_screen/order_screen.dart',
        'lib/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart',
        'lib/screen_ui/multi_vendor_service/favourite_screens/favourite_screen.dart',
        'lib/screen_ui/multi_vendor_service/review_list_screen/review_list_screen.dart',
        'lib/screen_ui/cab_service_screens/my_cab_booking_screen.dart',
        'lib/screen_ui/cab_service_screens/my_bids_screen.dart',
        'lib/screen_ui/cab_service_screens/available_trips_screen.dart',
        'lib/screen_ui/on_demand_service/my_booking_on_demand_screen.dart',
        'lib/screen_ui/parcel_service/my_booking_screen.dart',
        'lib/screen_ui/rental_service/my_rental_booking_screen.dart',
      ];
      for (final String path in customerHistoryScreens) {
        expect(boundedConfigLists.contains(path), isFalse, reason: '$path is a growing list; it must page, not be exempted');
        expect(File(path).readAsStringSync().contains('LoadMoreListener'), isTrue, reason: '$path must page');
      }
    });
  });
}
