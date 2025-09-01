import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/streaming/streaming.dart';

/// Compact streaming availability indicator for movie cards
class StreamingAvailabilityBadge extends ConsumerWidget {
  const StreamingAvailabilityBadge({
    super.key,
    required this.movieId,
    this.size = StreamingBadgeSize.small,
    this.maxPlatforms = 3,
  });

  final int movieId;
  final StreamingBadgeSize size;
  final int maxPlatforms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<StreamingAvailability?>(
      future: _getStreamingAvailability(movieId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final availability = snapshot.data!;
        final availablePlatforms = availability.platforms
            .where((p) => p.isAvailable)
            .take(maxPlatforms)
            .toList();

        if (availablePlatforms.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.all(size == StreamingBadgeSize.small ? 4 : 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...availablePlatforms.map((platform) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _buildPlatformIcon(platform, size),
                  )),
              if (availability.platforms.where((p) => p.isAvailable).length >
                  maxPlatforms)
                Text(
                  '+${availability.platforms.where((p) => p.isAvailable).length - maxPlatforms}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size == StreamingBadgeSize.small ? 8 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlatformIcon(
      PlatformAvailability platform, StreamingBadgeSize size) {
    final iconSize = size == StreamingBadgeSize.small ? 12.0 : 16.0;

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: _getPlatformColor(platform.platform.id),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getPlatformInitial(platform.platform.name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size == StreamingBadgeSize.small ? 6 : 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<StreamingAvailability?> _getStreamingAvailability(int movieId,
      [String? movieTitle]) async {
    try {
      final availabilityChecker = AvailabilityChecker();
      return await availabilityChecker.checkMovieAvailability(
        movieId: movieId.toString(),
        movieTitle: movieTitle ?? 'Unknown Movie',
      );
    } catch (e) {
      return null;
    }
  }

  Color _getPlatformColor(String platformId) {
    switch (platformId) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon_prime':
        return const Color(0xFF00A8E1);
      case 'disney_plus':
        return const Color(0xFF113CCF);
      case 'hbo_max':
        return const Color(0xFF7B2CBF);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple_tv':
        return const Color(0xFF000000);
      default:
        return Colors.grey;
    }
  }

  String _getPlatformInitial(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'netflix':
        return 'N';
      case 'amazon prime video':
        return 'P';
      case 'disney+':
        return 'D';
      case 'hbo max':
        return 'H';
      case 'hulu':
        return 'U';
      case 'apple tv+':
        return 'A';
      default:
        return platformName.isNotEmpty ? platformName[0].toUpperCase() : '?';
    }
  }
}

/// Detailed streaming availability widget for movie detail views
class StreamingAvailabilityDetail extends ConsumerWidget {
  const StreamingAvailabilityDetail({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.onPlatformTap,
  });

  final int movieId;
  final String movieTitle;
  final Function(StreamingPlatform)? onPlatformTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<StreamingAvailability?>(
      future: _getStreamingAvailability(movieId, movieTitle),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Verificando disponibilidad...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final availability = snapshot.data!;
        final availablePlatforms =
            availability.platforms.where((p) => p.isAvailable).toList();

        if (availablePlatforms.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: colors.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No disponible en plataformas de streaming',
                    style: textStyles.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
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
                  Icon(Icons.play_circle_outline, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Disponible en Streaming',
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
                children: availablePlatforms.map((platform) {
                  return _buildPlatformChip(context, platform);
                }).toList(),
              ),
              ...[
                const SizedBox(height: 8),
                Text(
                  'Última actualización: ${_formatDate(availability.lastUpdated)}',
                  style: textStyles.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlatformChip(
      BuildContext context, PlatformAvailability platform) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => onPlatformTap?.call(platform.platform),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getPlatformColor(platform.platform.id).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                _getPlatformColor(platform.platform.id).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getPlatformColor(platform.platform.id),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getPlatformInitial(platform.platform.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  platform.platform.displayName,
                  style: textStyles.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (platform.isFree)
                  Text(
                    'Gratis',
                    style: textStyles.bodySmall?.copyWith(
                      color: Colors.green,
                      fontSize: 10,
                    ),
                  )
                else if (platform.requiresSubscription)
                  Text(
                    'Suscripción',
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.primary,
                      fontSize: 10,
                    ),
                  )
                else if (platform.canRent || platform.canPurchase)
                  Text(
                    'Renta/Compra',
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.secondary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 12,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Future<StreamingAvailability?> _getStreamingAvailability(int movieId,
      [String? movieTitle]) async {
    try {
      final availabilityChecker = AvailabilityChecker();
      return await availabilityChecker.checkMovieAvailability(
        movieId: movieId.toString(),
        movieTitle: movieTitle ?? 'Unknown Movie',
      );
    } catch (e) {
      return null;
    }
  }

  Color _getPlatformColor(String platformId) {
    switch (platformId) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon_prime':
        return const Color(0xFF00A8E1);
      case 'disney_plus':
        return const Color(0xFF113CCF);
      case 'hbo_max':
        return const Color(0xFF7B2CBF);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple_tv':
        return const Color(0xFF000000);
      default:
        return Colors.grey;
    }
  }

  String _getPlatformInitial(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'netflix':
        return 'N';
      case 'amazon prime video':
      case 'amazon_prime':
        return 'A';
      case 'disney plus':
      case 'disney_plus':
        return 'D';
      case 'hbo max':
      case 'hbo_max':
        return 'H';
      case 'hulu':
        return 'H';
      case 'apple tv+':
      case 'apple_tv':
        return 'A';
      default:
        return platformName.isNotEmpty ? platformName[0].toUpperCase() : '?';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Quick action button for launching streaming apps
class StreamingQuickAction extends ConsumerWidget {
  const StreamingQuickAction({
    super.key,
    required this.movieId,
    required this.movieTitle,
  });

  final int movieId;
  final String movieTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<StreamingAvailability?>(
      future: _getStreamingAvailability(movieId, movieTitle),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final availability = snapshot.data!;
        final availablePlatforms =
            availability.platforms.where((p) => p.isAvailable).toList();

        if (availablePlatforms.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show the first available platform as primary action
        final primaryPlatform = availablePlatforms.first;

        return ElevatedButton.icon(
          onPressed: () => _launchStreamingApp(context, primaryPlatform),
          icon: Icon(
            Icons.play_arrow,
            color: Colors.white,
          ),
          label: Text(
            'Ver en ${primaryPlatform.platform.displayName}',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getPlatformColor(primaryPlatform.platform.id),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      },
    );
  }

  Future<void> _launchStreamingApp(
    BuildContext context,
    PlatformAvailability platform,
  ) async {
    try {
      final deepLinkingService = DeepLinkingService();
      final success = await deepLinkingService.launchStreamingApp(
        platform: platform.platform,
        movieId: movieId.toString(),
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir ${platform.platform.displayName}. ¿Tienes la app instalada?',
            ),
            action: SnackBarAction(
              label: 'Instalar',
              onPressed: () =>
                  deepLinkingService.launchAppStore(platform.platform),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir la aplicación: $e'),
          ),
        );
      }
    }
  }

  Future<StreamingAvailability?> _getStreamingAvailability(int movieId,
      [String? movieTitle]) async {
    try {
      final availabilityChecker = AvailabilityChecker();
      return await availabilityChecker.checkMovieAvailability(
        movieId: movieId.toString(),
        movieTitle: movieTitle ?? 'Unknown Movie',
      );
    } catch (e) {
      return null;
    }
  }

  Color _getPlatformColor(String platformId) {
    switch (platformId) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon_prime':
        return const Color(0xFF00A8E1);
      case 'disney_plus':
        return const Color(0xFF113CCF);
      case 'hbo_max':
        return const Color(0xFF7B2CBF);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple_tv':
        return const Color(0xFF000000);
      default:
        return Colors.grey;
    }
  }
}

enum StreamingBadgeSize {
  small,
  medium,
}
