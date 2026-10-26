import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

/// The documents a [FirestorePaginator] pages through.
///
/// Kept behind this interface so the paging state machine can be unit tested
/// without a Firestore connection.
abstract class PageSource<D> {
  /// Fetches at most [limit] documents that come after [after].
  Future<List<D>> fetch({required D? after, required int limit});

  /// A live view of the first [limit] documents, or `null` for one-shot paging.
  Stream<List<D>>? watchFirstPage(int limit) => null;

  /// Stable identity of a document, used to drop duplicates.
  String idOf(D doc);
}

/// Pages a Firestore query with `limit()` + `startAfterDocument()`.
///
/// The query must **not** carry its own `limit`.
class FirestorePageSource extends PageSource<DocumentSnapshot<Map<String, dynamic>>> {
  FirestorePageSource(this.query, {this.live = false});

  final Query<Map<String, dynamic>> query;

  /// Keep a listener on the first page so newly created documents still appear
  /// immediately, the way the un-paginated `snapshots()` listeners used to.
  final bool live;

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetch({required DocumentSnapshot<Map<String, dynamic>>? after, required int limit}) async {
    Query<Map<String, dynamic>> pageQuery = query.limit(limit);
    if (after != null) {
      pageQuery = pageQuery.startAfterDocument(after);
    }
    final snapshot = await pageQuery.get();
    return snapshot.docs;
  }

  @override
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>>? watchFirstPage(int limit) {
    if (!live) return null;
    return query.limit(limit).snapshots().map((snapshot) => snapshot.docs);
  }

  @override
  String idOf(DocumentSnapshot<Map<String, dynamic>> doc) => doc.id;
}

/// Cursor-based pagination for a list screen.
///
/// Replaces the "download the whole collection into an RxList" pattern:
/// documents arrive one page at a time, the first page can stay live, and the
/// paginator refuses to run two loads at once, to load after disposal, or to
/// add a document it has already emitted.
///
/// Tabs and other client-side filters are supported through [filter]: the
/// paginator can keep fetching until enough *visible* rows exist, so a tab is
/// not left looking empty just because its rows are further down the query.
class FirestorePaginator<D, T> {
  FirestorePaginator({required this.source, required this.mapper, this.pageSize = 20, this.filter, this.autoFillTarget = 0, this.autoFillMaxPages = 5, this.firstPageTimeout = const Duration(seconds: 12)});

  final PageSource<D> source;

  /// Builds the model shown in the list. Returning `null` skips the document.
  final T? Function(D doc) mapper;

  final int pageSize;

  /// Client-side visibility filter, e.g. the selected status tab.
  bool Function(T item)? filter;

  /// Keep loading until at least this many *visible* items exist.
  final int autoFillTarget;

  /// How long [refresh] waits for the live listener's first delivery.
  ///
  /// A `snapshots()` listener with nothing in the local cache and no usable
  /// connection never delivers anything, and `refresh()` used to await that
  /// first delivery unconditionally. Every screen that hides its list behind
  /// `isLoading` until `refresh()` returns therefore span its spinner for ever
  /// on a bad connection - the "stuck" half of the client's slowness report.
  ///
  /// Past this point the screen renders its empty/error state instead. The
  /// listener is deliberately left open, so a delivery that arrives late still
  /// fills the list in.
  final Duration firstPageTimeout;

  /// Upper bound on how many extra pages one auto-fill may load.
  ///
  /// Without it, selecting a tab that happens to match nothing would page
  /// through the user's entire history looking for a match. Past this point the
  /// list relies on the user scrolling.
  final int autoFillMaxPages;

  /// Everything loaded so far, in query order.
  final RxList<T> items = <T>[].obs;

  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final Rxn<Object> error = Rxn<Object>();

  final List<List<D>> _pages = <List<D>>[];
  StreamSubscription<List<D>>? _liveSub;
  bool _isDisposed = false;
  bool _isFetching = false;
  int _token = 0;

  /// The items the screen should render right now.
  List<T> get visibleItems {
    final currentFilter = filter;
    if (currentFilter == null) return items;
    return items.where(currentFilter).toList();
  }

  bool get isDisposed => _isDisposed;

  /// Loads the first page, discarding anything already loaded.
  ///
  /// Safe to call when a search, filter or sort changes: the cursor and the
  /// de-duplication set are reset together, so pages cannot interleave.
  Future<void> refresh() async {
    if (_isDisposed) return;

    final token = ++_token;
    await _liveSub?.cancel();
    _liveSub = null;
    _pages.clear();
    _isFetching = false;
    hasMore.value = true;
    error.value = null;
    isInitialLoading.value = true;
    isLoadingMore.value = false;
    items.clear();

    final liveStream = source.watchFirstPage(pageSize);
    if (liveStream != null) {
      final completer = Completer<void>();
      _liveSub = liveStream.listen(
        (docs) {
          if (_isDisposed || token != _token) return;
          if (_pages.isEmpty) {
            _pages.add(docs);
          } else {
            _pages[0] = _mergeFirstPage(_pages[0], docs);
          }
          // Only the very first delivery decides whether more pages exist; a
          // later live update to page 1 says nothing about the tail.
          if (!completer.isCompleted) {
            hasMore.value = docs.length >= pageSize;
          }
          _rebuild();
          isInitialLoading.value = false;
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e) {
          if (_isDisposed || token != _token) return;
          error.value = e;
          isInitialLoading.value = false;
          if (!completer.isCompleted) completer.complete();
        },
      );
      var timedOut = false;
      await completer.future.timeout(
        firstPageTimeout,
        onTimeout: () {
          if (_isDisposed || token != _token) return;
          timedOut = true;
          error.value ??= TimeoutException('the first page did not arrive', firstPageTimeout);
          isInitialLoading.value = false;
        },
      );
      // Auto-fill would issue more reads down the same dead connection, and
      // each one would block for as long as the first did.
      if (timedOut) return;
    } else {
      await _fetchNextPage(token);
      isInitialLoading.value = false;
    }

    await _autoFill(token);
  }

  /// Appends the next page. Concurrent calls collapse into one.
  Future<void> loadMore() async {
    if (_isDisposed || _isFetching || !hasMore.value) return;
    final token = _token;
    isLoadingMore.value = true;
    try {
      await _fetchNextPage(token);
      if (_isDisposed || token != _token) return;
      await _autoFill(token);
    } finally {
      // In a `finally`, because every early return above used to leave the
      // "loading more" row spinning at the bottom of the list for the rest of
      // the session.
      if (!_isDisposed && token == _token) isLoadingMore.value = false;
    }
  }

  /// Re-applies [filter] and tops the list up if the new tab looks empty.
  Future<void> applyFilter(bool Function(T item)? newFilter) async {
    filter = newFilter;
    items.refresh();
    await _autoFill(_token);
  }

  Future<void> _autoFill(int token) async {
    if (autoFillTarget <= 0 || filter == null) return;
    var pagesLoaded = 0;
    while (!_isDisposed && token == _token && hasMore.value && pagesLoaded < autoFillMaxPages && visibleItems.length < autoFillTarget) {
      final before = _pages.length;
      await _fetchNextPage(token);
      if (_pages.length == before) break;
      pagesLoaded++;
    }
  }

  Future<void> _fetchNextPage(int token) async {
    if (_isDisposed || _isFetching || !hasMore.value) return;
    _isFetching = true;
    try {
      final after = _pages.isEmpty || _pages.last.isEmpty ? null : _pages.last.last;
      final docs = await source.fetch(after: after, limit: pageSize);

      // The screen was disposed, or refreshed under us, while we were waiting.
      if (_isDisposed || token != _token) return;

      if (docs.isNotEmpty) _pages.add(docs);
      if (docs.length < pageSize) hasMore.value = false;
      _rebuild();
      error.value = null;
    } catch (e) {
      if (_isDisposed || token != _token) return;
      // Same visibility the one-shot `.get().catchError((e) => log(...))` calls
      // this replaces used to give.
      log('FirestorePaginator: page load failed :: $e');
      error.value = e;
      // Stop paging on failure so a broken query cannot spin the scroll
      // listener; refresh() clears this.
      hasMore.value = false;
    } finally {
      _isFetching = false;
    }
  }

  /// Folds a live delivery of page 1 into the page 1 already on screen.
  ///
  /// Replacing it outright is correct until the user pages further down, and
  /// wrong the moment they do: page 2 was fetched with a cursor anchored on the
  /// *old* last document of page 1, so as soon as one new document arrives at
  /// the top, the document page 1 pushes off its end belongs to no page at all
  /// and silently disappears from the middle of the list.
  ///
  /// Once a second page exists, page 1 therefore keeps every document it is
  /// already showing - refreshed to its newest snapshot, so a status change
  /// still moves a row between tabs - and genuinely new documents go in front
  /// of them. The page grows instead of shifting, which is what a cursor
  /// further down the list requires.
  ///
  /// The trade-off is deliberate: a document deleted server-side stays on
  /// screen until the next pull-to-refresh. A stale row is a far smaller fault
  /// than a row that vanishes out of a list the user is scrolling.
  List<D> _mergeFirstPage(List<D> current, List<D> incoming) {
    if (_pages.length <= 1) return incoming;
    final currentIds = current.map(source.idOf).toSet();
    final latest = <String, D>{for (final doc in incoming) source.idOf(doc): doc};
    final merged = <D>[];
    for (final doc in incoming) {
      if (!currentIds.contains(source.idOf(doc))) merged.add(doc);
    }
    for (final doc in current) {
      merged.add(latest[source.idOf(doc)] ?? doc);
    }
    return merged;
  }

  void _rebuild() {
    final seen = <String>{};
    final next = <T>[];
    for (final page in _pages) {
      for (final doc in page) {
        if (!seen.add(source.idOf(doc))) continue;
        final item = mapper(doc);
        if (item != null) next.add(item);
      }
    }
    items.value = next;
  }

  void dispose() {
    _isDisposed = true;
    _token++;
    _liveSub?.cancel();
    _liveSub = null;
  }
}
