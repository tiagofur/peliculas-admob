import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/entities.dart';
import '../../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/admob/banner_ad_widget.dart';
import '../../widgets/admob/full_width_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/admob/web_safe_ad_widgets.dart';
import '../../widgets/guest_mode_banner.dart';
import '../../widgets/movies/movie_horizontal_listview_with_ads.dart';
import '../../widgets/skeletons/skeletons.dart'; // Task 2.5
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

    final l10n = AppLocalizations.of(context)!;

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
                l10n: l10n,
                movies: nowPlayingMovies,
                sectionId: 'now-playing',
                title: l10n.homeNowPlayingTitle,
                subTitle: l10n.homeNowPlayingSubtitle,
                provider: nowPlayingMoviesProvider,
                state: nowPlayingState,
              ),

              _buildMovieSection(
                l10n: l10n,
                movies: popularMovies,
                sectionId: 'popular',
                title: l10n.homePopularTitle,
                subTitle: l10n.homePopularSubtitle,
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
                l10n: l10n,
                movies: upcomingMovies,
                sectionId: 'upcoming',
                title: l10n.homeUpcomingTitle,
                subTitle: l10n.homeUpcomingSubtitle,
                provider: upcomingMoviesProvider,
                state: upcomingState,
              ),

              _buildMovieSection(
                l10n: l10n,
                movies: topRatedMovies,
                sectionId: 'top-rated',
                title: l10n.homeTopRatedTitle,
                subTitle: l10n.homeTopRatedSubtitle,
                provider: topRatedMoviesProvider,
                state: topRatedState,
              ),

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
    required AppLocalizations l10n,
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

            // Task 2.5: Show skeleton while loading
            if (movies.isEmpty && state.state == MoviesState.loading) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subTitle,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const MovieHorizontalListSkeleton(itemCount: 5),
                ],
              );
            }

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
                    state.errorMessage ?? l10n.unknownError,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(provider.notifier).refresh(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  /// Construye la sección de recomendaciones personalizadas con ML
  Widget _buildRecommendationsSection(WidgetRef ref) {
    // Verificar si el usuario está autenticado
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    // Solo mostrar recomendaciones si el usuario está autenticado
    if (!isAuthenticated) {
      return const SizedBox.shrink();
    }

    // Watch ML recommendations
    final mlRecommendations = ref.watch(personalizedRecommendationsProvider);

    return mlRecommendations.when(
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        // Convertir Recommendations a Movies
        final movies = recommendations.map((rec) {
          return Movie(
            id: rec.movieId,
            title: rec.title,
            overview: rec.reason,
            posterPath: rec.posterPath,
            backdropPath: '',
            releaseDate: DateTime.now(),
            genreIds: [], // tags son String, no int - dejarlo vacío temporalmente
            voteAverage: rec.score * 10,
            voteCount: 0,
            popularity: rec.score * 100,
            adult: false,
            originalLanguage: 'en',
            originalTitle: rec.title,
            video: false,
          );
        }).toList();

        return Column(
          children: [
            const SizedBox(height: 8),
            // Contenedor con diseño especial para destacar las recomendaciones ML
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(ref.context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    Theme.of(ref.context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(ref.context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Theme.of(ref.context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎯 Recomendaciones con IA',
                          style: Theme.of(ref.context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(ref.context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Seleccionadas especialmente para ti',
                          style: Theme.of(ref.context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(ref.context)
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
            MovieHorizontalListviewWithAds(
              movies: movies,
              sectionId: 'ml-recommendations',
              title: '',
              subTitle: '',
              loadNextPage: () {
                // ML recommendations are loaded all at once
              },
            ),
          ],
        );
      },
      loading: () => Container(
        height: 280,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(ref.context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '🤖 Generando recomendaciones personalizadas...',
                style: Theme.of(ref.context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ref.context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) {
        // No mostrar error, simplemente ocultar la sección
        return const SizedBox.shrink();
      },
    );
  }
}
