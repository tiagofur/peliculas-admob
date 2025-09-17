import 'package:flutter/material.dart';

import '../../../core/streaming/streaming.dart';
import '../../../domain/entities/user_subscription.dart';
import 'edit_subscription_dialog.dart';

/// Card widget to display individual subscription information
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onUpdate,
    this.onRemove,
    this.showActions = true,
    this.compact = false,
  });

  final UserSubscription subscription;
  final Function(UserSubscription)? onUpdate;
  final Function(UserSubscription)? onRemove;
  final bool showActions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: showActions ? () => _showSubscriptionDetails(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: compact
              ? _buildCompactLayout(context)
              : _buildFullLayout(context),
        ),
      ),
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildPlatformIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subscription.platformName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      _buildStatusBadge(context),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        subscription.type.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        subscription.formattedBillingCycle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showActions)
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Remove', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                context,
                'Monthly Cost',
                subscription.formattedMonthlyCost,
                Icons.attach_money,
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoItem(
                context,
                'Next Billing',
                _getNextBillingText(),
                Icons.calendar_today,
                subscription.isExpiringSoon ? Colors.orange : Colors.grey[600]!,
              ),
            ),
          ],
        ),
        if (subscription.isExpiringSoon) ...[
          const SizedBox(height: 12),
          _buildExpiringWarning(context),
        ],
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Row(
      children: [
        _buildPlatformIcon(size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subscription.platformName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _buildStatusBadge(context, compact: true),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    subscription.formattedMonthlyCost,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subscription.type.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (subscription.isExpiringSoon)
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
      ],
    );
  }

  Widget _buildPlatformIcon({double size = 40}) {
    final platform = StreamingUtils.getPlatformById(subscription.platformId);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: platform?.logoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                platform!.logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackIcon(size);
                },
              ),
            )
          : _buildFallbackIcon(size),
    );
  }

  Widget _buildFallbackIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          subscription.platformName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, {bool compact = false}) {
    final isActive = subscription.isCurrentlyActive;
    final color = isActive ? Colors.green : Colors.grey;
    final text = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color[100],
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color[700],
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildExpiringWarning(BuildContext context) {
    final daysLeft = subscription.daysUntilNextBilling ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              daysLeft > 0
                  ? 'Renews in $daysLeft day${daysLeft != 1 ? 's' : ''}'
                  : 'Renewal due today',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextBillingText() {
    final nextBilling = subscription.nextBillingDate;
    if (nextBilling == null) return 'Unknown';

    final now = DateTime.now();
    final difference = nextBilling.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference <= 7) {
      return 'In $difference days';
    } else {
      return '${nextBilling.day}/${nextBilling.month}/${nextBilling.year}';
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        _editSubscription(context);
        break;
      case 'remove':
        onRemove?.call(subscription);
        break;
    }
  }

  void _editSubscription(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EditSubscriptionDialog(
        subscription: subscription,
        onSave: (updatedSubscription) {
          onUpdate?.call(updatedSubscription);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showSubscriptionDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(subscription.platformName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', subscription.type.displayName),
            _buildDetailRow('Monthly Cost', subscription.formattedMonthlyCost),
            _buildDetailRow(
                'Billing Cycle', subscription.formattedBillingCycle),
            _buildDetailRow('Start Date', _formatDate(subscription.startDate)),
            if (subscription.nextBillingDate != null)
              _buildDetailRow(
                  'Next Billing', _formatDate(subscription.nextBillingDate!)),
            _buildDetailRow('Status',
                subscription.isCurrentlyActive ? 'Active' : 'Inactive'),
            _buildDetailRow(
                'Auto Renew', subscription.autoRenew ? 'Yes' : 'No'),
            if (subscription.subscriptionDurationDays > 0)
              _buildDetailRow(
                  'Duration', '${subscription.subscriptionDurationDays} days'),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
