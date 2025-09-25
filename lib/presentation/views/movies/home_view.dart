import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/admob/banner_ad_widget.dart';
import '../../widgets/admob/full_width_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/admob/web_safe_ad_widgets.dart';
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
    LoggerFactory.info('🏠 HomeView - initState called');

    // ✅ SIMPLIFIED: No aggressive loading in initState - let UI show first
    // Data will be loaded lazily when sections become visible
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ✅ SIMPLIFIED LOADING: Don't block UI with initialLoading
    final slideShowMovies = ref.watch(moviesSlideshowProvider);
    final nowPlayingState = ref.watch(nowPlayingMoviesProvider);
    final popularState = ref.watch(popularMoviesProvider);
    final topRatedState = ref.watch(topRatedMoviesProvider);
    final upcomingState = ref.watch(upcomingMoviesProvider);

    final nowPlayingMovies = nowPlayingState.movies;
    final popularMovies = popularState.movies;
    final topRatedMovies = topRatedState.movies;
    final upcomingMovies = upcomingState.movies;

    LoggerFactory.info(
        '🏠 HomeView - Building UI with ${nowPlayingMovies.length} now playing, ${popularMovies.length} popular movies');

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
              // Show slideshow immediately, even if empty
              MoviesSlideshow(movies: slideShowMovies),

              // Banner de modo guest (solo se muestra en modo guest)
              const GuestModeBanner(),

              // Banner discreto después del slideshow
              kIsWeb ? const WebSafeBannerAdWidget() : const BannerAdWidget(),

              // ✅ LAZY LOADING: Load data when sections become visible
              _buildMovieSection(
                movies: nowPlayingMovies,
                sectionId: 'now-playing',
                title: 'En cines',
                subTitle: 'Lunes 20',
                provider: nowPlayingMoviesProvider,
                state: nowPlayingState,
              ),

              _buildMovieSection(
                movies: popularMovies,
                sectionId: 'popular',
                title: 'Tendencias',
                subTitle: 'Lo más popular ahora',
                provider: popularMoviesProvider,
                state: popularState,
              ),

              // Sección de recomendaciones personalizadas
              _buildRecommendationsSection(ref),

              // Anuncio nativo adicional entre "Tendencias" y "Próximamente" (MEDIA PRIORIDAD)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: kIsWeb ? WebSafeNativeAdWidget() : NativeAdWidget(),
              ),

              _buildMovieSection(
                movies: upcomingMovies,
                sectionId: 'upcoming',
                title: 'Próximamente',
                subTitle: 'En este mes',
                provider: upcomingMoviesProvider,
                state: upcomingState,
              ),

              _buildMovieSection(
                movies: topRatedMovies,
                sectionId: 'top-rated',
                title: 'Mejor calificadas',
                subTitle: 'Desde siempre',
                provider: topRatedMoviesProvider,
                state: topRatedState,
              ),

              // Sección de recomendaciones personalizadas
              _buildRecommendationsSection(ref),

              // Banner al final de la página (ALTA PRIORIDAD según documento)
              kIsWeb
                  ? const WebSafeFullWidthAdWidget()
                  : const FullWidthAdWidget(
                      height: 100,
                      margin:
                          EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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

  /// ✅ LAZY LOADING: Load data only when section is visible
  Widget _buildMovieSection({
    required List<Movie> movies,
    required String sectionId,
    required String title,
    required String subTitle,
    required NotifierProvider<dynamic, MoviesStateData> provider,
    required MoviesStateData state,
  }) {
    return Column(
      children: [
        // Load data when first built
        Builder(
          builder: (context) {
            // Load data lazily when section is first built
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (movies.isEmpty && state.state == MoviesState.initial) {
                ref.read(provider.notifier).loadNextPage();
              }
            });

            return MovieHorizontalListviewWithAds(
              movies: movies,
              sectionId: sectionId,
              title: title,
              subTitle: subTitle,
              loadNextPage: () => ref.read(provider.notifier).loadNextPage(),
            );
          },
        ),

        // Mostrar error si existe
        if (state.state == MoviesState.error)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    state.errorMessage ?? 'Error desconocido',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  /// Construye la sección de recomendaciones personalizadas
  Widget _buildRecommendationsSection(WidgetRef ref) {
    // ✅ TEMPORARY: Disable recommendations to avoid potential blocking issues
    return const SizedBox.shrink();

    /* ORIGINAL CODE - Temporarily disabled
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
    */
  }
}
