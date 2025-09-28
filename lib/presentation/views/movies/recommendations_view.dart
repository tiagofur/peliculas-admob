import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/recommendation.dart';
import '../../providers/providers.dart';
import '../../widgets/shared/full_screen_loader.dart';

class RecommendationsView extends ConsumerStatefulWidget {
  const RecommendationsView({super.key});

  @override
  RecommendationsViewState createState() => RecommendationsViewState();
}

class RecommendationsViewState extends ConsumerState<RecommendationsView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final personalizedRecommendations =
        ref.watch(personalizedRecommendationsProvider);
    final discoveryCategories = ref.watch(discoveryCategoriesProvider);
    final userStats = ref.watch(basicUserStatsProvider);

    return Scaffold(
      body: personalizedRecommendations.when(
        data: (recommendations) => _buildRecommendationsContent(
            recommendations, discoveryCategories, userStats),
        loading: () => const FullScreenLoader(),
        error: (error, stack) => _buildErrorState(),
      ),
    );
  }

  Widget _buildRecommendationsContent(
    List<Recommendation> recommendations,
    AsyncValue<List<RecommendationCategory>> categoriesAsync,
    BasicUserStats userStats,
  ) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        _buildUserStatsSection(userStats),
        if (recommendations.isNotEmpty)
          _buildPersonalizedSection(recommendations),
        _buildDiscoverySection(categoriesAsync),
        _buildMoodSection(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple, Colors.blue],
          ),
        ),
      ),
      title: const Text(
        'Recomendaciones',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildUserStatsSection(BasicUserStats userStats) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade100, Colors.blue.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu perfil cinéfilo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Favoritas',
                    userStats.totalFavorites.toString(),
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Vistas',
                    userStats.totalWatched.toString(),
                    Icons.visibility,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Rating',
                    userStats.averageRating.toStringAsFixed(1),
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
            if (userStats.topGenres.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Géneros favoritos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: userStats.topGenres
                    .map((genre) => Chip(
                          label: Text(
                            genre,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.8),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedSection(List<Recommendation> recommendations) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Especialmente para ti',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                return _buildRecommendationCard(recommendation);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation recommendation) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/movie/${recommendation.movieId}'),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: recommendation.posterPath.isNotEmpty
                      ? Image.network(
                          resolvePosterUrl(
                            recommendation.posterPath,
                            size: 'w500',
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.movie,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.movie,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRecommendationTypeColor(recommendation.type),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              recommendation.reason,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection(
      AsyncValue<List<RecommendationCategory>> categoriesAsync) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Descubrir',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(category);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(RecommendationCategory category) {
    return GestureDetector(
      onTap: () => _navigateToCategory(category),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getCategoryGradient(category.id),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _getCategoryIcon(category.icon),
                color: Colors.white,
                size: 28,
              ),
              const Spacer(),
              Text(
                category.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                category.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSection() {
    final moods = [
      {
        'name': 'Feliz',
        'mood': 'happy',
        'icon': Icons.sentiment_very_satisfied,
        'color': Colors.orange
      },
      {
        'name': 'Romántico',
        'mood': 'romantic',
        'icon': Icons.favorite,
        'color': Colors.pink
      },
      {
        'name': 'Emocionado',
        'mood': 'excited',
        'icon': Icons.flash_on,
        'color': Colors.blue
      },
      {
        'name': 'Relajado',
        'mood': 'relaxed',
        'icon': Icons.spa,
        'color': Colors.green
      },
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              '¿Cómo te sientes hoy?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: moods.length,
              itemBuilder: (context, index) {
                final mood = moods[index];
                return _buildMoodCard(mood);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCard(Map<String, dynamic> mood) {
    return GestureDetector(
      onTap: () => _navigateToMoodRecommendations(mood['mood'] as String),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: (mood['color'] as Color).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (mood['color'] as Color).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mood['icon'] as IconData,
              color: mood['color'] as Color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              mood['name'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mood['color'] as Color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Error al cargar recomendaciones',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRecommendationTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.basedOnFavorites:
        return Colors.red;
      case RecommendationType.basedOnWatched:
        return Colors.green;
      case RecommendationType.basedOnGenre:
        return Colors.blue;
      case RecommendationType.trending:
        return Colors.orange;
      case RecommendationType.similar:
        return Colors.purple;
      case RecommendationType.mood:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  List<Color> _getCategoryGradient(String categoryId) {
    switch (categoryId) {
      case 'romantic_night':
        return [Colors.pink.shade400, Colors.red.shade400];
      case 'hidden_gems':
        return [Colors.purple.shade400, Colors.indigo.shade400];
      case 'classic_forgotten':
        return [Colors.amber.shade400, Colors.orange.shade400];
      case 'weekend_fun':
        return [Colors.green.shade400, Colors.teal.shade400];
      case 'mind_bending':
        return [Colors.blue.shade400, Colors.cyan.shade400];
      case 'feel_good':
        return [Colors.yellow.shade400, Colors.lime.shade400];
      default:
        return [Colors.grey.shade400, Colors.blueGrey.shade400];
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'favorite':
        return Icons.favorite;
      case 'diamond':
        return Icons.diamond;
      case 'history':
        return Icons.history;
      case 'weekend':
        return Icons.weekend;
      case 'psychology':
        return Icons.psychology;
      case 'sentiment_very_satisfied':
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.movie;
    }
  }

  void _navigateToCategory(RecommendationCategory category) {
    context.push('/recommendations/category/${category.id}');
  }

  void _navigateToMoodRecommendations(String mood) {
    context.push('/recommendations/mood/$mood');
  }
}
