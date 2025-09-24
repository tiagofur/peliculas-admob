import 'package:flutter/material.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/streaming/streaming_service_manager.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import 'platform_availability_card.dart';
import 'streaming_error_widget.dart';
import 'streaming_loading_indicator.dart';

/// Compact widget for displaying streaming availability in lists or small spaces
class CompactStreamingWidget extends StatefulWidget {
  const CompactStreamingWidget({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.region = 'US',
    this.maxPlatforms = 3,
    this.showPrices = false,
    this.onTap,
    this.height = 60,
  });

  final int movieId;
  final String movieTitle;
  final String region;
  final int maxPlatforms;
  final bool showPrices;
  final VoidCallback? onTap;
  final double height;

  @override
  State<CompactStreamingWidget> createState() => _CompactStreamingWidgetState();
}

class _CompactStreamingWidgetState extends State<CompactStreamingWidget> {
  final StreamingServiceManager _streamingManager = StreamingServiceManager(
    analytics: AnalyticsService(),
    cache: CacheService.instance,
    // Using LoggerFactory for logging
  );

  StreamingAvailability? _availability;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  @override
  void didUpdateWidget(CompactStreamingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieId != widget.movieId ||
        oldWidget.region != widget.region) {
      _loadAvailability();
    }
  }

  Future<void> _loadAvailability() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final availability = await _streamingManager.getAvailability(
        widget.movieId,
        widget.movieTitle,
        region: widget.region,
      );

      if (mounted) {
        setState(() {
          _availability = availability;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load availability';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _streamingManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Row(
        children: [
          CompactStreamingLoader(size: 14),
          SizedBox(width: 8),
          Text('Loading...'),
        ],
      );
    }

    if (_error != null) {
      return StreamingErrorWidget(
        message: _error!,
        compact: true,
        showIcon: false,
      );
    }

    if (_availability == null || _availability!.platforms.isEmpty) {
      return _buildNotAvailable();
    }

    return _buildAvailabilityRow();
  }

  Widget _buildNotAvailable() {
    return Row(
      children: [
        Icon(
          Icons.search_off,
          size: 16,
          color: Theme.of(context).disabledColor,
        ),
        const SizedBox(width: 8),
        Text(
          'Not available',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityRow() {
    final availablePlatforms = _availability!.platforms
        .where((p) => p.isAvailable)
        .take(widget.maxPlatforms)
        .toList();

    // Sort by availability type (free first)
    availablePlatforms.sort((a, b) {
      if (a.isFree && !b.isFree) return -1;
      if (!a.isFree && b.isFree) return 1;
      return 0;
    });

    if (availablePlatforms.isEmpty) {
      return _buildNotAvailable();
    }

    return Row(
      children: [
        // Platform icons
        Expanded(
          child: Row(
            children: [
              ...availablePlatforms.take(3).map(
                    (platform) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildPlatformIcon(platform),
                    ),
                  ),
              if (_availability!.platforms.length > widget.maxPlatforms)
                _buildMoreIndicator(),
            ],
          ),
        ),
        // Price or availability info
        if (widget.showPrices && availablePlatforms.isNotEmpty)
          _buildPriceInfo(availablePlatforms.first),
        // Tap indicator
        if (widget.onTap != null)
          Icon(
            Icons.chevron_right,
            size: 16,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Widget _buildPlatformIcon(PlatformAvailability platform) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: platform.platform.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: platform.platform.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.network(
          platform.platform.iconUrl,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIcon(platform),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(PlatformAvailability platform) {
    return Icon(
      Icons.play_circle_outline,
      size: 14,
      color: platform.platform.primaryColor,
    );
  }

  Widget _buildMoreIndicator() {
    final remainingCount =
        _availability!.platforms.length - widget.maxPlatforms;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '+$remainingCount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildPriceInfo(PlatformAvailability platform) {
    if (platform.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'FREE',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
        ),
      );
    }

    if (platform.formattedRentalPrice != null) {
      return Text(
        platform.formattedRentalPrice!,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
      );
    }

    if (platform.requiresSubscription) {
      return Icon(
        Icons.subscriptions,
        size: 14,
        color: Theme.of(context).primaryColor,
      );
    }

    return const SizedBox.shrink();
  }
}

/// Horizontal scrollable list of streaming platforms
class StreamingPlatformsList extends StatelessWidget {
  const StreamingPlatformsList({
    super.key,
    required this.platforms,
    this.onPlatformTap,
    this.height = 80,
  });

  final List<PlatformAvailability> platforms;
  final Function(StreamingPlatform, PlatformAvailability)? onPlatformTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (platforms.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: platforms.length,
        itemBuilder: (context, index) {
          final platform = platforms[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 200,
              child: PlatformAvailabilityCard(
                availability: platform,
                compact: true,
                onTap: onPlatformTap != null
                    ? () => onPlatformTap!(platform.platform, platform)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
