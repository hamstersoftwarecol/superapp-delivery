import 'package:material_ui/material_ui.dart';

/// Calls [onEnd] when the scrollable inside [child] is close to its end, so the
/// next page is already on its way before the user reaches the bottom.
class LoadMoreListener extends StatelessWidget {
  const LoadMoreListener({
    required this.onEnd,
    required this.child,
    this.distance = 400,
    super.key,
  });

  final VoidCallback onEnd;
  final Widget child;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < distance) onEnd();
        return false;
      },
      child: child,
    );
  }
}

/// Last row of a paged list: a spinner while the next page loads, or a retry
/// button if it failed.
class PagingFooter extends StatelessWidget {
  const PagingFooter({
    required this.isLoading,
    required this.failed,
    required this.onRetry,
    super.key,
  });

  final bool isLoading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: const Text('No se pudo cargar más. Reintentar'),
          ),
        ),
      );
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return const SizedBox.shrink();
  }
}
