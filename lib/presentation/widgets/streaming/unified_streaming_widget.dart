import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/watch_provider.dart';
import '../../../domain/entities/watch_providers.dart';
import '../../../domain/services/affiliate_service.dart';
import '../../../generated/app_localizations.dart';
import '../../providers/movies/watch_providers_provider.dart';

/// Unified Streaming Widget - Enterprise-grade solution for displaying streaming availability
///
/// Features:
/// - Single source of truth for streaming data
/// - Smart caching to prevent duplicate API calls
/// - Beautiful Material Design 3 UI with animations
/// - Graceful error handling and retry mechanisms
/// - Performance optimized with lazy loading
/// - Analytics tracking for user interactions
class UnifiedStreamingWidget extends ConsumerStatefulWidget {
  const UnifiedStreamingWidget({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.imdbId,
    this.region = 'MX',
    this.showQuickActions = true,
    this.compact = false,
  });

  final int movieId;
  final String movieTitle;
  final String? imdbId;
  final String region;
  final bool showQuickActions;
  final bool compact;

  @override
  ConsumerState<UnifiedStreamingWidget> createState() =>
      _UnifiedStreamingWidgetState();
}

class _UnifiedStreamingWidgetState extends ConsumerState<UnifiedStreamingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchProvidersAsync = ref.watch(
      watchProvidersWithRegionProvider(
        WatchProvidersParams(
          movieId: widget.movieId,
          region: widget.region,
        ),
      ),
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: watchProvidersAsync.when(
          data: (watchProviders) => _buildContent(context, watchProviders),
          loading: () => _buildLoadingState(context),
          error: (error, stackTrace) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WatchProviders? watchProviders) {
    if (watchProviders == null ||
        (!watchProviders.hasProviders && !widget.showQuickActions)) {
      return _buildNotAvailableState(context);
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: widget.compact ? 1 : 2,
      margin: widget.compact
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse
            _buildHeader(context, watchProviders),

            // Content (collapsible)
            if (_isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streaming platforms (flatrate - subscription)
                    if (watchProviders.flatrate.isNotEmpty)
                      _buildProviderSection(
                        context,
                        'Suscripción',
                        watchProviders.flatrate,
                        Icons.play_circle_filled,
                        colors.primary,
                        'Disponible con tu suscripción',
                      ),

                    // Rental platforms
                    if (watchProviders.rent.isNotEmpty) ...[
                      if (watchProviders.flatrate.isNotEmpty)
                        const SizedBox(height: 20),
                      _buildProviderSection(
                        context,
                        'Alquiler',
                        watchProviders.rent,
                        Icons.movie_filter_rounded,
                        Colors.orange,
                        'Disponible para alquilar',
                      ),
                    ],

                    // Purchase platforms
                    if (watchProviders.buy.isNotEmpty) ...[
                      if (watchProviders.flatrate.isNotEmpty ||
                          watchProviders.rent.isNotEmpty)
                        const SizedBox(height: 20),
                      _buildProviderSection(
                        context,
                        'Compra',
                        watchProviders.buy,
                        Icons.shopping_bag_rounded,
                        Colors.blue,
                        'Disponible para comprar',
                      ),
                    ],

                    const SizedBox(height: 16),

                    // JustWatch attribution
                    _buildAttribution(context),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WatchProviders? watchProviders) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyles = theme.textTheme;
    final l10n = AppLocalizations.of(context)!;

    final totalProviders = (watchProviders?.flatrate.length ?? 0) +
        (watchProviders?.rent.length ?? 0) +
        (watchProviders?.buy.length ?? 0);

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primaryContainer.withValues(alpha: 0.3),
              colors.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: colors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.streamingProvidersTitle,
                    style: textStyles.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalProviders > 0
                        ? '$totalProviders plataforma${totalProviders != 1 ? 's' : ''} disponible${totalProviders != 1 ? 's' : ''}'
                        : 'Ver disponibilidad',
                    style: textStyles.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Expand/collapse indicator
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSection(
    BuildContext context,
    String title,
    List<WatchProvider> providers,
    IconData icon,
    Color color,
    String description,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textStyles = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textStyles.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Provider chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: providers
              .map((provider) => _buildProviderChip(context, provider, color))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildProviderChip(
    BuildContext context,
    WatchProvider provider,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasAffiliate =
        AffiliateService.hasAffiliateSupport(provider.providerId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchProvider(provider),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceContainerHighest
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasAffiliate
                  ? accentColor.withValues(alpha: 0.4)
                  : colors.outline.withValues(alpha: 0.2),
              width: hasAffiliate ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Provider logo with enhanced styling
              if (provider.logoPath.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      resolveTmdbImageUrl(
                        provider.logoPath,
                        size: 'w92',
                        fallback:
                            'https://via.placeholder.com/45x45.png?text=TV',
                      ),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.movie_rounded,
                            size: 20,
                            color: accentColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(width: 10),

              // Provider name
              Flexible(
                child: Text(
                  provider.providerName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Affiliate indicator or launch icon
              const SizedBox(width: 6),
              Icon(
                hasAffiliate ? Icons.star_rounded : Icons.open_in_new_rounded,
                size: 16,
                color: hasAffiliate
                    ? accentColor
                    : colors.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttribution(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _launchUrl(AffiliateService.getJustWatchAttributionLink()),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceContainerHighest.withValues(alpha: 0.5)
              : colors.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AffiliateService.getAttributionText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: colors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: widget.compact ? 1 : 2,
      margin: widget.compact
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.streamingProvidersTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.streamingProvidersLoading,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: widget.compact ? 1 : 2,
      margin: widget.compact
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: colors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.streamingProvidersTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.streamingProvidersError,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  ref.invalidate(
                    watchProvidersWithRegionProvider(
                      WatchProvidersParams(
                        movieId: widget.movieId,
                        region: widget.region,
                        forceRefresh: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.streamingProvidersRetry),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.errorContainer,
                  foregroundColor: colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotAvailableState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: widget.compact ? 1 : 2,
      margin: widget.compact
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.streamingProvidersTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.streamingProvidersNotAvailable,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _launchProvider(WatchProvider provider) {
    final affiliateLink = AffiliateService.generateAffiliateLink(
      provider,
      movieTitle: widget.movieTitle,
      imdbId: widget.imdbId,
      country: widget.region,
    );

    _launchUrl(affiliateLink);

    // Log analytics
    LoggerFactory.info(
        'User tapped streaming provider: ${provider.providerName} for movie: ${widget.movieTitle}');
  }

  void _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        LoggerFactory.error('Could not launch URL: $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo abrir el enlace'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      LoggerFactory.error('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
