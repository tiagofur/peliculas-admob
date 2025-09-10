import 'package:flutter/material.dart';
import '../../../domain/entities/streaming_availability.dart';
import '../../../domain/entities/streaming_platform.dart';


import 'streaming_action_button.dart';

/// Dialog that shows all streaming options for a movie
class StreamingOptionsDialog extends StatefulWidget {
  const StreamingOptionsDialog({
    super.key,
    required this.movieTitle,
    required this.platforms,
    this.onPlatformSelected,
  });

  final String movieTitle;
  final List<PlatformAvailability> platforms;
  final Function(StreamingPlatform, PlatformAvailability)? onPlatformSelected;

  @override
  State<StreamingOptionsDialog> createState() => _StreamingOptionsDialogState();
}

class _StreamingOptionsDialogState extends State<StreamingOptionsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PlatformAvailability> _freePlatforms = [];
  List<PlatformAvailability> _subscriptionPlatforms = [];
  List<PlatformAvailability> _rentalPlatforms = [];
  List<PlatformAvailability> _unavailablePlatforms = [];

  @override
  void initState() {
    super.initState();
    _categorizeplatforms();
    _tabController = TabController(
      length: _getTabCount(),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _categorizeplatforms() {
    _freePlatforms = widget.platforms
        .where((p) => p.isAvailable && p.isFree)
        .toList();
    
    _subscriptionPlatforms = widget.platforms
        .where((p) => p.isAvailable && p.requiresSubscription && !p.isFree)
        .toList();
    
    _rentalPlatforms = widget.platforms
        .where((p) => p.isAvailable && !p.requiresSubscription && !p.isFree)
        .toList();
    
    _unavailablePlatforms = widget.platforms
        .where((p) => !p.isAvailable)
        .toList();
  }

  int _getTabCount() {
    int count = 0;
    if (_freePlatforms.isNotEmpty) count++;
    if (_subscriptionPlatforms.isNotEmpty) count++;
    if (_rentalPlatforms.isNotEmpty) count++;
    if (_unavailablePlatforms.isNotEmpty) count++;
    return count.clamp(1, 4);
  }

  List<Tab> _buildTabs() {
    List<Tab> tabs = [];
    
    if (_freePlatforms.isNotEmpty) {
      tabs.add(Tab(
        icon: const Icon(Icons.free_breakfast),
        text: 'Free (${_freePlatforms.length})',
      ));
    }
    
    if (_subscriptionPlatforms.isNotEmpty) {
      tabs.add(Tab(
        icon: const Icon(Icons.subscriptions),
        text: 'Subscription (${_subscriptionPlatforms.length})',
      ));
    }
    
    if (_rentalPlatforms.isNotEmpty) {
      tabs.add(Tab(
        icon: const Icon(Icons.payment),
        text: 'Rental (${_rentalPlatforms.length})',
      ));
    }
    
    if (_unavailablePlatforms.isNotEmpty) {
      tabs.add(Tab(
        icon: const Icon(Icons.block),
        text: 'Unavailable (${_unavailablePlatforms.length})',
      ));
    }
    
    return tabs;
  }

  List<Widget> _buildTabViews() {
    List<Widget> views = [];
    
    if (_freePlatforms.isNotEmpty) {
      views.add(_buildPlatformList(_freePlatforms, true));
    }
    
    if (_subscriptionPlatforms.isNotEmpty) {
      views.add(_buildPlatformList(_subscriptionPlatforms, true));
    }
    
    if (_rentalPlatforms.isNotEmpty) {
      views.add(_buildPlatformList(_rentalPlatforms, true));
    }
    
    if (_unavailablePlatforms.isNotEmpty) {
      views.add(_buildPlatformList(_unavailablePlatforms, false));
    }
    
    return views;
  }

  Widget _buildPlatformList(List<PlatformAvailability> platforms, bool isAvailable) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: platforms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final platform = platforms[index];
        return _buildPlatformTile(platform, isAvailable);
      },
    );
  }

  Widget _buildPlatformTile(PlatformAvailability platform, bool isAvailable) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: _buildPlatformIcon(platform.platform),
        title: Text(
          platform.platform.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildAvailabilityInfo(platform),

          ],
        ),
        trailing: isAvailable
            ? StreamingActionButton(
                platform: platform.platform,
                availability: platform,
                movieTitle: widget.movieTitle,
                style: StreamingButtonStyle.primary,
                size: StreamingButtonSize.small,
                onPressed: () => _handlePlatformSelection(platform),
              )
            : Icon(
                Icons.block,
                color: Colors.grey[400],
              ),
      ),
    );
  }

  Widget _buildPlatformIcon(StreamingPlatform platform) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      ),
      child: Icon(
        Icons.play_circle_outline,
        color: Theme.of(context).primaryColor,
        size: 24,
      ),
    );
  }

  Widget _buildAvailabilityInfo(PlatformAvailability platform) {
    if (!platform.isAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Not Available',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    List<Widget> badges = [];

    if (platform.isFree) {
      badges.add(_buildBadge('Free', Colors.green));
    }

    if (platform.requiresSubscription) {
      badges.add(_buildBadge('Subscription', Colors.blue));
    }

    if (platform.formattedRentalPrice != null) {
      badges.add(_buildBadge(platform.formattedRentalPrice!, Colors.orange));
    }

    if (platform.formattedPurchasePrice != null) {
      badges.add(_buildBadge('Buy ${platform.formattedPurchasePrice}', Colors.purple));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges,
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }



  void _handlePlatformSelection(PlatformAvailability platform) {
    if (widget.onPlatformSelected != null) {
      widget.onPlatformSelected!(platform.platform, platform);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streaming Options',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.movieTitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Tabs
            if (_getTabCount() > 1)
              TabBar(
                controller: _tabController,
                tabs: _buildTabs(),
                isScrollable: true,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
              ),
            // Content
            Expanded(
              child: _getTabCount() > 1
                  ? TabBarView(
                      controller: _tabController,
                      children: _buildTabViews(),
                    )
                  : _buildTabViews().first,
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the streaming options dialog
Future<void> showStreamingOptionsDialog({
  required BuildContext context,
  required String movieTitle,
  required List<PlatformAvailability> platforms,
  Function(StreamingPlatform, PlatformAvailability)? onPlatformSelected,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => StreamingOptionsDialog(
      movieTitle: movieTitle,
      platforms: platforms,
      onPlatformSelected: onPlatformSelected,
    ),
  );
}