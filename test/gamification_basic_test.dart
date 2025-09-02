import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/core/gamification/gamification_manager.dart';
import 'package:peliculas/core/gamification/models/user_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Gamification Basic Tests', () {
    late GamificationManager gamificationManager;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      gamificationManager = GamificationManager();
      await gamificationManager.initialize();
    });

    test('should initialize with default user progress', () async {
      final userProgress = await gamificationManager.getUserProgress();
      
      expect(userProgress.totalPoints, equals(0));
      expect(userProgress.streakDays, equals(0));
      expect(userProgress.moviesWatched, equals(0));
      expect(userProgress.moviesFavorited, equals(0));
    });

    test('should track first movie favorite and unlock achievement', () async {
      // Track first movie favorite
      await gamificationManager.trackMovieAddedToFavorites('movie1', 'Action');
      
      final userProgress = await gamificationManager.getUserProgress();
      final achievements = gamificationManager.getUnlockedAchievements();
      
      // Check progress update
      expect(userProgress.totalPoints, greaterThan(0));
      expect(userProgress.moviesFavorited, equals(1));
      expect(userProgress.streakDays, equals(1)); // Should start streak
      
      // Check first movie achievement
      final firstMovieAchievement = achievements.firstWhere(
        (a) => a.id == 'first_movie',
        orElse: () => throw StateError('First movie achievement not found'),
      );
      expect(firstMovieAchievement.isUnlocked, isTrue);
    });

    test('should track movie sharing and unlock achievement', () async {
      // Track first movie share
      await gamificationManager.trackMovieShared('movie1');
      
      final userProgress = await gamificationManager.getUserProgress();
      final achievements = gamificationManager.getUnlockedAchievements();
      
      // Check progress update
      expect(userProgress.totalPoints, greaterThan(0));
      expect(userProgress.moviesShared, equals(1));
      
      // Check first share achievement
      final firstShareAchievement = achievements.firstWhere(
        (a) => a.id == 'first_share',
        orElse: () => throw StateError('First share achievement not found'),
      );
      expect(firstShareAchievement.isUnlocked, isTrue);
    });

    test('should track review writing and unlock achievement', () async {
      // Track first review
      await gamificationManager.trackReviewWritten('movie1', 4.5);
      
      final userProgress = await gamificationManager.getUserProgress();
      final achievements = gamificationManager.getUnlockedAchievements();
      
      // Check progress update
      expect(userProgress.totalPoints, greaterThan(0));
      expect(userProgress.reviewsWritten, equals(1));
      
      // Check first review achievement
      final firstReviewAchievement = achievements.firstWhere(
        (a) => a.id == 'first_review',
        orElse: () => throw StateError('First review achievement not found'),
      );
      expect(firstReviewAchievement.isUnlocked, isTrue);
    });

    test('should unlock collector achievement at 5 movies', () async {
      // Add 5 movies to favorites
      for (int i = 1; i <= 5; i++) {
        await gamificationManager.trackMovieAddedToFavorites('movie$i', 'Action');
      }
      
      final achievements = gamificationManager.getUnlockedAchievements();
      
      // Check collector achievement
      final collectorAchievement = achievements.firstWhere(
        (a) => a.id == 'movie_collector',
        orElse: () => throw StateError('Collector achievement not found'),
      );
      expect(collectorAchievement.isUnlocked, isTrue);
    });

    test('should handle daily streak correctly', () async {
      // First activity
      await gamificationManager.trackMovieAddedToFavorites('movie1', 'Action');
      var userProgress = await gamificationManager.getUserProgress();
      expect(userProgress.streakDays, equals(1));
      
      // Same day activity should not increase streak
      await gamificationManager.trackMovieShared('movie1');
      userProgress = await gamificationManager.getUserProgress();
      expect(userProgress.streakDays, equals(1));
    });

    test('should get recent achievements', () async {
      // Unlock some achievements
      await gamificationManager.trackMovieAddedToFavorites('movie1', 'Action');
      await gamificationManager.trackMovieShared('movie1');
      
      final recentAchievements = await gamificationManager.getRecentAchievements(limit: 2);
      
      expect(recentAchievements.length, greaterThan(0));
      expect(recentAchievements.length, lessThanOrEqualTo(2));
      
      // Should be sorted by unlock date (most recent first)
      if (recentAchievements.length > 1) {
        expect(
          recentAchievements[0].unlockedAt!.isAfter(recentAchievements[1].unlockedAt!) ||
          recentAchievements[0].unlockedAt!.isAtSameMomentAs(recentAchievements[1].unlockedAt!),
          isTrue,
        );
      }
    });

    test('should save and load progress correctly', () async {
      // Track some activities
      await gamificationManager.trackMovieAddedToFavorites('movie1', 'Action');
      await gamificationManager.trackMovieShared('movie1');
      
      final originalProgress = await gamificationManager.getUserProgress();
      final originalAchievements = gamificationManager.getUnlockedAchievements();
      
      // Create new manager instance and initialize
      final newManager = GamificationManager();
      await newManager.initialize();
      
      final loadedProgress = await newManager.getUserProgress();
      final loadedAchievements = newManager.getUnlockedAchievements();
      
      // Check that data was persisted
      expect(loadedProgress.totalPoints, equals(originalProgress.totalPoints));
      expect(loadedProgress.moviesFavorited, equals(originalProgress.moviesFavorited));
      expect(loadedProgress.moviesShared, equals(originalProgress.moviesShared));
      expect(loadedAchievements.length, equals(originalAchievements.length));
    });
  });
}