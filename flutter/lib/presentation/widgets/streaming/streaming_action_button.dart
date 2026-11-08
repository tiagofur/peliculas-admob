import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/services/analytics_service.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';

/// Action button for launching streaming platforms or performing streaming-related actions
class StreamingActionButton extends StatelessWidget {
  const StreamingActionButton({
    super.key,
    required this.platform,
    required this.availability,
    this.movieTitle,
    this.onPressed,
    this.style = StreamingButtonStyle.primary,
    this.size = StreamingButtonSize.medium,
    this.showPrice = true,
  });

  final StreamingPlatform platform;
  final PlatformAvailability availability;
  final String? movieTitle;
  final VoidCallback? onPressed;
  final StreamingButtonStyle style;
  final StreamingButtonSize size;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    return _buildButton(context);
  }

  Widget _buildButton(BuildContext context) {
    switch (style) {
      case StreamingButtonStyle.primary:
        return _buildPrimaryButton(context);
      case StreamingButtonStyle.outline:
        return _buildOutlineButton(context);
      case StreamingButtonStyle.text:
        return _buildTextButton(context);
      case StreamingButtonStyle.icon:
        return _buildIconButton(context);
      case StreamingButtonStyle.chip:
        return _buildChipButton(context);
    }
  }

  Widget _buildPrimaryButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: availability.isAvailable ? _handlePress : null,
      icon: _buildButtonIcon(),
      label: _buildButtonLabel(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: platform.primaryColor,
        foregroundColor: Colors.white,
        padding: _getButtonPadding(),
        minimumSize: _getButtonSize(),
      ),
    );
  }

  Widget _buildOutlineButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: availability.isAvailable ? _handlePress : null,
      icon: _buildButtonIcon(),
      label: _buildButtonLabel(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: platform.primaryColor,
        side: BorderSide(color: platform.primaryColor),
        padding: _getButtonPadding(),
        minimumSize: _getButtonSize(),
      ),
    );
  }

  Widget _buildTextButton(BuildContext context) {
    return TextButton.icon(
      onPressed: availability.isAvailable ? _handlePress : null,
      icon: _buildButtonIcon(),
      label: _buildButtonLabel(context),
      style: TextButton.styleFrom(
        foregroundColor: platform.primaryColor,
        padding: _getButtonPadding(),
        minimumSize: _getButtonSize(),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context) {
    return IconButton(
      onPressed: availability.isAvailable ? _handlePress : null,
      icon: _buildPlatformIcon(),
      tooltip: _getTooltipText(),
      style: IconButton.styleFrom(
        backgroundColor: platform.primaryColor.withValues(alpha: 0.1),
        foregroundColor: platform.primaryColor,
        iconSize: _getIconSize(),
      ),
    );
  }

  Widget _buildChipButton(BuildContext context) {
    return ActionChip(
      onPressed: availability.isAvailable ? _handlePress : null,
      avatar: _buildPlatformIcon(),
      label: _buildButtonLabel(context),
      backgroundColor: platform.primaryColor.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: platform.primaryColor,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(color: platform.primaryColor.withValues(alpha: 0.3)),
    );
  }

  Widget _buildButtonIcon() {
    if (availability.isFree) {
      return const Icon(Icons.play_circle, size: 18);
    } else if (availability.requiresSubscription) {
      return const Icon(Icons.subscriptions, size: 18);
    } else {
      return const Icon(Icons.payment, size: 18);
    }
  }

  Widget _buildPlatformIcon() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        platform.iconUrl,
        width: _getIconSize(),
        height: _getIconSize(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.play_circle_outline,
          size: _getIconSize(),
          color: platform.primaryColor,
        ),
      ),
    );
  }

  Widget _buildButtonLabel(BuildContext context) {
    String text = platform.name;

    if (showPrice && availability.formattedRentalPrice != null) {
      text += ' • ${availability.formattedRentalPrice}';
    } else if (availability.isFree) {
      text += ' • Free';
    }

    return Text(
      text,
      style: _getTextStyle(context),
      overflow: TextOverflow.ellipsis,
    );
  }

  EdgeInsets _getButtonPadding() {
    switch (size) {
      case StreamingButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case StreamingButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case StreamingButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
  }

  Size _getButtonSize() {
    switch (size) {
      case StreamingButtonSize.small:
        return const Size(80, 32);
      case StreamingButtonSize.medium:
        return const Size(120, 40);
      case StreamingButtonSize.large:
        return const Size(160, 48);
    }
  }

  double _getIconSize() {
    switch (size) {
      case StreamingButtonSize.small:
        return 16;
      case StreamingButtonSize.medium:
        return 20;
      case StreamingButtonSize.large:
        return 24;
    }
  }

  TextStyle? _getTextStyle(BuildContext context) {
    switch (size) {
      case StreamingButtonSize.small:
        return Theme.of(context).textTheme.bodySmall;
      case StreamingButtonSize.medium:
        return Theme.of(context).textTheme.bodyMedium;
      case StreamingButtonSize.large:
        return Theme.of(context).textTheme.bodyLarge;
    }
  }

  String _getTooltipText() {
    if (!availability.isAvailable) {
      return 'Not available on ${platform.name}';
    }

    String tooltip = 'Watch on ${platform.name}';

    if (availability.isFree) {
      tooltip += ' (Free)';
    } else if (availability.formattedRentalPrice != null) {
      tooltip += ' (${availability.formattedRentalPrice})';
    } else if (availability.requiresSubscription) {
      tooltip += ' (Subscription required)';
    }

    return tooltip;
  }

  void _handlePress() {
    if (onPressed != null) {
      onPressed!();
      return;
    }

    _launchPlatform();
  }

  Future<void> _launchPlatform() async {
    try {
      // Track analytics
      AnalyticsService().trackEvent('streaming_platform_launch', {
        'platform': platform.name,
        'movie_title': movieTitle,
        'availability_type': availability.availabilityType,
        'is_free': availability.isFree,
      });

      // Try to launch the platform's deep link or app
      String? targetUrl;

      if (availability.deepLink != null) {
        targetUrl = availability.deepLink;
      } else {
        // Fallback to platform's main URL or app store
        targetUrl = platform.websiteUrl;
      }

      if (targetUrl != null) {
        final uri = Uri.parse(targetUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          LoggerFactory.error('Cannot launch URL: $targetUrl');
        }
      }
    } catch (e) {
      LoggerFactory.error('Failed to launch platform: $e');
    }
  }
}

/// Button styles for streaming action buttons
enum StreamingButtonStyle {
  primary,
  outline,
  text,
  icon,
  chip,
}

/// Button sizes for streaming action buttons
enum StreamingButtonSize {
  small,
  medium,
  large,
}

/// Widget that displays multiple streaming action buttons in a row
class StreamingActionRow extends StatelessWidget {
  const StreamingActionRow({
    super.key,
    required this.platforms,
    this.movieTitle,
    this.maxButtons = 3,
    this.style = StreamingButtonStyle.chip,
    this.size = StreamingButtonSize.small,
    this.onPlatformPressed,
  });

  final List<PlatformAvailability> platforms;
  final String? movieTitle;
  final int maxButtons;
  final StreamingButtonStyle style;
  final StreamingButtonSize size;
  final Function(StreamingPlatform, PlatformAvailability)? onPlatformPressed;

  @override
  Widget build(BuildContext context) {
    final availablePlatforms =
        platforms.where((p) => p.isAvailable).take(maxButtons).toList();

    if (availablePlatforms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: availablePlatforms.map((platform) {
        return StreamingActionButton(
          platform: platform.platform,
          availability: platform,
          movieTitle: movieTitle,
          style: style,
          size: size,
          onPressed: onPlatformPressed != null
              ? () => onPlatformPressed!(platform.platform, platform)
              : null,
        );
      }).toList(),
    );
  }
}
