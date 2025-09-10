import 'package:flutter/material.dart';

/// Error widget specifically designed for streaming availability errors
class StreamingErrorWidget extends StatelessWidget {
  const StreamingErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.showIcon = true,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool showIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactError(context);
    }
    
    return _buildFullError(context);
  }

  Widget _buildCompactError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(
              Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullError(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Unable to Load Streaming Info',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Specific error types for streaming
class StreamingNetworkError extends StreamingErrorWidget {
  const StreamingNetworkError({
    super.key,
    super.onRetry,
    super.compact = false,
  }) : super(
    message: 'Check your internet connection and try again',
    showIcon: true,
  );
}

class StreamingTimeoutError extends StreamingErrorWidget {
  const StreamingTimeoutError({
    super.key,
    super.onRetry,
    super.compact = false,
  }) : super(
    message: 'Request timed out. Please try again',
    showIcon: true,
  );
}

class StreamingServiceError extends StreamingErrorWidget {
  const StreamingServiceError({
    super.key,
    super.onRetry,
    super.compact = false,
  }) : super(
    message: 'Streaming service is temporarily unavailable',
    showIcon: true,
  );
}

class StreamingRegionError extends StreamingErrorWidget {
  const StreamingRegionError({
    super.key,
    super.onRetry,
    super.compact = false,
    required String region,
  }) : super(
    message: 'Streaming data not available for $region',
    showIcon: true,
  );
}

/// Error widget for when no streaming platforms are available
class NoStreamingAvailableWidget extends StatelessWidget {
  const NoStreamingAvailableWidget({
    super.key,
    this.movieTitle,
    this.onSearchAlternatives,
  });

  final String? movieTitle;
  final VoidCallback? onSearchAlternatives;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Not Available for Streaming',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            movieTitle != null
                ? '$movieTitle is not currently available on any streaming platform'
                : 'This movie is not currently available on any streaming platform',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Try checking back later or explore other platforms',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          if (onSearchAlternatives != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onSearchAlternatives,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search Alternatives'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}