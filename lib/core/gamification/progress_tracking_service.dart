import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/challenge_providers.dart';
import 'gamification_manager.dart';
import 'models/user_level.dart';
import 'models/activity_type.dart' as activity;

import 'models/user_progress.dart';

/// Service for tracking user progress in real-time
class ProgressTrackingService {
  ProgressTrackingService(this._gamificationManager);

  final GamificationManager _gamificationManager;
  final _progressController = StreamController<ProgressUpdate>.broadcast();
  final _milestoneController = StreamController<MilestoneReached>.broadcast();

  /// Stream of progress updates
  Stream<ProgressUpdate> get progressUpdates => _progressController.stream;

  /// Stream of milestone notifications
  Stream<MilestoneReached> get milestoneNotifications =>
      _milestoneController.stream;

  UserProgress? _lastProgress;
  UserLevel? _lastLevel;

  /// Initialize progress tracking
  Future<void> initialize() async {
    try {
      _lastProgress = await _gamificationManager.getUserProgress();
      final currentLevel = await _gamificationManager.getCurrentLevel();
      _lastLevel = currentLevel;

      developer.log('✅ Progress tracking initialized');
    } catch (e) {
      developer.log('❌ Error initializing progress tracking: $e');
    }
  }

  /// Track activity and emit progress updates
  Future<void> trackActivity(activity.ActivityType activityType,
      {Map<String, dynamic>? metadata}) async {
    try {
      // Track the activity
      await _gamificationManager.trackActivity(activityType,
          metadata: metadata);

      // Get updated progress
      final newProgress = await _gamificationManager.getUserProgress();
      final newLevel = await _gamificationManager.getCurrentLevel();

      // Check for progress changes
      if (_lastProgress != null) {
        _checkForProgressUpdates(_lastProgress!, newProgress);
      }

      // Check for level changes
      if (_lastLevel != null && newLevel.index > _lastLevel!.index) {
        _milestoneController.add(MilestoneReached(
          type: MilestoneType.levelUp,
          title: 'Level Up!',
          description: 'You reached level ${newLevel.name}',
          userLevel: newLevel,
          timestamp: DateTime.now(),
        ));
      }

      // Update cached values
      _lastProgress = newProgress;
      _lastLevel = newLevel;
    } catch (e) {
      developer.log('❌ Error tracking activity: $e');
    }
  }

  /// Check for progress updates and emit notifications
  void _checkForProgressUpdates(
      UserProgress oldProgress, UserProgress newProgress) {
    // Points increase
    if (newProgress.totalPoints > oldProgress.totalPoints) {
      final pointsGained = newProgress.totalPoints - oldProgress.totalPoints;
      _progressController.add(ProgressUpdate(
        type: ProgressUpdateType.pointsGained,
        title: '+$pointsGained Points',
        description: 'You earned $pointsGained points!',
        pointsGained: pointsGained,
        timestamp: DateTime.now(),
      ));
    }

    // Movies watched milestone
    _checkMilestone(
      oldProgress.moviesWatched,
      newProgress.moviesWatched,
      [5, 10, 25, 50, 100, 250, 500, 1000],
      'Movies Watched',
      'movies watched',
    );

    // Movies favorited milestone
    _checkMilestone(
      oldProgress.moviesFavorited,
      newProgress.moviesFavorited,
      [5, 10, 25, 50, 100, 200],
      'Movies Favorited',
      'movies favorited',
    );

    // Content shared milestone
    _checkMilestone(
      oldProgress.contentShared,
      newProgress.contentShared,
      [1, 5, 10, 25, 50, 100],
      'Content Shared',
      'items shared',
    );

    // Reviews written milestone
    _checkMilestone(
      oldProgress.reviewsWritten,
      newProgress.reviewsWritten,
      [1, 5, 10, 25, 50, 100],
      'Reviews Written',
      'reviews written',
    );

    // Watchlists completed milestone
    _checkMilestone(
      oldProgress.watchlistsCompleted,
      newProgress.watchlistsCompleted,
      [1, 5, 10, 25, 50],
      'Watchlists Completed',
      'watchlists completed',
    );
  }

  /// Check for milestone achievements
  void _checkMilestone(
    int oldValue,
    int newValue,
    List<int> milestones,
    String title,
    String description,
  ) {
    for (final milestone in milestones) {
      if (oldValue < milestone && newValue >= milestone) {
        _milestoneController.add(MilestoneReached(
          type: MilestoneType.milestone,
          title: '$title Milestone',
          description: 'You have $milestone $description!',
          milestone: milestone,
          timestamp: DateTime.now(),
        ));
        break; // Only emit the first milestone reached
      }
    }
  }

  /// Get current progress summary
  Future<ProgressSummary> getProgressSummary() async {
    final progress = await _gamificationManager.getUserProgress();
    final userLevel = await _gamificationManager.getCurrentLevel();
    final achievements = await _gamificationManager.getUserAchievements();

    return ProgressSummary(
      progress: progress,
      userLevel: userLevel,
      totalAchievements: achievements.length,
      completionPercentage: _calculateCompletionPercentage(progress),
    );
  }

  /// Calculate overall completion percentage
  double _calculateCompletionPercentage(UserProgress progress) {
    // Define target values for 100% completion
    const targets = {
      'moviesWatched': 1000,
      'moviesFavorited': 200,
      'contentShared': 100,
      'reviewsWritten': 100,
      'watchlistsCompleted': 50,
    };

    final scores = [
      (progress.moviesWatched / targets['moviesWatched']!).clamp(0.0, 1.0),
      (progress.moviesFavorited / targets['moviesFavorited']!).clamp(0.0, 1.0),
      (progress.contentShared / targets['contentShared']!).clamp(0.0, 1.0),
      (progress.reviewsWritten / targets['reviewsWritten']!).clamp(0.0, 1.0),
      (progress.watchlistsCompleted / targets['watchlistsCompleted']!)
          .clamp(0.0, 1.0),
    ];

    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
    _milestoneController.close();
  }
}

/// Progress update notification
class ProgressUpdate {
  const ProgressUpdate({
    required this.type,
    required this.title,
    required this.description,
    this.pointsGained,
    required this.timestamp,
  });

  final ProgressUpdateType type;
  final String title;
  final String description;
  final int? pointsGained;
  final DateTime timestamp;
}

/// Milestone reached notification
class MilestoneReached {
  const MilestoneReached({
    required this.type,
    required this.title,
    required this.description,
    this.userLevel,
    this.milestone,
    required this.timestamp,
  });

  final MilestoneType type;
  final String title;
  final String description;
  final UserLevel? userLevel;
  final int? milestone;
  final DateTime timestamp;
}

/// Progress summary
class ProgressSummary {
  const ProgressSummary({
    required this.progress,
    required this.userLevel,
    required this.totalAchievements,
    required this.completionPercentage,
  });

  final UserProgress progress;
  final UserLevel userLevel;
  final int totalAchievements;
  final double completionPercentage;
}

/// Types of progress updates
enum ProgressUpdateType {
  pointsGained,
  achievementUnlocked,
  streakExtended,
}

/// Types of milestones
enum MilestoneType {
  levelUp,
  milestone,
  achievement,
}

/// Provider for progress tracking service
final progressTrackingServiceProvider =
    Provider<ProgressTrackingService>((ref) {
  final gamificationManager = ref.watch(gamificationManagerProvider);
  return ProgressTrackingService(gamificationManager);
});

/// Provider for progress updates stream
final progressUpdatesProvider = StreamProvider<ProgressUpdate>((ref) {
  final service = ref.watch(progressTrackingServiceProvider);
  return service.progressUpdates;
});

/// Provider for milestone notifications stream
final milestoneNotificationsProvider = StreamProvider<MilestoneReached>((ref) {
  final service = ref.watch(progressTrackingServiceProvider);
  return service.milestoneNotifications;
});

/// Provider for progress summary
final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final service = ref.watch(progressTrackingServiceProvider);
  return service.getProgressSummary();
});
