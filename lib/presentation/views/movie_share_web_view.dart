import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics_service.dart';
import '../../domain/entities/movie.dart';
import '../../models/shareable_content.dart';
import '../../services/share_service.dart';
import '../providers/providers.dart';

class MovieShareWebView extends ConsumerStatefulWidget {
  const MovieShareWebView({
    super.key,
    required this.movieId,
  });
  static const String name = 'MovieShareWebView';

  final String movieId;

  @override
  ConsumerState<MovieShareWebView> createState() => _MovieShareWebViewState();
}

class _MovieShareWebViewState extends ConsumerState<MovieShareWebView> {
  int _retryCount = 0;
  static const int _maxRetries = 3;

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

        // Track que alguien accedió a la URL de compartir
        await AnalyticsService().trackEvent(
          AnalyticsEventType.movieShare,
          {
            'movie_id': widget.movieId,
            'action': 'share_link_accessed',
            'source': 'web_share_url',
            'retry_count': _retryCount,
          },
        );
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
    final movieCacheAsync = ref.watch(movieInfoProvider);
    final failedMovieIds = ref.watch(movieLoadFailuresProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: movieCacheAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(movieInfoProvider.notifier)
                    .loadMovie(widget.movieId),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (movieMap) {
          final movie = movieMap[widget.movieId];
          if (movie == null) {
            if (failedMovieIds.contains(widget.movieId)) {
              return _buildMovieUnavailableContent(context);
            }
            return const Center(child: CircularProgressIndicator());
          }

          final shareableContent = ShareableContent.movie(
            movieTitle: movie.title,
            movieDescription: movie.overview,
            movieId: movie.id,
            posterUrl: movie.posterPath.isNotEmpty ? movie.posterPath : null,
            additionalData: {
              'releaseDate': movie.releaseDate.year.toString(),
              'genres': movie.genreIds.join(', '),
              'voteAverage': movie.voteAverage.toString(),
            },
          );
          return _MovieShareViewContent(
              movie: movie, shareableContent: shareableContent);
        },
      ),
    );
  }

  Widget _buildMovieUnavailableContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: colors.error),
            const SizedBox(height: 16),
            Text(
              'No pudimos cargar la película',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Verifica tu conexión a internet. Si el problema persiste, es posible que la película ya no esté disponible.',
              style: theme.textTheme.bodySmall?.copyWith(
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
                    // Limpiar el fallo y reintentar
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
                  onPressed: () => context.go('/'),
                  child: const Text('Abrir app'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieShareViewContent extends StatelessWidget {
  const _MovieShareViewContent({
    required this.movie,
    required this.shareableContent,
  });

  final Movie movie;
  final ShareableContent shareableContent;

  Future<void> _launchAppStore() async {
    const appStoreUrl = 'https://peliculas.creapolis.dev';
    final uri = Uri.parse(appStoreUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openInApp() async {
    // Track intento de abrir en la app
    await AnalyticsService().trackEvent(
      AnalyticsEventType.userEngagement,
      {
        'movie_id': movie.id,
        'action': 'open_in_app_clicked',
        'source': 'web_share_view',
      },
    );

    final deepLink = ShareService.generateMovieAppDeepLink(movie.id);
    final uri = Uri.parse(deepLink);

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _launchAppStore();
      }
    } catch (e) {
      await _launchAppStore();
    }
  }

  Future<void> _shareMovie(BuildContext context) async {
    // Track intento de re-compartir desde la vista de share
    await AnalyticsService().trackEvent(
      AnalyticsEventType.movieShare,
      {
        'movie_id': movie.id,
        'action': 'reshare_from_share_view',
        'source': 'web_share_view',
      },
    );

    ShareService.shareMovie(context: context, movie: movie);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isMobile = size.width <= 768;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(theme, isDesktop, isTablet, isMobile),
          _buildContentSection(theme, isDesktop, isTablet, isMobile),
          _buildCallToActionSection(
              context, theme, isDesktop, isTablet, isMobile),
          _buildFooter(context, theme),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
      ThemeData theme, bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primary.withAlpha(25),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 64 : (isTablet ? 32 : 16),
          vertical: isDesktop ? 80 : (isTablet ? 60 : 40),
        ),
        child: isDesktop
            ? _buildDesktopHero(shareableContent, theme)
            : _buildMobileHero(shareableContent, theme, isMobile),
      ),
    );
  }

  Widget _buildDesktopHero(ShareableContent content, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildPosterImage(content, 400),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 3,
          child: _buildMovieInfo(content, theme, isDesktop: true),
        ),
      ],
    );
  }

  Widget _buildMobileHero(
      ShareableContent content, ThemeData theme, bool isMobile) {
    return Column(
      children: [
        _buildPosterImage(content, isMobile ? 250 : 300),
        const SizedBox(height: 24),
        _buildMovieInfo(content, theme, isDesktop: false),
      ],
    );
  }

  Widget _buildPosterImage(ShareableContent content, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: content.imageUrl != null
            ? Image.network(
                content.imageUrl ?? '',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholderPoster(),
              )
            : _buildPlaceholderPoster(),
      ),
    );
  }

  Widget _buildPlaceholderPoster() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.movie,
          size: 64,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMovieInfo(ShareableContent content, ThemeData theme,
      {required bool isDesktop}) {
    final metadata = content.metadata ?? {};

    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          content.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (metadata['releaseDate'] != null || metadata['genres'] != null)
          Wrap(
            alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              if (metadata['releaseDate'] != null)
                _buildInfoChip('📅 ${metadata['releaseDate']}', theme),
              if (metadata['voteAverage'] != null)
                _buildInfoChip('⭐ ${metadata['voteAverage']}', theme),
            ],
          ),
        if (metadata['genres'] != null) ...[
          const SizedBox(height: 12),
          Text(
            metadata['genres'],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
            textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          content.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(180),
            height: 1.6,
          ),
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoChip(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(50),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildContentSection(
      ThemeData theme, bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 16),
        vertical: isDesktop ? 60 : (isTablet ? 48 : 32),
      ),
      child: Column(
        children: [
          Text(
            '🎬 Descubre más películas increíbles',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Únete a miles de usuarios que ya disfrutan de recomendaciones personalizadas, listas curadas y estadísticas detalladas de sus películas favoritas.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCallToActionSection(BuildContext context, ThemeData theme,
      bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 16),
        vertical: isDesktop ? 60 : (isTablet ? 48 : 32),
      ),
      child: Column(
        children: [
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  '📱 Abrir en la App',
                  _openInApp,
                  theme,
                  isPrimary: true,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  '📤 Compartir',
                  () => _shareMovie(context),
                  theme,
                  isPrimary: false,
                ),
              ],
            )
          else
            Column(
              children: [
                _buildActionButton(
                  '📱 Abrir en la App',
                  _openInApp,
                  theme,
                  isPrimary: true,
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                _buildActionButton(
                  '📤 Compartir',
                  () => _shareMovie(context),
                  theme,
                  isPrimary: false,
                  fullWidth: true,
                ),
              ],
            ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withAlpha(20),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '¿No tienes la app?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Descarga Películas y accede a todas las funciones',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _launchAppStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '⬇️ Descargar App',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    VoidCallback onPressed,
    ThemeData theme, {
    required bool isPrimary,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? theme.colorScheme.primary : theme.colorScheme.surface,
          foregroundColor: isPrimary
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          side: isPrimary ? null : BorderSide(color: theme.colorScheme.outline),
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isPrimary ? 2 : 0,
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(20),
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Películas App',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu compañero perfecto para descubrir películas',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('← Volver al inicio'),
          ),
        ],
      ),
    );
  }
}
