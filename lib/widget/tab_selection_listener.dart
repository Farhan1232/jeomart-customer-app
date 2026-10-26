import 'package:flutter/material.dart';

/// Reports every settled change of the ambient [TabController]'s index -
/// including the ones a `TabBar`'s `onTap` never sees.
///
/// `TabBar(onTap:)` fires on a tap and on nothing else. Swiping the
/// `TabBarView` sideways moves the controller without it, and the paginated
/// list screens are driven by that callback: it is what tells the paginator
/// which status filter is on screen, and the paginator is what keeps loading
/// pages until that filter actually has rows to show.
///
/// So a tab reached by swiping kept the previous tab's filter and never topped
/// itself up. It could sit there saying "No order found" while its rows were
/// one page further down the same query - and because an empty tab renders no
/// scrollable list, there was no scroll for the load-more listener to notice
/// and no way for the user to get out of it.
///
/// Wrap the `TabBarView` in one of these and a swipe does what a tap does.
class TabSelectionListener extends StatefulWidget {
  const TabSelectionListener({super.key, required this.child, required this.onChanged});

  final Widget child;

  /// Called with the settled tab index, once per change.
  final ValueChanged<int> onChanged;

  @override
  State<TabSelectionListener> createState() => _TabSelectionListenerState();
}

class _TabSelectionListenerState extends State<TabSelectionListener> {
  TabController? _controller;
  int? _reported;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final TabController? controller = DefaultTabController.maybeOf(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_handleChange);
    _controller = controller;
    // The tab already on screen is not a change, so it is not reported.
    _reported = controller?.index;
    _controller?.addListener(_handleChange);
  }

  void _handleChange() {
    final TabController? controller = _controller;
    if (controller == null) return;
    // A TabController notifies on every frame of its animation. Only the
    // settled index matters, and only when it is different from the last one
    // reported - otherwise a single swipe would fire dozens of reloads.
    if (controller.indexIsChanging) return;
    if (_reported == controller.index) return;
    _reported = controller.index;
    final int index = controller.index;
    // Out of the animation phase before touching controller state, so a
    // rebuild is never scheduled from inside the frame that caused it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(index);
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
