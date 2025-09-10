import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/datasources/local_storage_datasource.dart';
import '../logging/logger_factory.dart';

/// Service to manage offline cache automatically
class OfflineCacheManager {
  OfflineCacheManager({
    required LocalStorageDatasource datasource,
  }) : _datasource = datasource;

  final LocalStorageDatasource _datasource;
  Timer? _cleanupTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  static const Duration _cleanupInterval = Duration(hours: 6);

  /// Initialize the cache manager
  Future<void> initialize() async {
    try {
      LoggerFactory.info('🔧 Initializing OfflineCacheManager...');

      // Start periodic cache cleanup
      _startPeriodicCleanup();

      // Monitor connectivity for sync opportunities
      _monitorConnectivity();

      // Initial cleanup
      await _performCleanup();

      LoggerFactory.info('✅ OfflineCacheManager initialized successfully');
    } catch (e) {
      LoggerFactory.error('❌ Error initializing OfflineCacheManager: $e');
    }
  }

  /// Start periodic cache cleanup
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) async {
      await _performCleanup();
    });
    LoggerFactory.info('⏰ Periodic cache cleanup started');
  }

  /// Monitor connectivity changes
  void _monitorConnectivity() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      final hasConnection = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.ethernet);

      if (hasConnection) {
        LoggerFactory.info('📶 Connectivity restored - cache sync opportunity');
        _onConnectivityRestored();
      } else {
        LoggerFactory.info('📵 Connectivity lost - entering offline mode');
      }
    });
  }

  /// Handle connectivity restoration
  void _onConnectivityRestored() {
    // This could trigger sync operations when connectivity is restored
    // For now, just log the opportunity
    LoggerFactory.info('🔄 Connectivity restored - sync operations available');
  }

  /// Perform cache cleanup
  Future<void> _performCleanup() async {
    try {
      LoggerFactory.info('🧹 Starting cache cleanup...');

      final initialSize = await _datasource.getCacheSize();
      LoggerFactory.info('📊 Cache size before cleanup: $initialSize items');

      // Clear expired cache entries
      await _datasource.clearExpiredCache();

      final finalSize = await _datasource.getCacheSize();
      final cleaned = initialSize - finalSize;

      LoggerFactory.info(
          '🧹 Cache cleanup completed: removed $cleaned expired items');
      LoggerFactory.info('📊 Cache size after cleanup: $finalSize items');
    } catch (e) {
      LoggerFactory.error('❌ Error during cache cleanup: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStats> getCacheStats() async {
    try {
      final cacheSize = await _datasource.getCacheSize();

      return CacheStats(
        totalItems: cacheSize,
        lastCleanup: DateTime.now(),
      );
    } catch (e) {
      LoggerFactory.error('❌ Error getting cache stats: $e');
      return CacheStats(
        totalItems: 0,
        lastCleanup: DateTime.now(),
      );
    }
  }

  /// Manually trigger cache cleanup
  Future<void> forceCleanup() async {
    await _performCleanup();
  }

  /// Clear all cache (for emergency situations)
  Future<void> clearAllCache() async {
    try {
      LoggerFactory.warning('🗑️ Clearing all cache data...');

      await _datasource.clearAllCache();

      LoggerFactory.info('🗑️ All cache cleared');
    } catch (e) {
      LoggerFactory.error('❌ Error clearing all cache: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _connectivitySubscription?.cancel();
    LoggerFactory.info('🔧 OfflineCacheManager disposed');
  }
}

/// Cache statistics data class
class CacheStats {
  const CacheStats({
    required this.totalItems,
    required this.lastCleanup,
  });

  final int totalItems;
  final DateTime lastCleanup;

  @override
  String toString() {
    return 'CacheStats(totalItems: $totalItems, lastCleanup: $lastCleanup)';
  }
}

/// Provider for OfflineCacheManager
final offlineCacheManagerProvider = Provider<OfflineCacheManager>((ref) {
  // This will need to be initialized with proper datasource
  throw UnimplementedError('OfflineCacheManager provider needs datasource');
});
