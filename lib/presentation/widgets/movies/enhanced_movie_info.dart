import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/helpers/human_formats.dart';
import '../../../config/theme/custom_scroll_behavior.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../core/streaming/streaming.dart';
import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/entities.dart';
import '../streaming/streaming_availability_indicator.dart';
import '../watch_providers_widget.dart';

// Widgets públicos para usar en otras pantallas
class MovieInfoSection extends StatelessWidget {
  const MovieInfoSection({
    super.key,
    required this.movie,
    this.showCast = true,
    this.showStats = true,
  });

  final Movie movie;
  final bool showCast;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Información básica mejorada
        _BasicInfoSection(movie: movie),

        const SizedBox(height: 16),

        // Sinopsis expandida
        _ExpandedSynopsis(movie: movie),

        const SizedBox(height: 16),

        // Detalles técnicos
        _TechnicalDetails(movie: movie),

        const SizedBox(height: 16),

        // Colección si pertenece a una
        if (movie.belongsToCollection != null &&
            movie.belongsToCollection!.isNotEmpty)
          _CollectionInfo(movie: movie),
        if (movie.belongsToCollection != null &&
            movie.belongsToCollection!.isNotEmpty)
          const SizedBox(height: 16),

        // Idiomas hablados
        if (movie.spokenLanguages != null && movie.spokenLanguages!.isNotEmpty)
          _SpokenLanguages(movie: movie),
        if (movie.spokenLanguages != null && movie.spokenLanguages!.isNotEmpty)
          const SizedBox(height: 16),

        // Streaming Quick Action Button
        StreamingQuickAction(
          movieId: movie.id,
          movieTitle: movie.title,
        ),
        const SizedBox(height: 16),

        // Streaming Availability Section
        StreamingAvailabilityDetail(
          movieId: movie.id,
          movieTitle: movie.title,
          onPlatformTap: (platform) => _launchStreamingPlatform(platform),
        ),
        const SizedBox(height: 16),

        // Watch Providers - Plataformas de streaming
        if (movie.watchProviders != null)
          WatchProvidersWidget(
            watchProviders: movie.watchProviders,
            movieTitle: movie.title,
            imdbId: movie.imdbId,
            country: 'MX',
          ),
        if (movie.watchProviders != null) const SizedBox(height: 16),

        // Homepage link if available
        if (movie.homepage != null && movie.homepage!.isNotEmpty)
          Container(
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
                    Icon(Icons.link, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Sitio Oficial',
                      style: textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _launchURL(movie.homepage!),
                  child: Text(
                    movie.homepage!,
                    style: textStyles.bodyMedium?.copyWith(
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (movie.homepage != null && movie.homepage!.isNotEmpty)
          const SizedBox(height: 16),

        // Cast principal mejorado
        if (showCast) _EnhancedCast(movie: movie),
        if (showCast) const SizedBox(height: 16),

        // Estadísticas y datos curiosos
        if (showStats) _MovieStats(movie: movie),
      ],
    );
  }

  // Función para abrir URLs externas
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la URL: $url';
      }
    } catch (e) {
      LoggerFactory.error('Error al abrir URL: $e');
    }
  }

  Future<void> _launchStreamingPlatform(StreamingPlatform platform) async {
    try {
      final deepLinkingService = DeepLinkingService();
      final success = await deepLinkingService.launchStreamingApp(
        platform: platform,
        movieId: movie.id.toString(),
      );

      if (!success) {
        // Handle error - could show snackbar if context available
        LoggerFactory.error('No se pudo abrir ${platform.displayName}');
      }
    } catch (e) {
      LoggerFactory.error('Error al abrir la aplicación: $e');
    }
  }
}

class MovieCastSection extends StatelessWidget {
  const MovieCastSection({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return _EnhancedCast(movie: movie);
  }
}

class MovieStatsSection extends StatelessWidget {
  const MovieStatsSection({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return _MovieStats(movie: movie);
  }
}

class EnhancedMovieInfo extends ConsumerWidget {
  const EnhancedMovieInfo({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Información básica mejorada
        _BasicInfoSection(movie: movie),

        const SizedBox(height: 16),

        // Sinopsis expandida
        _ExpandedSynopsis(movie: movie),

        const SizedBox(height: 16),

        // Detalles técnicos
        _TechnicalDetails(movie: movie),

        const SizedBox(height: 16),

        // Colección si pertenece a una
        if (movie.belongsToCollection != null &&
            movie.belongsToCollection!.isNotEmpty)
          _CollectionInfo(movie: movie),
        if (movie.belongsToCollection != null &&
            movie.belongsToCollection!.isNotEmpty)
          const SizedBox(height: 16),

        // Idiomas hablados
        if (movie.spokenLanguages != null && movie.spokenLanguages!.isNotEmpty)
          _SpokenLanguages(movie: movie),
        if (movie.spokenLanguages != null && movie.spokenLanguages!.isNotEmpty)
          const SizedBox(height: 16),

        // Watch Providers - Plataformas de streaming
        if (movie.watchProviders != null)
          WatchProvidersWidget(
            watchProviders: movie.watchProviders,
            movieTitle: movie.title,
            imdbId: movie.imdbId,
            country: 'MX',
          ),
        if (movie.watchProviders != null) const SizedBox(height: 16),

        // Homepage link if available
        if (movie.homepage != null && movie.homepage!.isNotEmpty)
          Container(
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
                    Icon(Icons.link, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Sitio Oficial',
                      style: textStyles.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _launchURL(movie.homepage!),
                  child: Text(
                    movie.homepage!,
                    style: textStyles.bodyMedium?.copyWith(
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (movie.homepage != null && movie.homepage!.isNotEmpty)
          const SizedBox(height: 16),

        // Cast principal mejorado
        _EnhancedCast(movie: movie),

        const SizedBox(height: 16),

        // Estadísticas y datos curiosos
        _MovieStats(movie: movie),
      ],
    );
  }

  // Función para abrir URLs externas
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la URL: $url';
      }
    } catch (e) {
      LoggerFactory.error('Error al abrir URL: $e');
    }
  }
}

class _CollectionInfo extends StatelessWidget {
  const _CollectionInfo({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

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
              Icon(Icons.collections_bookmark, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Parte de la Colección',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.movie_filter, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    movie.belongsToCollection ?? '',
                    style: textStyles.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpokenLanguages extends StatelessWidget {
  const _SpokenLanguages({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

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
              Icon(Icons.translate, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Idiomas',
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
            children: (movie.spokenLanguages ?? [])
                .map((language) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.language, size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            language,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _BasicInfoSection extends StatelessWidget {
  const _BasicInfoSection({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      style: textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (movie.originalTitle != movie.title)
                      Text(
                        movie.originalTitle,
                        style: textStyles.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (movie.tagline != null &&
                        (movie.tagline?.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '"${movie.tagline}"',
                          style: textStyles.titleSmall?.copyWith(
                            color: colors.primary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRatingColor(movie.voteAverage),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      movie.voteAverage.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.calendar_today,
                label: HumanFormats.shortDate(movie.releaseDate),
              ),
              if (movie.runtime != null)
                _InfoChip(
                  icon: Icons.access_time,
                  label: '${movie.runtime} min',
                ),
              _InfoChip(
                icon: Icons.language,
                label: movie.originalLanguage.toUpperCase(),
              ),
              _InfoChip(
                icon: Icons.how_to_vote,
                label:
                    '${HumanFormats.number(movie.voteCount.toDouble())} votos',
              ),
              if (movie.status != null)
                _InfoChip(
                  icon: Icons.info,
                  label: movie.status ?? '',
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedSynopsis extends StatefulWidget {
  const _ExpandedSynopsis({required this.movie});

  final Movie movie;

  @override
  State<_ExpandedSynopsis> createState() => _ExpandedSynopsisState();
}

class _ExpandedSynopsisState extends State<_ExpandedSynopsis> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final overview = widget.movie.overview;

    if (overview.isEmpty) {
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
              Icon(Icons.description, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Sinopsis',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Text(
              overview.length > 150
                  ? '${overview.substring(0, 150)}...'
                  : overview,
              style: textStyles.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
            secondChild: Text(
              overview,
              style: textStyles.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          if (overview.length > 150)
            TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'Ver menos' : 'Ver más',
                style: TextStyle(color: colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    // DEBUG: Imprimir datos técnicos para verificar qué se está recibiendo
    LoggerFactory.debug(
        '🎬 DEBUG - Detalles técnicos de la película: ${movie.title}');
    LoggerFactory.debug('  💰 Budget: ${movie.budget}');
    LoggerFactory.debug('  💵 Revenue: ${movie.revenue}');
    LoggerFactory.debug('  ⏰ Runtime: ${movie.runtime}');
    LoggerFactory.debug('  🌟 Popularity: ${movie.popularity}');
    LoggerFactory.debug('  🎭 IMDb ID: ${movie.imdbId}');
    LoggerFactory.debug('  📊 Vote Average: ${movie.voteAverage}');
    LoggerFactory.debug('  🗳️ Vote Count: ${movie.voteCount}');
    LoggerFactory.debug(
        '  🏭 Production Companies: ${movie.productionCompanies}');

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
              Icon(Icons.info_outline, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Detalles Técnicos',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Runtime and Status row (most common data)
          Row(
            children: [
              if (movie.runtime != null && (movie.runtime ?? 0) > 0)
                Expanded(
                  child: _DetailItem(
                    label: 'Duración',
                    value: '${movie.runtime} min',
                    icon: Icons.access_time,
                  ),
                ),
              if (movie.status != null && movie.status!.isNotEmpty)
                Expanded(
                  child: _DetailItem(
                    label: 'Estado',
                    value: movie.status ?? '',
                    icon: Icons.info,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Vote Average and Vote Count
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'Calificación',
                  value: '${movie.voteAverage.toStringAsFixed(1)}/10',
                  icon: Icons.star,
                ),
              ),
              Expanded(
                child: _DetailItem(
                  label: 'Votos',
                  value: HumanFormats.number(movie.voteCount.toDouble()),
                  icon: Icons.how_to_vote,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Popularity and IMDb ID
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  label: 'Popularidad',
                  value: movie.popularity.toStringAsFixed(1),
                  icon: Icons.trending_up,
                ),
              ),
              if (movie.imdbId != null && movie.imdbId!.isNotEmpty)
                Expanded(
                  child: _DetailItem(
                    label: 'IMDb ID',
                    value: movie.imdbId ?? '',
                    icon: Icons.movie,
                  ),
                ),
            ],
          ),
          // Budget and Revenue (if available)
          if (movie.budget != null && (movie.budget ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    label: 'Presupuesto',
                    value:
                        '\$${HumanFormats.number((movie.budget ?? 0).toDouble())}',
                    icon: Icons.attach_money,
                  ),
                ),
                if (movie.revenue != null && (movie.revenue ?? 0) > 0)
                  Expanded(
                    child: _DetailItem(
                      label: 'Ingresos',
                      value:
                          '\$${HumanFormats.number((movie.revenue ?? 0).toDouble())}',
                      icon: Icons.show_chart,
                    ),
                  ),
              ],
            ),
          ],
          if (movie.productionCompanies != null &&
              (movie.productionCompanies?.isNotEmpty ?? false))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Compañías Productoras',
                  style: textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: (movie.productionCompanies ?? [])
                      .take(5)
                      .map((company) => Chip(
                            label: Text(
                              company,
                              style: const TextStyle(fontSize: 12),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ),
          if (movie.productionCountries != null &&
              (movie.productionCountries?.isNotEmpty ?? false))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Países de Producción',
                  style: textStyles.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: (movie.productionCountries ?? [])
                      .map((country) => Chip(
                            label: Text(
                              country,
                              style: const TextStyle(fontSize: 12),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnhancedCast extends StatelessWidget {
  const _EnhancedCast({required this.movie});

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
    final mainCast = castList.take(10).toList();

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
              Icon(Icons.people, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Reparto Principal',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ScrollConfiguration(
              behavior: CustomScrollBehavior(),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: mainCast.length,
                itemBuilder: (context, index) {
                  final actor = mainCast[index] as Map<String, dynamic>;
                  final profilePath = actor['profile_path'] as String?;
                  final name = actor['name'] as String? ?? 'Actor desconocido';
                  final character = actor['character'] as String?;

                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: colors.surfaceContainerHighest,
                          backgroundImage:
                              profilePath != null && profilePath.isNotEmpty
                                  ? NetworkImage(
                                      resolveTmdbImageUrl(
                                        profilePath,
                                        size: 'w185',
                                      ),
                                    )
                                  : null,
                          child: profilePath == null || profilePath.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 35,
                                  color: colors.onSurface,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: textStyles.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (character != null && character.isNotEmpty)
                          Text(
                            character,
                            style: textStyles.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovieStats extends StatelessWidget {
  const _MovieStats({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

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
              Icon(Icons.analytics, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Estadísticas',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Calificación',
                  value: movie.voteAverage.toStringAsFixed(1),
                  subtitle: 'de 10',
                  icon: Icons.star,
                  color: _getRatingColor(movie.voteAverage),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Votos',
                  value: HumanFormats.number(movie.voteCount.toDouble()),
                  subtitle: 'usuarios',
                  icon: Icons.how_to_vote,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Popularidad',
                  value: movie.popularity.toStringAsFixed(0),
                  subtitle: 'puntos',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Año',
                  value: movie.releaseDate.year.toString(),
                  subtitle: 'estreno',
                  icon: Icons.calendar_today,
                  color: Colors.green,
                ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: textStyles.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: textStyles.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: textStyles.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
