import 'dart:async';

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

    // ✅ PERFORMANCE OPTIMIZATION: Load progressively instead of all at once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDataProgressively();
      }
    });
  }

  /// ✅ PERFORMANCE OPTIMIZATION: Aggressive progressive loading for faster startup
  Future<void> _loadDataProgressively() async {
    if (!mounted) return;

    try {
      // Priority 1: Load essential content IMMEDIATELY (nowPlaying for slideshow)
      LoggerFactory.info('📱 Loading critical content (nowPlaying)...');
      final criticalFuture = ref.read(nowPlayingMoviesProvider.notifier).loadNextPage();

      // Start popular load immediately in parallel (no waiting)
      LoggerFactory.info('📱 Starting popular content load...');
      final popularFuture = ref.read(popularMoviesProvider.notifier).loadNextPage();

      // Wait only for critical content to show slideshow ASAP
      await criticalFuture;
      if (!mounted) return;

      // Minimal delay for UI responsiveness
      await Future.delayed(const Duration(milliseconds: 50));

      // Wait for popular to complete
      await popularFuture;
      if (!mounted) return;

      // Priority 3: Load remaining content in parallel with minimal delay
      LoggerFactory.info('📱 Loading additional content in parallel...');
      final additionalContentFutures = <Future>[
        ref.read(topRatedMoviesProvider.notifier).loadNextPage(),
        ref.read(upcomingMoviesProvider.notifier).loadNextPage(),
      ];

      // Priority 4: Start user-specific data loading immediately (don't wait)
      LoggerFactory.info('📱 Starting user-specific content load...');
      final userDataFutures = <Future>[
        ref.read(directFavoriteMoviesProvider.notifier).loadNextPage(),
        ref.read(paginatedRecommendationsProvider.notifier).loadInitialPage(),
      ];

      // Execute all remaining operations in parallel
      await Future.wait([
        Future.wait(additionalContentFutures),
        Future.wait(userDataFutures),
      ]);

      if (!mounted) return;
      LoggerFactory.info('✅ Aggressive progressive loading completed successfully');
    } catch (e) {
      LoggerFactory.error('❌ Error in progressive loading: $e');
      // If progressive loading fails, at least load critical content
      if (mounted) {
        unawaited(ref.read(nowPlayingMoviesProvider.notifier).loadNextPage());
        unawaited(ref.read(popularMoviesProvider.notifier).loadNextPage());
      }
    }
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
