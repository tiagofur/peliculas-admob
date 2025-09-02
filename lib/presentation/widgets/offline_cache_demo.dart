import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/offline_cache_manager.dart';
import '../../domain/entities/movie.dart';
import '../../domain/repositories/movies_repository.dart';
import '../providers/movies/cached_movies_repository_provider.dart';

/// Demo widget to test offline cache functionality
class OfflineCacheDemo extends ConsumerStatefulWidget {
  const OfflineCacheDemo({super.key});

  @override
  ConsumerState<OfflineCacheDemo> createState() => _OfflineCacheDemoState();
}

class _OfflineCacheDemoState extends ConsumerState<OfflineCacheDemo> {
  List<Movie> _cachedMovies = [];
  bool _isLoading = false;
  String _statusMessage = '';
  CacheStats? _cacheStats;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    try {
      final cacheManager = ref.read(offlineCacheManagerProvider);
      final stats = await cacheManager.getCacheStats();
      setState(() {
        _cacheStats = stats;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading cache stats: $e';
      });
    }
  }

  Future<void> _testOfflineCache() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Testing offline cache...';
    });

    try {
      final repository = ref.read(cachedMovieRepositoryProvider);
      
      // Test fetching popular movies (will cache them)
      final movies = await repository.getPopular(page: 1);
      
      setState(() {
        _cachedMovies = movies.take(5).toList(); // Show first 5 movies
        _statusMessage = 'Successfully cached ${movies.length} movies!';
      });

      // Update cache stats
      await _loadCacheStats();
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing cache...';
    });

    try {
      final cacheManager = ref.read(offlineCacheManagerProvider);
      await cacheManager.clearAllCache();
      
      setState(() {
        _cachedMovies = [];
        _statusMessage = 'Cache cleared successfully!';
      });

      // Update cache stats
      await _loadCacheStats();
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error clearing cache: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceCleanup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Performing cache cleanup...';
    });

    try {
      final cacheManager = ref.read(offlineCacheManagerProvider);
      await cacheManager.forceCleanup();
      
      setState(() {
        _statusMessage = 'Cache cleanup completed!';
      });

      // Update cache stats
      await _loadCacheStats();
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during cleanup: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Cache Demo'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cache Stats Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cache Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_cacheStats != null) ...[
                      Text('Total Items: ${_cacheStats!.totalItems}'),
                      Text('Last Cleanup: ${_cacheStats!.lastCleanup}'),
                    ] else
                      const Text('Loading cache stats...'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testOfflineCache,
                  child: const Text('Test Cache'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _forceCleanup,
                  child: const Text('Cleanup'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _clearCache,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Clear All'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status Message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage.isEmpty ? 'Ready to test offline cache' : _statusMessage,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Loading Indicator
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            
            // Cached Movies List
            if (_cachedMovies.isNotEmpty) ...[
              const Text(
                'Cached Movies:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _cachedMovies.length,
                  itemBuilder: (context, index) {
                    final movie = _cachedMovies[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.movie,
                          color: Theme.of(context).primaryColor,
                        ),
                        title: Text(movie.title),
                        subtitle: Text(
                          'Rating: ${movie.voteAverage}/10 • ID: ${movie.id}',
                        ),
                        trailing: const Icon(Icons.offline_bolt),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCacheStats,
        child: const Icon(Icons.refresh),
        tooltip: 'Refresh Stats',
      ),
    );
  }
}

/// Instructions widget for offline cache demo
class OfflineCacheInstructions extends StatelessWidget {
  const OfflineCacheInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Cache - How to Test'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to Test Offline Cache',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Online Testing',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('• Connect to internet'),
                      Text('• Navigate through movie categories (Popular, Top Rated, etc.)'),
                      Text('• Movies will be automatically cached for offline use'),
                      Text('• Check cache stats to see cached items count'),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Offline Testing',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('• Disconnect from internet (turn off WiFi/mobile data)'),
                      Text('• Navigate through the app'),
                      Text('• Previously cached movies should still be visible'),
                      Text('• Search and details will work for cached movies'),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3. Cache Features',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('• Automatic 7-day expiration'),
                      Text('• Size limits: 1000 movies (mobile), 500 movies (web)'),
                      Text('• Memory + persistent caching'),
                      Text('• Automatic cleanup of expired items'),
                      Text('• Platform-specific storage (Hive/SharedPreferences)'),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Cache Indicators',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('Look for these log messages:'),
                      Text('📱 "Retrieved from memory cache" - Fast memory access'),
                      Text('📱 "Retrieved from offline cache" - Persistent cache hit'),
                      Text('🌐 "Fetching from network" - Network request'),
                      Text('📱 "No connectivity" - Offline mode activated'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}