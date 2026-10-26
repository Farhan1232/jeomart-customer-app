import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The `users/{id}` document as seen from inside a wallet update.
///
/// Kept behind this interface so the read-modify-write can be unit tested for
/// concurrency without a Firestore connection.
abstract class WalletDocument {
  /// Whether the user document exists.
  bool get exists;

  /// The `wallet_amount` field exactly as Firestore stores it.
  ///
  /// Deliberately untyped: production documents hold this field as a number in
  /// some rows and as a numeric string in others, and both have always been
  /// accepted.
  Object? get rawBalance;

  /// Queues the new balance. Only `wallet_amount` is written.
  void setBalance(double amount);
}

/// Runs one wallet update atomically.
///
/// The contract the implementation must honour: either [rawBalance] is still
/// the stored value when the queued write lands, or the whole body is run
/// again against the newer value. Nothing else about the document is touched.
abstract class WalletTransactionRunner {
  Future<T> run<T>(String userId, Future<T> Function(WalletDocument doc) body);
}

/// A [WalletTransactionRunner] backed by a real Firestore transaction.
class FirestoreWalletTransactionRunner implements WalletTransactionRunner {
  FirestoreWalletTransactionRunner(this.fireStore, {this.collection = 'users'});

  final FirebaseFirestore fireStore;
  final String collection;

  @override
  Future<T> run<T>(String userId, Future<T> Function(WalletDocument doc) body) {
    final DocumentReference<Map<String, dynamic>> ref = fireStore.collection(collection).doc(userId);
    return fireStore.runTransaction<T>((transaction) async {
      final snapshot = await transaction.get(ref);
      final document = _FirestoreWalletDocument(snapshot);
      final T result = await body(document);
      final double? pending = document.pending;
      if (pending != null) {
        transaction.update(ref, <String, dynamic>{WalletLedger.balanceField: pending});
      }
      return result;
    });
  }
}

class _FirestoreWalletDocument implements WalletDocument {
  _FirestoreWalletDocument(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;

  double? pending;

  @override
  bool get exists => _snapshot.exists;

  @override
  Object? get rawBalance => _snapshot.data()?[WalletLedger.balanceField];

  @override
  void setBalance(double amount) => pending = amount;
}

/// Thrown when `wallet_amount` holds something that cannot be read as a
/// number. The update is abandoned rather than guessed at.
class WalletBalanceUnreadable implements Exception {
  WalletBalanceUnreadable(this.userId);

  final String userId;

  @override
  String toString() => 'WalletBalanceUnreadable: wallet_amount of user $userId is not a number';
}

/// Applies deltas to `users/{id}.wallet_amount` without losing concurrent
/// updates.
///
/// The old implementation read the whole user profile, added the delta in Dart
/// and wrote the whole profile back. Two updates that overlapped - a top-up
/// landing while a ride was being paid for, an admin credit landing while the
/// customer spent - read the same balance and the second write silently
/// discarded the first. This runs the same arithmetic inside a transaction,
/// and writes the one field instead of the whole document.
class WalletLedger {
  WalletLedger(this.runner);

  /// The Firestore field holding the balance. Unchanged.
  static const String balanceField = 'wallet_amount';

  final WalletTransactionRunner runner;

  /// Adds [delta] (negative to debit) to the balance of [userId].
  ///
  /// Returns `false` if the user document does not exist, matching what the
  /// previous implementation did when the profile could not be read.
  Future<bool> applyDelta({required String userId, required double delta}) {
    return runner.run<bool>(userId, (WalletDocument document) async {
      if (!document.exists) return false;
      final double current = readBalance(document.rawBalance, userId: userId);
      document.setBalance(current + delta);
      return true;
    });
  }

  /// Reads a stored `wallet_amount` the way the apps have always read it:
  /// a missing field counts as zero, and a numeric string counts as its
  /// number.
  ///
  /// This is why the balance is not updated with `FieldValue.increment()`:
  /// against a string-typed balance an increment does not add, it replaces,
  /// which would wipe the stored amount on those documents.
  static double readBalance(Object? raw, {required String userId}) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    final double? parsed = double.tryParse(raw.toString());
    if (parsed == null) throw WalletBalanceUnreadable(userId);
    return parsed;
  }

  /// Parses an amount as the callers hand it over: a string, negative for a
  /// debit (`"12.5"`, `"-12.5"`). `null` means the amount is unusable and the
  /// caller must not write anything.
  static double? parseAmount(String amount) {
    final double? parsed = double.tryParse(amount.trim());
    if (parsed == null) {
      log('updateUserWallet: refusing to apply unparseable amount "$amount"');
    }
    return parsed;
  }
}
