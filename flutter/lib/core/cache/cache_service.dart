import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Testing seam: drop the cached instance so tests can swap mock values.
  @visibleForTesting
  void debugResetForTesting() {
    _prefs = null;
  }

  /// Reads a string key without throwing on non-String value types
  /// (bool/int/double/list keys coexist in the shared store).
  String? _readString(SharedPreferences prefs, String key) {
    try {
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
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

    final prefs = _prefs;
    if (prefs == null) return null;
    final cachedString = _readString(prefs, key);
    if (cachedString == null) return null;

    if (!_isCacheEnvelope(cachedString)) {
      // Not our entry (foreign key or corrupted data): never delete it.
      return null;
    }
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
      return null;
    }
  }

  /// Remove a value from cache
  Future<bool> remove(String key) async {
    await initialize();
    return await (_prefs?.remove(key) ?? Future.value(false));
  }

  /// Cache envelope written by [set]: {value, timestamp, expiration}.
  /// Anything else in SharedPreferences belongs to someone else and must
  /// never be touched (auth tokens, settings, sync queues...).
  bool _isCacheEnvelope(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded['timestamp'] is int &&
          decoded.containsKey('value') &&
          decoded.containsKey('expiration');
    } catch (_) {
      return false;
    }
  }

  /// Clear all cache entries. Scoped to our own envelope keys: SharedPreferences
  /// is a shared store, so a blanket `clear()` would wipe other features' data.
  Future<bool> clear() async {
    await initialize();
    final prefs = _prefs;
    if (prefs == null) return false;
    for (final key in prefs.getKeys().toList()) {
      final raw = _readString(prefs, key);
      if (raw != null && _isCacheEnvelope(raw)) {
        await prefs.remove(key);
      }
    }
    return true;
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
      final prefs = _prefs;
      if (prefs == null) continue;
      final cachedString = _readString(prefs, key);
      // Skip foreign keys and anything that is not our envelope:
      // deleting what we cannot parse is how sync queues got wiped.
      if (cachedString == null || !_isCacheEnvelope(cachedString)) continue;

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
        // Envelope shape changed mid-flight: leave it, never delete blindly.
      }
    }
  }

  /// Get cache size (approximate)
  Future<int> getCacheSize() async {
    await initialize();

    final keys = await getAllKeys();
    int totalSize = 0;

    final prefs = _prefs;
    if (prefs == null) return 0;
    for (final key in keys) {
      final value = _readString(prefs, key);
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
