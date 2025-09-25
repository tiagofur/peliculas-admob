import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:peliculas/domain/entities/achievement.dart';
import 'package:peliculas/domain/entities/achievement_progress.dart';
import 'package:peliculas/domain/entities/movie.dart';
import 'package:peliculas/domain/entities/user_achievements.dart';
import 'package:peliculas/domain/entities/watch_provider.dart';
import 'package:peliculas/domain/entities/watch_providers.dart';
import 'package:peliculas/domain/entities/watched_movie.dart';
import 'package:peliculas/domain/entities/watchlist_movie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test setup helper class for initializing services
class TestSetupHelper {
  static bool _hiveInitialized = false;
  static bool _supabaseInitialized = false;

  /// Initialize Hive for testing with all required type adapters
  static Future<void> initializeHive() async {
    if (_hiveInitialized) return;

    // Use in-memory directory for tests
    final directory = Directory.systemTemp.createTempSync();
    Hive.init(directory.path);

    // Register all type adapters needed by the app
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MovieAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WatchedMovieAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AchievementRarityAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(AchievementCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(WatchProviderAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(WatchProvidersAdapter());
    }
    if (!Hive.isAdapterRegistered(51)) {
      Hive.registerAdapter(AchievementAdapter());
    }
    if (!Hive.isAdapterRegistered(52)) {
      Hive.registerAdapter(AchievementTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(53)) {
      Hive.registerAdapter(UserAchievementsAdapter());
    }
    if (!Hive.isAdapterRegistered(54)) {
      Hive.registerAdapter(AchievementProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(55)) {
      Hive.registerAdapter(ProgressEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(WatchlistMovieAdapter());
    }
    if (!Hive.isAdapterRegistered(101)) {
      Hive.registerAdapter(WatchlistPriorityAdapter());
    }

    _hiveInitialized = true;
  }

  /// Initialize Supabase for testing (mock)
  static Future<void> initializeSupabase() async {
    if (_supabaseInitialized) return;

    try {
      await Supabase.initialize(
        url: 'https://mock-supabase-url.supabase.co',
        anonKey: 'mock-anon-key-for-testing-purposes-only-not-real',
        debug: false,
      );
      _supabaseInitialized = true;
    } catch (e) {
      // If already initialized, that's fine
      if (e.toString().contains('already initialized') ||
          e.toString().contains('_instance._isInitialized')) {
        _supabaseInitialized = true;
      } else {
        rethrow;
      }
    }
  }

  /// Force reinitialize Supabase (for tests that need fresh instance)
  static Future<void> forceInitializeSupabase() async {
    try {
      // Reset the flag and try to initialize
      _supabaseInitialized = false;
      await Supabase.initialize(
        url: 'https://mock-supabase-url.supabase.co',
        anonKey: 'mock-anon-key-for-testing-purposes-only-not-real',
        debug: false,
      );
      _supabaseInitialized = true;
    } catch (e) {
      // If already initialized, that's acceptable
      _supabaseInitialized = true;
    }
  }

  /// Initialize SharedPreferences for testing
  static void initializeSharedPreferences() {
    SharedPreferences.setMockInitialValues({});
  }

  /// Complete test setup - call this in setUp() method
  static Future<void> setupTest() async {
    // Initialize SharedPreferences first
    initializeSharedPreferences();

    // Initialize Hive with safe registration
    await initializeHiveOnce();

    // Initialize Supabase (force if needed)
    await forceInitializeSupabase();
  }

  /// Cleanup after tests
  static Future<void> tearDownTest() async {
    // Close all Hive boxes if needed
    try {
      await Hive.close();
    } catch (e) {
      // Ignore errors during cleanup
    }
    // Note: Don't reset initialization flags to prevent re-registration
  }

  /// Reset Hive initialization state (for testing purposes)
  static void resetHiveState() {
    _hiveInitialized = false;
  }

  /// Initialize Hive only once per test session
  static Future<void> initializeHiveOnce() async {
    if (_hiveInitialized) return;

    // Use in-memory directory for tests
    final directory = Directory.systemTemp.createTempSync();
    Hive.init(directory.path);

    // Register all type adapters needed by the app (only if not already registered)
    _registerAdapterSafely(0, () => MovieAdapter());
    _registerAdapterSafely(1, () => WatchedMovieAdapter());
    _registerAdapterSafely(2, () => AchievementRarityAdapter());
    _registerAdapterSafely(3, () => AchievementCategoryAdapter());
    _registerAdapterSafely(10, () => WatchProviderAdapter());
    _registerAdapterSafely(11, () => WatchProvidersAdapter());
    _registerAdapterSafely(51, () => AchievementAdapter());
    _registerAdapterSafely(52, () => AchievementTypeAdapter());
    _registerAdapterSafely(53, () => UserAchievementsAdapter());
    _registerAdapterSafely(54, () => AchievementProgressAdapter());
    _registerAdapterSafely(55, () => ProgressEntryAdapter());
    _registerAdapterSafely(100, () => WatchlistMovieAdapter());
    _registerAdapterSafely(101, () => WatchlistPriorityAdapter());

    _hiveInitialized = true;
  }

  /// Register adapter safely without throwing if already registered
  static void _registerAdapterSafely(
      int typeId, TypeAdapter Function() adapterFactory) {
    if (!Hive.isAdapterRegistered(typeId)) {
      Hive.registerAdapter(adapterFactory());
    }
  }

  /// Check if services are initialized
  static bool get isHiveInitialized => _hiveInitialized;
  static bool get isSupabaseInitialized => _supabaseInitialized;
}
