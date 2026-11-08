import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/achievement.dart';
import '../../../services/gamification_service.dart';
import '../../providers/gamification_stats_provider.dart';

/// Widget para mostrar el progreso de logros en desarrollo
class AchievementProgressWidget extends ConsumerWidget {
  const AchievementProgressWidget({
    super.key,
    required this.userId,
  });
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(activeAchievementProgressProvider(userId));

    return progressAsync.when(
      data: (progressList) {
        if (progressList.isEmpty) {
          return _buildEmptyWidget(context);
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(activeAchievementProgressProvider(userId).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProgressSummary(context, progressList),
              const SizedBox(height: 20),
              _buildProgressList(context, progressList),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) =>
          _buildErrorWidget(context, ref, error.toString()),
    );
  }

  Widget _buildErrorWidget(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error al cargar el progreso',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                ref.refresh(activeAchievementProgressProvider(userId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin Progreso Activo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comienza a usar la aplicación para ver tu progreso hacia los logros',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navegar a la pantalla principal
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              },
              icon: const Icon(Icons.movie),
              label: const Text('Explorar Películas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummary(
      BuildContext context, List<DetailedAchievementProgress> progressList) {
    final totalProgress = progressList.length;
    final nearCompletionCount =
        progressList.where((p) => p.getProgressPercentage() >= 0.75).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progreso Activo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$totalProgress logros en progreso',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nearCompletionCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.near_me,
                    color: Colors.yellow.shade300,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$nearCompletionCount cerca de completarse (75%+)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressList(
      BuildContext context, List<DetailedAchievementProgress> progressList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logros en Progreso',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: progressList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final detailedProgress = progressList[index];
            return _buildProgressCard(context, detailedProgress);
          },
        ),
      ],
    );
  }

  Widget _buildProgressCard(
      BuildContext context, DetailedAchievementProgress detailedProgress) {
    final progressPercentage = detailedProgress.getProgressPercentage() * 100;
    final isNearCompletion = detailedProgress.isNearCompletion;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isNearCompletion ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isNearCompletion ? 2 : 1,
        ),
        boxShadow: isNearCompletion
            ? [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título y rareza
          Row(
            children: [
              // Icono de rareza
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getRarityColor(detailedProgress.achievement.rarity)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getRarityIcon(detailedProgress.achievement.rarity),
                  color: _getRarityColor(detailedProgress.achievement.rarity),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detailedProgress.achievement.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getRarityName(detailedProgress.achievement.rarity),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getRarityColor(
                                detailedProgress.achievement.rarity),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              if (isNearCompletion)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me,
                        color: Colors.orange.shade700,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cerca',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Descripción
          Text(
            detailedProgress.achievement.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),

          const SizedBox(height: 16),

          // Barra de progreso
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso: ${detailedProgress.progress.currentValue}/${detailedProgress.achievement.targetValue}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    '${progressPercentage.toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isNearCompletion
                              ? Colors.orange.shade700
                              : Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressPercentage / 100,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNearCompletion
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
                minHeight: 6,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Información adicional
          Row(
            children: [
              Icon(
                Icons.stars,
                color: Colors.amber.shade600,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${detailedProgress.achievement.points} puntos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getCategoryName(detailedProgress.achievement.category),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Colors.grey.shade600;
      case AchievementRarity.uncommon:
        return Colors.green.shade600;
      case AchievementRarity.rare:
        return Colors.blue.shade600;
      case AchievementRarity.epic:
        return Colors.purple.shade600;
      case AchievementRarity.legendary:
        return Colors.orange.shade600;
    }
  }

  IconData _getRarityIcon(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Icons.circle;
      case AchievementRarity.uncommon:
        return Icons.hexagon;
      case AchievementRarity.rare:
        return Icons.diamond;
      case AchievementRarity.epic:
        return Icons.auto_awesome;
      case AchievementRarity.legendary:
        return Icons.workspace_premium;
    }
  }

  String _getRarityName(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Común';
      case AchievementRarity.uncommon:
        return 'Poco Común';
      case AchievementRarity.rare:
        return 'Raro';
      case AchievementRarity.epic:
        return 'Épico';
      case AchievementRarity.legendary:
        return 'Legendario';
    }
  }

  String _getCategoryName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.movies:
        return 'Películas';
      case AchievementCategory.favorites:
        return 'Favoritos';
      case AchievementCategory.exploration:
        return 'Exploración';
      case AchievementCategory.social:
        return 'Social';
    }
  }
}
