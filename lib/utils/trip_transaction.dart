import 'package:cloud_firestore/cloud_firestore.dart';

/// A document as seen from inside a trip transaction.
abstract class TripDocument {
  bool get exists;

  Map<String, dynamic>? get data;
}

/// The reads and writes a trip transaction body may perform.
///
/// Firestore requires every read to happen before the first write, so bodies
/// always [get] first and then [set] / [update].
abstract class TripTransactionContext {
  Future<TripDocument> get(String path);

  void set(String path, Map<String, dynamic> data, {bool merge = true});

  void update(String path, Map<String, dynamic> data);
}

/// Runs one trip transaction.
///
/// The contract the implementation must honour is Firestore's: if any document
/// read by the body changed before the writes landed, the whole body runs
/// again against the newer values. That replay is the entire reason two
/// customers cannot both take the same full vehicle, so it is modelled
/// explicitly here and exercised by tests with a fake that really does replay.
///
/// This is deliberately a **separate** abstraction from the bidding feature's
/// `BidTransactionRunner`, even though the shapes are similar. My Trips must
/// not depend on bidding: bidding is switched off in production, and neither
/// feature should be able to break the other by changing a shared type.
abstract class TripTransactionRunner {
  Future<T> run<T>(Future<T> Function(TripTransactionContext ctx) body);
}

/// Firestore-backed [TripTransactionRunner].
class FirestoreTripTransactionRunner implements TripTransactionRunner {
  FirestoreTripTransactionRunner(this.fireStore);

  final FirebaseFirestore fireStore;

  @override
  Future<T> run<T>(Future<T> Function(TripTransactionContext ctx) body) {
    return fireStore.runTransaction<T>((Transaction transaction) async {
      final _FirestoreTripTransactionContext ctx = _FirestoreTripTransactionContext(fireStore, transaction);
      final T result = await body(ctx);
      ctx.flush();
      return result;
    });
  }
}

class _FirestoreTripTransactionContext implements TripTransactionContext {
  _FirestoreTripTransactionContext(this._fireStore, this._transaction);

  final FirebaseFirestore _fireStore;
  final Transaction _transaction;

  /// Writes are queued rather than applied immediately, so a body that reads
  /// after its first write still works: everything is flushed once the body
  /// has finished, which keeps Firestore's reads-before-writes rule.
  final List<void Function()> _pending = <void Function()>[];

  DocumentReference<Map<String, dynamic>> _ref(String path) => _fireStore.doc(path);

  @override
  Future<TripDocument> get(String path) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _transaction.get(_ref(path));
    return _FirestoreTripDocument(snapshot);
  }

  @override
  void set(String path, Map<String, dynamic> data, {bool merge = true}) {
    _pending.add(() => _transaction.set(_ref(path), data, SetOptions(merge: merge)));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    _pending.add(() => _transaction.update(_ref(path), data));
  }

  void flush() {
    for (final void Function() write in _pending) {
      write();
    }
    _pending.clear();
  }
}

class _FirestoreTripDocument implements TripDocument {
  _FirestoreTripDocument(this._snapshot);

  final DocumentSnapshot<Map<String, dynamic>> _snapshot;

  @override
  bool get exists => _snapshot.exists;

  @override
  Map<String, dynamic>? get data => _snapshot.data();
}
