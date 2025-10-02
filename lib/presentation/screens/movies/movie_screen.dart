import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/helpers/human_formats.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/movie.dart';
import '../../../services/share_service.dart';
import '../../providers/providers.dart';
import '../../providers/storage/direct_favorites_provider.dart';
import '../../providers/storage/direct_watched_provider.dart';
import '../../providers/storage/direct_watchlist_provider.dart';
import '../../widgets/admob/banner_ad_widget.dart';
import '../../widgets/admob/native_ad_widget.dart';
import '../../widgets/admob/web_safe_ad_widgets.dart';
import '../../widgets/movies/movie_rating_and_notes.dart';
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
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    // Se retrasa la llamada para evitar modificar el provider durante el build.
    _loadMovieWithRetry();
  }

  Future<void> _loadMovieWithRetry() async {
    await Future(() async {
      try {
        await ref.read(movieInfoProvider.notifier).loadMovie(widget.movieId);
      } catch (e) {
        if (_retryCount < _maxRetries && mounted) {
          _retryCount++;
          // Esperar un poco antes de reintentar (exponential backoff)
          await Future.delayed(Duration(seconds: _retryCount));
          if (mounted) {
            _loadMovieWithRetry();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Observa el estado del caché de películas completo.
    final moviesCache = ref.watch(movieInfoProvider);
    final failedMovieIds = ref.watch(movieLoadFailuresProvider);

    // Usa .when para manejar los estados del caché (mapa).
    return moviesCache.when(
      loading: () => const ElegantLoadingScreen(
        message: 'Cargando película...',
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('No se pudo cargar la película: $error')),
      ),
      data: (moviesMap) {
        // Una vez que el caché tiene datos, busca la película específica.
        final movie = moviesMap[widget.movieId];

        // Si la película específica aún no está en el mapa, muestra un loader.
        if (movie == null) {
          if (failedMovieIds.contains(widget.movieId)) {
            return _buildUnavailableMovieScaffold();
          }

          return const Scaffold(
            body: MovieDetailLoadingPlaceholder(),
          );
        }

        // Si la película existe, construye la UI.
        return Scaffold(
          body: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              _CustomSliverAppBar(movie: movie),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _MovieDetails(movie: movie),
                  childCount: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnavailableMovieScaffold() {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Error al cargar película')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 64, color: colors.error),
              const SizedBox(height: 16),
              Text(
                'No pudimos cargar los detalles',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica tu conexión a internet e intenta de nuevo. Si el problema persiste, es posible que la película ya no esté disponible.',
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () {
                      // Limpiar el fallo y reintentar con force
                      ref
                          .read(movieLoadFailuresProvider.notifier)
                          .remove(widget.movieId);
                      ref
                          .read(movieInfoProvider.notifier)
                          .loadMovie(widget.movieId, force: true);
                    },
                    child: const Text('Reintentar'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ],
          ),
        ),
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

              // Géneros de la película - Movido aquí arriba
              const SizedBox(height: 16),
              _Genres(movie: movie),

              // User rating section
              const SizedBox(height: 16),
              MovieRatingAndNotes(movie: movie),

              //* 1. Banner antes de 'Elenco Completo'
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: kIsWeb ? WebSafeBannerAdWidget() : BannerAdWidget(),
              ),
            ],
          ),
        ),

        //* Elenco Completo - NUEVO
        _FullCastList(movie: movie),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Reparto Principal (sección reducida)
              _CastSection(movie: movie),

              // Crew (Director, Writer, etc.)
              const SizedBox(height: 16),
              _CrewSection(movie: movie),

              // Detalles Técnicos + Estadísticas UNIFICADOS - NUEVO
              const SizedBox(height: 16),
              _TechnicalAndStatsSection(movie: movie),

              //* 2. Anuncio nativo después de info técnica
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: kIsWeb
                    ? WebSafeNativeAdWidget()
                    : NativeAdWidget(
                        height: 100,
                        showLabel: false,
                      ),
              ),
            ],
          ),
        ),

        //* Listas personalizadas
        MovieListsWidget(movie: movie),

        //* Videos de la película (si tiene)
        VideosFromMovie(movieId: movie.id),

        //* 3. Anuncio nativo antes de 'Recomendaciones'
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: kIsWeb
              ? WebSafeNativeAdWidget()
              : NativeAdWidget(
                  height: 100,
                  showLabel: false,
                ),
        ),

        //* Películas similares (Recomendaciones con anuncios)
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
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    if (movie.genreIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Géneros',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: movie.genreIds.map((genreIdStr) {
              final genreId = int.tryParse(genreIdStr) ?? 0;
              final genreName = _getGenreName(genreId);

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.7),
                      colors.primary.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  genreName,
                  style: textStyles.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CrewSection extends StatelessWidget {
  const _CrewSection({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    // Get crew from credits
    if (movie.credits == null || movie.credits?['crew'] == null) {
      return const SizedBox.shrink();
    }

    final crew = movie.credits?['crew'] as List?;
    if (crew == null || crew.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract key crew members
    final director = crew.firstWhere(
      (member) => member['job'] == 'Director',
      orElse: () => null,
    );

    final writer = crew.firstWhere(
      (member) =>
          member['job'] == 'Screenplay' ||
          member['job'] == 'Writer' ||
          member['department'] == 'Writing',
      orElse: () => null,
    );

    final producer = crew.firstWhere(
      (member) => member['job'] == 'Producer',
      orElse: () => null,
    );

    final composer = crew.firstWhere(
      (member) => member['job'] == 'Original Music Composer',
      orElse: () => null,
    );

    // Si no hay ningún miembro clave, no mostrar la sección
    if (director == null &&
        writer == null &&
        producer == null &&
        composer == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.movie_creation, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Equipo Creativo',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (director != null)
            _CrewMember(
              role: 'Director',
              name: director['name'] ?? '',
              icon: Icons.videocam,
            ),
          if (writer != null) ...[
            const SizedBox(height: 8),
            _CrewMember(
              role: 'Guionista',
              name: writer['name'] ?? '',
              icon: Icons.create,
            ),
          ],
          if (producer != null) ...[
            const SizedBox(height: 8),
            _CrewMember(
              role: 'Productor',
              name: producer['name'] ?? '',
              icon: Icons.business_center,
            ),
          ],
          if (composer != null) ...[
            const SizedBox(height: 8),
            _CrewMember(
              role: 'Compositor',
              name: composer['name'] ?? '',
              icon: Icons.music_note,
            ),
          ],
        ],
      ),
    );
  }
}

class _CrewMember extends StatelessWidget {
  const _CrewMember({
    required this.role,
    required this.name,
    required this.icon,
  });

  final String role;
  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                name,
                style: textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
    final isFavorite =
        ref.watch(directFavoriteMoviesProvider).containsKey(movie.id);
    final isWatched =
        ref.watch(directWatchedMoviesProvider).containsKey(movie.id);
    final size = MediaQuery.of(context).size;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final heroImageUrl = movie.backdropPath.trim().isNotEmpty
        ? resolveBackdropUrl(movie.backdropPath, size: 'w1280')
        : resolvePosterUrl(movie.posterPath, size: 'w780');

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
            isWatched ? Icons.visibility : Icons.visibility_outlined,
            color: isWatched ? Colors.green : Colors.white,
          ),
        ),
        // Botón de favoritos con animación
        _AnimatedActionButton(
          onPressed: () {
            ref
                .read(directFavoriteMoviesProvider.notifier)
                .toggleFavorite(movie);
          },
          feedbackType: FeedbackType.success,
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.white,
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
                heroImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress != null) return const SizedBox();
                  return FadeIn(child: child);
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade900,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
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

// Helper function to convert genre IDs to names
String _getGenreName(int genreId) {
  const genreMap = {
    28: 'Acción',
    12: 'Aventura',
    16: 'Animación',
    35: 'Comedia',
    80: 'Crimen',
    99: 'Documental',
    18: 'Drama',
    10751: 'Familiar',
    14: 'Fantasía',
    36: 'Historia',
    27: 'Terror',
    10402: 'Música',
    9648: 'Misterio',
    10749: 'Romance',
    878: 'Ciencia Ficción',
    10770: 'Película de TV',
    53: 'Thriller',
    10752: 'Guerra',
    37: 'Western',
  };

  return genreMap[genreId] ?? 'Desconocido';
}

// Widget para mostrar el elenco completo
class _FullCastList extends StatelessWidget {
  const _FullCastList({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    // Show cast only if available from API
    if (movie.credits == null ||
        movie.credits?['cast'] == null ||
        ((movie.credits?['cast'] as List?) ?? []).isEmpty) {
      return const SizedBox.shrink();
    }

    final castList = (movie.credits?['cast'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.groups, color: colors.primary, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Elenco Completo',
                  style: textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${castList.length}',
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: castList.length,
              itemBuilder: (context, index) {
                final actor = castList[index] as Map<String, dynamic>;
                final profilePath = actor['profile_path'] as String?;
                final name = actor['name'] as String? ?? 'Actor desconocido';
                final character = actor['character'] as String?;

                return Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: profilePath != null && profilePath.isNotEmpty
                              ? Image.network(
                                  resolveBackdropUrl(profilePath, size: 'w185'),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 120,
                                    height: 120,
                                    color: colors.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.person,
                                      size: 50,
                                      color: colors.onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 120,
                                  height: 120,
                                  color: colors.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color:
                                        colors.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  style: textStyles.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (character != null &&
                                    character.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    character,
                                    style: textStyles.bodySmall?.copyWith(
                                      color: colors.onSurface
                                          .withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Widget unificado para Detalles Técnicos + Estadísticas
class _TechnicalAndStatsSection extends StatelessWidget {
  const _TechnicalAndStatsSection({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(alpha: 0.3),
            colors.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.analytics, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Información Técnica y Estadísticas',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grid de stats
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              if (movie.runtime != null && (movie.runtime ?? 0) > 0)
                _StatBox(
                  icon: Icons.access_time,
                  title: 'Duración',
                  value: '${movie.runtime} min',
                  color: Colors.blue,
                ),
              _StatBox(
                icon: Icons.calendar_today,
                title: 'Año',
                value: movie.releaseDate.year.toString(),
                color: Colors.green,
              ),
              _StatBox(
                icon: Icons.star,
                title: 'Calificación',
                value: '${movie.voteAverage.toStringAsFixed(1)}/10',
                color: _getRatingColor(movie.voteAverage),
              ),
              _StatBox(
                icon: Icons.how_to_vote,
                title: 'Votos',
                value: HumanFormats.number(movie.voteCount.toDouble()),
                color: Colors.purple,
              ),
              _StatBox(
                icon: Icons.trending_up,
                title: 'Popularidad',
                value: movie.popularity.toStringAsFixed(0),
                color: Colors.orange,
              ),
              if (movie.imdbId != null && movie.imdbId!.isNotEmpty)
                _StatBox(
                  icon: Icons.movie,
                  title: 'IMDb ID',
                  value: movie.imdbId!,
                  color: Colors.amber,
                  isSmallText: true,
                ),
              if (movie.budget != null && (movie.budget ?? 0) > 0)
                _StatBox(
                  icon: Icons.attach_money,
                  title: 'Presupuesto',
                  value:
                      '\$${HumanFormats.number((movie.budget ?? 0).toDouble())}',
                  color: Colors.teal,
                  isSmallText: true,
                ),
              if (movie.revenue != null && (movie.revenue ?? 0) > 0)
                _StatBox(
                  icon: Icons.show_chart,
                  title: 'Ingresos',
                  value:
                      '\$${HumanFormats.number((movie.revenue ?? 0).toDouble())}',
                  color: Colors.lightGreen,
                  isSmallText: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) return Colors.green;
    if (rating >= 7.0) return Colors.lightGreen;
    if (rating >= 6.0) return Colors.orange;
    if (rating >= 5.0) return Colors.deepOrange;
    return Colors.red;
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.isSmallText = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isSmallText;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isSmallText ? 12 : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: textStyles.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
