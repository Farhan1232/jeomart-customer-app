import 'package:flutter/material.dart';

/// Keeps the tabs a customer has already opened alive, and builds the ones they
/// have not opened yet only when they first ask for them.
///
/// ## What it replaces
///
/// Every dashboard in this app rendered its current tab as
///
/// ```dart
/// body: controller.pageList[controller.selectedIndex.value]
/// ```
///
/// which puts exactly one page in the widget tree. Moving to another tab
/// **removes** the old page, and removing a page disposes the `GetxController`
/// that `GetX(init: ...)` created for it. Coming back builds a brand new one and
/// runs `onInit()` again - so every tap on the bar re-ran that tab's whole
/// startup: its Firestore reads, its listeners, its map setup.
///
/// On the cab bar that is the difference between switching tabs and reloading
/// the section, which is what "the bottom nav bar is slow" describes.
///
/// ## Why lazy, rather than a plain IndexedStack
///
/// A plain `IndexedStack` fixes the disposal, but it builds **every** tab the
/// first time the dashboard is shown - so entering a section would start six
/// controllers at once and fire all of their Firestore reads together, making
/// the first paint worse to make later taps better.
///
/// This builds a tab the first time it is selected and keeps it from then on.
/// The first visit to each tab costs what it always did; every visit after it
/// is free.
///
/// ## What stays correct
///
/// A page kept alive no longer re-queries on entry, so anything that must stay
/// current has to say so itself. Every tab that lives in one of these bars
/// already does: the booking, order, parcel, rental, trips and bid lists all
/// page with `live: true`, meaning their first page is a `snapshots()`
/// listener, and the wallet re-reads itself after a top-up.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({super.key, required this.index, required this.children});

  /// The tab to show.
  final int index;

  /// One builder per tab, in bar order. Called at most once each.
  final List<WidgetBuilder> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  /// Tabs that have been shown at least once. Only these are in the tree.
  final Set<int> _built = <int>{};

  @override
  void initState() {
    super.initState();
    _built.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A shorter `children` (the wallet tab appears and disappears with
    // `walletSetting`) must not leave a remembered index pointing past the end.
    _built.removeWhere((int i) => i >= widget.children.length);
    _built.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final int index = widget.index.clamp(0, widget.children.length - 1);
    _built.add(index);

    return IndexedStack(
      index: index,
      // `IndexedStack` lays out every child and paints only the selected one, so
      // an unvisited tab is a zero-size placeholder until it is asked for.
      children: <Widget>[
        for (int i = 0; i < widget.children.length; i++)
          if (_built.contains(i)) widget.children[i](context) else const SizedBox.shrink(),
      ],
    );
  }
}
