import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/streaming/streaming.dart';
import '../../../core/streaming/subscription_tracker.dart' as tracker;
import '../../../core/analytics/analytics_service.dart';
import '../../../core/cache/cache_service.dart';
// Removed unnecessary imports - all elements available from streaming.dart

class StreamingDashboardScreen extends ConsumerStatefulWidget {
  const StreamingDashboardScreen({super.key});

  static const name = 'streaming-dashboard';

  @override
  StreamingDashboardScreenState createState() =>
      StreamingDashboardScreenState();
}

class StreamingDashboardScreenState
    extends ConsumerState<StreamingDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final StreamingServiceManager _streamingManager = StreamingServiceManager(
    analytics: AnalyticsService.instance,
    cache: CacheService.instance,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _streamingManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Streaming Dashboard',
          style: textStyles.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.subscriptions),
              text: 'Suscripciones',
            ),
            Tab(
              icon: Icon(Icons.explore),
              text: 'Descubrir',
            ),
            Tab(
              icon: Icon(Icons.trending_up),
              text: 'Tendencias',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SubscriptionsTab(),
          _DiscoverTab(),
          _TrendingTab(),
        ],
      ),
    );
  }
}

class _SubscriptionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SubscriptionSummaryCard(),
          const SizedBox(height: 24),
          _ActiveSubscriptionsList(),
          const SizedBox(height: 24),
          _AvailablePlatformsGrid(),
        ],
      ),
    );
  }
}

class _DiscoverTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PersonalizedRecommendations(),
          const SizedBox(height: 24),
          _PlatformHighlights(),
          const SizedBox(height: 24),
          _NewReleases(),
        ],
      ),
    );
  }
}

class _TrendingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrendingContent(),
          const SizedBox(height: 24),
          _PopularByPlatform(),
        ],
      ),
    );
  }
}

class _SubscriptionSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return FutureBuilder<SubscriptionSummary>(
      future: _getSubscriptionSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = snapshot.data ??
            SubscriptionSummary(
              userId: 'demo_user',
              subscriptions: [],
              totalMonthlySpend: 0.0,
              currency: 'USD',
              activeSubscriptions: 0,
              expiringSoon: 0,
              lastUpdated: DateTime.now(),
            );

        return FadeInUp(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resumen de Suscripciones',
                      style: textStyles.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.subscriptions,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        title: 'Activas',
                        value: '${summary.activeSubscriptions}',
                        subtitle: 'suscripciones',
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        title: 'Gasto Mensual',
                        value:
                            '\$${summary.totalMonthlySpend.toStringAsFixed(2)}',
                        subtitle: summary.currency,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<SubscriptionSummary> _getSubscriptionSummary() async {
    final subscriptionTracker = tracker.SubscriptionTracker();
    final subscriptions =
        await subscriptionTracker.getUserSubscriptions('user123');
    return SubscriptionSummary.fromSubscriptions(
      userId: 'user123',
      subscriptions: subscriptions,
      currency: 'USD',
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textStyles.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textStyles.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: textStyles.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ActiveSubscriptionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suscripciones Activas',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Subscription>>(
          future: _getActiveSubscriptions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final subscriptions = snapshot.data ?? [];

            if (subscriptions.isEmpty) {
              return const _EmptySubscriptionsCard();
            }

            return Column(
              children: subscriptions.asMap().entries.map((entry) {
                final index = entry.key;
                final subscription = entry.value;
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SubscriptionCard(subscription: subscription),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<List<Subscription>> _getActiveSubscriptions() async {
    final subscriptionTracker = tracker.SubscriptionTracker();
    // For demo purposes, using a mock user ID
    return await subscriptionTracker.getActiveSubscriptions('demo_user');
  }
}

class _EmptySubscriptionsCard extends StatelessWidget {
  const _EmptySubscriptionsCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.subscriptions_outlined,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes suscripciones activas',
            style: textStyles.titleMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explora las plataformas disponibles y encuentra tu contenido favorito',
            textAlign: TextAlign.center,
            style: textStyles.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getPlatformColor(subscription.platform.name),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _getPlatformInitial(subscription.platform.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subscription.platform.displayName,
                  style: textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${subscription.tier.displayName} • \$${subscription.monthlyPrice?.toStringAsFixed(2) ?? '0.00'}/${subscription.currency}',
                  style: textStyles.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (subscription.nextBillingDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Próximo pago: ${_formatDate(subscription.nextBillingDate!)}',
                    style: textStyles.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: subscription.isActive
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subscription.status.displayName,
              style: textStyles.bodySmall?.copyWith(
                color: subscription.isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon prime video':
        return const Color(0xFF00A8E1);
      case 'disney+':
        return const Color(0xFF113CCF);
      case 'hbo max':
        return const Color(0xFF7B2CBF);
      case 'hulu':
        return const Color(0xFF1CE783);
      case 'apple tv+':
        return const Color(0xFF000000);
      default:
        return Colors.grey;
    }
  }

  String _getPlatformInitial(String platform) {
    switch (platform.toLowerCase()) {
      case 'netflix':
        return 'N';
      case 'amazon prime video':
        return 'P';
      case 'disney+':
        return 'D';
      case 'hbo max':
        return 'H';
      case 'hulu':
        return 'U';
      case 'apple tv+':
        return 'A';
      default:
        return platform.isNotEmpty ? platform[0].toUpperCase() : '?';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Mañana';
    } else if (difference.inDays < 7) {
      return 'En ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _AvailablePlatformsGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plataformas Disponibles',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<StreamingPlatform>>(
          future: _getAvailablePlatforms(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final platforms = snapshot.data ?? [];

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: platforms.length,
              itemBuilder: (context, index) {
                final platform = platforms[index];
                return FadeInUp(
                  delay: Duration(milliseconds: 100 * index),
                  child: _PlatformTile(platform: platform),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<List<StreamingPlatform>> _getAvailablePlatforms() async {
    // Mock data - in real app, this would come from the streaming service
    return [
      const StreamingPlatform(
        id: 'netflix',
        name: 'Netflix',
        displayName: 'Netflix',
        logoUrl: '',
        baseUrl: 'https://netflix.com',
        deepLinkScheme: 'nflx',
        supportedCountries: ['US', 'CA', 'MX', 'ES', 'AR'],
        requiresSubscription: true,
      ),
      const StreamingPlatform(
        id: 'amazon_prime',
        name: 'Amazon Prime Video',
        displayName: 'Prime Video',
        logoUrl: '',
        baseUrl: 'https://primevideo.com',
        deepLinkScheme: 'aiv',
        supportedCountries: ['US', 'CA', 'MX', 'ES', 'AR'],
        requiresSubscription: true,
      ),
      const StreamingPlatform(
        id: 'disney_plus',
        name: 'Disney+',
        displayName: 'Disney+',
        logoUrl: '',
        baseUrl: 'https://disneyplus.com',
        deepLinkScheme: 'disneyplus',
        supportedCountries: ['US', 'CA', 'MX', 'ES', 'AR'],
        requiresSubscription: true,
      ),
      const StreamingPlatform(
        id: 'hbo_max',
        name: 'HBO Max',
        displayName: 'HBO Max',
        logoUrl: '',
        baseUrl: 'https://hbomax.com',
        deepLinkScheme: 'hbomax',
        supportedCountries: ['US', 'CA', 'MX', 'ES', 'AR'],
        requiresSubscription: true,
      ),
    ];
  }
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({required this.platform});

  final StreamingPlatform platform;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => _launchPlatform(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getPlatformColor(platform.id),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  _getPlatformInitial(platform.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                platform.displayName,
                style: textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _launchPlatform(BuildContext context) async {
    final deepLinkingService = DeepLinkingService();
    final success = await deepLinkingService.launchStreamingApp(
      platform: platform,
      movieId: '', // No specific movie ID for platform launch
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir ${platform.displayName}'),
          action: SnackBarAction(
            label: 'Instalar',
            onPressed: () => deepLinkingService.launchAppStore(platform),
          ),
        ),
      );
    }
  }

  Color _getPlatformColor(String platformId) {
    switch (platformId) {
      case 'netflix':
        return const Color(0xFFE50914);
      case 'amazon_prime':
        return const Color(0xFF00A8E1);
      case 'disney_plus':
        return const Color(0xFF113CCF);
      case 'hbo_max':
        return const Color(0xFF7B2CBF);
      default:
        return Colors.grey;
    }
  }

  String _getPlatformInitial(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'netflix':
        return 'N';
      case 'amazon prime video':
        return 'P';
      case 'disney+':
        return 'D';
      case 'hbo max':
        return 'H';
      default:
        return platformName.isNotEmpty ? platformName[0].toUpperCase() : '?';
    }
  }
}

// Placeholder widgets for other tabs
class _PersonalizedRecommendations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recomendaciones Personalizadas',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 200,
          child: Center(
            child: Text('Contenido de recomendaciones próximamente...'),
          ),
        ),
      ],
    );
  }
}

class _PlatformHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destacados por Plataforma',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 200,
          child: Center(
            child: Text('Destacados próximamente...'),
          ),
        ),
      ],
    );
  }
}

class _NewReleases extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nuevos Lanzamientos',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 200,
          child: Center(
            child: Text('Nuevos lanzamientos próximamente...'),
          ),
        ),
      ],
    );
  }
}

class _TrendingContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contenido en Tendencia',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 200,
          child: Center(
            child: Text('Contenido en tendencia próximamente...'),
          ),
        ),
      ],
    );
  }
}

class _PopularByPlatform extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular por Plataforma',
          style: textStyles.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 200,
          child: Center(
            child: Text('Contenido popular próximamente...'),
          ),
        ),
      ],
    );
  }
}
