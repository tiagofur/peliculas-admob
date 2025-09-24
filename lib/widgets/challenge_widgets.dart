import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gamification/challenge_notifications.dart';
import '../core/gamification/models/challenge.dart';
import '../core/gamification/models/challenge_enums.dart';
import '../presentation/providers/challenge_providers.dart';

/// Widget to display a single challenge card
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    this.onTap,
    this.showProgress = true,
    this.isCompact = false,
  });
  final Challenge challenge;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildChallengeIcon(colorScheme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isCompact) ...[
                          const SizedBox(height: 4),
                          Text(
                            challenge.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildDifficultyBadge(theme),
                ],
              ),
              if (showProgress) ...[
                const SizedBox(height: 12),
                _buildProgressSection(theme),
              ],
              if (!isCompact) ...[
                const SizedBox(height: 12),
                _buildRewardSection(theme),
              ],
              const SizedBox(height: 8),
              _buildTimeSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeIcon(ColorScheme colorScheme) {
    IconData iconData;
    Color iconColor;

    switch (challenge.type) {
      case ChallengeType.genreExplorer:
        iconData = Icons.explore;
        iconColor = Colors.blue;
        break;
      case ChallengeType.marathonWeekend:
        iconData = Icons.weekend;
        iconColor = Colors.green;
        break;
      case ChallengeType.socialSharer:
        iconData = Icons.share;
        iconColor = Colors.orange;
        break;
      case ChallengeType.reviewMaster:
        iconData = Icons.rate_review;
        iconColor = Colors.purple;
        break;
      case ChallengeType.discoveryQuest:
        iconData = Icons.search;
        iconColor = Colors.red;
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
        size: isCompact ? 20 : 24,
      ),
    );
  }

  Widget _buildDifficultyBadge(ThemeData theme) {
    Color badgeColor;
    String difficultyText;

    switch (challenge.difficulty) {
      case ChallengeDifficulty.easy:
        badgeColor = Colors.green;
        difficultyText = 'Easy';
        break;
      case ChallengeDifficulty.medium:
        badgeColor = Colors.orange;
        difficultyText = 'Medium';
        break;
      case ChallengeDifficulty.hard:
        badgeColor = Colors.red;
        difficultyText = 'Hard';
        break;
      case ChallengeDifficulty.expert:
        badgeColor = Colors.purple;
        difficultyText = 'Expert';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        difficultyText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme) {
    final progressPercentage = challenge.progressPercentage;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              '${challenge.currentProgress}/${challenge.targetValue}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progressPercentage,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            challenge.isCompleted ? Colors.green : colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progressPercentage * 100).round()}% complete',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardSection(ThemeData theme) {
    return Row(
      children: [
        const Icon(
          Icons.stars,
          size: 16,
          color: Colors.amber,
        ),
        const SizedBox(width: 4),
        Text(
          '${challenge.rewardPoints} points',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade700,
          ),
        ),
        if (challenge.rewardBadges.isNotEmpty) ...[
          const SizedBox(width: 16),
          Icon(
            Icons.military_tech,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '${challenge.rewardBadges.length} badge${challenge.rewardBadges.length != 1 ? 's' : ''}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeSection(ThemeData theme) {
    final timeRemaining = challenge.timeRemaining;
    final colorScheme = theme.colorScheme;

    String timeText;
    Color timeColor;
    IconData timeIcon;

    if (challenge.isCompleted) {
      timeText = 'Completed';
      timeColor = Colors.green;
      timeIcon = Icons.check_circle;
    } else if (challenge.isExpired) {
      timeText = 'Expired';
      timeColor = Colors.red;
      timeIcon = Icons.cancel;
    } else {
      if (timeRemaining.inDays > 0) {
        timeText =
            '${timeRemaining.inDays} day${timeRemaining.inDays != 1 ? 's' : ''} left';
      } else if (timeRemaining.inHours > 0) {
        timeText =
            '${timeRemaining.inHours} hour${timeRemaining.inHours != 1 ? 's' : ''} left';
      } else {
        timeText =
            '${timeRemaining.inMinutes} minute${timeRemaining.inMinutes != 1 ? 's' : ''} left';
      }

      if (timeRemaining.inHours < 24) {
        timeColor = Colors.orange;
        timeIcon = Icons.schedule;
      } else {
        timeColor = colorScheme.onSurface;
        timeIcon = Icons.schedule;
      }
    }

    return Row(
      children: [
        Icon(
          timeIcon,
          size: 16,
          color: timeColor,
        ),
        const SizedBox(width: 4),
        Text(
          timeText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: timeColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Widget to display a list of challenges
class ChallengeList extends StatelessWidget {
  const ChallengeList({
    super.key,
    required this.challenges,
    this.emptyMessage,
    this.isCompact = false,
    this.onChallengeSelected,
  });
  final List<Challenge> challenges;
  final String? emptyMessage;
  final bool isCompact;
  final Function(Challenge)? onChallengeSelected;

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage ?? 'No challenges available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: isCompact ? const NeverScrollableScrollPhysics() : null,
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        return ChallengeCard(
          challenge: challenge,
          isCompact: isCompact,
          onTap: onChallengeSelected != null
              ? () => onChallengeSelected!(challenge)
              : null,
        );
      },
    );
  }
}

/// Widget to display challenge statistics
class ChallengeStats extends ConsumerWidget {
  const ChallengeStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Challenge Stats',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Active',
                    stats['activeChallenges'].toString(),
                    Icons.play_circle_outline,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Completed',
                    stats['completedChallenges'].toString(),
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Movies Watched',
                    stats['totalMoviesWatched'].toString(),
                    Icons.movie,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Reviews Written',
                    stats['totalReviewsWritten'].toString(),
                    Icons.rate_review,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Movies Shared',
                    stats['totalMoviesShared'].toString(),
                    Icons.share,
                    Colors.teal,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Genres Explored',
                    stats['totalGenresExplored'].toString(),
                    Icons.explore,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: stats['engagementScore'] as double,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Engagement Score: ${((stats['engagementScore'] is double ? stats['engagementScore'] as double : double.tryParse(stats['engagementScore'].toString()) ?? 0.0) * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget to display challenge notifications
class ChallengeNotificationBadge extends ConsumerWidget {
  const ChallengeNotificationBadge({
    super.key,
    required this.count,
    this.onTap,
  });
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.notifications),
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget to display a challenge notification item
class ChallengeNotificationItem extends StatelessWidget {
  const ChallengeNotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });
  final ChallengeNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: notification.isRead
          ? null
          : colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: ListTile(
        leading: _buildNotificationIcon(colorScheme),
        title: Text(
          notification.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        trailing: onDismiss != null
            ? IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                iconSize: 20,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildNotificationIcon(ColorScheme colorScheme) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case ChallengeNotificationType.newChallenge:
        iconData = Icons.new_releases;
        iconColor = Colors.blue;
        break;
      case ChallengeNotificationType.progressUpdate:
        iconData = Icons.trending_up;
        iconColor = Colors.orange;
        break;
      case ChallengeNotificationType.challengeCompleted:
        iconData = Icons.celebration;
        iconColor = Colors.green;
        break;
      case ChallengeNotificationType.challengeExpiring:
        iconData = Icons.schedule;
        iconColor = Colors.red;
        break;
      case ChallengeNotificationType.weeklyDigest:
      case ChallengeNotificationType.monthlyDigest:
        iconData = Icons.analytics;
        iconColor = Colors.purple;
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
        size: 20,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
