import 'package:flutter/material.dart';

import '../../../core/streaming/subscription_manager.dart';
import '../../../domain/entities/user_subscription.dart';
import '../subscription/add_subscription_dialog.dart';

/// Widget for displaying quick actions in the dashboard
class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({
    super.key,
    required this.subscriptions,
    required this.subscriptionManager,
    this.onRefresh,
    this.onViewAll,
    this.onSearchContent,
  });
  final List<UserSubscription> subscriptions;
  final SubscriptionManager subscriptionManager;
  final VoidCallback? onRefresh;
  final VoidCallback? onViewAll;
  final VoidCallback? onSearchContent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildActionGrid(context),
        const SizedBox(height: 16),
        _buildExpiringSubscriptions(context),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildActionCard(
          context,
          icon: Icons.add_circle_outline,
          title: 'Add Subscription',
          subtitle: 'Track new service',
          color: Colors.blue,
          onTap: () => _showAddSubscriptionDialog(context),
        ),
        _buildActionCard(
          context,
          icon: Icons.search,
          title: 'Search Content',
          subtitle: 'Find movies & shows',
          color: Colors.green,
          onTap: onSearchContent,
        ),
        _buildActionCard(
          context,
          icon: Icons.list_alt,
          title: 'View All',
          subtitle: 'Manage subscriptions',
          color: Colors.orange,
          onTap: onViewAll,
        ),
        _buildActionCard(
          context,
          icon: Icons.refresh,
          title: 'Refresh',
          subtitle: 'Update data',
          color: Colors.purple,
          onTap: onRefresh,
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiringSubscriptions(BuildContext context) {
    final expiringSubscriptions = _getExpiringSubscriptions();

    if (expiringSubscriptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: Colors.orange[700],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Expiring Soon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: expiringSubscriptions
                  .map((sub) => _buildExpiringItem(context, sub))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiringItem(
      BuildContext context, UserSubscription subscription) {
    final daysUntilExpiry =
        subscription.nextBillingDate?.difference(DateTime.now()).inDays ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            _getPlatformIcon(subscription.platformId),
            size: 16,
            color: Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subscription.platformId,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Text(
            daysUntilExpiry == 0
                ? 'Today'
                : daysUntilExpiry == 1
                    ? 'Tomorrow'
                    : '$daysUntilExpiry days',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  List<UserSubscription> _getExpiringSubscriptions() {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    return subscriptions
        .where((sub) =>
            sub.isActive &&
            sub.nextBillingDate != null &&
            sub.nextBillingDate!.isAfter(now) &&
            sub.nextBillingDate!.isBefore(sevenDaysFromNow))
        .toList()
      ..sort((a, b) => a.nextBillingDate!.compareTo(b.nextBillingDate!));
  }

  IconData _getPlatformIcon(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'netflix':
        return Icons.movie;
      case 'prime_video':
      case 'amazon_prime':
        return Icons.shopping_bag;
      case 'disney_plus':
      case 'disney+':
        return Icons.castle;
      case 'hbo_max':
      case 'hbo':
        return Icons.live_tv;
      case 'apple_tv':
      case 'apple_tv+':
        return Icons.apple;
      case 'paramount_plus':
      case 'paramount+':
        return Icons.flag;
      case 'peacock':
        return Icons.pets;
      case 'hulu':
        return Icons.tv;
      default:
        return Icons.play_circle_outline;
    }
  }

  Future<void> _showAddSubscriptionDialog(BuildContext context) async {
    final result = await showDialog<UserSubscription>(
      context: context,
      builder: (context) => const AddSubscriptionDialog(),
    );

    if (result != null) {
      try {
        await subscriptionManager.addSubscription(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${result.platformId} subscription'),
              backgroundColor: Colors.green,
            ),
          );
          onRefresh?.call();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add subscription: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
