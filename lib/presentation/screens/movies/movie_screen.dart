import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../domain/entities/movie.dart';
import '../../../services/share_service.dart';
import '../../providers/providers.dart';
import '../../providers/storage/direct_favorites_provider.dart';
import '../../providers/storage/direct_watched_provider.dart';
import '../../providers/storage/direct_watchlist_provider.dart';
import '../../widgets/admob/banner_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
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

    // Rastrear vista de película cuando se carga la pantalla
    final movie = ref.read(movieInfoProvider)[widget.movieId];
    if (movie != null) {
      _analytics.trackMovieView(movie.id.toString(), movie.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Movie? movie = ref.watch(movieInfoProvider)[widget.movieId];

    if (movie == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          _CustomSliverAppBar(movie: movie),
          SliverList(
              delegate: SliverChildBuilderDelegate(
                  (context, index) => _MovieDetails(movie: movie),
                  childCount: 1))
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

              //* 1. Banner antes de 'Reparto Principal'
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: BannerAdWidget(),
              ),

              // Reparto Principal
              _CastSection(movie: movie),

              // Estadísticas
              _StatsSection(movie: movie),

              //* 2. Anuncio nativo entre estadísticas y 'Mis Listas'
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: NativeAdWidget(
                  height: 100,
                  showLabel: false,
                ),
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

        //* 3. Anuncio nativo antes de 'Recomendaciones'
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: NativeAdWidget(
            height: 100,
            showLabel: false,
          ),
        ),

        //* Películas similares (Recomendaciones)
        SimilarMovies(movieId: movie.id),
      ],
    );
  }
}

class _Genres extends StatelessWidget {
  const _Genres({
    required this.movie,
  });

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            ...movie.genreIds.map((gender) => Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Chip(
                    label: Text(gender),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ))
          ],
        ),
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
    final isFavoriteFuture = ref.watch(isFavoriteProvider(movie.id));
    final isWatchedFuture = ref.watch(isWatchedProvider(movie.id));
    final size = MediaQuery.of(context).size;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return SliverAppBar(
      backgroundColor: Colors.black,
      expandedHeight: size.height * 0.7,
      foregroundColor: Colors.white,
      actions: [
        // Botón de compartir con animación
        _AnimatedActionButton(
          onPressed: () async {
            // Rastrear evento de compartir
            await AnalyticsService()
                .trackMovieShare(movie.id.toString(), 'native_share');
            await ShareService.shareMovie(context: context, movie: movie);
          },
          feedbackType: FeedbackType.info,
          child: const Icon(
            Icons.share,
            color: Colors.white,
          ),
        ),
        // Botón de marcar como vista con animación
        _AnimatedActionButton(
          onPressed: () async {
            // Use direct provider for real-time sync
            await ref
                .read(directWatchedMoviesProvider.notifier)
                .toggleWatched(movie);
          },
          feedbackType: FeedbackType.success,
          child: Icon(
            isWatchedFuture ? Icons.visibility : Icons.visibility_outlined,
            color: isWatchedFuture ? Colors.green : Colors.white,
          ),
        ),
        // Botón de favoritos con animación
        _AnimatedActionButton(
          onPressed: () {
            ref
                .read(directFavoriteMoviesProvider.notifier)
                .toggleFavorite(movie);
            ref.invalidate(directIsFavoriteProvider(movie.id));
          },
          feedbackType: FeedbackType.success,
          child: Icon(
            isFavoriteFuture ? Icons.favorite_rounded : Icons.favorite_border,
            color: isFavoriteFuture ? Colors.red : Colors.white,
          ),
        ),
        // Botón de watchlist
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
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress != null) return const SizedBox();
                  return FadeIn(child: child);
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

enum FeedbackType { success, error, warning, info }

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

class _AnimatedActionButton extends StatefulWidget {
  const _AnimatedActionButton({
    required this.onPressed,
    required this.child,
    this.feedbackType = FeedbackType.success,
  });

  final VoidCallback onPressed;
  final Widget child;
  final FeedbackType feedbackType;

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: _getFeedbackColor(),
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Color _getFeedbackColor() {
    switch (widget.feedbackType) {
      case FeedbackType.success:
        return Colors.green.withValues(alpha: 0.3);
      case FeedbackType.error:
        return Colors.red.withValues(alpha: 0.3);
      case FeedbackType.warning:
        return Colors.orange.withValues(alpha: 0.3);
      case FeedbackType.info:
        return Colors.blue.withValues(alpha: 0.3);
    }
  }

  void _onTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });

    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });

    widget.onPressed();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _scaleController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorAnimation.value,
            ),
            child: Transform.scale(
              scale: _pulseAnimation.value,
              child: IconButton(
                onPressed: _onTap,
                icon: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
