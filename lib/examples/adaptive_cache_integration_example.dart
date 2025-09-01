// Example integration of the adaptive image caching system
// This file demonstrates how to integrate and use the new adaptive caching features

import 'package:flutter/material.dart';
import 'package:peliculas/core/cache/image_cache_manager.dart';
import 'package:peliculas/core/cache/adaptive_cache_config.dart';
import 'package:peliculas/core/cache/network_aware_strategy.dart';
import 'package:peliculas/core/cache/image_cache_performance_metrics.dart';

/// Example of how to initialize the adaptive caching system
class AdaptiveCacheIntegrationExample {
  
  /// Initialize the adaptive caching system (typically in main.dart)
  static Future<void> initializeAdaptiveCache() async {
    print('🚀 Initializing adaptive image cache system...');
    
    try {
      // Initialize the entire adaptive caching system
      await ImageCacheManager.instance.initialize();
      
      print('✅ Adaptive cache system initialized successfully');
      
      // Log initial configuration
      final config = AdaptiveCacheConfig.instance.configuration;
      final capabilities = AdaptiveCacheConfig.instance.deviceCapabilities;
      
      print('📱 Device: ${capabilities.deviceType} (${capabilities.performanceTier})');
      print('💾 Memory cache: ${(config.memoryCacheSize / 1024 / 1024).toStringAsFixed(1)}MB');
      print('💿 Disk cache: ${(config.diskCacheSize / 1024 / 1024).toStringAsFixed(1)}MB');
      
    } catch (e) {
      print('❌ Failed to initialize adaptive cache: $e');
      // System will fall back to default configuration
    }
  }
  
  /// Example of monitoring performance (for admin/debug screens)
  static Future<void> showPerformanceReport() async {
    final report = ImageCacheManager.instance.generatePerformanceReport();
    print('\n📊 ADAPTIVE CACHE PERFORMANCE REPORT\n$report');
    
    // Get enhanced stats for detailed analysis
    final enhancedStats = await ImageCacheManager.instance.getEnhancedStats();
    print('\n🔍 Enhanced Stats: $enhancedStats');
    
    // Check performance assessment
    final assessment = ImageCachePerformanceMetrics.instance.assessPerformance();
    print('🏥 Health: ${assessment.healthStatus} (Score: ${assessment.score.toStringAsFixed(1)})');
    
    if (assessment.issues.isNotEmpty) {
      print('⚠️ Issues detected:');
      for (final issue in assessment.issues) {
        print('  - $issue');
      }
    }
  }
  
  /// Example of refreshing configuration when network changes
  static Future<void> onNetworkChanged() async {
    print('🌐 Network changed, refreshing adaptive configuration...');
    await ImageCacheManager.instance.refreshAdaptiveConfiguration();
    
    final networkStatus = NetworkAwareStrategy.instance.getNetworkStatus();
    print('📡 New network status: $networkStatus');
  }
  
  /// Example widget showing how to use cached images (no changes needed!)
  static Widget buildCachedImageExample(String imageUrl) {
    return CachedNetworkImageWidget(
      imageUrl: imageUrl,
      placeholder: const CircularProgressIndicator(),
      errorWidget: const Icon(Icons.error),
      fit: BoxFit.cover,
      width: 200,
      height: 300,
    );
  }
  
  /// Example of getting cache statistics for UI display
  static Future<Map<String, String>> getCacheStatsForUI() async {
    final stats = await ImageCacheManager.instance.getEnhancedStats();
    final performanceStats = stats.performanceStats;
    
    return {
      'Cache Hit Rate': '${(performanceStats.overallCacheHitRate * 100).toStringAsFixed(1)}%',
      'Average Load Time': '${performanceStats.averageLoadTime.inMilliseconds}ms',
      'Memory Usage': '${(stats.memoryCacheSize / 1024 / 1024).toStringAsFixed(1)}MB',
      'Network Condition': stats.networkCondition.toString().split('.').last,
      'Performance Score': '${stats.performanceAssessment.score.toStringAsFixed(0)}/100',
      'Device Tier': stats.deviceCapabilities.performanceTier.toString().split('.').last,
    };
  }
  
  /// Example of clearing cache when needed
  static Future<void> clearCacheExample() async {
    print('🧹 Clearing image cache...');
    await ImageCacheManager.instance.clearCache();
    print('✅ Cache cleared successfully');
  }
}

/// Example usage in main.dart
class MainAppExample extends StatelessWidget {
  const MainAppExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peliculas with Adaptive Cache',
      home: FutureBuilder<void>(
        future: AdaptiveCacheIntegrationExample.initializeAdaptiveCache(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing adaptive cache...'),
                  ],
                ),
              ),
            );
          }
          
          if (snapshot.hasError) {
            print('⚠️ Cache initialization error (using fallback): ${snapshot.error}');
          }
          
          return const HomeScreen();
        },
      ),
    );
  }
}

/// Example debug screen to monitor cache performance
class CacheDebugScreen extends StatefulWidget {
  const CacheDebugScreen({super.key});

  @override
  State<CacheDebugScreen> createState() => _CacheDebugScreenState();
}

class _CacheDebugScreenState extends State<CacheDebugScreen> {
  Map<String, String>? _cacheStats;
  
  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }
  
  Future<void> _loadCacheStats() async {
    final stats = await AdaptiveCacheIntegrationExample.getCacheStatsForUI();
    if (mounted) {
      setState(() {
        _cacheStats = stats;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCacheStats,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () async {
              await AdaptiveCacheIntegrationExample.clearCacheExample();
              _loadCacheStats();
            },
          ),
        ],
      ),
      body: _cacheStats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Adaptive Cache Statistics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._cacheStats!.entries.map((entry) => Card(
                  child: ListTile(
                    title: Text(entry.key),
                    trailing: Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    AdaptiveCacheIntegrationExample.showPerformanceReport();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Check console for detailed report')),
                    );
                  },
                  child: const Text('Generate Performance Report'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    await AdaptiveCacheIntegrationExample.onNetworkChanged();
                    _loadCacheStats();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Configuration refreshed')),
                      );
                    }
                  },
                  child: const Text('Refresh Network Config'),
                ),
              ],
            ),
    );
  }
}

/// Example home screen with cached images
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peliculas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CacheDebugScreen()),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 20,
        itemBuilder: (context, index) {
          final imageUrl = 'https://image.tmdb.org/t/p/w500/example_$index.jpg';
          
          return Card(
            clipBehavior: Clip.antiAlias,
            child: AdaptiveCacheIntegrationExample.buildCachedImageExample(imageUrl),
          );
        },
      ),
    );
  }
}

// Usage notes:
//
// 1. Initialize in main():
//    await AdaptiveCacheIntegrationExample.initializeAdaptiveCache();
//
// 2. Use CachedNetworkImageWidget as before (no changes needed)
//
// 3. Monitor performance with:
//    AdaptiveCacheIntegrationExample.showPerformanceReport();
//
// 4. Handle network changes:
//    AdaptiveCacheIntegrationExample.onNetworkChanged();
//
// 5. The system automatically adapts to:
//    - Device capabilities (memory, performance)
//    - Network conditions (speed, stability)
//    - Usage patterns (cache hits, load times)
//
// 6. No breaking changes to existing code!
//    All existing CachedNetworkImageWidget usage continues to work
//    with improved performance automatically.