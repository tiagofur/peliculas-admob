import 'package:flutter/material.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/streaming/subscription_manager.dart';
import '../../../domain/entities/user_subscription.dart';

/// Widget to display subscription statistics and insights
class SubscriptionStatsWidget extends StatefulWidget {
  const SubscriptionStatsWidget({
    super.key,
    required this.subscriptions,
    this.stats,
    this.onRefresh,
    this.padding,
  });
  final List<UserSubscription> subscriptions;
  final SubscriptionStats? stats;
  final VoidCallback? onRefresh;
  final EdgeInsetsGeometry? padding;

  @override
  State<SubscriptionStatsWidget> createState() =>
      _SubscriptionStatsWidgetState();
}

class _SubscriptionStatsWidgetState extends State<SubscriptionStatsWidget> {
  final AnalyticsService _analytics = AnalyticsService();
  // Using LoggerFactory for logging

  @override
  void initState() {
    super.initState();
    _analytics.trackEvent('subscription_stats_viewed');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (widget.stats != null) ...[
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildCostBreakdown(),
            const SizedBox(height: 24),
            _buildInsights(),
          ] else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Subscription Statistics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (widget.onRefresh != null)
          IconButton(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh stats',
          ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = widget.stats!;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          'Total Monthly',
          '\$${stats.totalMonthlyCost.toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.green,
          '\$${(stats.totalMonthlyCost * 12).toStringAsFixed(0)}/year',
        ),
        _buildStatCard(
          'Active Services',
          stats.activeSubscriptions.toString(),
          Icons.subscriptions,
          Colors.blue,
          '${stats.totalSubscriptions - stats.activeSubscriptions} inactive',
        ),
        _buildStatCard(
          'Average Cost',
          '\$${stats.activeSubscriptions > 0 ? (stats.totalMonthlyCost / stats.activeSubscriptions).toStringAsFixed(2) : '0.00'}',
          Icons.trending_up,
          Colors.purple,
          'per service',
        ),
        _buildStatCard(
          'Most Expensive',
          _getMostExpensiveService(),
          Icons.star,
          Colors.orange,
          _getMostExpensiveAmount(),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cost Breakdown',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...widget.subscriptions
                    .where((sub) => sub.isActive)
                    .map((sub) => _buildCostItem(sub)),
                if (widget.subscriptions
                    .where((sub) => sub.isActive)
                    .isNotEmpty)
                  const Divider(),
                _buildTotalCostItem(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCostItem(UserSubscription subscription) {
    final monthlyCost = subscription.monthlyCost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getPlatformColor(subscription.platformName),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getPlatformIcon(subscription.platformName),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.platformName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  subscription.type.name.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${monthlyCost.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '/month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCostItem() {
    final totalCost = widget.stats!.totalMonthlyCost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calculate,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total Monthly Cost',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${totalCost.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
              ),
              Text(
                '\$${(totalCost * 12).toStringAsFixed(0)}/year',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights & Recommendations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ..._getInsights().map((insight) => _buildInsightCard(insight)),
      ],
    );
  }

  Widget _buildInsightCard(SubscriptionInsight insight) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: insight.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                insight.icon,
                color: insight.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            if (insight.actionLabel != null)
              TextButton(
                onPressed: insight.onAction,
                child: Text(insight.actionLabel!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Statistics Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some subscriptions to see detailed statistics and insights',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getMostExpensiveService() {
    if (widget.subscriptions.isEmpty) return 'N/A';

    final activeSubs =
        widget.subscriptions.where((sub) => sub.isActive).toList();
    if (activeSubs.isEmpty) return 'N/A';

    activeSubs.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
    return activeSubs.first.platformName;
  }

  String _getMostExpensiveAmount() {
    if (widget.subscriptions.isEmpty) return '';

    final activeSubs =
        widget.subscriptions.where((sub) => sub.isActive).toList();
    if (activeSubs.isEmpty) return '';

    activeSubs.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
    return '\$${activeSubs.first.monthlyCost.toStringAsFixed(2)}/mo';
  }

  List<SubscriptionInsight> _getInsights() {
    final insights = <SubscriptionInsight>[];
    final stats = widget.stats!;
    final activeSubs =
        widget.subscriptions.where((sub) => sub.isActive).toList();

    // High cost warning
    if (stats.totalMonthlyCost > 50) {
      insights.add(SubscriptionInsight(
        title: 'High Monthly Cost',
        description:
            'You\'re spending over \$50/month. Consider reviewing unused services.',
        icon: Icons.warning,
        color: Colors.orange,
        actionLabel: 'Review',
        onAction: () => _analytics.trackEvent('insight_high_cost_clicked'),
      ));
    }

    // Too many subscriptions
    if (stats.activeSubscriptions > 5) {
      insights.add(SubscriptionInsight(
        title: 'Many Subscriptions',
        description:
            'You have ${stats.activeSubscriptions} active subscriptions. Consider consolidating.',
        icon: Icons.apps,
        color: Colors.blue,
        actionLabel: 'Optimize',
        onAction: () => _analytics.trackEvent('insight_many_subs_clicked'),
      ));
    }

    // Expiring soon
    final expiringSoon = activeSubs.where((sub) => sub.isExpiringSoon).toList();
    if (expiringSoon.isNotEmpty) {
      insights.add(SubscriptionInsight(
        title: 'Expiring Soon',
        description:
            '${expiringSoon.length} subscription(s) expiring within 7 days.',
        icon: Icons.schedule,
        color: Colors.red,
        actionLabel: 'View',
        onAction: () => _analytics.trackEvent('insight_expiring_clicked'),
      ));
    }

    // Good optimization
    if (stats.totalMonthlyCost < 30 && stats.activeSubscriptions > 0) {
      insights.add(const SubscriptionInsight(
        title: 'Well Optimized',
        description: 'Your streaming costs are well managed. Keep it up!',
        icon: Icons.thumb_up,
        color: Colors.green,
      ));
    }

    // No subscriptions
    if (stats.activeSubscriptions == 0) {
      insights.add(SubscriptionInsight(
        title: 'Get Started',
        description:
            'Add your streaming subscriptions to get personalized insights.',
        icon: Icons.add_circle_outline,
        color: Colors.blue,
        actionLabel: 'Add',
        onAction: () => _analytics.trackEvent('insight_get_started_clicked'),
      ));
    }

    return insights;
  }

  Color _getPlatformColor(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon prime video':
      case 'prime video':
        return const Color(0xFF00A8E1);
      case 'disney+':
      case 'disney plus':
        return const Color(0xFF113CCF);
      case 'hbo max':
      case 'max':
        return const Color(0xFF7B2CBF);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple tv+':
      case 'apple tv plus':
        return const Color(0xFF000000);
      case 'paramount+':
      case 'paramount plus':
        return const Color(0xFF0064FF);
      case 'peacock':
        return const Color(0xFF000000);
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getPlatformIcon(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'netflix':
        return Icons.movie;
      case 'amazon prime video':
      case 'prime video':
        return Icons.shopping_bag;
      case 'disney+':
      case 'disney plus':
        return Icons.castle;
      case 'hbo max':
      case 'max':
        return Icons.hd;
      case 'hulu':
        return Icons.tv;
      case 'apple tv+':
      case 'apple tv plus':
        return Icons.apple;
      case 'paramount+':
      case 'paramount plus':
        return Icons.flag;
      case 'peacock':
        return Icons.pets;
      default:
        return Icons.play_circle_outline;
    }
  }
}

/// Data class for subscription insights
class SubscriptionInsight {
  const SubscriptionInsight({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
}
