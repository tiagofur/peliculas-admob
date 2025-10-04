import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/logger_factory.dart';
import '../../core/utils/tmdb_image_utils.dart';
import '../../domain/entities/watch_provider.dart';
import '../../domain/entities/watch_providers.dart';
import '../../domain/services/affiliate_service.dart';
import '../../generated/app_localizations.dart';

class WatchProvidersWidget extends StatelessWidget {
  const WatchProvidersWidget({
    super.key,
    required this.watchProviders,
    this.movieTitle,
    this.imdbId,
    this.country = 'MX',
  });
  final WatchProviders? watchProviders;
  final String? movieTitle;
  final String? imdbId;
  final String country;

  @override
  Widget build(BuildContext context) {
    if (watchProviders == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Text(
                l10n.streamingProvidersTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
            const SizedBox(height: 12),

            // Streaming platforms (flatrate)
            if (watchProviders?.flatrate.isNotEmpty ?? false)
              _buildProviderSection(
                'Streaming',
                watchProviders!.flatrate,
                Icons.play_circle_fill,
                Colors.green,
              ),

            // Rental platforms
            if (watchProviders?.rent.isNotEmpty ?? false)
              _buildProviderSection(
                'Alquiler',
                watchProviders!.rent,
                Icons.movie_filter,
                Colors.orange,
              ),

            // Purchase platforms
            if (watchProviders?.buy.isNotEmpty ?? false)
              _buildProviderSection(
                'Compra',
                watchProviders!.buy,
                Icons.shopping_cart,
                Colors.blue,
              ),

            const SizedBox(height: 16),

            // JustWatch attribution
            _buildAttribution(),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSection(
    String title,
    List<WatchProvider> providers,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: providers
              .map((provider) => _buildProviderChip(provider))
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProviderChip(WatchProvider provider) {
    final hasAffiliate =
        AffiliateService.hasAffiliateSupport(provider.providerId);

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Semantics(
          label: 'Streaming provider ${provider.providerName}',
          button: true,
          onTapHint: 'Open provider',
          child: GestureDetector(
            onTap: () => _launchProvider(provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasAffiliate
                      ? Colors.green.withValues(alpha: isDark ? 0.5 : 0.3)
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Provider logo
                  if (provider.logoPath.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        resolveTmdbImageUrl(
                          provider.logoPath,
                          size: 'w45',
                          fallback:
                              'https://via.placeholder.com/45x45.png?text=TV',
                        ),
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 24,
                            height: 24,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.movie,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(width: 8),

                  // Provider name
                  Flexible(
                    child: Tooltip(
                      message: provider.providerName,
                      child: Text(
                        provider.providerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Affiliate indicator
                  if (hasAffiliate) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.link,
                      size: 16,
                      color: Colors.green[isDark ? 400 : 600],
                    ),
                  ]
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttribution() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _launchUrl(
                      AffiliateService.getJustWatchAttributionLink()),
                  child: Text(
                    AffiliateService.getAttributionText(),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchProvider(WatchProvider provider) {
    final affiliateLink = AffiliateService.generateAffiliateLink(
      provider,
      movieTitle: movieTitle,
      imdbId: imdbId,
      country: country,
    );

    _launchUrl(affiliateLink);
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      LoggerFactory.error('No se pudo abrir la URL: $url');
    }
  }
}
