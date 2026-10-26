import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Session 36 - the customer app's remaining waits, queues and leaks.
///
/// Source-level guards in the house style: every screen and controller here
/// builds Firebase listeners, so they are pinned by shape rather than pumped.
/// Each change is a speed change only - the same reads, the same values, the
/// same order of effects - and these tests are what keep it that way.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Source with comment lines dropped, so a comment quoting old code is not
  /// mistaken for the code.
  String code(String source) => source
      .split('\n')
      .where((String line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  /// The text of the member that starts with [signature], up to the next
  /// member at the same indentation.
  String bodyOf(String source, String signature) {
    final int start = source.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature is missing');
    final RegExp next = RegExp(r'\n  (static |Future<|void |bool |String |Widget |@override)');
    final Match? end = next.firstMatch(source.substring(start + signature.length));
    return end == null ? source.substring(start) : source.substring(start, start + signature.length + end.start);
  }

  group('payment settings', () {
    test('all thirteen documents are requested together and applied in the original order', () {
      final String body = bodyOf(code(read('lib/service/fire_store_utils.dart')), 'static Future getPaymentSettingsData() async {');

      expect(body, contains('await Parallel.applyInOrder<String, DocumentSnapshot<Map<String, dynamic>>>('));
      expect(body.contains('await fireStore.collection(CollectionName.settings).doc('), isFalse,
          reason: 'thirteen consecutive awaits were thirteen round trips in series');

      const List<String> order = <String>[
        'payFastSettings', 'MercadoPago', 'paypalSettings', 'stripeSettings', 'flutterWave', 'payStack', 'PaytmSettings',
        'walletSettings', 'razorpaySettings', 'CODSettings', 'midtrans_settings', 'orange_money_settings', 'xendit_settings',
      ];
      int last = -1;
      for (final String id in order) {
        final int at = body.indexOf('"$id": (DocumentSnapshot<Map<String, dynamic>> value) async {');
        expect(at, greaterThan(last), reason: '$id is missing or out of order');
        last = at;
      }
    });
  });

  group('the service picker', () {
    test('the tax lookup starts with the tap, and is applied where it always was', () {
      final String source = code(read('lib/controllers/service_list_controller.dart'));
      final int started = source.indexOf('final Future<List<TaxModel>?> taxReq = FireStoreUtils.getTaxList(sectionModel.id);');
      final int profile = source.indexOf('await FireStoreUtils.getUserProfile(uid);');

      expect(started, greaterThan(-1));
      expect(started, lessThan(profile), reason: 'it used to wait behind the profile read, the token and the write');
      expect('await _navigate(sectionModel, taxReq);'.allMatches(source).length, 2);

      final String navigate = source.substring(source.indexOf('Future<void> _navigate('));
      expect(navigate, contains('await taxReq.then((value) {'));
      expect(navigate.contains('FireStoreUtils.getTaxList('), isFalse, reason: 'read once per tap, not twice');
    });
  });

  group('nearby store streams', () {
    test('each call owns its controller and stops its geohash query with its listener', () {
      final String store = code(read('lib/service/fire_store_utils.dart'));

      expect(store.contains('static StreamController<List<VendorModel>>?'), isFalse,
          reason: 'a shared static controller let an old query feed the newest screen');
      for (final String signature in <String>[
        'static Stream<List<VendorModel>> getAllNearestRestaurantByCategoryId(',
        'static Stream<List<VendorModel>> getAllNearestRestaurant(',
      ]) {
        final String body = bodyOf(store, signature);
        expect(body, contains('final StreamController<List<VendorModel>> vendors = StreamController<List<VendorModel>>.broadcast();'));
        expect(body, contains('late final StreamSubscription<List<DocumentSnapshot>> geoQuery;'));
        expect(body, contains('geoQuery = stream.listen('));
        expect(body, contains('vendors.onCancel = () {\n        stopLive();\n        vendors.close();'));
        expect(body, contains('geoQuery.cancel();'));
        // ANR round 2: the listeners stop once the server's list has arrived,
        // or after the live window at most.
        expect(body, contains('if (fromServer) stopLive();'));
        expect(body, contains('liveWindow = Timer(_vendorListLiveWindow, stopLive);'));
        expect(body, contains('if (!vendors.isClosed) vendors.sink.add(vendorList);'));
        expect(body, contains('yield* vendors.stream;'));
      }
    });
  });

  group('e-commerce home', () {
    test('a category card reads its products once per visit, not once per rebuild', () {
      final String screen = code(read('lib/screen_ui/ecommarce/home_e_commerce_screen.dart'));
      expect(screen, contains('future: controller.productsForCategory(item.id.toString()),'));
      expect(screen.contains('FireStoreUtils.getProductListByCategoryId('), isFalse);

      final String controller = code(read('lib/controllers/home_e_commerce_controller.dart'));
      expect(controller, contains('final Map<String, Future<List<ProductModel>>> _categoryProducts'));
      expect(controller, contains('FireStoreUtils.getProductListByCategoryId(categoryId, storeProducts: storeProducts)'));
    });

    test('store products are read once for all cards, every store at once, in store order', () {
      final String store = code(read('lib/service/fire_store_utils.dart'));
      final String body = bodyOf(store, 'static Future<List<ProductModel>> getStoreProducts() async {');

      expect(body, contains('await Future.wait(<Future<List<ProductModel>>>[for (var vendor in vendorList) getAllProducts(vendor!.id.toString())]);'));
      expect(body.contains('await getAllProducts('), isFalse, reason: 'one store at a time was a round trip per store in series');
      expect(body, contains('for (int index = 0; index < vendorList.length; index++) {'));

      final String byCategory = bodyOf(store, 'static Future<List<ProductModel>> getProductListByCategoryId(');
      expect(byCategory, contains('await (storeProducts ?? getStoreProducts());'));
    });
  });

  group('the intercity ride screen', () {
    test('a profile snapshot resolves the in-progress rides only when they changed', () {
      final String source = code(read('lib/controllers/intercity_home_controller.dart'));

      expect(source, contains('if (inProgressKey == _resolvedInProgressKey) return;'));
      expect(source.indexOf('_resolvedInProgressKey = inProgressKey;'), greaterThan(source.indexOf('for (String id in userModel.value.inProgressOrderID!) {')),
          reason: 'recorded after resolving, so a failed read is retried on the next snapshot');
      expect(source, contains('if (validRideId != null && validRideId == _watchedRideId && _rideSub != null) return;'));
      expect(source.contains('.doc(validRideId).snapshots()'), isFalse, reason: 'no listener on doc(null)');
      expect(source, contains('_resolvedInProgressKey = null;'));
    });

    test('the driver listener is reopened only for a different driver', () {
      final String source = code(read('lib/controllers/intercity_home_controller.dart'));

      expect(source, contains('} else if (driverId != _watchedDriverId || _driverSub == null) {'));
      expect(source, contains('unawaited(updateDriverRoute(driverModel.value));'),
          reason: 'what the reopened listener used to redraw for a new ride status');
      expect(source.contains('print("Current Ride Status: \$status");'), isFalse);
    });

    test('the route is refetched only when it can have changed, and the markers are redrawn every time', () {
      final String source = code(read('lib/controllers/intercity_home_controller.dart'));
      final String body = bodyOf(source, 'Future<void> updateDriverRoute(UserModel driverModel) async {');

      expect(body, contains("final String routeKey = '\${order.id}|\${order.status}|\${driverLat.toStringAsFixed(3)},\${driverLng.toStringAsFixed(3)}';"));
      expect(body.indexOf('routePoints.clear();'), greaterThan(body.indexOf('if (fetchRoute) {')));
      expect('updateRouteMarkers(driverModel);'.allMatches(body).length, 2);
      expect(body, contains('if (routePoints.isEmpty) _driverRouteKey = null;'));
    });

    test('route marker images are decoded and downloaded once', () {
      final String source = code(read('lib/controllers/intercity_home_controller.dart'));

      expect(source, contains("_routeDepartureIcon ??= BitmapDescriptor.fromBytes(await Constant().getBytesFromAsset('assets/images/location_black3x.png', 50));"));
      expect(source, contains('if (_routeTaxiIcon == null || _routeTaxiIconSource != markerIcon) {'));
      expect(source, contains('taxiIcon = _routeTaxiIcon;'));
      expect(source.contains('log("=======>\$data");'), isFalse);
    });
  });

  group('the booking maps', () {
    test('nearby vehicle markers are swapped in with one assignment', () {
      final String body = bodyOf(code(read('lib/controllers/cab_booking_controller.dart')), 'Future<void> updateNearbyDriverMarkers() async {');

      expect(body, contains('markers.assignAll(next);'));
      expect(body.contains('markers.add('), isFalse);
      expect(body.contains('markers.removeWhere('), isFalse);
      expect(code(read('lib/controllers/cab_booking_controller.dart')).contains('log("=======>\$data");'), isFalse);
    });

    test('the confirm sheet uses the screen\'s controller instead of building another', () {
      for (final MapEntry<String, String> screen in <String, String>{
        'lib/screen_ui/cab_service_screens/cab_booking_screen.dart': 'CabBookingController',
        'lib/screen_ui/cab_service_screens/intercity_home_screen.dart': 'IntercityHomeController',
      }.entries) {
        final String source = code(read(screen.key));
        expect(source, contains('    return GetX(\n      init: ${screen.value}('), reason: 'the screen still registers it');
        expect(source, contains('          return GetX<${screen.value}>(\n            builder: (controller) {'));
        expect(source.contains('            init: ${screen.value}(),'), isFalse, reason: screen.key);
      }
    });
  });

  group('timers', () {
    test('photo slider timers are cancelled with their card or page', () {
      final String view = code(read('lib/widget/restaurant_image_view.dart'));
      expect(view, contains('_slideTimer = Timer.periodic('));
      expect(view, contains('_slideTimer?.cancel();\n    pageController.dispose();'));

      for (final String path in <String>[
        'lib/controllers/restaurant_details_controller.dart',
        'lib/controllers/dine_in_restaurant_details_controller.dart',
      ]) {
        final String source = code(read(path));
        expect(source, contains('_slideTimer = Timer.periodic('), reason: path);
        expect(source, contains('void onClose() {\n    _slideTimer?.cancel();'), reason: path);
      }
    });
  });

  group('independent reads', () {
    test('the parcel home reads its banners and categories together', () {
      final String source = code(read('lib/controllers/home_parcel_controller.dart'));
      expect(source, contains('await Future.wait(<Future<void>>['));
      expect(source.contains('await FireStoreUtils.getHomeTopBanner()'), isFalse);
      expect(source.contains('await FireStoreUtils.getParcelServiceCategory()'), isFalse);
    });

    test('order details start the driver and the review together, and apply them in order', () {
      for (final String path in <String>[
        'lib/controllers/cab_order_details_controller.dart',
        'lib/controllers/rental_order_details_controller.dart',
      ]) {
        final String source = code(read(path));
        final int review = source.indexOf('final reviewReq = FireStoreUtils.getReviewsbyID(');
        final int driver = source.indexOf('await driverReq.then((value) {');
        expect(review, greaterThan(-1), reason: path);
        expect(review, lessThan(driver), reason: path);
        expect(driver, lessThan(source.indexOf('await reviewReq.then((value) {')), reason: path);
      }
      expect(code(read('lib/controllers/cab_order_details_controller.dart')).contains('print(driverUser.value.toJson());'), isFalse);
    });

    test('dine-in bookings start both lists together, and apply them in order', () {
      final String source = code(read('lib/controllers/dine_in_booking_controller.dart'));
      final int history = source.indexOf('final historyReq = FireStoreUtils.getDineInBooking(false);');
      expect(history, greaterThan(-1));
      expect(history, lessThan(source.indexOf('await featureReq.then(')));
      expect(source.indexOf('await featureReq.then('), lessThan(source.indexOf('await historyReq.then(')));
    });
  });

  group('notifications', () {
    test('booking a trip does not hold the tab switch for the driver\'s push', () {
      final String source = code(read('lib/controllers/available_trips_controller.dart'));
      final int detached = source.indexOf('unawaited(() async {');
      final int notify = source.indexOf('await DriverTripService.notifyDriverOfReservation(trip);');
      expect(detached, greaterThan(-1));
      expect(detached, lessThan(notify));
    });

    test('concurrent sends share one token request, and tokens and bodies stay out of release logs', () {
      final String source = code(read('lib/service/send_notification.dart'));
      expect(source, contains('final Future<String> inFlight = _accessTokenInFlight ??= _fetchAccessToken();'));
      expect(source, contains('_accessTokenInFlight = null;'));

      final List<String> lines = source.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('debugPrint(accessToken);') || lines[i].contains('debugPrint(response.body);')) {
          final String before = lines.sublist(i - 3 < 0 ? 0 : i - 3, i).join('\n');
          expect(before, contains('if (kDebugMode) {'), reason: 'line ${i + 1}');
        }
      }
    });
  });

  group('images', () {
    test('oversized GIFs are decoded near their display size', () {
      const Map<String, String> sites = <String, String>{
        'lib/screen_ui/multi_vendor_service/dine_in_screeen/dine_in_screen.dart': 'Image.asset("assets/images/location.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/multi_vendor_service/home_screen/home_screen_two.dart': 'Image.asset("assets/images/location.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/multi_vendor_service/home_screen/home_screen.dart': 'Image.asset("assets/images/location.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/on_demand_service/on_demand_home_screen.dart': 'Image.asset("assets/images/location.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/multi_vendor_service/favourite_screens/favourite_screen.dart': 'Image.asset("assets/images/login.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart': 'Image.asset("assets/images/login.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/multi_vendor_service/order_list_screen/order_screen.dart': 'Image.asset("assets/images/login.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/on_demand_service/favourite_ondemand_screen.dart': 'Image.asset("assets/images/login.gif", height: 120, cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round())',
        'lib/screen_ui/multi_vendor_service/cart_screen/oder_placing_screens.dart': 'Image.asset("assets/images/ic_timer.gif", height: 140, cacheHeight: (140 * MediaQuery.devicePixelRatioOf(context)).round())',
      };
      sites.forEach((String path, String expected) {
        expect(code(read(path)), contains(expected), reason: path);
      });

      final String profile = code(read('lib/screen_ui/multi_vendor_service/profile_screen/profile_screen.dart'));
      expect(profile, contains("Image.asset('assets/images/ic_logout.gif', height: 50, width: 50, cacheWidth: (50 * MediaQuery.devicePixelRatioOf(context)).round())"));
      expect(profile, contains("Image.asset('assets/icons/delete_dialog.gif', height: 50, width: 50, cacheWidth: (50 * MediaQuery.devicePixelRatioOf(context)).round())"));

      final String store = code(read('lib/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart'));
      expect(store, contains('ResizeImage(const AssetImage("assets/images/offer_gif.gif"), width: (120 * MediaQuery.devicePixelRatioOf(context)).round())'));
      expect(store, contains('Image.asset("assets/images/ic_table.gif", cacheHeight: (60 * MediaQuery.devicePixelRatioOf(context)).round())'));
    });
  });

  group('logging on hot paths', () {
    test('whole documents are no longer stringified per row, per slot or per send', () {
      final String store = code(read('lib/service/fire_store_utils.dart'));
      expect(store.contains('print(value.docs.first.data());'), isFalse);
      expect(store.contains('Rental Package Data:'), isFalse);
      expect(store.contains('":: isExpireDate(expiryDay ::'), isFalse);

      final String details = bodyOf(code(read('lib/controllers/restaurant_details_controller.dart')), 'bool isCurrentDateInRange(');
      expect(details.contains('print('), isFalse);

      expect(code(read('lib/screen_ui/multi_vendor_service/chat_screens/driver_inbox_screen.dart')).contains('inboxModel.toJson()'), isFalse);
    });
  });
}
