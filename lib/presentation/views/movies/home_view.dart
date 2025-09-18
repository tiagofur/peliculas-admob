import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../providers/providers.dart';
import '../../providers/storage/direct_favorites_provider.dart';
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
        ref.read(directFavoriteMoviesProvider.notifier).loadNextPage();
        // Cargar recomendaciones paginadas
        ref.read(paginatedRecommendationsProvider.notifier).loadInitialPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialLoading = ref.watch(initialLoadingProvider);
    LoggerFactory.info('🏠 HomeView - initialLoading: $initialLoading');
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
                loadNextPage: () {
                  ref.read(topRatedMoviesProvider.notifier).loadNextPage();
                },
              ),

              // Sección de recomendaciones personalizadas
              _buildRecommendationsSection(ref),

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
    final recommendations = recommendationsState.movies;

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return MovieHorizontalListviewWithAds(
      movies: recommendations,
      sectionId: 'recommendations',
      title: 'Recomendaciones para ti',
      subTitle: 'Basadas en tus gustos',
      loadNextPage: () {
        ref.read(paginatedRecommendationsProvider.notifier).loadNextPage();
      },
    );
  }
}
