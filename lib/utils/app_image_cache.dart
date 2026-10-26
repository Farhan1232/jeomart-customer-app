import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The image cache the whole customer app draws through.
///
/// ## The problem it solves
///
/// Firebase Storage serves every uploaded image on this project with
///
/// ```
/// cache-control: private, max-age=0
/// ```
///
/// `flutter_cache_manager` honours that header literally: it computes
/// `validTill = now + max-age`, so every photo is stale the instant it lands.
/// The file is still written to disk and still shown from disk on the next
/// visit - the picture is not slow to appear - but the manager also re-fetches
/// it **every single time** to revalidate.
///
/// On the home screen that is 45 vendor photographs, measured at 65-286 KB each
/// (one is 1.8 MB), so roughly 4 MB is pulled down again on every entry to a
/// section and again on every trip back to it. On a phone on mobile data those
/// downloads compete with the Firestore reads the same screen is waiting for,
/// which is why re-entering a section felt slower than opening it the first
/// time.
///
/// ## What this changes
///
/// Nothing about which image is shown, its size, or its quality. Only how long
/// a downloaded copy is trusted:
///
/// * a real `max-age` from the server is still obeyed, unchanged;
/// * a **zero or missing** `max-age` - which is every image on this project -
///   is treated as [_assumedFreshness] instead of "already stale".
///
/// The `eTag` is passed through untouched, so once the period does lapse the
/// manager still revalidates and still gets a `304` for an unchanged file. An
/// image the admin replaces is picked up on the next lapse, or immediately for
/// any device that has never seen the old one.
class AppImageCache {
  AppImageCache._();

  /// Cache key for the manager's own store.
  static const String _cacheKey = 'jeomartImageCache';

  /// How long a copy is trusted when the server declines to say.
  ///
  /// Deliberately shorter than the 30 days `flutter_cache_manager` uses for its
  /// own default: vendor photographs, banners and adverts are things the admin
  /// edits, and a week is long enough to make browsing free without making an
  /// edit invisible for a month.
  static const Duration _assumedFreshness = Duration(days: 7);

  /// How long an untouched file is kept before the store evicts it.
  static const Duration _stalePeriod = Duration(days: 30);

  /// The most files kept on disk at once.
  static const int _maxObjects = 800;

  static CacheManager? _instance;

  static CacheManager get manager {
    return _instance ??= CacheManager(
      Config(
        _cacheKey,
        stalePeriod: _stalePeriod,
        maxNrOfCacheObjects: _maxObjects,
        fileService: _FreshnessFloorFileService(),
      ),
    );
  }

  /// Test seam. Lets a test install a manager without touching the disk.
  static set manager(CacheManager value) => _instance = value;

  /// The freshness a response should be given, given what the server said.
  ///
  /// Pulled out as a pure function so it can be tested without a network.
  /// Returns [serverValidTill] when the server asked for a future time, and
  /// `now + `[_assumedFreshness] when it asked for now or the past.
  static DateTime freshnessFor(DateTime serverValidTill, {DateTime? now}) {
    final at = now ?? DateTime.now();
    if (serverValidTill.isAfter(at)) return serverValidTill;
    return at.add(_assumedFreshness);
  }
}

/// Wraps [HttpFileService] and raises a zero freshness to a usable one.
class _FreshnessFloorFileService extends FileService {
  _FreshnessFloorFileService() : _inner = HttpFileService();

  final HttpFileService _inner;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final response = await _inner.get(url, headers: headers);
    return _FreshnessFloorResponse(response);
  }
}

/// Delegates everything to the real response except [validTill].
class _FreshnessFloorResponse implements FileServiceResponse {
  _FreshnessFloorResponse(this._inner);

  final FileServiceResponse _inner;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  int get statusCode => _inner.statusCode;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;

  @override
  DateTime get validTill => AppImageCache.freshnessFor(_inner.validTill);
}
