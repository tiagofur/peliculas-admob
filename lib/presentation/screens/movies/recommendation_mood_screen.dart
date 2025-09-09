import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/movies/movie_poster_link.dart';

class RecommendationMoodScreen extends ConsumerStatefulWidget {
  const RecommendationMoodScreen({
    super.key,
    required this.mood,
  });

  static const name = 'recommendation-mood-screen';
  final String mood;

  @override
  RecommendationMoodScreenState createState() =>
      RecommendationMoodScreenState();
}

class RecommendationMoodScreenState
    extends ConsumerState<RecommendationMoodScreen> {
  @override
  Widget build(BuildContext context) {
    final recommendationsAsync =
        ref.watch(recommendationsByMoodProvider(widget.mood));
    final moodInfo = _getMoodInfo(widget.mood);

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
                  moodInfo['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getMoodGradient(widget.mood),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          moodInfo['icon'] as IconData,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            moodInfo['description'] as String,
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
                            'No se encontraron películas\npara este estado de ánimo',
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                          ref.invalidate(
                              recommendationsByMoodProvider(widget.mood));
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

  Map<String, dynamic> _getMoodInfo(String mood) {
    switch (mood) {
      case 'happy':
        return {
          'title': 'Películas para estar feliz',
          'description': 'Comedias y películas que te harán sonreír',
          'icon': Icons.sentiment_very_satisfied,
        };
      case 'romantic':
        return {
          'title': 'Películas románticas',
          'description': 'Para momentos especiales y románticos',
          'icon': Icons.favorite,
        };
      case 'excited':
        return {
          'title': 'Películas emocionantes',
          'description':
              'Acción y aventura para mantenerte al borde del asiento',
          'icon': Icons.flash_on,
        };
      case 'relaxed':
        return {
          'title': 'Películas relajantes',
          'description': 'Para descansar y disfrutar tranquilamente',
          'icon': Icons.spa,
        };
      case 'sad':
        return {
          'title': 'Películas emotivas',
          'description': 'Dramas que tocan el corazón',
          'icon': Icons.sentiment_dissatisfied,
        };
      case 'adventurous':
        return {
          'title': 'Películas de aventura',
          'description': 'Explora mundos nuevos y emocionantes',
          'icon': Icons.explore,
        };
      default:
        return {
          'title': 'Recomendaciones por estado de ánimo',
          'description': 'Películas seleccionadas según tu estado de ánimo',
          'icon': Icons.mood,
        };
    }
  }

  List<Color> _getMoodGradient(String mood) {
    switch (mood) {
      case 'happy':
        return [Colors.orange.shade400, Colors.yellow.shade400];
      case 'romantic':
        return [Colors.pink.shade400, Colors.red.shade400];
      case 'excited':
        return [Colors.blue.shade400, Colors.purple.shade400];
      case 'relaxed':
        return [Colors.green.shade400, Colors.teal.shade400];
      case 'sad':
        return [Colors.indigo.shade400, Colors.blue.shade600];
      case 'adventurous':
        return [Colors.amber.shade400, Colors.orange.shade400];
      default:
        return [Colors.grey.shade400, Colors.blueGrey.shade400];
    }
  }
}
