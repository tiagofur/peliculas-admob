import 'package:flutter/material.dart';

import '../../core/cache/cache_service.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/streaming/streaming_service_manager.dart';
import '../../core/streaming/subscription_manager.dart';
import '../../domain/entities/user_subscription.dart';
import '../widgets/dashboard/index.dart';
import '../widgets/subscription/index.dart';

/// Main dashboard page for streaming management
class StreamingDashboardPage extends StatefulWidget {
  const StreamingDashboardPage({super.key});

  @override
  State<StreamingDashboardPage> createState() => _StreamingDashboardPageState();
}

class _StreamingDashboardPageState extends State<StreamingDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SubscriptionManager _subscriptionManager = SubscriptionManager();
  final StreamingServiceManager _streamingManager = StreamingServiceManager(
    analytics: AnalyticsService.instance,
    cache: CacheService.instance,
  );
  final AnalyticsService _analytics = AnalyticsService();
  final _logger = LoggerFactory.getLogger('StreamingDashboardPage');

  List<UserSubscription> _subscriptions = [];
  SubscriptionStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
    _analytics.trackEvent(AnalyticsEventType.userEngagement, {'action': 'streaming_dashboard_opened'});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await Future.wait([
        _subscriptionManager.initialize(),
        _streamingManager.initialize(),
      ]);

      final subscriptions = _subscriptionManager.getAllSubscriptions();
      final stats = _subscriptionManager.getSubscriptionStats();

      setState(() {
        _subscriptions = subscriptions;
        _stats = stats;
        _isLoading = false;
      });

      _analytics.trackEvent(AnalyticsEventType.userEngagement, {
        'action': 'dashboard_data_loaded',
        'subscription_count': subscriptions.length,
        'total_monthly_cost': stats.totalMonthlyCost,
      });
    } catch (e) {
      _logger.error('Error loading dashboard data: $e');
      setState(() {
        _error = 'Failed to load dashboard data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildDashboardContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Streaming Dashboard',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _showSettings,
          icon: const Icon(Icons.settings),
        ),
        IconButton(
          onPressed: _loadDashboardData,
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(
            icon: Icon(Icons.dashboard),
            text: 'Overview',
          ),
          Tab(
            icon: Icon(Icons.subscriptions),
            text: 'Subscriptions',
          ),
          Tab(
            icon: Icon(Icons.movie),
            text: 'Availability',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading dashboard...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
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
            onPressed: _loadDashboardData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildSubscriptionsTab(),
        _buildAvailabilityTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    return UserSubscriptionsWidget(
      onSubscriptionChanged: _loadDashboardData,
      padding: const EdgeInsets.all(16),
    );
  }

  Widget _buildAvailabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Availability',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'See where your favorite movies and shows are available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          _buildAvailabilitySearch(),
          const SizedBox(height: 24),
          _buildPopularContent(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return SubscriptionStatsWidget(
      subscriptions: _subscriptions,
      stats: _stats,
      onRefresh: _loadDashboardData,
    );
  }

  Widget _buildQuickActions() {
    return QuickActionsWidget(
      subscriptions: _subscriptions,
      subscriptionManager: _subscriptionManager,
      onRefresh: _loadDashboardData,
      onViewAll: () => _tabController.animateTo(1),
      onSearchContent: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search feature coming soon'),
          ),
        );
      },
    );
  }



  Widget _buildRecommendations() {
    return ContentRecommendationsWidget(
      subscriptions: _subscriptions,
      streamingManager: _streamingManager,
      onContentTap: () {
        // Navigate to content details or search
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content details coming soon'),
          ),
        );
      },
    );
  }

  Widget _buildAvailabilitySearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search for movies or TV shows...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: _searchContent,
            ),
            const SizedBox(height: 16),
            Text(
              'Find out which of your subscriptions has the content you want to watch',
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

  Widget _buildPopularContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular on Your Platforms',
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
                Icon(
                  Icons.movie_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Popular Content Coming Soon',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'re working on showing you popular content available on your subscribed platforms',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_tabController.index == 1) {
      return FloatingActionButton(
        onPressed: _showAddSubscription,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
    return null;
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings feature coming soon'),
      ),
    );
  }

  void _showAddSubscription() async {
    final result = await showDialog<UserSubscription>(
      context: context,
      builder: (context) => const AddSubscriptionDialog(),
    );

    if (result != null) {
      try {
        await _subscriptionManager.addSubscription(result);
        await _loadDashboardData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.platformName} subscription added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
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



  void _searchContent(String query) {
    if (query.trim().isEmpty) return;

    _analytics.trackEvent(AnalyticsEventType.searchQuery, {'query': query});

    // TODO: Implement content search functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for "$query"...'),
      ),
    );
  }
}
