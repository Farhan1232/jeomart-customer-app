import 'package:flutter/material.dart';

/// Wraps a scrollable list and calls [onLoadMore] shortly before the user
/// reaches the bottom, which is how the paginated screens ask
/// `FirestorePaginator` for the next page.
///
/// The paginator itself ignores overlapping calls, so this only has to notice
/// the scroll position.
class LoadMoreListener extends StatelessWidget {
  const LoadMoreListener({super.key, required this.child, required this.onLoadMore, this.threshold = 200});

  final Widget child;
  final VoidCallback onLoadMore;

  /// How far from the bottom, in pixels, the next page starts loading.
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.axis != Axis.vertical) return false;
        if (metrics.pixels >= metrics.maxScrollExtent - threshold) {
          onLoadMore();
        }
        return false;
      },
      child: child,
    );
  }
}

/// The row shown at the end of a paginated list while the next page loads.
class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))));
  }
}
