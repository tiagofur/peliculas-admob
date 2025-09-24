import 'package:flutter/material.dart';
import '../../../domain/entities/user_subscription.dart';
import '../../../core/streaming/subscription_manager.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../core/logging/base_logger.dart';
import 'subscription_card.dart';
import 'add_subscription_dialog.dart';

/// Widget to display and manage user's streaming subscriptions
class UserSubscriptionsWidget extends StatefulWidget {
  const UserSubscriptionsWidget({
    super.key,
    this.showAddButton = true,
    this.showInactiveSubscriptions = false,
    this.onSubscriptionChanged,
    this.padding,
  });

  final bool showAddButton;
  final bool showInactiveSubscriptions;
  final VoidCallback? onSubscriptionChanged;
  final EdgeInsetsGeometry? padding;

  @override
  State<UserSubscriptionsWidget> createState() =>
      _UserSubscriptionsWidgetState();
}

class _UserSubscriptionsWidgetState extends State<UserSubscriptionsWidget> {
  final SubscriptionManager _subscriptionManager = SubscriptionManager();
  final AnalyticsService _analytics = AnalyticsService.instance;

  List<UserSubscription> _subscriptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _subscriptionManager.initialize();
      final subscriptions = _subscriptionManager.subscriptions;

      setState(() {
        _subscriptions = widget.showInactiveSubscriptions
            ? subscriptions
            : subscriptions.where((s) => s.isCurrentlyActive).toList();
        _isLoading = false;
      });

      await _analytics.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'action': 'subscriptions_loaded',
          'count': _subscriptions.length,
          'active_count':
              _subscriptions.where((s) => s.isCurrentlyActive).length,
        },
      );
    } catch (e) {
      LoggerFactory.error('Error loading subscriptions: $e',
          category: LogCategory.error);
      setState(() {
        _error = 'Failed to load subscriptions';
        _isLoading = false;
      });
    }
  }

  Future<void> _addSubscription() async {
    final result = await showDialog<UserSubscription>(
      context: context,
      builder: (context) => const AddSubscriptionDialog(),
    );

    if (result != null) {
      try {
        await _subscriptionManager.addSubscription(result);
        await _loadSubscriptions();
        widget.onSubscriptionChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Subscription to ${result.platformName} added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _analytics.trackEvent(
          AnalyticsEventType.userEngagement,
          {
            'action': 'subscription_added',
            'platform': result.platformName,
            'type': result.type.name,
            'cost': result.monthlyCost,
          },
        );
      } catch (e) {
        LoggerFactory.error('Error adding subscription: $e',
            category: LogCategory.error);
        if (mounted) {
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

  Future<void> _updateSubscription(UserSubscription subscription) async {
    try {
      await _subscriptionManager.updateSubscription(subscription);
      await _loadSubscriptions();
      widget.onSubscriptionChanged?.call();

      await _analytics.trackEvent(
        AnalyticsEventType.userEngagement,
        {
          'action': 'subscription_updated',
          'platform': subscription.platformName,
          'subscription_id': subscription.id,
        },
      );
    } catch (e) {
      LoggerFactory.error('Error updating subscription: $e',
          category: LogCategory.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeSubscription(UserSubscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subscription'),
        content: Text(
          'Are you sure you want to remove your ${subscription.platformName} subscription?\n\n'
          'This will only remove it from your tracking list, not cancel the actual subscription.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await _subscriptionManager.removeSubscription(subscription.id);
        await _loadSubscriptions();
        widget.onSubscriptionChanged?.call();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${subscription.platformName} subscription removed'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        await _analytics.trackEvent(
          AnalyticsEventType.userEngagement,
          {
            'action': 'subscription_removed',
            'platform': subscription.platformName,
            'subscription_id': subscription.id,
          },
        );
      } catch (e) {
        LoggerFactory.error('Error removing subscription: $e',
            category: LogCategory.error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove subscription: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Subscriptions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (_subscriptions.isNotEmpty)
              Text(
                '${_subscriptions.length} active subscription${_subscriptions.length != 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
          ],
        ),
        if (widget.showAddButton)
          ElevatedButton.icon(
            onPressed: _addSubscription,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubscriptions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_subscriptions.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        ..._subscriptions.map((subscription) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SubscriptionCard(
                subscription: subscription,
                onUpdate: _updateSubscription,
                onRemove: _removeSubscription,
              ),
            )),
        if (_subscriptions.length > 3) _buildSummaryCard(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.subscriptions_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Subscriptions Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your streaming subscriptions to track costs and availability',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            if (widget.showAddButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _addSubscription,
                icon: const Icon(Icons.add),
                label: const Text('Add First Subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalCost = _subscriptions.fold<double>(
      0,
      (sum, sub) => sum + sub.monthlyCost,
    );

    final expiringSoon = _subscriptions.where((s) => s.isExpiringSoon).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  Text(
                    '\$${totalCost.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                ],
              ),
            ),
            if (expiringSoon > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$expiringSoon expiring soon',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
