import 'package:flutter/material.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/streaming/streaming_service_manager.dart';
import '../../../domain/entities/user_subscription.dart';

/// Widget to display content recommendations based on user subscriptions
class ContentRecommendationsWidget extends StatefulWidget {
  const ContentRecommendationsWidget({
    super.key,
    required this.subscriptions,
    required this.streamingManager,
    this.onContentTap,
    this.padding,
  });
  final List<UserSubscription> subscriptions;
  final StreamingServiceManager streamingManager;
  final VoidCallback? onContentTap;
  final EdgeInsetsGeometry? padding;

  @override
  State<ContentRecommendationsWidget> createState() =>
      _ContentRecommendationsWidgetState();
}

class _ContentRecommendationsWidgetState
    extends State<ContentRecommendationsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AnalyticsService _analytics = AnalyticsService();
  final _logger = LoggerFactory.getLogger('ContentRecommendationsWidget');

  List<ContentRecommendation> _recommendations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecommendations();
    _analytics.trackEvent('content_recommendations_viewed');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final recommendations = await _generateRecommendations();

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });

      _analytics.trackEvent('recommendations_loaded', {
        'count': recommendations.length,
        'subscription_count': widget.subscriptions.length,
      });
    } catch (e) {
      _logger.error('Error loading recommendations: $e');
      setState(() {
        _error = 'Failed to load recommendations';
        _isLoading = false;
      });
    }
  }

  Future<List<ContentRecommendation>> _generateRecommendations() async {
    final recommendations = <ContentRecommendation>[];
    final activeSubs =
        widget.subscriptions.where((sub) => sub.isActive).toList();

    if (activeSubs.isEmpty) {
      return _getDefaultRecommendations();
    }

    // Generate recommendations for each platform
    for (final subscription in activeSubs) {
      final platformRecommendations = await _getRecommendationsForPlatform(
        subscription.platformName,
      );
      recommendations.addAll(platformRecommendations);
    }

    // Sort by relevance score
    recommendations
        .sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return recommendations.take(20).toList();
  }

  Future<List<ContentRecommendation>> _getRecommendationsForPlatform(
    String platformName,
  ) async {
    // Simulate API call to get platform-specific content
    await Future.delayed(const Duration(milliseconds: 100));

    final recommendations = <ContentRecommendation>[];
    final content = _getMockContentForPlatform(platformName);

    for (final item in content) {
      recommendations.add(ContentRecommendation(
        title: item['title']!,
        description: item['description']!,
        imageUrl: item['imageUrl']!,
        platform: platformName,
        type: item['type']! as ContentType,
        genre: item['genre']!,
        rating: item['rating']! as double,
        releaseYear: item['releaseYear']! as int,
        relevanceScore: item['relevanceScore']! as double,
        isNew: item['isNew']! as bool,
        isTrending: item['isTrending']! as bool,
      ));
    }

    return recommendations;
  }

  List<Map<String, dynamic>> _getMockContentForPlatform(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'netflix':
        return [
          {
            'title': 'Stranger Things 5',
            'description': 'The final season of the hit sci-fi series',
            'imageUrl':
                'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=stranger%20things%20poster%20dark%20supernatural&image_size=portrait_4_3',
            'type': ContentType.series,
            'genre': 'Sci-Fi',
            'rating': 8.9,
            'releaseYear': 2024,
            'relevanceScore': 0.95,
            'isNew': true,
            'isTrending': true,
          },
          {
            'title': 'The Crown: Final Season',
            'description': 'The conclusion of the royal drama',
            'imageUrl':
                'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=the%20crown%20royal%20drama%20poster&image_size=portrait_4_3',
            'type': ContentType.series,
            'genre': 'Drama',
            'rating': 8.7,
            'releaseYear': 2024,
            'relevanceScore': 0.88,
            'isNew': true,
            'isTrending': false,
          },
        ];
      case 'amazon prime video':
      case 'prime video':
        return [
          {
            'title': 'The Boys: Season 4',
            'description': 'Superhero satire continues',
            'imageUrl':
                'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=the%20boys%20superhero%20dark%20poster&image_size=portrait_4_3',
            'type': ContentType.series,
            'genre': 'Action',
            'rating': 8.8,
            'releaseYear': 2024,
            'relevanceScore': 0.92,
            'isNew': true,
            'isTrending': true,
          },
          {
            'title': 'Rings of Power: Season 2',
            'description': 'Middle-earth epic continues',
            'imageUrl':
                'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=lord%20of%20the%20rings%20fantasy%20epic%20poster&image_size=portrait_4_3',
            'type': ContentType.series,
            'genre': 'Fantasy',
            'rating': 8.5,
            'releaseYear': 2024,
            'relevanceScore': 0.85,
            'isNew': true,
            'isTrending': false,
          },
        ];
      case 'disney+':
      case 'disney plus':
        return [
          {
            'title': 'The Mandalorian: Season 4',
            'description': 'This is the way continues',
            'imageUrl':
                'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=mandalorian%20star%20wars%20poster&image_size=portrait_4_3',
            'type': ContentType.series,
            'genre': 'Sci-Fi',
            'rating': 8.9,
            'releaseYear': 2024,
            'relevanceScore': 0.93,
            'isNew': true,
            'isTrending': true,
          },
          {
            'title': 'Loki: Season 3',
            'description': 'God of Mischief returns',
            'imageUrl':
                'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=loki%20marvel%20god%20mischief%20poster&image_size=portrait_4_3',
            'type': ContentType.series,
            'genre': 'Action',
            'rating': 8.6,
            'releaseYear': 2024,
            'relevanceScore': 0.87,
            'isNew': false,
            'isTrending': true,
          },
        ];
      default:
        return [];
    }
  }

  List<ContentRecommendation> _getDefaultRecommendations() {
    return [
      const ContentRecommendation(
        title: 'Popular Movies This Week',
        description: 'Trending movies across all platforms',
        imageUrl:
            'https://trae-api-us.mchost.guru/api/ide/v1/text_to_image?prompt=popular%20movies%20cinema%20poster&image_size=portrait_4_3',
        platform: 'Multiple',
        type: ContentType.movie,
        genre: 'Various',
        rating: 8.0,
        releaseYear: 2024,
        relevanceScore: 0.8,
        isNew: false,
        isTrending: true,
      ),
    ];
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
          if (_isLoading)
            _buildLoadingState()
          else if (_error != null)
            _buildErrorState()
          else if (_recommendations.isEmpty)
            _buildEmptyState()
          else
            _buildContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recommended for You',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        IconButton(
          onPressed: _loadRecommendations,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh recommendations',
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading recommendations...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              onPressed: _loadRecommendations,
              child: const Text('Retry'),
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
              Icons.movie_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Recommendations Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add streaming subscriptions to get personalized content recommendations',
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

  Widget _buildContent() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'New'),
            Tab(text: 'Trending'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecommendationsList(_recommendations),
              _buildRecommendationsList(
                _recommendations.where((r) => r.isNew).toList(),
              ),
              _buildRecommendationsList(
                _recommendations.where((r) => r.isTrending).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsList(
      List<ContentRecommendation> recommendations) {
    if (recommendations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No content available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final recommendation = recommendations[index];
        return _buildRecommendationCard(recommendation);
      },
    );
  }

  Widget _buildRecommendationCard(ContentRecommendation recommendation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _analytics.trackEvent('recommendation_tapped', {
            'title': recommendation.title,
            'platform': recommendation.platform,
            'type': recommendation.type.name,
          });
          widget.onContentTap?.call();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recommendation.imageUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 120,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.movie,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recommendation.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (recommendation.isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recommendation.rating.toStringAsFixed(1),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          recommendation.releaseYear.toString(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          recommendation.genre,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _getPlatformIcon(recommendation.platform),
                          size: 16,
                          color: _getPlatformColor(recommendation.platform),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recommendation.platform,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    _getPlatformColor(recommendation.platform),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        if (recommendation.isTrending) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.trending_up,
                            size: 16,
                            color: Colors.red[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Trending',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.red[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ],
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
      default:
        return Icons.play_circle_outline;
    }
  }
}

/// Data class for content recommendations
class ContentRecommendation {
  const ContentRecommendation({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.platform,
    required this.type,
    required this.genre,
    required this.rating,
    required this.releaseYear,
    required this.relevanceScore,
    required this.isNew,
    required this.isTrending,
  });
  final String title;
  final String description;
  final String imageUrl;
  final String platform;
  final ContentType type;
  final String genre;
  final double rating;
  final int releaseYear;
  final double relevanceScore;
  final bool isNew;
  final bool isTrending;
}

/// Content type enumeration
enum ContentType {
  movie,
  series,
  documentary,
  special,
}
