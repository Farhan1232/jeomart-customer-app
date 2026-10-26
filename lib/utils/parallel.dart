import 'dart:async';

/// Runs the same asynchronous read over a list of inputs without waiting for
/// each one to come back before starting the next.
///
/// ## Why the app needed this
///
/// The customer app is full of loops shaped like
///
/// ```dart
/// for (var element in list) {
///   await FireStoreUtils.getSomethingById(element.id);
/// }
/// ```
///
/// Every one of those costs one network round trip **per row, in series**. The
/// search screen was the extreme case: it ran one query per vendor over the 45
/// vendors on live before its results were complete, so the time to a usable
/// search screen was 45 round trips laid end to end. None of those reads
/// depended on the one before it - they were sequential only because a `for`
/// loop with an `await` in it is the easiest thing to write.
///
/// ## What it guarantees
///
/// * **Order is preserved.** The result at index *i* is the result for the
///   input at index *i*, whatever order the network answered in. Several call
///   sites feed a list that is then rendered in order, so this is not optional.
/// * **Concurrency is bounded.** Firing 45 reads into a phone's radio at once
///   is its own kind of slow, and starves whatever else the screen is waiting
///   for. [defaultConcurrency] is a compromise: enough to collapse the
///   round-trip chain, few enough to stay polite.
/// * **One failure does not lose the batch.** `Future.wait` rejects the whole
///   batch on the first error, which would turn one unreadable document into an
///   empty screen. Each task is guarded and a failed one yields `null`, exactly
///   as the sequential code it replaces did when its own `catchError` fired.
class Parallel {
  Parallel._();

  /// How many reads are allowed to be in flight at once.
  static const int defaultConcurrency = 8;

  /// Maps [items] through [task], at most [concurrency] at a time.
  ///
  /// The returned list is the same length as [items] and in the same order. An
  /// entry is `null` where that task threw.
  static Future<List<R?>> map<T, R>(Iterable<T> items, Future<R?> Function(T item) task, {int concurrency = defaultConcurrency}) async {
    final List<T> inputs = items.toList(growable: false);
    if (inputs.isEmpty) return <R?>[];

    final List<R?> results = List<R?>.filled(inputs.length, null);
    final int limit = concurrency < 1 ? 1 : concurrency;
    int next = 0;

    Future<void> worker() async {
      while (true) {
        final int index = next;
        if (index >= inputs.length) return;
        next++;
        try {
          results[index] = await task(inputs[index]);
        } catch (_) {
          results[index] = null;
        }
      }
    }

    final int workers = limit < inputs.length ? limit : inputs.length;
    await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));
    return results;
  }

  /// Starts [read] for every item at once, then hands the results to [apply]
  /// one at a time, in list order.
  ///
  /// For code that used to `await` a read, apply it, then `await` the next:
  /// the network part overlaps, and everything observable on the apply side
  /// stays as it was - the order things are applied in, and that a failure at
  /// item *k* reaches the caller and stops every item after *k* being applied.
  /// Unlike [map], a failure is not swallowed.
  static Future<void> applyInOrder<T, R>(Iterable<T> items, Future<R> Function(T item) read, FutureOr<void> Function(T item, R result) apply) async {
    final List<T> inputs = items.toList(growable: false);
    final List<Future<R>> started = <Future<R>>[for (final T item in inputs) Future<R>.sync(() => read(item))];
    // A read queued behind a failure is never awaited, so each one is given a
    // handler here - otherwise its own failure is an uncaught error.
    for (final Future<R> future in started) {
      unawaited(future.then<void>((R _) {}, onError: (Object _) {}));
    }
    for (int i = 0; i < inputs.length; i++) {
      await apply(inputs[i], await started[i]);
    }
  }

  /// [map], with the `null`s - failed or absent - dropped.
  static Future<List<R>> mapNotNull<T, R>(Iterable<T> items, Future<R?> Function(T item) task, {int concurrency = defaultConcurrency}) async {
    final List<R?> results = await map<T, R>(items, task, concurrency: concurrency);
    return results.whereType<R>().toList();
  }
}
