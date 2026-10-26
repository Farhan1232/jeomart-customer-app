
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/utils/wallet_ledger.dart';

/// An in-memory stand-in for `users/{id}`, with the same optimistic
/// concurrency Firestore transactions have: a body that read a document which
/// changed before the write lands is run again against the newer value.
class FakeWalletStore implements WalletTransactionRunner {
  FakeWalletStore({this.maxAttempts = 64});

  final int maxAttempts;

  final Map<String, Object?> balances = <String, Object?>{};
  final Map<String, int> _versions = <String, int>{};

  /// How many times a body had to be replayed because of a conflict.
  int retries = 0;

  /// How many writes actually reached the store.
  int writes = 0;

  void seed(String userId, Object? balance) {
    balances[userId] = balance;
    _versions[userId] = 0;
  }

  bool _exists(String userId) => _versions.containsKey(userId);

  @override
  Future<T> run<T>(String userId, Future<T> Function(WalletDocument doc) body) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final int readVersion = _versions[userId] ?? -1;
      final document = _FakeWalletDocument(exists: _exists(userId), rawBalance: balances[userId]);

      final T result = await body(document);

      // Yield, so bodies started together really do interleave between their
      // read and their write.
      await Future<void>.delayed(Duration.zero);

      if ((_versions[userId] ?? -1) != readVersion) {
        retries++;
        continue;
      }
      if (document.pending != null) {
        balances[userId] = document.pending;
        _versions[userId] = readVersion + 1;
        writes++;
      }
      return result;
    }
    throw StateError('transaction on $userId gave up after $maxAttempts attempts');
  }
}

class _FakeWalletDocument implements WalletDocument {
  _FakeWalletDocument({required this.exists, required this.rawBalance});

  @override
  final bool exists;

  @override
  final Object? rawBalance;

  double? pending;

  @override
  void setBalance(double amount) => pending = amount;
}

/// The implementation that was replaced: read the profile, add the delta in
/// Dart, write it back. Present only so the tests can show what it does under
/// the same load.
Future<bool> naiveApplyDelta(FakeWalletStore store, String userId, double delta) async {
  if (!store.balances.containsKey(userId)) return false;
  final double current = double.parse((store.balances[userId] ?? 0).toString());
  await Future<void>.delayed(Duration.zero); // the read-to-write window
  store.balances[userId] = current + delta;
  return true;
}

void main() {
  group('WalletLedger.readBalance', () {
    test('a missing wallet_amount reads as zero', () {
      expect(WalletLedger.readBalance(null, userId: 'u'), 0);
    });

    test('numbers read as themselves', () {
      expect(WalletLedger.readBalance(150.5, userId: 'u'), 150.5);
      expect(WalletLedger.readBalance(150, userId: 'u'), 150.0);
    });

    test('numeric strings read as their number, as old documents store them', () {
      expect(WalletLedger.readBalance('150.5', userId: 'u'), 150.5);
      expect(WalletLedger.readBalance('-20', userId: 'u'), -20.0);
    });

    test('an unreadable balance aborts rather than being guessed at', () {
      expect(() => WalletLedger.readBalance('n/a', userId: 'u'), throwsA(isA<WalletBalanceUnreadable>()));
    });
  });

  group('WalletLedger.parseAmount', () {
    test('accepts the string amounts the callers pass', () {
      expect(WalletLedger.parseAmount('12.5'), 12.5);
      expect(WalletLedger.parseAmount('-12.5'), -12.5);
      expect(WalletLedger.parseAmount(' 7 '), 7.0);
    });

    test('refuses an unparseable amount instead of writing something', () {
      expect(WalletLedger.parseAmount(''), isNull);
      expect(WalletLedger.parseAmount('abc'), isNull);
    });
  });

  group('WalletLedger.applyDelta', () {
    test('credits and debits an existing balance', () async {
      final store = FakeWalletStore()..seed('u1', 100.0);
      final ledger = WalletLedger(store);

      expect(await ledger.applyDelta(userId: 'u1', delta: 25.5), isTrue);
      expect(store.balances['u1'], 125.5);

      expect(await ledger.applyDelta(userId: 'u1', delta: -30.0), isTrue);
      expect(store.balances['u1'], 95.5);
    });

    test('a missing user document is reported, not created', () async {
      final store = FakeWalletStore();
      final ledger = WalletLedger(store);

      expect(await ledger.applyDelta(userId: 'ghost', delta: 10), isFalse);
      expect(store.balances.containsKey('ghost'), isFalse);
      expect(store.writes, 0);
    });

    test('a string-typed balance is added to, not replaced', () async {
      // FieldValue.increment() would have written -20 over the 150.5 here.
      final store = FakeWalletStore()..seed('u1', '150.5');
      final ledger = WalletLedger(store);

      await ledger.applyDelta(userId: 'u1', delta: -20);

      expect(store.balances['u1'], 130.5);
    });

    test('a document with no wallet_amount yet starts from zero', () async {
      final store = FakeWalletStore()..seed('u1', null);
      final ledger = WalletLedger(store);

      await ledger.applyDelta(userId: 'u1', delta: 40);

      expect(store.balances['u1'], 40.0);
    });

    test('an unreadable balance leaves the stored value alone', () async {
      final store = FakeWalletStore()..seed('u1', 'n/a');
      final ledger = WalletLedger(store);

      await expectLater(ledger.applyDelta(userId: 'u1', delta: 10), throwsA(isA<WalletBalanceUnreadable>()));
      expect(store.balances['u1'], 'n/a');
      expect(store.writes, 0);
    });
  });

  group('concurrent wallet updates', () {
    test('ten simultaneous credits all land', () async {
      final store = FakeWalletStore()..seed('u1', 100.0);
      final ledger = WalletLedger(store);

      await Future.wait(List<Future<bool>>.generate(10, (_) => ledger.applyDelta(userId: 'u1', delta: 10)));

      expect(store.balances['u1'], 200.0);
      expect(store.writes, 10);
      expect(store.retries, greaterThan(0), reason: 'the updates should really have collided');
    });

    test('simultaneous credits and debits net out', () async {
      final store = FakeWalletStore()..seed('u1', 500.0);
      final ledger = WalletLedger(store);

      final deltas = <double>[120, -45.5, 60, -200, 15.25, -0.75, 30, -80];
      await Future.wait(deltas.map((d) => ledger.applyDelta(userId: 'u1', delta: d)));

      expect(store.balances['u1'], closeTo(500 + deltas.reduce((a, b) => a + b), 1e-9));
    });

    test('a top-up landing during a ride payment does not overwrite it', () async {
      final store = FakeWalletStore()..seed('u1', 300.0);
      final ledger = WalletLedger(store);

      await Future.wait(<Future<bool>>[
        ledger.applyDelta(userId: 'u1', delta: 250), // wallet top-up
        ledger.applyDelta(userId: 'u1', delta: -180), // fare taken for a ride
      ]);

      expect(store.balances['u1'], 370.0);
    });

    test('updates to different users do not contend', () async {
      final store = FakeWalletStore()
        ..seed('u1', 10.0)
        ..seed('u2', 20.0);
      final ledger = WalletLedger(store);

      await Future.wait(<Future<bool>>[
        ledger.applyDelta(userId: 'u1', delta: 5),
        ledger.applyDelta(userId: 'u2', delta: 5),
      ]);

      expect(store.balances['u1'], 15.0);
      expect(store.balances['u2'], 25.0);
      expect(store.retries, 0);
    });

    test('the replaced read-modify-write loses updates under the same load', () async {
      final store = FakeWalletStore()..seed('u1', 100.0);

      await Future.wait(List<Future<bool>>.generate(10, (_) => naiveApplyDelta(store, 'u1', 10)));

      // Every writer read 100 and wrote 110: nine credits vanished. This is
      // the bug the transaction fixes.
      expect(store.balances['u1'], isNot(200.0));
      expect(store.balances['u1'], 110.0);
    });

    test('a body that keeps colliding gives up instead of writing a stale balance', () async {
      final store = FakeWalletStore(maxAttempts: 2)..seed('u1', 0.0);
      final ledger = WalletLedger(store);

      final futures = List<Future<bool>>.generate(8, (_) => ledger.applyDelta(userId: 'u1', delta: 1));
      final results = await Future.wait(futures.map((f) => f.then<Object?>((v) => v).catchError((Object e) => e)));

      final failures = results.whereType<StateError>().length;
      final applied = results.whereType<bool>().length;
      expect(failures, greaterThan(0));
      // No write is lost: the balance equals exactly the updates that returned.
      expect(store.balances['u1'], applied.toDouble());
    });
  });
}
