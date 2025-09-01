import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/movie.dart';
import '../../models/shareable_content.dart';
import '../../services/share_service.dart';
import '../providers/providers.dart';

/// Web view for sharing individual movies
/// Provides a responsive, SEO-optimized page for movie sharing
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
  ShareableContent? _shareableContent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovieData();
  }

  Future<void> _loadMovieData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load movie using movieInfoProvider
      ref.read(movieInfoProvider.notifier).loadMovie(widget.movieId);

      // Wait a bit for the movie to load
      await Future.delayed(const Duration(milliseconds: 500));

      final movie = ref.read(movieInfoProvider)[widget.movieId];

      if (movie != null) {
        // Create shareable content
        _shareableContent = ShareableContent.movie(
          movieTitle: movie.title,
          movieDescription: movie.overview,
          movieId: int.parse(widget.movieId),
          posterUrl: movie.posterPath.isNotEmpty ? movie.posterPath : null,
          additionalData: {
            'releaseDate': movie.releaseDate.year.toString(),
            'genres': movie.genreIds.join(', '),
            'voteAverage': movie.voteAverage.toString(),
          },
        );
      } else {
        _error = 'No se pudo cargar la información de la película';
      }
    } catch (e) {
      _error = 'Error al cargar la película: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _launchAppStore() async {
    const appStoreUrl = 'https://peliculas.creapolis.dev';
    final uri = Uri.parse(appStoreUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openInApp() async {
    final deepLink = 'peliculas://movie/${widget.movieId}';
    final uri = Uri.parse(deepLink);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to app store if app is not installed
      await _launchAppStore();
    }
  }

  Future<void> _shareMovie() async {
    if (_shareableContent != null && mounted) {
      // Create a Movie object from the shareable content for ShareService
      final movie = Movie(
        id: _shareableContent!.metadata?['movieId'] ?? 0,
        title: _shareableContent!.metadata?['movieTitle'] ??
            _shareableContent!.title,
        overview: _shareableContent!.description,
        posterPath: _shareableContent!.imageUrl ?? '',
        adult: false,
        backdropPath: '',
        genreIds: [],
        originalLanguage: '',
        originalTitle: _shareableContent!.title,
        popularity: 0.0,
        releaseDate: DateTime.now(),
        video: false,
        voteAverage: 0.0,
        voteCount: 0,
      );

      ShareService.shareMovie(context: context, movie: movie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isMobile = size.width <= 768;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
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
                        _error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMovieData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _shareableContent != null
                  ? _buildContent(context, theme, isDesktop, isTablet, isMobile)
                  : const Center(
                      child: Text('No se encontró información de la película'),
                    ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, bool isDesktop,
      bool isTablet, bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero Section
          _buildHeroSection(theme, isDesktop, isTablet, isMobile),

          // Content Section
          _buildContentSection(theme, isDesktop, isTablet, isMobile),

          // Call to Action Section
          _buildCallToActionSection(theme, isDesktop, isTablet, isMobile),

          // Footer
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
      ThemeData theme, bool isDesktop, bool isTablet, bool isMobile) {
    final content = _shareableContent!;

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
            ? _buildDesktopHero(content, theme)
            : _buildMobileHero(content, theme, isMobile),
      ),
    );
  }

  Widget _buildDesktopHero(ShareableContent content, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Movie Poster
        Expanded(
          flex: 2,
          child: _buildPosterImage(content, 400),
        ),
        const SizedBox(width: 48),
        // Movie Info
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
        // Movie Poster
        _buildPosterImage(content, isMobile ? 250 : 300),
        const SizedBox(height: 24),
        // Movie Info
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
                content.imageUrl!,
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
        // Title
        Text(
          content.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Movie Details
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

        // Description
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

  Widget _buildCallToActionSection(
      ThemeData theme, bool isDesktop, bool isTablet, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : (isTablet ? 32 : 16),
        vertical: isDesktop ? 60 : (isTablet ? 48 : 32),
      ),
      child: Column(
        children: [
          // Action Buttons
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
                  _shareMovie,
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
                  _shareMovie,
                  theme,
                  isPrimary: false,
                  fullWidth: true,
                ),
              ],
            ),

          const SizedBox(height: 32),

          // Download App Section
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

  Widget _buildFooter(ThemeData theme) {
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
