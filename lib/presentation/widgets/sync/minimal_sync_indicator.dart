import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider temporal para el estado de sincronización
final syncStatusProvider = Provider<bool>((ref) => false);

class MinimalSyncIndicator extends ConsumerWidget {
  const MinimalSyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(syncStatusProvider);

    if (!isSyncing) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).colorScheme.tertiary,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Alternative version with shimmer effect
class MinimalSyncIndicatorShimmer extends ConsumerStatefulWidget {
  const MinimalSyncIndicatorShimmer({super.key});

  @override
  ConsumerState<MinimalSyncIndicatorShimmer> createState() =>
      _MinimalSyncIndicatorShimmerState();
}

class _MinimalSyncIndicatorShimmerState
    extends ConsumerState<MinimalSyncIndicatorShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = ref.watch(syncStatusProvider);

    if (!isSyncing) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 3,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
                Theme.of(context).colorScheme.tertiary,
                Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
              ],
              stops: [
                0.0,
                _animation.value * 0.3,
                _animation.value * 0.5,
                _animation.value * 0.7,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}
