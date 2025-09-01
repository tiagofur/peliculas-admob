import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gamification/challenge_notifications.dart';
import '../../core/gamification/challenge_system.dart';
import '../../core/gamification/challenge_tracker.dart';
import '../../core/gamification/gamification_manager.dart';

/// Provider for the ChallengeSystem singleton
final challengeSystemProvider = Provider<ChallengeSystem>((ref) {
  return ChallengeSystem.instance;
});

/// Provider for the ChallengeTracker singleton
final challengeTrackerProvider = Provider<ChallengeTracker>((ref) {
  return ChallengeTracker.instance;
});

/// Provider for the ChallengeNotificationService singleton
final challengeNotificationServiceProvider =
    Provider<ChallengeNotificationService>((ref) {
  return ChallengeNotificationService.instance;
});

/// Provider for the GamificationManager singleton
final gamificationManagerProvider = Provider<GamificationManager>((ref) {
  return GamificationManager.instance;
});

/// StateNotifier provider for active challenges
final activeChallengesProvider =
    StateNotifierProvider<ActiveChallengesNotifier, List<Challenge>>((ref) {
  final challengeSystem = ref.watch(challengeSystemProvider);
  return ActiveChallengesNotifier(challengeSystem);
});

/// StateNotifier provider for completed challenges
final completedChallengesProvider =
    StateNotifierProvider<CompletedChallengesNotifier, List<Challenge>>((ref) {
  final challengeSystem = ref.watch(challengeSystemProvider);
  return CompletedChallengesNotifier(challengeSystem);
});

/// StateNotifier provider for challenge notifications
final challengeNotificationsProvider = StateNotifierProvider<
    ChallengeNotificationsNotifier, List<ChallengeNotification>>((ref) {
  final notificationService = ref.watch(challengeNotificationServiceProvider);
  return ChallengeNotificationsNotifier(notificationService);
});

/// StateNotifier provider for user statistics
final userStatsProvider =
    StateNotifierProvider<UserStatsNotifier, Map<String, dynamic>>((ref) {
  final challengeTracker = ref.watch(challengeTrackerProvider);
  return UserStatsNotifier(challengeTracker);
});

/// StateNotifier for managing active challenges
class ActiveChallengesNotifier extends StateNotifier<List<Challenge>> {
  ActiveChallengesNotifier(this._challengeSystem) : super([]) {
    _challengeSystem.addListener(_updateState);
    _updateState();
  }
  final ChallengeSystem _challengeSystem;

  void _updateState() {
    state = List.from(_challengeSystem.activeChallenges);
  }

  Future<void> generateNewChallenges() async {
    await _challengeSystem.generateNewChallenges();
  }

  void updateChallengeProgress(String challengeId, int progress) {
    _challengeSystem.updateChallengeProgress(challengeId, progress);
  }

  @override
  void dispose() {
    _challengeSystem.removeListener(_updateState);
    super.dispose();
  }
}

/// StateNotifier for managing completed challenges
class CompletedChallengesNotifier extends StateNotifier<List<Challenge>> {
  CompletedChallengesNotifier(this._challengeSystem) : super([]) {
    _challengeSystem.addListener(_updateState);
    _updateState();
  }
  final ChallengeSystem _challengeSystem;

  void _updateState() {
    state = List.from(_challengeSystem.completedChallenges);
  }

  @override
  void dispose() {
    _challengeSystem.removeListener(_updateState);
    super.dispose();
  }
}

/// StateNotifier for managing challenge notifications
class ChallengeNotificationsNotifier
    extends StateNotifier<List<ChallengeNotification>> {
  ChallengeNotificationsNotifier(this._notificationService) : super([]) {
    _notificationService.addListener(_updateState);
    _updateState();
  }
  final ChallengeNotificationService _notificationService;

  void _updateState() {
    state = List.from(_notificationService.notifications);
  }

  void markAsRead(String notificationId) {
    _notificationService.markAsRead(notificationId);
  }

  void removeNotification(String notificationId) {
    _notificationService.removeNotification(notificationId);
  }

  void clearAllNotifications() {
    _notificationService.clearAllNotifications();
  }

  int get unreadCount => _notificationService.unreadCount;

  @override
  void dispose() {
    _notificationService.removeListener(_updateState);
    super.dispose();
  }
}

/// StateNotifier for managing user statistics
class UserStatsNotifier extends StateNotifier<Map<String, dynamic>> {
  UserStatsNotifier(this._challengeTracker) : super({}) {
    _challengeTracker.addListener(_updateState);
    _updateState();
  }
  final ChallengeTracker _challengeTracker;

  void _updateState() {
    state = Map.from(_challengeTracker.getUserStatistics());
  }

  void trackMovieWatched(
      String movieId, String movieTitle, List<String> genres) {
    _challengeTracker.trackMovieWatched(
      movieId: movieId,
      movieTitle: movieTitle,
      genres: genres,
    );
  }

  void trackReviewWritten(
      String movieId, String movieTitle, double rating, String reviewText) {
    _challengeTracker.trackReviewWritten(
      movieId: movieId,
      movieTitle: movieTitle,
      rating: rating,
      reviewText: reviewText,
    );
  }

  void trackMovieShared(String movieId, String movieTitle, String platform) {
    _challengeTracker.trackMovieShared(
      movieId: movieId,
      movieTitle: movieTitle,
      platform: platform,
    );
  }

  void trackNewReleaseDiscovered(
      String movieId, String movieTitle, DateTime releaseDate) {
    _challengeTracker.trackNewReleaseDiscovered(
      movieId: movieId,
      movieTitle: movieTitle,
      releaseDate: releaseDate,
    );
  }

  @override
  void dispose() {
    _challengeTracker.removeListener(_updateState);
    super.dispose();
  }
}

/// Provider for all user challenges (active + completed)
final userChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  final challengeSystem = ref.watch(challengeSystemProvider);
  final activeChallenges = challengeSystem.activeChallenges;
  final completedChallenges = challengeSystem.completedChallenges;
  return [...activeChallenges, ...completedChallenges];
});

/// Provider for available challenges
final availableChallengesProvider = Provider<List<Challenge>>((ref) {
  final challengeSystem = ref.watch(challengeSystemProvider);
  return challengeSystem.getAvailableChallenges();
});

/// Provider for challenge system service (alias for challengeSystemProvider)
final challengeSystemServiceProvider =
    StateNotifierProvider<ChallengeSystemServiceNotifier, ChallengeSystem>(
        (ref) {
  final challengeSystem = ref.watch(challengeSystemProvider);
  return ChallengeSystemServiceNotifier(challengeSystem);
});

/// StateNotifier for challenge system service operations
class ChallengeSystemServiceNotifier extends StateNotifier<ChallengeSystem> {
  ChallengeSystemServiceNotifier(super.challengeSystem);

  Future<void> generateWeeklyChallenges() async {
    await state.generateNewChallenges();
  }

  void acceptChallenge(String challengeId) {
    state.acceptChallenge(challengeId);
  }

  void completeChallenge(String challengeId) {
    state.completeChallenge(challengeId);
  }
}

/// Provider for challenge initialization
final challengeInitializationProvider = FutureProvider<void>((ref) async {
  final challengeSystem = ref.watch(challengeSystemProvider);
  final notificationService = ref.watch(challengeNotificationServiceProvider);

  // Initialize challenge system
  await challengeSystem.generateNewChallenges();

  // Set up periodic challenge generation
  challengeSystem.startPeriodicChallengeGeneration();

  // Initialize notification service
  notificationService.initialize();
});

/// Provider for checking if challenges are available
final hasChallengesProvider = Provider<bool>((ref) {
  final activeChallenges = ref.watch(activeChallengesProvider);
  final completedChallenges = ref.watch(completedChallengesProvider);
  return activeChallenges.isNotEmpty || completedChallenges.isNotEmpty;
});

/// Provider for unread notification count
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationService = ref.watch(challengeNotificationServiceProvider);
  return notificationService.unreadCount;
});

/// Provider for current user engagement score
final engagementScoreProvider = Provider<double>((ref) {
  final stats = ref.watch(userStatsProvider);
  return stats['engagementScore'] as double? ?? 0.0;
});

/// Provider for total points earned
final totalPointsProvider = Provider<int>((ref) {
  final completedChallenges = ref.watch(completedChallengesProvider);
  return completedChallenges.fold<int>(
    0,
    (total, challenge) => total + challenge.rewardPoints.toInt(),
  );
});

/// Provider for total badges earned
final totalBadgesProvider = Provider<List<String>>((ref) {
  final completedChallenges = ref.watch(completedChallengesProvider);
  final badges = <String>{};

  for (final challenge in completedChallenges) {
    badges.addAll(challenge.rewardBadges);
  }

  return badges.toList();
});

/// Provider for challenge completion rate
final challengeCompletionRateProvider = Provider<double>((ref) {
  final activeChallenges = ref.watch(activeChallengesProvider);
  final completedChallenges = ref.watch(completedChallengesProvider);

  final totalChallenges = activeChallenges.length + completedChallenges.length;
  if (totalChallenges == 0) return 0.0;

  return completedChallenges.length / totalChallenges;
});
