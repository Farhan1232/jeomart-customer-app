import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:customer/utils/firestore_paginator.dart';

/// A document stand-in so the paging logic can be tested without Firestore.
class FakeDoc {
  FakeDoc(this.id, this.status);

  final String id;
  final String status;
}

class FakeSource extends PageSource<FakeDoc> {
  FakeSource(this.docs, {this.live = false, this.neverDelivers = false});

  final List<FakeDoc> docs;
  final bool live;

  /// A live listener that opens and then delivers nothing - what a
  /// `snapshots()` listener does with an empty cache and no usable connection.
  final bool neverDelivers;

  int fetchCalls = 0;
  int docsRead = 0;
  StreamController<List<FakeDoc>>? controller;

  /// Set to make a fetch fail once.
  Object? failNext;

  /// Set to delay a fetch so overlapping calls can be exercised.
  Completer<void>? gate;

  @override
  Future<List<FakeDoc>> fetch({required FakeDoc? after, required int limit}) async {
    fetchCalls++;
    if (gate != null) await gate!.future;
    if (failNext != null) {
      final error = failNext;
      failNext = null;
      throw error!;
    }
    var start = 0;
    if (after != null) {
      final index = docs.indexWhere((d) => d.id == after.id);
      start = index < 0 ? 0 : index + 1;
    }
    final page = docs.skip(start).take(limit).toList();
    docsRead += page.length;
    return page;
  }

  @override
  Stream<List<FakeDoc>>? watchFirstPage(int limit) {
    if (!live) return null;
    controller = StreamController<List<FakeDoc>>();
    if (!neverDelivers) controller!.add(docs.take(limit).toList());
    return controller!.stream;
  }

  @override
  String idOf(FakeDoc doc) => doc.id;
}

List<FakeDoc> makeDocs(int count) => List<FakeDoc>.generate(count, (i) => FakeDoc('doc-$i', i % 3 == 0 ? 'Order Completed' : 'Order Placed'));

void main() {
  group('FirestorePaginator', () {
    test('loads only the first page up front', () async {
      final source = FakeSource(makeDocs(100));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();

      expect(paginator.items.length, 10);
      expect(source.docsRead, 10);
      expect(paginator.hasMore.value, isTrue);
      expect(paginator.isInitialLoading.value, isFalse);
      paginator.dispose();
    });

    test('load more appends without duplicating or skipping rows', () async {
      final source = FakeSource(makeDocs(35));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      await paginator.loadMore();
      await paginator.loadMore();

      expect(paginator.items.length, 30);
      expect(paginator.items.toSet().length, 30, reason: 'no duplicates');
      expect(paginator.items.first, 'doc-0');
      expect(paginator.items.last, 'doc-29');
      expect(paginator.hasMore.value, isTrue);
      paginator.dispose();
    });

    test('stops at the end of the collection', () async {
      final source = FakeSource(makeDocs(25));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      await paginator.loadMore();
      await paginator.loadMore();
      final callsAtEnd = source.fetchCalls;
      await paginator.loadMore();

      expect(paginator.items.length, 25);
      expect(paginator.hasMore.value, isFalse);
      expect(source.fetchCalls, callsAtEnd, reason: 'no fetch past the end');
      paginator.dispose();
    });

    test('concurrent loadMore calls collapse into one page', () async {
      final source = FakeSource(makeDocs(100))..gate = Completer<void>();
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      final first = paginator.refresh();
      source.gate!.complete();
      await first;

      source.gate = Completer<void>();
      final a = paginator.loadMore();
      final b = paginator.loadMore();
      final c = paginator.loadMore();
      source.gate!.complete();
      await Future.wait(<Future<void>>[a, b, c]);

      expect(paginator.items.length, 20, reason: 'only one extra page loaded');
      expect(paginator.items.toSet().length, 20);
      paginator.dispose();
    });

    test('refresh resets the cursor so pages cannot interleave', () async {
      final source = FakeSource(makeDocs(50));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      await paginator.loadMore();
      expect(paginator.items.length, 20);

      await paginator.refresh();
      expect(paginator.items.length, 10);
      expect(paginator.items.first, 'doc-0');
      expect(paginator.hasMore.value, isTrue);
      paginator.dispose();
    });

    test('a load in flight when refresh happens is discarded', () async {
      final source = FakeSource(makeDocs(50))..gate = Completer<void>();
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      final stale = paginator.refresh();
      // A second refresh supersedes the first before it resolves.
      source.gate!.complete();
      await stale;

      source.gate = Completer<void>();
      final pending = paginator.loadMore();
      final fresh = paginator.refresh();
      source.gate!.complete();
      await Future.wait(<Future<void>>[pending, fresh]);

      expect(paginator.items.length, 10);
      expect(paginator.items.toSet().length, 10);
      paginator.dispose();
    });

    test('nothing loads after dispose', () async {
      final source = FakeSource(makeDocs(50));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      final callsBefore = source.fetchCalls;
      paginator.dispose();
      await paginator.loadMore();
      await paginator.refresh();

      expect(source.fetchCalls, callsBefore);
      expect(paginator.isDisposed, isTrue);
    });

    test('a failed page surfaces the error and stops paging', () async {
      final source = FakeSource(makeDocs(50))..failNext = StateError('boom');
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();

      expect(paginator.error.value, isA<StateError>());
      expect(paginator.hasMore.value, isFalse);
      expect(paginator.items, isEmpty);

      // refresh() clears the error and recovers.
      await paginator.refresh();
      expect(paginator.error.value, isNull);
      expect(paginator.items.length, 10);
      paginator.dispose();
    });

    test('mapper returning null skips a document', () async {
      final source = FakeSource(makeDocs(20));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id == 'doc-3' ? null : doc.id, pageSize: 10);

      await paginator.refresh();

      expect(paginator.items.length, 9);
      expect(paginator.items.contains('doc-3'), isFalse);
      paginator.dispose();
    });

    test('a tab filter keeps loading until it has rows to show', () async {
      final source = FakeSource(makeDocs(120));
      final paginator = FirestorePaginator<FakeDoc, FakeDoc>(source: source, mapper: (doc) => doc, pageSize: 10, autoFillTarget: 10, filter: (item) => item.status == 'Order Completed');

      await paginator.refresh();

      expect(paginator.visibleItems.length, greaterThanOrEqualTo(10));
      expect(paginator.visibleItems.every((d) => d.status == 'Order Completed'), isTrue);
      // It stops as soon as the tab is filled instead of reading everything.
      expect(source.docsRead, lessThan(120));
      paginator.dispose();
    });

    test('switching tab re-fills without reloading from scratch', () async {
      final source = FakeSource(makeDocs(120));
      final paginator = FirestorePaginator<FakeDoc, FakeDoc>(source: source, mapper: (doc) => doc, pageSize: 10, autoFillTarget: 5, filter: (item) => item.status == 'Order Placed');

      await paginator.refresh();
      final readAfterFirstTab = source.docsRead;

      await paginator.applyFilter((item) => item.status == 'Order Completed');

      expect(paginator.visibleItems.every((d) => d.status == 'Order Completed'), isTrue);
      expect(source.docsRead, greaterThanOrEqualTo(readAfterFirstTab));
      paginator.dispose();
    });

    test('auto-fill gives up instead of walking the whole history', () async {
      // A tab that matches nothing must not page through everything looking.
      final source = FakeSource(makeDocs(1000));
      final paginator = FirestorePaginator<FakeDoc, FakeDoc>(
        source: source,
        mapper: (doc) => doc,
        pageSize: 10,
        autoFillTarget: 10,
        autoFillMaxPages: 3,
        filter: (item) => item.status == 'Nothing Matches This',
      );

      await paginator.refresh();

      expect(paginator.visibleItems, isEmpty);
      // First page plus at most autoFillMaxPages more.
      expect(source.docsRead, lessThanOrEqualTo(40));
      expect(paginator.hasMore.value, isTrue, reason: 'the user can still scroll for more');
      paginator.dispose();
    });

    test('a live first page keeps updating and still pages', () async {
      final docs = makeDocs(40);
      final source = FakeSource(docs, live: true);
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      expect(paginator.items.length, 10);

      await paginator.loadMore();
      expect(paginator.items.length, 20);

      // A new document arriving at the top goes in front of page 1; the ten
      // documents page 1 is already showing all stay, because page 2's cursor
      // is anchored on the last of them.
      //
      // This used to expect 20 - that is, it asserted that doc-9 was dropped,
      // which is precisely the gap the live-page merge now closes.
      final updated = <FakeDoc>[FakeDoc('doc-new', 'Order Placed'), ...docs.take(9)];
      source.controller!.add(updated);
      await Future<void>.delayed(Duration.zero);

      expect(paginator.items.first, 'doc-new');
      expect(paginator.items.length, 21);
      expect(paginator.items.toSet().length, 21, reason: 'no duplicates after a live update');
      paginator.dispose();
    });

    test('dispose cancels the live listener', () async {
      final source = FakeSource(makeDocs(20), live: true);
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      paginator.dispose();

      expect(source.controller!.hasListener, isFalse);
    });

    test('a live first page that never delivers gives up instead of hanging', () async {
      // The stuck spinner: refresh() awaited the first delivery unconditionally,
      // so a listener that never delivers left every caller of refresh() - and
      // the screen behind it - waiting for the rest of the session.
      final source = FakeSource(makeDocs(30), live: true, neverDelivers: true);
      final paginator = FirestorePaginator<FakeDoc, String>(
        source: source,
        mapper: (doc) => doc.id,
        pageSize: 10,
        firstPageTimeout: const Duration(milliseconds: 50),
      );

      await paginator.refresh().timeout(const Duration(seconds: 2));

      expect(paginator.isInitialLoading.value, isFalse, reason: 'the screen must be allowed to render');
      expect(paginator.error.value, isA<TimeoutException>());
      paginator.dispose();
    });

    test('a late delivery still fills the list after the wait was given up on', () async {
      final source = FakeSource(makeDocs(30), live: true, neverDelivers: true);
      final paginator = FirestorePaginator<FakeDoc, String>(
        source: source,
        mapper: (doc) => doc.id,
        pageSize: 10,
        firstPageTimeout: const Duration(milliseconds: 50),
      );

      await paginator.refresh();
      expect(paginator.items, isEmpty);

      source.controller!.add(source.docs.take(10).toList());
      await Future<void>.delayed(Duration.zero);

      expect(paginator.items.length, 10, reason: 'the listener is left open on purpose');
      paginator.dispose();
    });

    test('a new document at the top does not push a loaded row out of the list', () async {
      // Page 2 is anchored on the last document of page 1. Replacing page 1
      // wholesale when a new document arrived therefore dropped the document
      // that fell off its end: it was in neither page, and vanished from the
      // middle of the list the user was scrolling.
      final source = FakeSource(makeDocs(30), live: true);
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);

      await paginator.refresh();
      await paginator.loadMore();
      expect(paginator.items.length, 20);

      final fresh = FakeDoc('doc-new', 'Order Placed');
      source.controller!.add(<FakeDoc>[fresh, ...source.docs.take(9)]);
      await Future<void>.delayed(Duration.zero);

      expect(paginator.items.first, 'doc-new');
      expect(paginator.items, contains('doc-9'), reason: 'the row pushed off page 1 must not disappear');
      expect(paginator.items.toSet().length, paginator.items.length, reason: 'no duplicates');
      expect(paginator.items.length, 21);
      paginator.dispose();
    });

    test('a live update to page 1 still refreshes a row that changed', () async {
      final source = FakeSource(makeDocs(30), live: true);
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => '${doc.id}:${doc.status}', pageSize: 10);

      await paginator.refresh();
      await paginator.loadMore();
      expect(paginator.items, contains('doc-1:Order Placed'));

      final changed = <FakeDoc>[FakeDoc('doc-1', 'Order Completed'), ...source.docs.take(10).where((d) => d.id != 'doc-1')];
      source.controller!.add(changed);
      await Future<void>.delayed(Duration.zero);

      expect(paginator.items, contains('doc-1:Order Completed'));
      expect(paginator.items, isNot(contains('doc-1:Order Placed')));
      paginator.dispose();
    });

    test('a refresh during a load-more does not leave the bottom spinner running', () async {
      final source = FakeSource(makeDocs(40));
      final paginator = FirestorePaginator<FakeDoc, String>(source: source, mapper: (doc) => doc.id, pageSize: 10);
      await paginator.refresh();

      source.gate = Completer<void>();
      final pending = paginator.loadMore();
      expect(paginator.isLoadingMore.value, isTrue);

      source.gate!.complete();
      await pending;

      expect(paginator.isLoadingMore.value, isFalse);
      paginator.dispose();
    });
  });
}
