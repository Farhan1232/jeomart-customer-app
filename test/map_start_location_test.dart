import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:customer/utils/map_start_location.dart';

/// "When the map page is open then instantly the map should be open and current
/// location of the driver and customer should be visible."
///
/// The reason it was not: `FlutterMap.initialCenter` and
/// `GoogleMap.initialCameraPosition` are read **once**, at first build, and a
/// high-accuracy GPS fix is not available that early. The customer map fell
/// back to `41.4219057, -102.0840772` — a field in Nebraska — and the driver's
/// to `21.18, 72.84`, Surat. Neither then moved.
///
/// These tests pin the resolver that now supplies a real coordinate before the
/// first frame, without ever waiting for a fix.
void main() {
  MapStartLocationStore storeWith(String saved, {List<String>? writes}) {
    return MapStartLocationStore(
      read: (String key) => key == MapStartLocationStore.key ? saved : '',
      write: (String key, String value) async => writes?.add('$key=$value'),
    );
  }

  Position position(double lat, double lng) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime(2026, 9, 7),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  group('what counts as a usable coordinate', () {
    test('a real one is usable', () {
      expect(MapStartLocationStore.isUsable(33.5651, 71.4328), isTrue);
    });

    test('null island is not — it is what an uninitialised LatLng reads as', () {
      expect(MapStartLocationStore.isUsable(0, 0), isFalse);
    });

    test('nulls, infinities and out-of-range values are not', () {
      expect(MapStartLocationStore.isUsable(null, 10), isFalse);
      expect(MapStartLocationStore.isUsable(10, null), isFalse);
      expect(MapStartLocationStore.isUsable(double.nan, 10), isFalse);
      expect(MapStartLocationStore.isUsable(double.infinity, 10), isFalse);
      expect(MapStartLocationStore.isUsable(91, 10), isFalse);
      expect(MapStartLocationStore.isUsable(10, 181), isFalse);
    });

    test('a real coordinate with a zero component is still usable', () {
      expect(MapStartLocationStore.isUsable(0, 71.4328), isTrue, reason: 'the equator is a place');
      expect(MapStartLocationStore.isUsable(33.5651, 0), isTrue, reason: 'the prime meridian is a place');
    });
  });

  group('resolution order', () {
    test('a live position this session wins', () async {
      final MapStartLocation start = await resolveMapStart(
        store: storeWith('31.5204,74.3587'),
        liveLatitude: 33.5651,
        liveLongitude: 71.4328,
        lastKnown: () async => position(1, 1),
      );
      expect(start.source, MapStartSource.live);
      expect(start.latitude, 33.5651);
    });

    test('with no live position, the one saved last run is used', () async {
      final MapStartLocation start = await resolveMapStart(
        store: storeWith('31.5204,74.3587'),
        lastKnown: () async => position(1, 1),
      );
      expect(start.source, MapStartSource.saved);
      expect(start.latitude, 31.5204);
      expect(start.longitude, 74.3587);
    });

    test('with nothing saved, the platform last-known position is used', () async {
      final MapStartLocation start = await resolveMapStart(
        store: storeWith(''),
        lastKnown: () async => position(33.5651, 71.4328),
      );
      expect(start.source, MapStartSource.lastKnown);
      expect(start.latitude, 33.5651);
    });

    test('with nothing at all it falls back, and says so', () async {
      final MapStartLocation start = await resolveMapStart(
        store: storeWith(''),
        lastKnown: () async => null,
      );
      expect(start.source, MapStartSource.fallback);
      expect(start.isReal, isFalse);
    });

    test('the fallback is not a plausible city — a wrong city is the bug', () async {
      final MapStartLocation start = await resolveMapStart(store: storeWith(''));
      // The two coordinates this replaces.
      expect(start.latitude, isNot(41.4219057), reason: 'Nebraska');
      expect(start.longitude, isNot(-102.0840772), reason: 'Nebraska');
      expect(start.latitude, isNot(21.18), reason: 'Surat');
      expect(start.latitude, isNot(23.0225), reason: 'Ahmedabad');
    });

    test('a live 0,0 is ignored rather than centring on the Atlantic', () async {
      final MapStartLocation start = await resolveMapStart(
        store: storeWith('31.5204,74.3587'),
        liveLatitude: 0,
        liveLongitude: 0,
      );
      expect(start.source, MapStartSource.saved);
    });

    test('a last-known lookup that throws does not break the map', () async {
      final MapStartLocation start = await resolveMapStart(
        store: storeWith(''),
        lastKnown: () async => throw Exception('permission denied'),
      );
      expect(start.source, MapStartSource.fallback);
    });

    test('it never waits for a GPS fix — only the callbacks given are consulted', () async {
      var called = 0;
      await resolveMapStart(
        store: storeWith(''),
        lastKnown: () async {
          called++;
          return null;
        },
      );
      expect(called, 1, reason: 'getLastKnownPosition reads a cache; it does not request a fix');
    });
  });

  group('persisting a fix', () {
    test('a real fix is written so the next cold start opens on it', () async {
      final List<String> writes = <String>[];
      await storeWith('', writes: writes).remember(33.5651, 71.4328);
      expect(writes, <String>['${MapStartLocationStore.key}=33.5651,71.4328']);
    });

    test('an unusable fix is not written', () async {
      final List<String> writes = <String>[];
      final MapStartLocationStore store = storeWith('', writes: writes);
      await store.remember(0, 0);
      await store.remember(null, null);
      await store.remember(double.nan, 10);
      expect(writes, isEmpty);
    });

    test('a write that fails is swallowed — a cache must not break the screen', () async {
      final MapStartLocationStore store = MapStartLocationStore(
        read: (_) => '',
        write: (_, __) async => throw Exception('disk full'),
      );
      await expectLater(store.remember(33.5651, 71.4328), completes);
    });

    test('what is written is read back identically', () async {
      final List<String> writes = <String>[];
      await storeWith('', writes: writes).remember(31.5204, 74.3587);
      final String saved = writes.single.split('=')[1];
      final MapStartLocation? back = storeWith(saved).saved();
      expect(back, isNotNull);
      expect(back!.latitude, 31.5204);
      expect(back.longitude, 74.3587);
    });

    test('a corrupt saved value is ignored rather than parsed into a wrong place', () {
      for (final String bad in <String>['', 'x', '1', '1,2,3', 'abc,def', '0,0', '999,999']) {
        expect(storeWith(bad).saved(), isNull, reason: 'saved value "$bad"');
      }
    });
  });
}
