import 'package:flutter/material.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/cache/cache_service.dart';
import '../../../core/streaming/streaming_service_manager.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';
import 'platform_availability_card.dart';
import 'streaming_error_widget.dart';
import 'streaming_loading_indicator.dart';

/// Widget that displays streaming availability for a movie
class StreamingAvailabilityWidget extends StatefulWidget {
  const StreamingAvailabilityWidget({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.region = 'US',
    this.showHeader = true,
    this.maxPlatforms = 6,
    this.onPlatformTap,
  });

  final int movieId;
  final String movieTitle;
  final String region;
  final bool showHeader;
  final int maxPlatforms;
  final Function(StreamingPlatform, PlatformAvailability)? onPlatformTap;

  @override
  State<StreamingAvailabilityWidget> createState() =>
      _StreamingAvailabilityWidgetState();
}

class _StreamingAvailabilityWidgetState
    extends State<StreamingAvailabilityWidget> {
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
  void didUpdateWidget(StreamingAvailabilityWidget oldWidget) {
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
          _error = 'Failed to load streaming availability';
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) _buildHeader(),
            const SizedBox(height: 12),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.play_circle_outline,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          'Where to Watch',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Spacer(),
        if (_isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const StreamingLoadingIndicator();
    }

    if (_error != null) {
      return StreamingErrorWidget(
        message: _error!,
        onRetry: _loadAvailability,
      );
    }

    if (_availability == null || _availability!.platforms.isEmpty) {
      return _buildNotAvailable();
    }

    return _buildAvailabilityList();
  }

  Widget _buildNotAvailable() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Not currently available on streaming platforms',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later or try other platforms',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityList() {
    final platforms = _availability!.platforms
        .where((p) => p.isAvailable)
        .take(widget.maxPlatforms)
        .toList();

    // Sort by availability type (free first, then subscription, then rental)
    platforms.sort((a, b) {
      if (a.isFree && !b.isFree) return -1;
      if (!a.isFree && b.isFree) return 1;
      if (a.requiresSubscription && !b.requiresSubscription) return -1;
      if (!a.requiresSubscription && b.requiresSubscription) return 1;
      return 0;
    });

    return Column(
      children: [
        ...platforms.map((platform) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlatformAvailabilityCard(
                availability: platform,
                onTap: widget.onPlatformTap != null
                    ? () => widget.onPlatformTap!(platform.platform, platform)
                    : null,
              ),
            )),
        if (_availability!.platforms.length > widget.maxPlatforms)
          _buildShowMoreButton(),
      ],
    );
  }

  Widget _buildShowMoreButton() {
    final remainingCount =
        _availability!.platforms.length - widget.maxPlatforms;

    return TextButton(
      onPressed: () {
        _showAllPlatformsDialog();
      },
      child: Text(
        'Show $remainingCount more platform${remainingCount > 1 ? 's' : ''}',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showAllPlatformsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Streaming Platforms'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            // 🚀 PERFORMANCE: Cache para lista de plataformas
            cacheExtent: 300.0,
            itemCount: _availability!.platforms.length,
            itemBuilder: (context, index) {
              final platform = _availability!.platforms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PlatformAvailabilityCard(
                  availability: platform,
                  onTap: widget.onPlatformTap != null
                      ? () {
                          Navigator.of(context).pop();
                          widget.onPlatformTap!(platform.platform, platform);
                        }
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
