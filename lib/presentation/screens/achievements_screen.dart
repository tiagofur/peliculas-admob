import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/achievement_progress.dart';
import '../../services/gamification_service.dart';
import '../providers/gamification_stats_provider.dart';
import '../widgets/achievements/achievement_card_widget.dart';

/// Provider para obtener todos los logros disponibles
final allAchievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final service = ref.read(gamificationServiceProvider);
  await service.initialize();
  return service.getAllAchievements();
});

/// Provider para obtener estadísticas de gamificación del usuario
final gamificationStatsProvider =
    FutureProvider.family<GamificationStats?, String>((ref, userId) async {
  final service = ref.read(gamificationServiceProvider);
  await service.initialize();
  return service.getGamificationStats(userId);
});

/// Provider para obtener progreso detallado del usuario
final userProgressProvider =
    FutureProvider.family<Map<String, AchievementProgress>, String>(
        (ref, userId) async {
  final service = ref.read(gamificationServiceProvider);
  await service.initialize();
  return service.getUserProgressDetails(userId);
});

/// Pantalla principal de logros y gamificación
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({
    super.key,
    required this.userId,
  });
  final String userId;

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    LoggerFactory.info(
        'AchievementsScreen inicializada para usuario: ${widget.userId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _buildAchievementsContent(),
    );
  }

  /// Contenido principal de logros simplificado
  Widget _buildAchievementsContent() {
    return Consumer(
      builder: (context, ref, child) {
        final achievementsAsync = ref.watch(allAchievementsProvider);
        final progressAsync = ref.watch(userProgressProvider(widget.userId));

        return achievementsAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando logros...'),
              ],
            ),
          ),
          error: (error, stack) {
            LoggerFactory.error('Error cargando logros: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error al cargar logros: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(allAchievementsProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          },
          data: (achievements) {
            return progressAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (progress) {
                // Separar logros desbloqueados y por desbloquear
                final unlockedAchievements = achievements.where((achievement) {
                  final achievementProgress = progress[achievement.id];
                  return achievementProgress?.isUnlocked ?? false;
                }).toList();

                final lockedAchievements = achievements.where((achievement) {
                  final achievementProgress = progress[achievement.id];
                  return !(achievementProgress?.isUnlocked ?? false);
                }).toList();

                return CustomScrollView(
                  slivers: [
                    // Header con título
                    SliverAppBar(
                      expandedHeight: 120.0,
                      floating: false,
                      pinned: true,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          'Mis Logros',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        centerTitle: false,
                        titlePadding:
                            const EdgeInsets.only(left: 16, bottom: 16),
                      ),
                    ),

                    // Logros desbloqueados
                    if (unlockedAchievements.isNotEmpty) ...[
                      _buildSectionHeader(
                        '✨ Logros Completados',
                        '${unlockedAchievements.length} desbloqueado${unlockedAchievements.length != 1 ? 's' : ''}',
                        true,
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final achievement = unlockedAchievements[index];
                              final achievementProgress =
                                  progress[achievement.id];
                              return AchievementCardWidget(
                                achievement: achievement,
                                progress: achievementProgress,
                                onTap: () => _showAchievementDetails(
                                    context, achievement, achievementProgress),
                              );
                            },
                            childCount: unlockedAchievements.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],

                    // Logros por desbloquear
                    if (lockedAchievements.isNotEmpty) ...[
                      _buildSectionHeader(
                        '🎯 Por Conseguir',
                        '${lockedAchievements.length} disponible${lockedAchievements.length != 1 ? 's' : ''}',
                        false,
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final achievement = lockedAchievements[index];
                              final achievementProgress =
                                  progress[achievement.id];
                              return AchievementCardWidget(
                                achievement: achievement,
                                progress: achievementProgress,
                                onTap: () => _showAchievementDetails(
                                    context, achievement, achievementProgress),
                              );
                            },
                            childCount: lockedAchievements.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],

                    // Estado vacío si no hay logros
                    if (achievements.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_events_outlined,
                                size: 80,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay logros disponibles',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '¡Comienza a ver películas para desbloquear logros!',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Header de sección con estilo Material 3
  Widget _buildSectionHeader(String title, String subtitle, bool isCompleted) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isCompleted
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra detalles de un logro específico
  void _showAchievementDetails(BuildContext context, Achievement achievement,
      AchievementProgress? progress) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header del logro
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _getRarityColor(achievement.rarity)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getRarityColor(achievement.rarity),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getAchievementIcon(achievement.type),
                                size: 30,
                                color: _getRarityColor(achievement.rarity),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    achievement.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    _getRarityText(achievement.rarity),
                                    style: TextStyle(
                                      color:
                                          _getRarityColor(achievement.rarity),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (progress?.isUnlocked ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${achievement.points}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Descripción
                        Text(
                          'Descripción',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          achievement.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),

                        const SizedBox(height: 24),

                        // Progreso
                        if (progress != null) ...[
                          Text(
                            'Progreso',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress
                                .getProgressPercentage(achievement.targetValue),
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getRarityColor(achievement.rarity),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${progress.currentValue} / ${achievement.targetValue}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (progress.unlockedDate != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_available,
                                      color: Colors.green.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Desbloqueado el',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${progress.unlockedDate!.day}/${progress.unlockedDate!.month}/${progress.unlockedDate!.year}',
                                          style: TextStyle(
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 24),

                        // Detalles adicionales
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                  'Puntos', '${achievement.points}'),
                              _buildDetailRow('Categoría',
                                  _getCategoryText(achievement.category)),
                              _buildDetailRow(
                                  'Tipo', _getTypeText(achievement.type)),
                              if (achievement.prerequisites.isNotEmpty)
                                _buildDetailRow('Prerequisitos',
                                    '${achievement.prerequisites.length} logro(s)'),
                              if (achievement.isRepeatable)
                                _buildDetailRow('Repetible', 'Sí'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return Colors.grey;
      case AchievementRarity.uncommon:
        return Colors.green;
      case AchievementRarity.rare:
        return Colors.blue;
      case AchievementRarity.epic:
        return Colors.purple;
      case AchievementRarity.legendary:
        return Colors.orange;
    }
  }

  String _getRarityText(AchievementRarity rarity) {
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

  String _getCategoryText(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.movies:
        return 'Películas';
      case AchievementCategory.exploration:
        return 'Exploración';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.favorites:
        return 'Favoritos';
    }
  }

  String _getTypeText(AchievementType type) {
    switch (type) {
      case AchievementType.moviesWatched:
        return 'Películas Vistas';
      case AchievementType.genreExplorer:
        return 'Explorador de Géneros';
      case AchievementType.yearStreak:
        return 'Racha Anual';
      case AchievementType.socialInteraction:
        return 'Interacción Social';
      case AchievementType.qualityViewer:
        return 'Espectador de Calidad';
      case AchievementType.timeSpent:
        return 'Tiempo Invertido';
      case AchievementType.discovery:
        return 'Descubrimiento';
    }
  }

  IconData _getAchievementIcon(AchievementType type) {
    switch (type) {
      case AchievementType.moviesWatched:
        return Icons.movie;
      case AchievementType.genreExplorer:
        return Icons.explore;
      case AchievementType.yearStreak:
        return Icons.calendar_today;
      case AchievementType.socialInteraction:
        return Icons.people;
      case AchievementType.qualityViewer:
        return Icons.star;
      case AchievementType.timeSpent:
        return Icons.schedule;
      case AchievementType.discovery:
        return Icons.search;
    }
  }
}
