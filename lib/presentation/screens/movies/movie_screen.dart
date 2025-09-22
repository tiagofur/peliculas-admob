import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../domain/entities/movie.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/share_service.dart';
import '../../providers/providers.dart';
import '../../providers/storage/direct_favorites_provider.dart';
import '../../providers/storage/direct_watched_provider.dart';
import '../../providers/storage/direct_watchlist_provider.dart';
import '../../widgets/admob/banner_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/adsense/adsense_widget.dart';
import '../../widgets/watchlist/add_to_watchlist_button.dart';
import '../../widgets/widgets.dart';

class MovieScreen extends ConsumerStatefulWidget {
  const MovieScreen({super.key, required this.movieId});

  static const name = 'movie-screen';

  final String movieId;

  @override
  MovieScreenState createState() => MovieScreenState();
}

class MovieScreenState extends ConsumerState<MovieScreen> {
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();

    ref.read(movieInfoProvider.notifier).loadMovie(widget.movieId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Rastrear vista de película cuando se carga la pantalla (defer for performance)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final movie = ref.read(movieInfoProvider)[widget.movieId];
      if (movie != null) {
        _analytics.trackMovieView(movie.id.toString(), movie.title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Movie? movie = ref.watch(movieInfoProvider)[widget.movieId];

    if (movie == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.loadingMovie,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        cacheExtent: 200.0, // Cache widgets for smoother scrolling
        slivers: [
          _CustomSliverAppBar(movie: movie),
          SliverToBoxAdapter(
            child: _MovieDetails(movie: movie),
          ),
        ],
      ),
    );
  }
}

class _MovieDetails extends StatelessWidget {
  const _MovieDetails({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        //* Información mejorada de la película
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Información básica, sinopsis, detalles técnicos, etc.
              _MovieInfoBeforeCast(movie: movie),

              // User rating section
              MovieRatingAndNotes(movie: movie),

              // Banner Ad responsivo
              const ResponsiveAdWidget(
                height: 50,
                adMobWidget: BannerAdWidget(),
                adSenseSlot: 'movie-banner-1',
              ),

              // Reparto Principal
              _CastSection(movie: movie),

              // Estadísticas
              _StatsSection(movie: movie),

              // Native Ad responsivo entre estadísticas y listas
              const ResponsiveAdWidget(
                height: 100,
                adMobWidget: NativeAdWidget(
                  height: 100,
                  showLabel: false,
                ),
                adSenseSlot: 'movie-native-1',
              ),
            ],
          ),
        ),

        //* Listas personalizadas
        MovieListsWidget(movie: movie),

        //* Generos de la película
        _Genres(movie: movie),

        //* Videos de la película (si tiene)
        VideosFromMovie(movieId: movie.id),

        // Native Ad responsivo antes de recomendaciones
        const ResponsiveAdWidget(
          height: 100,
          adMobWidget: NativeAdWidget(
            height: 100,
            showLabel: false,
          ),
          adSenseSlot: 'movie-native-2',
        ),

        //* Películas similares (Recomendaciones)
        SimilarMovies(movieId: movie.id),
      ],
    );
  }
}

class _Genres extends StatelessWidget {
  const _Genres({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: movie.genreIds
            .map((gender) => Chip(
                  label: Text(gender, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    );
  }
}

final isFavoriteProvider =
    Provider.family.autoDispose<bool, int>((ref, int movieId) {
  return ref.watch(directIsFavoriteProvider(movieId));
});

final isWatchedProvider =
    Provider.family.autoDispose<bool, int>((ref, int movieId) {
  final directWatchedMovies = ref.watch(directWatchedMoviesProvider);
  return directWatchedMovies.containsKey(movieId);
});

final isInWatchlistProvider =
    Provider.family.autoDispose<bool, int>((ref, int movieId) {
  final directWatchlistMovies = ref.watch(directWatchlistMoviesProvider);
  return directWatchlistMovies.containsKey(movieId);
});

class _CustomSliverAppBar extends ConsumerWidget {
  const _CustomSliverAppBar({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use more efficient direct providers
    final isFavoriteFuture = ref.watch(directIsFavoriteProvider(movie.id));
    final isWatchedFuture =
        ref.watch(directWatchedMoviesProvider).containsKey(movie.id);
    final size = MediaQuery.of(context).size;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return SliverAppBar(
      backgroundColor: Colors.black,
      expandedHeight: size.height * 0.5, // Reduced from 0.7 to 0.5
      foregroundColor: Colors.white,
      pinned: true, // Keep app bar visible while scrolling
      actions: [
        // Botón de compartir con animación suave
        _EfficientAnimatedButton(
          onPressed: () async {
            await AnalyticsService()
                .trackMovieShare(movie.id.toString(), 'native_share');
            await ShareService.shareMovie(context: context, movie: movie);
          },
          icon: const Icon(Icons.share, color: Colors.white),
          tooltip: 'Compartir',
        ),
        // Botón de marcar como vista con animación
        _EfficientAnimatedButton(
          onPressed: () async {
            await ref
                .read(directWatchedMoviesProvider.notifier)
                .toggleWatched(movie);
          },
          icon: Icon(
            isWatchedFuture ? Icons.visibility : Icons.visibility_outlined,
            color: isWatchedFuture ? Colors.green : Colors.white,
          ),
          tooltip: 'Marcar como vista',
        ),
        // Botón de favoritos con animación
        _EfficientAnimatedButton(
          onPressed: () {
            ref
                .read(directFavoriteMoviesProvider.notifier)
                .toggleFavorite(movie);
          },
          icon: Icon(
            isFavoriteFuture ? Icons.favorite_rounded : Icons.favorite_border,
            color: isFavoriteFuture ? Colors.red : Colors.white,
          ),
          tooltip: 'Favorito',
        ),
        // Botón de watchlist con animación suave
        AddToWatchlistButton(
          movie: movie,
          isIconButton: true,
          showLabel: false,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 0),
        title: _CustomGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.7, 1.0],
            colors: [Colors.transparent, scaffoldBackgroundColor]),
        background: Stack(
          children: [
            SizedBox.expand(
              child: Image.network(
                movie.posterPath,
                fit: BoxFit.cover,
                cacheWidth: (size.width * 2).round(), // Cache optimized image
                cacheHeight: (size.height).round(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress != null) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  }
                  // Animación sutil de fade-in
                  return AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: child,
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child:
                        const Icon(Icons.error, color: Colors.white, size: 50),
                  );
                },
              ),
            ),

            //* Favorite Gradient Background
            const _CustomGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                stops: [
                  0.0,
                  0.2
                ],
                colors: [
                  Colors.black54,
                  Colors.transparent,
                ]),

            //* Back arrow background
            const _CustomGradient(begin: Alignment.topLeft, stops: [
              0.0,
              0.3
            ], colors: [
              Colors.black87,
              Colors.transparent,
            ]),
          ],
        ),
      ),
    );
  }
}

class _CustomGradient extends StatelessWidget {
  const _CustomGradient(
      {this.begin = Alignment.centerLeft,
      this.end = Alignment.centerRight,
      required this.stops,
      required this.colors});

  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final List<double> stops;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: begin, end: end, stops: stops, colors: colors))),
    );
  }
}

// Widgets auxiliares para separar las secciones de EnhancedMovieInfo
class _MovieInfoBeforeCast extends StatelessWidget {
  const _MovieInfoBeforeCast({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return MovieInfoSection(
      movie: movie,
      showCast: false,
      showStats: false,
    );
  }
}

class _CastSection extends StatelessWidget {
  const _CastSection({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return MovieCastSection(movie: movie);
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return MovieStatsSection(movie: movie);
  }
}

/// Animación eficiente con un solo controller y efectos sutiles
class _EfficientAnimatedButton extends StatefulWidget {
  const _EfficientAnimatedButton({
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String? tooltip;

  @override
  State<_EfficientAnimatedButton> createState() =>
      _EfficientAnimatedButtonState();
}

class _EfficientAnimatedButtonState extends State<_EfficientAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: IconButton(
            onPressed: _handleTap,
            icon: widget.icon,
            tooltip: widget.tooltip,
          ),
        );
      },
    );
  }
}
