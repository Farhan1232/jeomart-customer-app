import 'dart:async';
import 'dart:developer';

/// A short-lived in-memory cache for the *configuration* reads the app repeats
/// on every screen entry.
///
/// ## Why this exists
///
/// The customer app is round-trip bound, not data bound. The live project holds
/// 45 vendors, 27 vendor categories, 17 brands, 8 attributes and 4 zones - all
/// of it tiny, none of it changing while somebody is shopping. But every one of
/// those collections is re-read from Firestore each time a screen is opened,
/// because a GetX controller created by `GetX(init: ...)` is disposed when its
/// route is popped and runs `onInit()` again when the route is pushed back.
///
/// `getZone()` was the clearest case: it is the **first** thing awaited by the
/// service list, the food home, the dine-in home, the on-demand home and the
/// category list. Nothing on screen can be drawn until it returns, and it
/// returns the same four documents every time. That is the round trip the
/// client was watching when they said the app "load all things again" on the
/// way back from a section.
///
/// ## What it deliberately is not
///
/// * **Not a persistence layer.** Nothing is written to disk, so a stale value
///   can never outlive the app session, and a fresh launch is always truthful.
/// * **Not long-lived.** The default TTL is two minutes - long enough to cover
///   a browse-and-come-back loop, short enough that an admin's change reaches a
///   running app without a restart.
/// * **Not a cache of user data.** Orders, rides, carts, wallets, chats and
///   profiles are never routed through here; they stay live. `UserCache` covers
///   `users` documents separately and with its own rules.
///
/// ## Two behaviours, both load-bearing
///
/// 1. **Memoisation** - a repeat read inside the TTL is served from memory.
/// 2. **In-flight de-duplication** - concurrent callers asking for the same key
///    share one request. This matters as much as the caching: opening a section
///    can start the home controller and the dashboard controller in the same
///    frame, and both call `getZone()`. Without this they make two identical
///    round trips and the screen waits for the slower one.
///
/// Empty results are held only briefly. Most of the read helpers in
/// `FireStoreUtils` swallow their errors and return an empty list, so an empty
/// value is indistinguishable from a failed read - pinning one for the full TTL
/// would turn one dropped packet into two minutes of an empty screen.
///
/// ## One thing to be careful of
///
/// A cached `List` is handed back **by reference**, so mutating it mutates what
/// every later caller sees for the rest of the TTL. Every current caller either
/// reads it (`for`, `.where`, `.map`) or hands it to an `RxList` via `.value =`
/// or `assignAll`, which is safe; the `clear()`/`addAll()` calls in the
/// controllers are all on the controller's *own* `RxList`, not on the list that
/// came out of here.
///
/// If you ever need to mutate one in place, copy it first
/// (`List<T>.of(cached)`), or the next screen will see your edit.
class FirestoreCache {
  FirestoreCache._();

  /// How long a normal (non-empty) value is served from memory.
  static const Duration defaultTtl = Duration(minutes: 2);

  /// How long an empty value is served from memory.
  ///
  /// Short on purpose: an empty list may be a failed read wearing a successful
  /// read's clothes. Long enough to still collapse the burst of duplicate calls
  /// a single screen entry makes.
  static const Duration emptyTtl = Duration(seconds: 15);

  static final Map<String, _Entry> _entries = <String, _Entry>{};
  static final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};

  /// Keys invalidated while a load for them was still in flight.
  ///
  /// Without this, a write that lands between a read starting and finishing
  /// would be undone in the cache: the read's completion writes the value it
  /// fetched *before* the write, and the invalidation that happened in between
  /// has nothing left to remove. A key listed here refuses to be cached when
  /// its in-flight load completes.
  static final Set<String> _staleInFlight = <String>{};

  /// Whether [value] should be held for [emptyTtl] rather than the full TTL.
  static bool _isEmpty(Object? value) {
    if (value == null) return true;
    if (value is Iterable) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    if (value is String) return value.isEmpty;
    return false;
  }

  /// Serves [key] from memory when it is fresh, otherwise runs [load].
  ///
  /// A caller arriving while [load] is already running for the same key waits on
  /// that same future instead of starting a second one.
  ///
  /// A throwing [load] is never cached: the failure propagates to every waiting
  /// caller and the next call tries again.
  static Future<T> remember<T>(String key, Future<T> Function() load, {Duration? ttl}) {
    final entry = _entries[key];
    if (entry != null) {
      if (DateTime.now().isBefore(entry.expiresAt)) {
        return Future<T>.value(entry.value as T);
      }
      _entries.remove(key);
    }

    final pending = _inFlight[key];
    if (pending != null) return pending.then((dynamic value) => value as T);

    final future = load()
        .then((T value) {
          if (!_staleInFlight.contains(key)) {
            _entries[key] = _Entry(value, DateTime.now().add(_isEmpty(value) ? emptyTtl : (ttl ?? defaultTtl)));
          }
          return value;
        })
        .whenComplete(() {
          _inFlight.remove(key);
          _staleInFlight.remove(key);
        });

    _inFlight[key] = future;
    return future;
  }

  /// Drops one key, so the next read goes to Firestore.
  ///
  /// Also marks a load already in flight for that key as not cacheable, so a
  /// read that started before a write cannot install its pre-write value after
  /// the write has happened.
  static void invalidate(String key) {
    _entries.remove(key);
    if (_inFlight.containsKey(key)) _staleInFlight.add(key);
  }

  /// Drops every key starting with [prefix].
  ///
  /// Used when the thing a family of keys is scoped by changes - picking a
  /// different section invalidates every `section:<id>:*` entry at once.
  static void invalidatePrefix(String prefix) {
    _entries.removeWhere((String key, _Entry value) => key.startsWith(prefix));
    for (final String key in _inFlight.keys) {
      if (key.startsWith(prefix)) _staleInFlight.add(key);
    }
  }

  /// Drops everything. Call on sign-out, sign-in and account switch.
  static void clear() {
    _entries.clear();
    _staleInFlight.addAll(_inFlight.keys);
    log('FirestoreCache cleared');
  }

  /// Test seam: how many values are currently held.
  static int get size => _entries.length;

  /// Test seam: whether [key] would be served from memory right now.
  static bool isFresh(String key) {
    final entry = _entries[key];
    return entry != null && DateTime.now().isBefore(entry.expiresAt);
  }
}

class _Entry {
  _Entry(this.value, this.expiresAt);

  final Object? value;
  final DateTime expiresAt;
}
