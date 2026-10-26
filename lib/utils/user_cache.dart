import 'package:customer/models/user_model.dart';

/// A small, short-lived in-memory cache for `users` documents.
///
/// The same profile was being re-read constantly: `getUserProfile()` is called
/// from ~50 places per app, including from inside list `itemBuilder`s, where a
/// rebuild issued a fresh document read for every visible row.
///
/// Deliberately modest:
///  * process-lifetime only - nothing is written to disk, so a stale profile
///    can never outlive the app session;
///  * short TTL, so anything that matters (wallet balance, active status)
///    refreshes on its own;
///  * cleared for a user as soon as that user is written, and cleared wholesale
///    on sign-out.
class UserCache {
  UserCache._();

  /// How long a cached profile is served before Firestore is asked again.
  static const Duration ttl = Duration(minutes: 2);

  static final Map<String, _Entry> _entries = <String, _Entry>{};

  static UserModel? get(String uid) {
    final entry = _entries[uid];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.at) > ttl) {
      _entries.remove(uid);
      return null;
    }
    return entry.user;
  }

  static void put(String uid, UserModel user) {
    _entries[uid] = _Entry(user, DateTime.now());
  }

  /// Call after any write to a user document.
  static void invalidate(String? uid) {
    if (uid == null) return;
    _entries.remove(uid);
  }

  /// Call on sign-out / account switch.
  static void clear() => _entries.clear();
}

class _Entry {
  _Entry(this.user, this.at);

  final UserModel user;
  final DateTime at;
}
