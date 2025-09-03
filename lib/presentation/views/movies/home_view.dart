import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/admob/banner_ad_widget.dart';
import '../../widgets/admob/full_width_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/guest_mode_banner.dart';
import '../../widgets/movies/movie_horizontal_listview_with_ads.dart';
import '../../widgets/widgets.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends ConsumerState<HomeView>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(nowPlayingMoviesProvider.notifier).loadNextPage();
        ref.read(popularMoviesProvider.notifier).loadNextPage();
        ref.read(topRatedMoviesProvider.notifier).loadNextPage();
        ref.read(upcomingMoviesProvider.notifier).loadNextPage();
        // Cargar favoritos al iniciar la app
        ref.read(favoriteMoviesProvider.notifier).loadNextPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialLoading = ref.watch(initialLoadingProvider);
    if (initialLoading) return const FullScreenLoader();

    final slideShowMovies = ref.watch(moviesSlideshowProvider);
    final nowPlayingState = ref.watch(nowPlayingMoviesProvider);
    final popularState = ref.watch(popularMoviesProvider);
    final topRatedState = ref.watch(topRatedMoviesProvider);
    final upcomingState = ref.watch(upcomingMoviesProvider);

    final nowPlayingMovies = nowPlayingState.movies;
    final popularMovies = popularState.movies;
    final topRatedMovies = topRatedState.movies;
    final upcomingMovies = upcomingState.movies;

    return SafeArea(
      child: CustomScrollView(slivers: [
        const SliverAppBar(
          floating: true,
          flexibleSpace: FlexibleSpaceBar(
            title: CustomAppbar(),
          ),
        ),
        SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
          return Column(
            children: [
              // const CustomAppbar(),

              MoviesSlideshow(movies: slideShowMovies),

              // Banner de modo guest (solo se muestra en modo guest)
              const GuestModeBanner(),

              // Banner discreto después del slideshow
              const BannerAdWidget(),

              MovieHorizontalListviewWithAds(
                  movies: nowPlayingMovies,
                  title: 'En cines',
                  subTitle: 'Lunes 20',
                  loadNextPage: () => ref
                      .read(nowPlayingMoviesProvider.notifier)
                      .loadNextPage()),

              // Mostrar error si existe
              if (nowPlayingState.state == MoviesState.error)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nowPlayingState.errorMessage ?? 'Error desconocido',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(nowPlayingMoviesProvider.notifier)
                            .refresh(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),

              // Nueva sección de Tendencias
              MovieHorizontalListviewWithAds(
                movies: popularMovies,
                title: 'Tendencias',
                subTitle: 'Lo más popular ahora',
                loadNextPage: () =>
                    ref.read(popularMoviesProvider.notifier).loadNextPage(),
              ),

              // Mostrar error si existe
              if (popularState.state == MoviesState.error)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          popularState.errorMessage ?? 'Error desconocido',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(popularMoviesProvider.notifier).refresh(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),

              // Sección de recomendaciones personalizadas
              _buildRecommendationsSection(ref),

              // Anuncio nativo adicional entre "Tendencias" y "Próximamente" (MEDIA PRIORIDAD)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: NativeAdWidget(),
              ),

              MovieHorizontalListviewWithAds(
                movies: upcomingMovies,
                title: 'Próximamente',
                subTitle: 'En este mes',
                loadNextPage: () =>
                    ref.read(upcomingMoviesProvider.notifier).loadNextPage(),
              ),

              // Mostrar error si existe
              if (upcomingState.state == MoviesState.error)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          upcomingState.errorMessage ?? 'Error desconocido',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(upcomingMoviesProvider.notifier).refresh(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),

              MovieHorizontalListviewWithAds(
                  movies: topRatedMovies,
                  title: 'Mejor calificadas',
                  subTitle: 'Desde siempre',
                  loadNextPage: () =>
                      ref.read(topRatedMoviesProvider.notifier).loadNextPage()),

              // Mostrar error si existe
              if (topRatedState.state == MoviesState.error)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          topRatedState.errorMessage ?? 'Error desconocido',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(topRatedMoviesProvider.notifier).refresh(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),

              // Banner al final de la página (ALTA PRIORIDAD según documento)
              const FullWidthAdWidget(
                height: 100,
                margin: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                showLabel: true,
                borderRadius: 12,
              ),

              const SizedBox(height: 20),
            ],
          );
        }, childCount: 1)),
      ]),
    );
  }

  @override
  bool get wantKeepAlive => true;

  /// Construye la sección de recomendaciones personalizadas
  Widget _buildRecommendationsSection(WidgetRef ref) {
    final recommendationsAsync = ref.watch(personalizedRecommendationsProvider);

    return recommendationsAsync.when(
      data: (recommendations) {
        if (recommendations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con botón para ver todas las recomendaciones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recomendado para ti',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Basado en tus gustos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full recommendations view
                      context.push('/recommendations');
                    },
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
            ),
            // Lista horizontal de recomendaciones
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recommendations.take(10).length,
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];
                  return _buildRecommendationCard(recommendation, context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  /// Construye una tarjeta individual de recomendación
  Widget _buildRecommendationCard(dynamic recommendation, BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          context.push('/movie/${recommendation.movieId}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster de la película
            Container(
              width: 120,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: recommendation.posterPath.isNotEmpty
                    ? FadeInImage.assetNetwork(
                        placeholder: 'assets/loaders/bottle-loader.gif',
                        image: 'https://image.tmdb.org/t/p/w500${recommendation.posterPath}',
                        fit: BoxFit.cover,
                        imageErrorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.movie,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.movie,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Título de la película
            Text(
              recommendation.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Razón de la recomendación
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1 * 255),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                recommendation.reason,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
