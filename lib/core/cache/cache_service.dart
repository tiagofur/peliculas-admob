import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling application caching
class CacheService {
  CacheService._();
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  SharedPreferences? _prefs;

  /// Initialize the cache service
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Store a value in cache with optional expiration
  Future<bool> set(String key, dynamic value, {Duration? expiration}) async {
    await initialize();

    final cacheData = {
      'value': value,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiration': expiration?.inMilliseconds,
    };

    return await (_prefs?.setString(key, jsonEncode(cacheData)) ??
        Future.value(false));
  }

  /// Get a value from cache
  Future<T?> get<T>(String key) async {
    await initialize();

    final cachedString = _prefs?.getString(key);
    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiration = cacheData['expiration'] as int?;

      // Check if cache has expired
      if (expiration != null) {
        final expirationTime = timestamp + expiration;
        if (DateTime.now().millisecondsSinceEpoch > expirationTime) {
          await remove(key);
          return null;
        }
      }

      return cacheData['value'] as T?;
    } catch (e) {
      // If parsing fails, remove the corrupted cache entry
      await remove(key);
      return null;
    }
  }

  /// Remove a value from cache
  Future<bool> remove(String key) async {
    await initialize();
    return await (_prefs?.remove(key) ?? Future.value(false));
  }

  /// Clear all cache
  Future<bool> clear() async {
    await initialize();
    return await (_prefs?.clear() ?? Future.value(false));
  }

  /// Check if a key exists in cache
  Future<bool> containsKey(String key) async {
    await initialize();
    return _prefs?.containsKey(key) ?? false;
  }

  /// Get all cache keys
  Future<Set<String>> getAllKeys() async {
    await initialize();
    return _prefs?.getKeys() ?? <String>{};
  }

  /// Clear expired cache entries
  Future<void> clearExpired() async {
    await initialize();

    final keys = await getAllKeys();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final key in keys) {
      final cachedString = _prefs?.getString(key);
      if (cachedString == null) continue;

      try {
        final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
        final timestamp = cacheData['timestamp'] as int;
        final expiration = cacheData['expiration'] as int?;

        if (expiration != null) {
          final expirationTime = timestamp + expiration;
          if (now > expirationTime) {
            await remove(key);
          }
        }
      } catch (e) {
        // Remove corrupted entries
        await remove(key);
      }
    }
  }

  /// Get cache size (approximate)
  Future<int> getCacheSize() async {
    await initialize();

    final keys = await getAllKeys();
    int totalSize = 0;

    for (final key in keys) {
      final value = _prefs?.getString(key);
      if (value != null) {
        totalSize += value.length;
      }
    }

    return totalSize;
  }
}

/// Cache configuration
class CacheConfig {
  static const Duration defaultExpiration = Duration(hours: 24);
  static const Duration shortExpiration = Duration(minutes: 30);
  static const Duration longExpiration = Duration(days: 7);

  // Cache keys
  static const String movieDetails = 'movie_details_';
  static const String movieRecommendations = 'movie_recommendations_';
  static const String userPreferences = 'user_preferences';
  static const String genreList = 'genre_list';
  static const String popularMovies = 'popular_movies';
  static const String trendingMovies = 'trending_movies';
  static const String searchResults = 'search_results_';
}
