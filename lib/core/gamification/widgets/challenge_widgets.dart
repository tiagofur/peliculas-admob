import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/challenge_providers.dart';
import '../models/challenge.dart' as models;
import '../models/challenge_enums.dart';

// Challenge Card Widget
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onTap,
    this.onCompleted,
    this.onAccepted,
    this.showCompletedBadge = false,
  });
  final models.Challenge challenge;
  final VoidCallback? onTap;
  final Function(models.Challenge)? onCompleted;
  final Function(models.Challenge)? onAccepted;
  final bool showCompletedBadge;

  bool get isExpired => challenge.endDate.isBefore(DateTime.now());

  double get progressPercentage => challenge.targetValue > 0
      ? challenge.currentProgress / challenge.targetValue
      : 0.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCompleted = challenge.isCompleted;

    return Card(
      elevation: isCompleted ? 8 : 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted
              ? Colors.green
              : isExpired
                  ? Colors.red.withValues(alpha: 0.3)
                  : theme.primaryColor.withValues(alpha: 0.3),
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isCompleted
                ? LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.1),
                      Colors.transparent
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildChallengeIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isExpired ? Colors.grey : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isExpired ? Colors.grey : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(theme),
                ],
              ),
              const SizedBox(height: 16),
              _buildProgressSection(theme),
              const SizedBox(height: 12),
              _buildRewardSection(theme),
              const SizedBox(height: 8),
              _buildTimeSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeIcon() {
    IconData iconData;
    Color iconColor;

    switch (challenge.type) {
      case ChallengeType.genreExplorer:
        iconData = Icons.explore;
        iconColor = Colors.purple;
        break;
      case ChallengeType.marathonWeekend:
        iconData = Icons.weekend;
        iconColor = Colors.orange;
        break;
      case ChallengeType.socialSharer:
        iconData = Icons.share;
        iconColor = Colors.blue;
        break;
      case ChallengeType.reviewMaster:
        iconData = Icons.rate_review;
        iconColor = Colors.green;
        break;
      case ChallengeType.discoveryQuest:
        iconData = Icons.new_releases;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.star;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    if (challenge.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              'Completed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Expired',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Since Challenge model doesn't have difficulty property,
    // we'll determine difficulty based on points reward
    final difficulty = _getDifficultyFromPoints();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getDifficultyColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: _getDifficultyColor(),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getDifficultyFromPoints() {
    if (challenge.rewardPoints >= 200) return 'expert';
    if (challenge.rewardPoints >= 100) return 'hard';
    if (challenge.rewardPoints >= 50) return 'medium';
    return 'easy';
  }

  Color _getDifficultyColor() {
    final difficulty = _getDifficultyFromPoints();
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProgressSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${challenge.currentProgress}/${challenge.targetValue}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progressPercentage,
          backgroundColor: Colors.grey.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            challenge.isCompleted ? Colors.green : theme.primaryColor,
          ),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildRewardSection(ThemeData theme) {
    return Row(
      children: [
        const Icon(
          Icons.stars,
          color: Colors.amber,
          size: 20,
        ),
        const SizedBox(width: 4),
        Text(
          '${challenge.rewardPoints} points',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.amber.shade700,
          ),
        ),
        if (challenge.rewardBadges.isNotEmpty) ...[
          const SizedBox(width: 16),
          const Icon(
            Icons.military_tech,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            '${challenge.rewardBadges.length} badge${challenge.rewardBadges.length > 1 ? 's' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeSection(ThemeData theme) {
    final now = DateTime.now();
    final timeLeft = challenge.endDate.difference(now);

    String timeText;
    Color timeColor;

    if (challenge.isCompleted) {
      timeText = 'Completed';
      timeColor = Colors.green;
    } else if (challenge.isExpired) {
      timeText = 'Expired';
      timeColor = Colors.red;
    } else if (timeLeft.inDays > 0) {
      timeText = '${timeLeft.inDays} day${timeLeft.inDays > 1 ? 's' : ''} left';
      timeColor = timeLeft.inDays <= 1 ? Colors.orange : Colors.grey;
    } else if (timeLeft.inHours > 0) {
      timeText =
          '${timeLeft.inHours} hour${timeLeft.inHours > 1 ? 's' : ''} left';
      timeColor = Colors.orange;
    } else {
      timeText = 'Expires soon';
      timeColor = Colors.red;
    }

    return Row(
      children: [
        Icon(
          Icons.schedule,
          color: timeColor,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          timeText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: timeColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Challenge List View
class ChallengeListView extends ConsumerWidget {
  const ChallengeListView({
    super.key,
    this.challenges,
    this.showCompleted = false,
    this.showCompletedBadge = false,
    this.onChallengeCompleted,
    this.onChallengeAccepted,
  });
  final List<models.Challenge>? challenges;
  final bool showCompleted;
  final bool showCompletedBadge;
  final Function(models.Challenge)? onChallengeCompleted;
  final Function(models.Challenge)? onChallengeAccepted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesList = challenges ?? ref.watch(activeChallengesProvider);

    final filteredChallenges = showCompleted
        ? challengesList?.where((c) => c.isCompleted).toList() ?? []
        : challengesList
                ?.where((c) =>
                    !c.isCompleted && !c.endDate.isBefore(DateTime.now()))
                .toList() ??
            [];

    if (filteredChallenges.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      itemCount: filteredChallenges.length,
      itemBuilder: (context, index) {
        final challenge = filteredChallenges[index];
        return ChallengeCard(
          challenge: challenge,
          onTap: () => _showChallengeDetails(context, challenge),
          onCompleted: onChallengeCompleted,
          onAccepted: onChallengeAccepted,
          showCompletedBadge: showCompletedBadge,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showCompleted ? Icons.emoji_events : Icons.assignment,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            showCompleted
                ? 'No completed challenges yet'
                : 'No active challenges',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showCompleted
                ? 'Complete some challenges to see them here'
                : 'New challenges will appear automatically',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showChallengeDetails(BuildContext context, models.Challenge challenge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChallengeDetailsSheet(challenge: challenge),
    );
  }
}

// Challenge Card Skeleton
class ChallengeCardSkeleton extends StatelessWidget {
  const ChallengeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Challenge Details Sheet
class ChallengeDetailsSheet extends StatelessWidget {
  const ChallengeDetailsSheet({
    super.key,
    required this.challenge,
  });
  final models.Challenge challenge;

  bool get isExpired => challenge.endDate.isBefore(DateTime.now());

  double get progressPercentage => challenge.targetValue > 0
      ? challenge.currentProgress / challenge.targetValue
      : 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildChallengeIcon(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            challenge.description,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildProgressDetails(theme),
                const SizedBox(height: 24),
                _buildRewardDetails(theme),
                const SizedBox(height: 24),
                _buildTimeDetails(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeIcon() {
    // Same as in ChallengeCard
    IconData iconData;
    Color iconColor;

    switch (challenge.challengeType) {
      case 'genreExplorer':
        iconData = Icons.explore;
        iconColor = Colors.purple;
        break;
      case 'marathonWeekend':
        iconData = Icons.weekend;
        iconColor = Colors.orange;
        break;
      case 'socialSharer':
        iconData = Icons.share;
        iconColor = Colors.blue;
        break;
      case 'reviewMaster':
        iconData = Icons.rate_review;
        iconColor = Colors.green;
        break;
      case 'discoveryQuest':
        iconData = Icons.new_releases;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.star;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 32,
      ),
    );
  }

  Widget _buildProgressDetails(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Progress:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${challenge.currentProgress}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${challenge.targetValue}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressPercentage,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              challenge.isCompleted ? Colors.green : theme.primaryColor,
            ),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${(progressPercentage * 100).toInt()}% Complete',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardDetails(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rewards',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                '${challenge.pointsReward} Points',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          if (challenge.rewardBadges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.military_tech, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Badges:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: challenge.rewardBadges
                  .map((badge) => Chip(
                        label: Text(
                          badge.replaceAll('_', ' ').toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.3)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeDetails(ThemeData theme) {
    final now = DateTime.now();
    final timeLeft = challenge.endDate.difference(now);
    final startTime = challenge.startDate;
    final endTime = challenge.endDate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Started:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${startTime.day}/${startTime.month}/${startTime.year}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ends:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${endTime.day}/${endTime.month}/${endTime.year}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Time Remaining:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                challenge.isCompleted
                    ? 'Completed'
                    : isExpired
                        ? 'Expired'
                        : timeLeft.inDays > 0
                            ? '${timeLeft.inDays} days'
                            : '${timeLeft.inHours} hours',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: challenge.isCompleted
                      ? Colors.green
                      : isExpired
                          ? Colors.red
                          : timeLeft.inDays <= 1
                              ? Colors.orange
                              : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Challenge Completion Celebration
class ChallengeCompletionCelebration extends StatefulWidget {
  const ChallengeCompletionCelebration({
    super.key,
    required this.challenge,
    this.onDismiss,
  });
  final models.Challenge challenge;
  final VoidCallback? onDismiss;

  @override
  State<ChallengeCompletionCelebration> createState() =>
      _ChallengeCompletionCelebrationState();
}

class _ChallengeCompletionCelebrationState
    extends State<ChallengeCompletionCelebration>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5),
    ));

    _animationController.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.black54,
      child: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TODO: Add confetti animation
                      const Icon(
                        Icons.celebration,
                        size: 64,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Challenge Completed!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.challenge.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.stars, color: Colors.amber),
                                const SizedBox(width: 8),
                                Text(
                                  '+${widget.challenge.pointsReward} Points',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (widget.challenge.rewardBadges.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.military_tech,
                                      color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'New Badge${widget.challenge.rewardBadges.length > 1 ? 's' : ''} Unlocked!',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
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
            );
          },
        ),
      ),
    );
  }
}

// Challenge Summary Widget
class ChallengeSummaryCard extends StatelessWidget {
  const ChallengeSummaryCard({
    super.key,
    required this.challenges,
  });
  final List<models.Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeChallenges = challenges
        .where((c) => !c.isCompleted && !c.endDate.isBefore(DateTime.now()))
        .length;
    final completedChallenges = challenges.where((c) => c.isCompleted).length;
    final totalPoints = challenges
        .where((c) => c.isCompleted)
        .fold<int>(0, (sum, c) => sum + c.pointsReward);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Challenge Summary',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.assignment,
                    'Active',
                    activeChallenges.toString(),
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.check_circle,
                    'Completed',
                    completedChallenges.toString(),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    theme,
                    Icons.stars,
                    'Points Earned',
                    totalPoints.toString(),
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
