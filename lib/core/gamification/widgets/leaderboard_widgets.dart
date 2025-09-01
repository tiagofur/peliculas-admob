import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/leaderboard_providers.dart';
import '../leaderboard_service.dart';

/// Main leaderboard view with tabs for different categories
class LeaderboardView extends ConsumerStatefulWidget {
  const LeaderboardView({super.key});

  @override
  ConsumerState<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends ConsumerState<LeaderboardView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LeaderboardTimePeriod _selectedTimePeriod = LeaderboardTimePeriod.weekly;

  final List<LeaderboardCategory> _categories = [
    LeaderboardCategory.totalPoints,
    LeaderboardCategory.moviesWatched,
    LeaderboardCategory.achievementsUnlocked,
    LeaderboardCategory.streakDays,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboards'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<LeaderboardTimePeriod>(
            icon: Icon(
              Icons.schedule,
              color: theme.colorScheme.primary,
            ),
            onSelected: (period) {
              setState(() {
                _selectedTimePeriod = period;
              });
            },
            itemBuilder: (context) =>
                LeaderboardTimePeriod.values.map((period) {
              return PopupMenuItem(
                value: period,
                child: Row(
                  children: [
                    Icon(
                      _selectedTimePeriod == period
                          ? Icons.check
                          : Icons.schedule,
                      size: 16,
                      color: _selectedTimePeriod == period
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(period.displayName),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: theme.colorScheme.primary,
          tabs: _categories.map((category) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon),
                  const SizedBox(width: 4),
                  Text(category.displayName),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((category) {
          return LeaderboardTab(
            category: category,
            timePeriod: _selectedTimePeriod,
          );
        }).toList(),
      ),
    );
  }
}

/// Individual leaderboard tab
class LeaderboardTab extends ConsumerWidget {
  const LeaderboardTab({
    super.key,
    required this.category,
    required this.timePeriod,
  });

  final LeaderboardCategory category;
  final LeaderboardTimePeriod timePeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = LeaderboardQuery(
      category: category,
      timePeriod: timePeriod,
      limit: 50,
    );

    final leaderboardAsync = ref.watch(leaderboardProvider(query));
    final statsAsync = ref.watch(leaderboardStatsProvider(query));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider(query));
        ref.invalidate(leaderboardStatsProvider(query));
      },
      child: CustomScrollView(
        slivers: [
          // Stats header
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => LeaderboardStatsCard(stats: stats),
              loading: () => const LeaderboardStatsCardSkeleton(),
              error: (error, stack) => const SizedBox.shrink(),
            ),
          ),

          // Leaderboard list
          leaderboardAsync.when(
            data: (entries) => _buildLeaderboardList(context, entries),
            loading: () => const SliverToBoxAdapter(
              child: LeaderboardSkeleton(),
            ),
            error: (error, stack) => SliverToBoxAdapter(
              child: LeaderboardErrorWidget(
                error: error.toString(),
                onRetry: () {
                  ref.invalidate(leaderboardProvider(query));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(
      BuildContext context, List<LeaderboardEntry> entries) {
    if (entries.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyLeaderboardWidget(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = entries[index];
          final rank = index + 1;

          if (rank <= 3) {
            return TopRankCard(
              entry: entry,
              rank: rank,
              category: category,
            );
          } else {
            return LeaderboardEntryCard(
              entry: entry,
              rank: rank,
              category: category,
            );
          }
        },
        childCount: entries.length,
      ),
    );
  }
}

/// Stats card showing leaderboard statistics
class LeaderboardStatsCard extends StatelessWidget {
  const LeaderboardStatsCard({super.key, required this.stats});

  final LeaderboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Participants',
              value: stats.totalParticipants.toString(),
              icon: Icons.people,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: 'Top Score',
              value: stats.topScore.toString(),
              icon: Icons.emoji_events,
            ),
          ),
          Expanded(
            child: _StatItem(
              label: 'Average',
              value: stats.averageScore.toStringAsFixed(0),
              icon: Icons.trending_up,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Top 3 rank card with special styling
class TopRankCard extends StatelessWidget {
  const TopRankCard({
    super.key,
    required this.entry,
    required this.rank,
    required this.category,
  });

  final LeaderboardEntry entry;
  final int rank;
  final LeaderboardCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = _getRankColor(rank);
    final rankIcon = _getRankIcon(rank);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rankColor.withValues(alpha: 0.1),
            rankColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rankColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surface,
              child: entry.avatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: entry.avatarUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => Icon(
                          Icons.person,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : Icon(
                        Icons.person,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1,
                  ),
                ),
                child: Icon(
                  rankIcon,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          entry.username,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Active player',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '#$rank',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
            Text(
              entry.score.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.military_tech;
      case 3:
        return Icons.workspace_premium;
      default:
        return Icons.star;
    }
  }
}

/// Regular leaderboard entry card
class LeaderboardEntryCard extends StatelessWidget {
  const LeaderboardEntryCard({
    super.key,
    required this.entry,
    required this.rank,
    required this.category,
  });

  final LeaderboardEntry entry;
  final int rank;
  final LeaderboardCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.surface,
        child: entry.avatarUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: entry.avatarUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => Icon(
                    Icons.person,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              )
            : Icon(
                Icons.person,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
      ),
      title: Text(
        entry.username,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: const Text(
        'Active player',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#$rank',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                entry.score.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading widget
class LeaderboardSkeleton extends StatelessWidget {
  const LeaderboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(10, (index) {
        return const ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey,
          ),
          title: SizedBox(
            height: 16,
            width: 120,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
          subtitle: SizedBox(
            height: 12,
            width: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
          trailing: SizedBox(
            height: 16,
            width: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Stats card skeleton
class LeaderboardStatsCardSkeleton extends StatelessWidget {
  const LeaderboardStatsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        children: [
          Expanded(child: _SkeletonStatItem()),
          Expanded(child: _SkeletonStatItem()),
          Expanded(child: _SkeletonStatItem()),
        ],
      ),
    );
  }
}

class _SkeletonStatItem extends StatelessWidget {
  const _SkeletonStatItem();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Colors.grey,
        ),
        SizedBox(height: 4),
        SizedBox(
          height: 16,
          width: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        SizedBox(height: 2),
        SizedBox(
          height: 12,
          width: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty leaderboard widget
class EmptyLeaderboardWidget extends StatelessWidget {
  const EmptyLeaderboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Rankings Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to appear on the leaderboard!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error widget
class LeaderboardErrorWidget extends StatelessWidget {
  const LeaderboardErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Leaderboard',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
