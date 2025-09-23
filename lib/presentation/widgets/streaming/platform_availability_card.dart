import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/streaming_availability.dart';

/// Card widget that displays availability information for a single streaming platform
class PlatformAvailabilityCard extends StatelessWidget {
  const PlatformAvailabilityCard({
    super.key,
    required this.availability,
    this.onTap,
    this.showDetails = true,
    this.compact = false,
  });

  final PlatformAvailability availability;
  final VoidCallback? onTap;
  final bool showDetails;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: availability.isAvailable ? 2 : 1,
      color: availability.isAvailable
          ? null
          : Theme.of(context).disabledColor.withValues(alpha: 0.1),
      child: InkWell(
        onTap: availability.isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: compact
              ? _buildCompactLayout(context)
              : _buildFullLayout(context),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Row(
      children: [
        _buildPlatformIcon(context, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                availability.platform.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: availability.isAvailable
                          ? null
                          : Theme.of(context).disabledColor,
                    ),
              ),
              if (availability.isAvailable)
                _buildAvailabilityBadge(context, compact: true),
            ],
          ),
        ),
        if (availability.isAvailable && onTap != null)
          Icon(
            Icons.launch,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
      ],
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    return Row(
      children: [
        _buildPlatformIcon(context),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                availability.platform.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: availability.isAvailable
                          ? null
                          : Theme.of(context).disabledColor,
                    ),
              ),
              const SizedBox(height: 4),
              if (availability.isAvailable) ...[
                _buildAvailabilityBadge(context),
                if (showDetails && _hasAdditionalInfo()) ...[
                  const SizedBox(height: 4),
                  _buildAdditionalInfo(context),
                ],
              ] else
                Text(
                  'Not available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                ),
            ],
          ),
        ),
        if (availability.isAvailable) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (availability.formattedRentalPrice != null)
                Text(
                  availability.formattedRentalPrice!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              if (availability.formattedPurchasePrice != null)
                Text(
                  'Buy: ${availability.formattedPurchasePrice}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (onTap != null) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.launch,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPlatformIcon(BuildContext context, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: availability.platform.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: availability.platform.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        // 🚀 PERFORMANCE: Using CachedNetworkImage for better caching
        child: CachedNetworkImage(
          imageUrl: availability.platform.iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              _buildFallbackIcon(context, size),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(BuildContext context, double size) {
    return Icon(
      Icons.play_circle_outline,
      size: size * 0.6,
      color: availability.platform.primaryColor,
    );
  }

  Widget _buildAvailabilityBadge(BuildContext context, {bool compact = false}) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (availability.isFree) {
      badgeColor = Colors.green;
      badgeText = 'Free';
      badgeIcon = Icons.check_circle;
    } else if (availability.requiresSubscription) {
      badgeColor = Colors.blue;
      badgeText = 'Subscription';
      badgeIcon = Icons.subscriptions;
    } else {
      badgeColor = Colors.orange;
      badgeText = 'Rental';
      badgeIcon = Icons.payment;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: compact ? 12 : 14,
            color: badgeColor,
          ),
          SizedBox(width: compact ? 2 : 4),
          Text(
            badgeText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 10 : 12,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(BuildContext context) {
    final info = <String>[];

    if (availability.quality != null) {
      info.add(availability.quality!);
    }

    if (availability.isExpiringSoon) {
      info.add('Expires soon');
    }

    if (availability.availableUntil != null) {
      final daysLeft =
          availability.availableUntil!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        info.add('$daysLeft days left');
      }
    }

    if (info.isEmpty) return const SizedBox.shrink();

    return Text(
      info.join(' • '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
    );
  }

  bool _hasAdditionalInfo() {
    return availability.quality != null ||
        availability.isExpiringSoon ||
        availability.availableUntil != null;
  }
}
