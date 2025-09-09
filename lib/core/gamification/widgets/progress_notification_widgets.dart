import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../progress_tracking_service.dart';

/// Widget that displays progress notifications as overlays
class ProgressNotificationOverlay extends ConsumerStatefulWidget {
  const ProgressNotificationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ProgressNotificationOverlay> createState() =>
      _ProgressNotificationOverlayState();
}

class _ProgressNotificationOverlayState
    extends ConsumerState<ProgressNotificationOverlay>
    with TickerProviderStateMixin {
  final List<OverlayEntry> _activeNotifications = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _clearAllNotifications();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to progress updates
    ref.listen<AsyncValue<ProgressUpdate>>(progressUpdatesProvider,
        (previous, next) {
      next.whenData((update) => _showProgressNotification(update));
    });

    // Listen to milestone notifications
    ref.listen<AsyncValue<MilestoneReached>>(milestoneNotificationsProvider,
        (previous, next) {
      next.whenData((milestone) => _showMilestoneNotification(milestone));
    });

    return widget.child;
  }

  void _showProgressNotification(ProgressUpdate update) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => ProgressNotificationCard(
        update: update,
        onDismiss: () {
          entry.remove();
          _activeNotifications.remove(entry);
        },
      ),
    );

    _activeNotifications.add(entry);
    overlay.insert(entry);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (_activeNotifications.contains(entry)) {
        entry.remove();
        _activeNotifications.remove(entry);
      }
    });
  }

  void _showMilestoneNotification(MilestoneReached milestone) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => MilestoneNotificationCard(
        milestone: milestone,
        onDismiss: () {
          entry.remove();
          _activeNotifications.remove(entry);
        },
      ),
    );

    _activeNotifications.add(entry);
    overlay.insert(entry);

    // Auto-dismiss after 5 seconds for milestones
    Future.delayed(const Duration(seconds: 5), () {
      if (_activeNotifications.contains(entry)) {
        entry.remove();
        _activeNotifications.remove(entry);
      }
    });
  }

  void _clearAllNotifications() {
    for (final entry in _activeNotifications) {
      entry.remove();
    }
    _activeNotifications.clear();
  }
}

/// Card widget for progress notifications
class ProgressNotificationCard extends StatefulWidget {
  const ProgressNotificationCard({
    super.key,
    required this.update,
    required this.onDismiss,
  });

  final ProgressUpdate update;
  final VoidCallback onDismiss;

  @override
  State<ProgressNotificationCard> createState() =>
      _ProgressNotificationCardState();
}

class _ProgressNotificationCardState extends State<ProgressNotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getIconForUpdateType(widget.update.type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.update.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.update.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForUpdateType(ProgressUpdateType type) {
    switch (type) {
      case ProgressUpdateType.pointsGained:
        return Icons.stars;
      case ProgressUpdateType.achievementUnlocked:
        return Icons.emoji_events;
      case ProgressUpdateType.streakExtended:
        return Icons.local_fire_department;
    }
  }
}

/// Card widget for milestone notifications
class MilestoneNotificationCard extends StatefulWidget {
  const MilestoneNotificationCard({
    super.key,
    required this.milestone,
    required this.onDismiss,
  });

  final MilestoneReached milestone;
  final VoidCallback onDismiss;

  @override
  State<MilestoneNotificationCard> createState() =>
      _MilestoneNotificationCardState();
}

class _MilestoneNotificationCardState extends State<MilestoneNotificationCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _celebrationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
    _celebrationController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: (screenWidth - 320) / 2,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebration icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        _getIconForMilestoneType(widget.milestone.type),
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      widget.milestone.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      widget.milestone.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Dismiss button
                    ElevatedButton(
                      onPressed: widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Awesome!'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForMilestoneType(MilestoneType type) {
    switch (type) {
      case MilestoneType.levelUp:
        return Icons.trending_up;
      case MilestoneType.milestone:
        return Icons.flag;
      case MilestoneType.achievement:
        return Icons.emoji_events;
    }
  }
}

/// Simple progress indicator widget
class ProgressIndicatorWidget extends ConsumerWidget {
  const ProgressIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressSummary = ref.watch(progressSummaryProvider);

    return progressSummary.when(
      data: (summary) => _buildProgressIndicator(context, summary),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => const Icon(Icons.error),
    );
  }

  Widget _buildProgressIndicator(
      BuildContext context, ProgressSummary summary) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${summary.userLevel.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${summary.progress.totalPoints} pts',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: summary.completionPercentage,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            '${(summary.completionPercentage * 100).toStringAsFixed(1)}% Complete',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
