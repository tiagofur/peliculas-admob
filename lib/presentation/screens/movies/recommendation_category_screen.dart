import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class RecommendationCategoryScreen extends ConsumerStatefulWidget {
  const RecommendationCategoryScreen({
    super.key,
    required this.categoryId,
  });

  static const name = 'recommendation-category-screen';
  final String categoryId;

  @override
  RecommendationCategoryScreenState createState() => RecommendationCategoryScreenState();
}

class RecommendationCategoryScreenState extends ConsumerState<RecommendationCategoryScreen> {
  @override
  Widget build(BuildContext context) {
    final recommendationsAsync = ref.watch(recommendationsByCategoryProvider(widget.categoryId));
    final categoryInfo = _getCategoryInfo(widget.categoryId);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  categoryInfo['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getCategoryGradient(widget.categoryId),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          categoryInfo['icon'] as IconData,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            categoryInfo['description'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            recommendationsAsync.when(
              data: (recommendations) {
                if (recommendations.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No se encontraron películas\npara esta categoría',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final recommendation = recommendations[index];
                        return MoviePosterLink(
                          movie: Movie(
                            id: recommendation.movieId,
                            title: recommendation.title,
                            overview: recommendation.reason,
                            releaseDate: DateTime.now(),
                            adult: false,
                            backdropPath: '',
                            genreIds: [],
                            originalLanguage: 'es',
                            originalTitle: recommendation.title,
                            popularity: recommendation.score,
                            posterPath: recommendation.posterPath,
                            video: false,
                            voteAverage: recommendation.score,
                            voteCount: 0,
                          ),
                        );
                      },
                      childCount: recommendations.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar recomendaciones:\n${error.toString()}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(recommendationsByCategoryProvider(widget.categoryId));
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(String categoryId) {
    switch (categoryId) {
      case 'romantic_night':
        return {
          'title': 'Para ver en pareja',
          'description': 'Películas perfectas para una noche romántica',
          'icon': Icons.favorite,
        };
      case 'hidden_gems':
        return {
          'title': 'Joyas ocultas',
          'description': 'Películas increíbles que pocos conocen',
          'icon': Icons.diamond,
        };
      case 'classic_forgotten':
        return {
          'title': 'Clásicos olvidados',
          'description': 'Obras maestras del cine que merecen ser recordadas',
          'icon': Icons.history,
        };
      case 'weekend_fun':
        return {
          'title': 'Diversión de fin de semana',
          'description': 'Entretenimiento ligero para relajarse',
          'icon': Icons.weekend,
        };
      case 'mind_bending':
        return {
          'title': 'Que te harán pensar',
          'description': 'Películas complejas y fascinantes',
          'icon': Icons.psychology,
        };
      case 'feel_good':
        return {
          'title': 'Para sentirse bien',
          'description': 'Películas que alegran el día',
          'icon': Icons.sentiment_very_satisfied,
        };
      default:
        return {
          'title': 'Recomendaciones',
          'description': 'Películas seleccionadas para ti',
          'icon': Icons.movie,
        };
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
}