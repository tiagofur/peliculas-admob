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
        // Cargar recomendaciones paginadas
        ref.read(paginatedRecommendationsProvider.notifier).loadInitialPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialLoading = ref.watch(initialLoadingProvider);
    print('🏠 HomeView - initialLoading: $initialLoading');
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
                  sectionId: 'now-playing',
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
                sectionId: 'popular',
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
                sectionId: 'upcoming',
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
                  sectionId: 'top-rated',
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
    final recommendationsState = ref.watch(paginatedRecommendationsProvider);

    if (recommendationsState.hasError) {
      return const SizedBox.shrink();
    }

    if (recommendationsState.movies.isEmpty &&
        !recommendationsState.isLoading) {
      return const SizedBox.shrink();
    }

    // Lista horizontal de recomendaciones con paginación
    if (recommendationsState.movies.isNotEmpty) {
      return MovieHorizontalListviewWithAds(
        title: 'Recomendado para ti',
        subTitle: 'Basado en tus gustos',
        movies: recommendationsState.movies,
        sectionId: 'recommendations',
        loadNextPage: () {
          ref.read(paginatedRecommendationsProvider.notifier).loadNextPage();
        },
        enableAds: true,
      );
    } else if (recommendationsState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Construye una tarjeta individual de recomendación
  Widget _buildRecommendationCard(
      dynamic recommendation, BuildContext context) {
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
                        image:
                            'https://image.tmdb.org/t/p/w500${recommendation.posterPath}',
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
              width:
                  120, // Asegurar que no exceda el ancho del contenedor padre
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Text(
                recommendation.reason,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
