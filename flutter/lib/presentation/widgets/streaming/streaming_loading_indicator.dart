import 'package:flutter/material.dart';

/// Loading indicator specifically designed for streaming availability
class StreamingLoadingIndicator extends StatefulWidget {
  const StreamingLoadingIndicator({
    super.key,
    this.message = 'Checking streaming availability...',
    this.showPlatformPlaceholders = true,
    this.platformCount = 4,
  });

  final String message;
  final bool showPlatformPlaceholders;
  final int platformCount;

  @override
  State<StreamingLoadingIndicator> createState() =>
      _StreamingLoadingIndicatorState();
}

class _StreamingLoadingIndicatorState extends State<StreamingLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildLoadingMessage(),
        const SizedBox(height: 16),
        if (widget.showPlatformPlaceholders) _buildPlatformPlaceholders(),
      ],
    );
  }

  Widget _buildLoadingMessage() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlatformPlaceholders() {
    return Column(
      children: List.generate(
        widget.platformCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildPlatformPlaceholder(index),
        ),
      ),
    );
  }

  Widget _buildPlatformPlaceholder(int index) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildShimmerBox(32, 32, isCircular: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildShimmerBox(120, 16),
                          const SizedBox(height: 4),
                          _buildShimmerBox(80, 12),
                        ],
                      ),
                    ),
                    _buildShimmerBox(60, 20),
                  ],
                ),
              ),
              _buildShimmerOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox(double width, double height,
      {bool isCircular = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isCircular ? height / 2 : 4),
      ),
    );
  }

  Widget _buildShimmerOverlay() {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shimmerAnimation.value * 200, 0),
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact loading indicator for smaller spaces
class CompactStreamingLoader extends StatelessWidget {
  const CompactStreamingLoader({
    super.key,
    this.size = 16,
    this.message,
  });

  final double size;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: 8),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ],
    );
  }
}
