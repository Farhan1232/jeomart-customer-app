import 'dart:developer';

import 'package:geolocator/geolocator.dart';

/// Where a map should be centred the instant it is built.
///
/// The problem this solves: `FlutterMap.initialCenter` and
/// `GoogleMap.initialCameraPosition` are read **once**, when the widget is
/// first built. A high-accuracy GPS fix takes seconds on a cold start - tens of
/// seconds indoors - so the map was being built before any location existed and
/// fell back to a hardcoded coordinate. In this app that fallback was
/// `41.4219057, -102.0840772`, which is a field in **Nebraska, USA**; the driver
/// app's was `21.18, 72.84`, in **Surat, India**. Neither map then moved,
/// because nothing told it to.
///
/// So there are two halves to "the map opens on my location straight away":
///
/// 1. **Have a usable coordinate before the first frame.** That is [best],
///    which never waits for a GPS fix - it uses what is already in memory, then
///    what was saved on disk from last time, then the operating system's own
///    last-known position, which is returned immediately from cache.
/// 2. **Correct the map once the real fix lands.** `initialCenter` cannot do
///    that, so callers move the map controller when [remember] is called with a
///    genuine fix.
///
/// Kept free of Flutter and Firestore imports so both apps hold the same file
/// and it can be unit tested directly.
class MapStartLocation {
  const MapStartLocation({required this.latitude, required this.longitude, required this.source});

  final double latitude;
  final double longitude;

  /// Where the coordinate came from. Only used for logging and tests, but it is
  /// the difference between "we know where you are" and "this is a guess".
  final MapStartSource source;

  /// Whether this is a real position for *this* user rather than a placeholder.
  bool get isReal => source != MapStartSource.fallback;

  @override
  String toString() => 'MapStartLocation($latitude, $longitude, ${source.name})';
}

enum MapStartSource {
  /// Already held in memory this session.
  live,

  /// Saved by [MapStartLocationStore.remember] on a previous run.
  saved,

  /// The operating system's cached fix. Returned without waiting for GPS.
  lastKnown,

  /// Nothing was available. A neutral coordinate, deliberately not a real
  /// place, so it is obvious on screen that the location is not known yet.
  fallback,
}

/// The store [MapStartLocation] is read from and written to.
///
/// Backed by the app's existing `Preferences` through these two callbacks, so
/// this file needs no dependency on it and the tests need no SharedPreferences.
class MapStartLocationStore {
  MapStartLocationStore({required this.read, required this.write});

  final String Function(String key) read;
  final Future<void> Function(String key, String value) write;

  static const String key = 'lastKnownMapLocation';

  /// A coordinate that is valid to centre a map on.
  ///
  /// `0, 0` is rejected on purpose: it is Null Island in the Atlantic and is
  /// what an uninitialised `LatLng` reads as throughout this project, so it is
  /// far more likely to be "no value" than a real position.
  static bool isUsable(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (!lat.isFinite || !lng.isFinite) return false;
    if (lat == 0 && lng == 0) return false;
    return lat.abs() <= 90 && lng.abs() <= 180;
  }

  /// The saved position from a previous run, if there is a usable one.
  MapStartLocation? saved() {
    final String raw = read(key);
    if (raw.isEmpty) return null;
    final List<String> parts = raw.split(',');
    if (parts.length != 2) return null;
    final double? lat = double.tryParse(parts[0].trim());
    final double? lng = double.tryParse(parts[1].trim());
    if (!isUsable(lat, lng)) return null;
    return MapStartLocation(latitude: lat!, longitude: lng!, source: MapStartSource.saved);
  }

  /// Saves a real fix so the next cold start opens on it immediately.
  ///
  /// Deliberately silent on failure: not being able to write a convenience
  /// cache must never break the screen that produced the fix.
  Future<void> remember(double? lat, double? lng) async {
    if (!isUsable(lat, lng)) return;
    try {
      await write(key, '$lat,$lng');
    } catch (error) {
      log('MapStartLocationStore.remember failed :: $error');
    }
  }
}

/// Resolves the best coordinate available **without waiting for a GPS fix**.
///
/// [liveLatitude]/[liveLongitude] are whatever the app already holds this
/// session (`Constant.currentLocation`). [lastKnown] is
/// `Geolocator.getLastKnownPosition()`, which reads the platform's cache and
/// returns straight away - it is not a fix request and does not turn the GPS on.
Future<MapStartLocation> resolveMapStart({
  required MapStartLocationStore store,
  double? liveLatitude,
  double? liveLongitude,
  Future<Position?> Function()? lastKnown,
  MapStartLocation fallback = const MapStartLocation(
    // Deliberately mid-ocean rather than a plausible city: if this ever reaches
    // the screen it should look wrong, not look like somewhere the user might
    // be. A wrong city is the bug being fixed here.
    latitude: 0.0001,
    longitude: 0.0001,
    source: MapStartSource.fallback,
  ),
}) async {
  if (MapStartLocationStore.isUsable(liveLatitude, liveLongitude)) {
    return MapStartLocation(latitude: liveLatitude!, longitude: liveLongitude!, source: MapStartSource.live);
  }

  final MapStartLocation? fromDisk = store.saved();
  if (fromDisk != null) return fromDisk;

  if (lastKnown != null) {
    try {
      final Position? position = await lastKnown();
      if (position != null && MapStartLocationStore.isUsable(position.latitude, position.longitude)) {
        return MapStartLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          source: MapStartSource.lastKnown,
        );
      }
    } catch (error) {
      log('resolveMapStart: getLastKnownPosition failed :: $error');
    }
  }

  return fallback;
}
