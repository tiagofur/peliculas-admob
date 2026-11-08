import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/tmdb_image_utils.dart';
import '../../domain/entities/enhanced_user_profile.dart';
import '../../services/enhanced_user_profile_service.dart';
import '../../services/performance/image_optimization_service.dart';
import '../../services/performance/memory_manager_service.dart';
import '../widgets/achievement_display_widget.dart';
import '../widgets/preferences_settings_widget.dart';
import '../widgets/stats_overview_widget.dart';

/// Provider para el perfil de usuario mejorado
final enhancedUserProfileProvider =
    FutureProvider.family<EnhancedUserProfile, String>((ref, userId) {
  return EnhancedUserProfileService.instance.getUserProfile(userId);
});

/// Pantalla principal del perfil de usuario mejorado
class EnhancedUserProfileScreen extends ConsumerStatefulWidget {
  const EnhancedUserProfileScreen({
    super.key,
    required this.userId,
  });
  final String userId;

  @override
  ConsumerState<EnhancedUserProfileScreen> createState() =>
      _EnhancedUserProfileScreenState();
}

class _EnhancedUserProfileScreenState
    extends ConsumerState<EnhancedUserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Colores pre-computados para evitar reconstrucción
  static const Color _whiteWithOpacity09 =
      Color(0xE6FFFFFF); // white.withValues(alpha: 0.9)
  static const Color _whiteWithOpacity02 =
      Color(0x33FFFFFF); // white.withValues(alpha: 0.2)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Inicializar optimizaciones de performance
    MemoryManagerService.instance.configureImageCache();
    MemoryManagerService.instance.optimizeForDevice();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Limpieza de memoria al salir de la pantalla
    MemoryManagerService.instance.performMemoryCleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync =
        ref.watch(enhancedUserProfileProvider(widget.userId));

    return Scaffold(
      body: userProfileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => _buildErrorWidget(error),
        data: (profile) => _buildProfileContent(context, profile),
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar el perfil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.refresh(enhancedUserProfileProvider(widget.userId)),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
      BuildContext context, EnhancedUserProfile profile) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildProfileHeader(context, profile),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettingsBottomSheet(context, profile),
              ),
            ],
          ),
        ];
      },
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.analytics), text: 'Estadísticas'),
                Tab(icon: Icon(Icons.emoji_events), text: 'Logros'),
                Tab(icon: Icon(Icons.favorite), text: 'Favoritas'),
                Tab(icon: Icon(Icons.settings), text: 'Configuración'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(context, profile),
                _buildAchievementsTab(context, profile),
                _buildFavoritesTab(context, profile),
                _buildSettingsTab(context, profile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, EnhancedUserProfile profile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.primary,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Avatar optimizado
              ImageOptimizationService.instance.buildOptimizedAvatar(
                imageUrl: profile.avatarUrl,
                radius: 50,
                child: Text(
                  profile.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Name and level
              Text(
                profile.displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _whiteWithOpacity02,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getUserLevelIcon(profile.userLevel),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      profile.userLevel.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _whiteWithOpacity09,
                    fontSize: 14,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Quick stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickStat(
                    'Películas',
                    profile.stats.totalMoviesWatched.toString(),
                    Icons.movie,
                  ),
                  _buildQuickStat(
                    'Calificadas',
                    profile.stats.totalMoviesRated.toString(),
                    Icons.star,
                  ),
                  _buildQuickStat(
                    'Promedio',
                    profile.stats.averageRating.toStringAsFixed(1),
                    Icons.grade,
                  ),
                  _buildQuickStat(
                    'Horas',
                    profile.stats.totalWatchTimeHours.round().toString(),
                    Icons.access_time,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: _whiteWithOpacity09,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  IconData _getUserLevelIcon(UserLevel level) {
    switch (level) {
      case UserLevel.newcomer:
        return Icons.baby_changing_station;
      case UserLevel.movieFan:
        return Icons.favorite;
      case UserLevel.cinephile:
        return Icons.local_movies;
      case UserLevel.movieExpert:
        return Icons.school;
      case UserLevel.filmCritic:
        return Icons.workspace_premium;
    }
  }

  Widget _buildStatsTab(BuildContext context, EnhancedUserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsOverviewWidget(stats: profile.stats),
          const SizedBox(height: 16),

          // Géneros favoritos
          _buildGenrePreferencesCard(profile.stats.genrePreferences),
          const SizedBox(height: 16),

          // Estadísticas anuales
          _buildAnnualStatsCard(profile.stats.annualStats),
          const SizedBox(height: 16),

          // Décadas favoritas
          _buildDecadePreferencesCard(profile.stats.yearPreferences),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab(
      BuildContext context, EnhancedUserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AchievementDisplayWidget(achievements: profile.stats.achievements),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab(BuildContext context, EnhancedUserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Películas favoritas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (profile.favoriteMovies.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tienes películas favoritas aún',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Marca películas como favoritas para verlas aquí',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            ImageOptimizationService.instance.buildOptimizedMovieList(
              itemCount: profile.favoriteMovies.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final movie = profile.favoriteMovies[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        ImageOptimizationService.instance.buildOptimizedPoster(
                      imageUrl: movie.posterPath.isNotEmpty
                          ? resolvePosterUrl(
                              movie.posterPath,
                              size: 'w154',
                            )
                          : null,
                      width: 50,
                      height: 75,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(movie.title),
                  subtitle: Text('${movie.releaseDate.year}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(movie.voteAverage.toStringAsFixed(1)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context, EnhancedUserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PreferencesSettingsWidget(preferences: profile.preferences),
        ],
      ),
    );
  }

  Widget _buildGenrePreferencesCard(Map<String, int> genrePreferences) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Géneros favoritos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...genrePreferences.entries.take(5).map((entry) {
              final percentage = (entry.value /
                      genrePreferences.values.reduce((a, b) => a + b)) *
                  100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(entry.key),
                    ),
                    Expanded(
                      flex: 5,
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${percentage.round()}%'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnualStatsCard(Map<String, dynamic> annualStats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu ${annualStats['year'] ?? DateTime.now().year} en películas',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Películas este año',
                    '${annualStats['moviesThisYear'] ?? 0}',
                    Icons.movie,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Género top',
                    annualStats['topGenreThisYear'] ?? 'N/A',
                    Icons.category,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Mes favorito',
                    annualStats['favoriteMonthForMovies'] ?? 'N/A',
                    Icons.calendar_month,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Película más larga',
                    '${annualStats['longestMovieWatched'] ?? 0}m',
                    Icons.access_time,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecadePreferencesCard(Map<int, int> yearPreferences) {
    Map<String, int> decades = {};
    for (var entry in yearPreferences.entries) {
      String decade = '${(entry.key ~/ 10) * 10}s';
      decades[decade] = (decades[decade] ?? 0) + entry.value;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Décadas favoritas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: decades.entries.take(4).map((entry) {
                return Chip(
                  label: Text('${entry.key}: ${entry.value}'),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showSettingsBottomSheet(
      BuildContext context, EnhancedUserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Configuración del perfil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PreferencesSettingsWidget(
                        preferences: profile.preferences),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
