import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/challenge_providers.dart';
import '../../../presentation/providers/gamification_providers.dart';
import '../achievement_system.dart' as achievement_sys;
import '../challenge_system.dart';
import '../models/user_progress.dart';
import 'achievement_card.dart';
import 'level_progress_indicator.dart';

/// Dashboard principal de gamificación
class GamificationDashboard extends ConsumerStatefulWidget {
  const GamificationDashboard({
    super.key,
    this.onViewAllAchievements,
    this.onViewLeaderboard,
    this.onViewChallenges,
  });
  final VoidCallback? onViewAllAchievements;
  final VoidCallback? onViewLeaderboard;
  final VoidCallback? onViewChallenges;

  @override
  ConsumerState<GamificationDashboard> createState() =>
      _GamificationDashboardState();
}

class _GamificationDashboardState extends ConsumerState<GamificationDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProgressAsync = ref.watch(userProgressProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: userProgressAsync.when(
        data: (userProgress) => Column(
          children: [
            _buildHeader(theme, userProgress),
            _buildTabBar(theme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(userProgress),
                  _buildAchievementsTab(userProgress),
                  _buildChallengesTab(),
                  _buildStatsTab(userProgress),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, UserProgress userProgress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tu Progreso',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nivel ${userProgress.currentLevel} • ${userProgress.totalPoints} puntos',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                LevelProgressIndicator(
                  userProgress: userProgress,
                  size: 80,
                  showDetails: false,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQuickStats(theme, userProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, UserProgress userProgress) {
    final activeChallengesAsync = ref.watch(activeChallengesProvider);
    return Row(
      children: [
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final unlockedAchievements =
                  ref.watch(unlockedAchievementsProvider);
              return _buildStatCard(
                theme,
                'Logros',
                '${unlockedAchievements.length}',
                Icons.emoji_events,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme,
            'Desafíos',
            '${activeChallengesAsync.length}',
            Icons.flag,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme,
            'Racha',
            '${userProgress.streakDays}',
            Icons.local_fire_department,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      child: TabBar(
        controller: _tabController,
        labelColor: theme.primaryColor,
        unselectedLabelColor:
            theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
        indicatorColor: theme.primaryColor,
        tabs: const [
          Tab(text: 'Resumen', icon: Icon(Icons.dashboard, size: 20)),
          Tab(text: 'Logros', icon: Icon(Icons.emoji_events, size: 20)),
          Tab(text: 'Desafíos', icon: Icon(Icons.flag, size: 20)),
          Tab(text: 'Estadísticas', icon: Icon(Icons.analytics, size: 20)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(UserProgress userProgress) {
    final recentAchievementsAsync = ref.watch(recentAchievementsProvider);
    final activeChallengesAsync = ref.watch(activeChallengesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progreso de nivel
          _buildSectionHeader('Progreso de Nivel'),
          const SizedBox(height: 12),
          LevelProgressIndicator(
            userProgress: userProgress,
            size: 120,
            showDetails: true,
          ),
          const SizedBox(height: 24),

          // Logros recientes
          _buildSectionHeader('Logros Recientes'),
          const SizedBox(height: 12),
          recentAchievementsAsync.when(
            data: (achievements) {
              if (achievements.isEmpty) {
                return _buildEmptyState('No hay logros recientes');
              }
              return Column(
                children: achievements
                    .map((achievement) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AchievementCard(
                            achievement: achievement,
                            isUnlocked: true,
                            isCompact: true,
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (err, stack) => Text('Error: $err'),
          ),

          Consumer(
            builder: (context, ref, child) {
              final recentAchievements = ref.watch(recentAchievementsProvider);
              return recentAchievements.when(
                data: (achievements) => achievements.isNotEmpty
                    ? Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildViewAllButton('Ver todos los logros',
                              widget.onViewAllAchievements),
                          const SizedBox(height: 24),
                        ],
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              );
            },
          ),

          // Insignias
          // TODO: Implement badge display
          // _buildSectionHeader('Insignias'),
          // const SizedBox(height: 12),
          // BadgeDisplay(
          //   unlockedAchievements: [], // TODO: Pass unlocked achievements
          //   isHorizontal: true,
          //   maxVisible: 5,
          //   onViewAll: widget.onViewAllAchievements,
          // ),
          // const SizedBox(height: 24),

          // Desafíos activos
          _buildSectionHeader('Desafíos Activos'),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              if (activeChallengesAsync.isEmpty) {
                return _buildEmptyState('No hay desafíos activos');
              }
              return Column(
                children: activeChallengesAsync
                    .take(2)
                    .map((challenge) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildChallengeCard(challenge, userProgress),
                        ))
                    .toList(),
              );
            },
          ),

          if (activeChallengesAsync.length > 2) ...[
            const SizedBox(height: 8),
            _buildViewAllButton(
                'Ver todos los desafíos', widget.onViewChallenges),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementsTab(UserProgress userProgress) {
    final availableAchievements =
        ref.watch(achievement_sys.allAchievementsProvider);
    final unlockedAchievements = ref.watch(unlockedAchievementsProvider);
    final unlockedIds = unlockedAchievements.map((a) => a.id).toSet();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Próximos Logros'),
          const SizedBox(height: 12),
          if (availableAchievements.isEmpty)
            _buildEmptyState('No hay logros disponibles')
          else
            ...availableAchievements.map((achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AchievementCard(
                    achievement: achievement,
                    isUnlocked: unlockedIds.contains(achievement.id),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildChallengesTab() {
    final activeChallengesAsync = ref.watch(activeChallengesProvider);
    final userProgressAsync = ref.watch(userProgressProvider);

    return userProgressAsync.when(
      data: (userProgress) => activeChallengesAsync.isEmpty
          ? _buildEmptyState('No hay desafíos disponibles')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Desafíos Activos'),
                  const SizedBox(height: 12),
                  ...activeChallengesAsync.map((challenge) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildChallengeCard(challenge, userProgress),
                      )),
                ],
              ),
            ),
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }

  Widget _buildStatsTab(UserProgress userProgress) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Estadísticas Generales'),
          const SizedBox(height: 12),
          _buildStatsGrid(userProgress),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  Widget _buildChallengeCard(Challenge challenge, UserProgress userProgress) {
    final theme = Theme.of(context);
    final progress = challenge.currentProgress;
    final progressPercent = (progress / challenge.targetValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.flag,
                  color: theme.primaryColor,
                  size: 20,
                ),
              ),
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
                    ),
                    Text(
                      challenge.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${challenge.pointsReward}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '$progress / ${challenge.targetValue}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progressPercent,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(UserProgress userProgress) {
    final theme = Theme.of(context);
    final unlockedAchievements = ref.watch(unlockedAchievementsProvider);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatGridItem(
          theme,
          'Puntos Totales',
          '${userProgress.totalPoints}',
          Icons.stars,
          Colors.amber,
        ),
        _buildStatGridItem(
          theme,
          'Nivel Actual',
          '${userProgress.currentLevel}',
          Icons.trending_up,
          Colors.blue,
        ),
        _buildStatGridItem(
          theme,
          'Logros Desbloqueados',
          '${unlockedAchievements.length}',
          Icons.emoji_events,
          Colors.green,
        ),
        _buildStatGridItem(
          theme,
          'Racha Actual',
          '${userProgress.streakDays} días',
          Icons.local_fire_department,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatGridItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
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
            style: theme.textTheme.titleLarge?.copyWith(
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
      ),
    );
  }
}
