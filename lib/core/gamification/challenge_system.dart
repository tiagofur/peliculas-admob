import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/challenge_completion_celebration.dart';
import '../logging/base_logger.dart';
import '../logging/logger_factory.dart';
import 'challenge_categories/discovery_quest_challenge.dart';
import 'challenge_categories/genre_explorer_challenge.dart';
import 'challenge_categories/marathon_weekend_challenge.dart';
import 'challenge_categories/review_master_challenge.dart';
import 'challenge_categories/social_sharer_challenge.dart';
import 'models/challenge.dart' as models;
import 'models/challenge_enums.dart';
import 'models/user_progress.dart';

// Using Challenge class from models/challenge.dart
typedef Challenge = models.Challenge;

/// User behavior patterns for challenge generation
class UserBehaviorPattern {
  const UserBehaviorPattern({
    this.genrePreferences = const {},
    this.averageMoviesPerWeek = 0,
    this.averageReviewsPerMonth = 0,
    this.socialSharesPerMonth = 0,
    this.favoriteGenres = const [],
    this.engagementScore = 0.0,
    required this.lastActiveDate,
  });
  final Map<String, int> genrePreferences;
  final int averageMoviesPerWeek;
  final int averageReviewsPerMonth;
  final int socialSharesPerMonth;
  final List<String> favoriteGenres;
  final double engagementScore;
  final DateTime lastActiveDate;
}

/// Challenge template for generation
class ChallengeTemplate {
  const ChallengeTemplate({
    required this.type,
    required this.titleTemplate,
    required this.descriptionTemplate,
    required this.difficulty,
    required this.duration,
    required this.baseTargetValue,
    required this.baseRewardPoints,
    this.possibleBadges = const [],
    this.requirements = const {},
  });
  final ChallengeType type;
  final String titleTemplate;
  final String descriptionTemplate;
  final ChallengeDifficulty difficulty;
  final ChallengeDuration duration;
  final int baseTargetValue;
  final int baseRewardPoints;
  final List<String> possibleBadges;
  final Map<String, dynamic> requirements;
}

/// Dynamic Challenge System
class ChallengeSystem extends ChangeNotifier {
  factory ChallengeSystem() => _instance;
  ChallengeSystem._internal();
  static final ChallengeSystem _instance = ChallengeSystem._internal();
  static ChallengeSystem get instance => _instance;

  final List<Challenge> _activeChallenges = [];
  final List<Challenge> _completedChallenges = [];
  final Random _random = Random();
  Timer? _generationTimer;
  UserBehaviorPattern? _userBehavior;

  /// Get all active challenges
  List<Challenge> get activeChallenges => List.unmodifiable(_activeChallenges);

  /// Get completed challenges
  List<Challenge> get completedChallenges =>
      List.unmodifiable(_completedChallenges);

  /// Get challenges by type
  List<Challenge> getChallengesByType(ChallengeType type) {
    return _activeChallenges
        .where((c) => c.challengeType == type.name)
        .toList();
  }

  /// Get challenges by difficulty
  List<Challenge> getChallengesByDifficulty(ChallengeDifficulty difficulty) {
    // Since Challenge doesn't have difficulty, return all challenges
    return _activeChallenges;
  }

  /// Get available challenges (challenges that can be accepted)
  List<Challenge> getAvailableChallenges() {
    return _activeChallenges.where((c) => c.isActive).toList();
  }

  /// Complete a challenge
  Future<void> completeChallenge(String challengeId) async {
    final challengeIndex =
        _activeChallenges.indexWhere((c) => c.id == challengeId);
    if (challengeIndex != -1) {
      final challenge = _activeChallenges[challengeIndex];
      // Mark challenge as completed by moving it to completed list
      _completedChallenges.add(challenge);
      _activeChallenges.removeAt(challengeIndex);
      notifyListeners();
    }
  }

  /// Accept a challenge
  Future<void> acceptChallenge(String challengeId) async {
    final challengeIndex =
        _activeChallenges.indexWhere((c) => c.id == challengeId);
    if (challengeIndex != -1) {
      // Mark challenge as active (already accepted by being in active list)
      notifyListeners();
    }
  }

  /// Initialize the challenge system
  void initialize(UserBehaviorPattern userBehavior) {
    _userBehavior = userBehavior;
    _startAutomaticGeneration();
    _generateInitialChallenges();
  }

  /// Start automatic challenge generation
  void _startAutomaticGeneration() {
    _generationTimer?.cancel();
    _generationTimer = Timer.periodic(
      const Duration(hours: 6), // Check every 6 hours
      (_) => _checkAndGenerateChallenges(),
    );
  }

  /// Generate initial challenges for new users
  void _generateInitialChallenges() {
    // Generate a mix of easy challenges to get users started
    final challengeTypes = [
      ChallengeType.genreExplorer,
      ChallengeType.marathonWeekend,
      ChallengeType.socialSharer,
    ];

    for (final type in challengeTypes) {
      final challenge =
          _generateSpecificChallenge(type, ChallengeDuration.weekly);
      if (challenge != null) {
        _activeChallenges.add(challenge);
      }
    }

    notifyListeners();
  }

  /// Check and generate new challenges based on user behavior
  void _checkAndGenerateChallenges() {
    _cleanupExpiredChallenges();

    final now = DateTime.now();
    final weekday = now.weekday;

    // Generate weekly challenges on Monday
    if (weekday == DateTime.monday && !_hasActiveWeeklyChallenges()) {
      _generateWeeklyChallenges();
    }

    // Generate monthly challenges on the 1st
    if (now.day == 1 && !_hasActiveMonthlyChallenges()) {
      _generateMonthlyChallenges();
    }

    // Generate daily challenges if needed
    if (_activeChallenges.length < 2) {
      _generateDailyChallenges();
    }

    notifyListeners();
  }

  /// Clean up expired challenges
  void _cleanupExpiredChallenges() {
    _activeChallenges.removeWhere((challenge) {
      if (challenge.isExpired) {
        _completedChallenges.add(challenge);
        return true;
      }
      return false;
    });
  }

  /// Check if there are active weekly challenges
  bool _hasActiveWeeklyChallenges() {
    // Simplified check - assume we have weekly challenges if we have any active challenges
    return _activeChallenges.isNotEmpty;
  }

  /// Check if there are active monthly challenges
  bool _hasActiveMonthlyChallenges() {
    // Simplified check - assume we have monthly challenges if we have any active challenges
    return _activeChallenges.isNotEmpty;
  }

  /// Generate weekly challenges
  void _generateWeeklyChallenges() {
    final challengeTypes = [
      ChallengeType.genreExplorer,
      ChallengeType.marathonWeekend,
      ChallengeType.socialSharer
    ];
    final selectedTypes =
        _selectChallengeTypesBasedOnBehavior(challengeTypes, 2);

    for (final type in selectedTypes) {
      final challenge =
          _generateSpecificChallenge(type, ChallengeDuration.weekly);
      if (challenge != null) {
        _activeChallenges.add(challenge);
      }
    }
  }

  /// Generate monthly challenges
  void _generateMonthlyChallenges() {
    final challengeTypes = [
      ChallengeType.reviewMaster,
      ChallengeType.discoveryQuest
    ];
    final selectedTypes =
        _selectChallengeTypesBasedOnBehavior(challengeTypes, 1);

    for (final type in selectedTypes) {
      final challenge =
          _generateSpecificChallenge(type, ChallengeDuration.monthly);
      if (challenge != null) {
        _activeChallenges.add(challenge);
      }
    }
  }

  /// Generate daily challenges
  void _generateDailyChallenges() {
    final challengeTypes = [
      ChallengeType.genreExplorer,
      ChallengeType.socialSharer
    ];
    final selectedType =
        _selectChallengeTypesBasedOnBehavior(challengeTypes, 1).first;

    final challenge =
        _generateSpecificChallenge(selectedType, ChallengeDuration.daily);
    if (challenge != null) {
      _activeChallenges.add(challenge);
    }
  }

  /// Select challenge types based on user behavior
  List<ChallengeType> _selectChallengeTypesBasedOnBehavior(
    List<ChallengeType> types,
    int count,
  ) {
    if (_userBehavior == null) {
      return types.take(count).toList();
    }

    // Score types based on user behavior
    final scoredTypes = types.map((type) {
      double score = _scoreChallengeTypeForUser(type);
      return MapEntry(type, score);
    }).toList();

    // Sort by score and select top types
    scoredTypes.sort((a, b) => b.value.compareTo(a.value));
    return scoredTypes.take(count).map((e) => e.key).toList();
  }

  /// Score a challenge type based on user behavior
  double _scoreChallengeTypeForUser(ChallengeType type) {
    if (_userBehavior == null) return 0.5;

    double score = 0.0;

    switch (type) {
      case ChallengeType.genreExplorer:
        // Higher score if user has diverse genre preferences
        score = (_userBehavior?.genrePreferences.length ?? 0) / 10.0;
        break;
      case ChallengeType.marathonWeekend:
        // Higher score if user watches many movies per week
        score =
            ((_userBehavior?.averageMoviesPerWeek ?? 0) / 10.0).clamp(0.0, 1.0);
        break;
      case ChallengeType.socialSharer:
        // Higher score if user shares frequently
        score =
            ((_userBehavior?.socialSharesPerMonth ?? 0) / 20.0).clamp(0.0, 1.0);
        break;
      case ChallengeType.reviewMaster:
        // Higher score if user writes reviews
        score = ((_userBehavior?.averageReviewsPerMonth ?? 0) / 15.0)
            .clamp(0.0, 1.0);
        break;
      case ChallengeType.discoveryQuest:
        // Higher score for engaged users
        score = _userBehavior?.engagementScore ?? 0.5;
        break;
    }

    // Add some randomness to keep things interesting
    score += _random.nextDouble() * 0.2;

    return score.clamp(0.0, 1.0);
  }

  /// Handle challenge completion with celebrations and rewards
  void _handleChallengeCompletion(Challenge challenge, BuildContext? context) {
    // Move to completed challenges
    _activeChallenges.removeWhere((c) => c.id == challenge.id);
    _completedChallenges.add(challenge);

    // Award points and badges
    final pointsEarned = challenge.pointsReward;
    String? badgeEarned;

    // Note: Badge system would need to be implemented separately
    // if (challenge.rewardBadges.isNotEmpty) {
    //   badgeEarned = challenge.rewardBadges.first;
    // }

    // Show celebration if context is available
    if (context != null && context.mounted) {
      showChallengeCompletionCelebration(
        context,
        challenge,
        pointsEarned,
        badgeEarned,
      );
    }

    // Trigger notification
    notifyListeners();

    // Save progress
    _saveToStorage();

    // Generate new challenge to replace completed one
    _generateReplacementChallenge(challenge);
  }

  /// Generate a replacement challenge when one is completed
  void _generateReplacementChallenge(Challenge completedChallenge) {
    // Generate a new challenge of the same type but potentially different difficulty
    // For now, generate a random challenge since we don't have type/duration mapping
    _generateDailyChallenges();

    notifyListeners();
    _saveToStorage();
  }

  /// Generate a specific challenge using challenge category implementations
  Challenge? _generateSpecificChallenge(
      ChallengeType type, ChallengeDuration duration) {
    final difficulty = _selectDifficultyForUser();

    switch (type) {
      case ChallengeType.genreExplorer:
        return GenreExplorerChallenge.generateChallenge(
          userBehavior: UserProgress(
            userId: 'temp',
            totalPoints: 0,
            currentLevel: 1,
            moviesWatched: _userBehavior?.averageMoviesPerWeek ?? 2,
            moviesFavorited: 0,
            contentShared: _userBehavior?.socialSharesPerMonth ?? 1,
            reviewsWritten: _userBehavior?.averageReviewsPerMonth ?? 1,
            watchlistsCompleted: 0,
            genresExplored: _userBehavior?.favoriteGenres.length ?? 3,
            streakDays: 0,
            lastActivityDate: _userBehavior?.lastActiveDate ?? DateTime.now(),
          ),
          difficulty: difficulty,
          duration: duration,
        );
      case ChallengeType.marathonWeekend:
        return MarathonWeekendChallenge.generateChallenge(
          userBehavior: _userBehavior ??
              UserBehaviorPattern(
                genrePreferences: const {},
                averageMoviesPerWeek: 2,
                averageReviewsPerMonth: 1,
                socialSharesPerMonth: 1,
                favoriteGenres: const [],
                engagementScore: 0.5,
                lastActiveDate: DateTime.now(),
              ),
          difficulty: difficulty,
          duration: duration,
        );
      case ChallengeType.socialSharer:
        return SocialSharerChallenge.generateChallenge(
          userBehavior: _userBehavior ??
              UserBehaviorPattern(
                genrePreferences: const {},
                averageMoviesPerWeek: 2,
                averageReviewsPerMonth: 1,
                socialSharesPerMonth: 1,
                favoriteGenres: const [],
                engagementScore: 0.5,
                lastActiveDate: DateTime.now(),
              ),
          difficulty: difficulty,
          duration: duration,
        );
      case ChallengeType.reviewMaster:
        return ReviewMasterChallenge.generateChallenge(
          userBehavior: _userBehavior ??
              UserBehaviorPattern(
                genrePreferences: const {},
                averageMoviesPerWeek: 2,
                averageReviewsPerMonth: 1,
                socialSharesPerMonth: 1,
                favoriteGenres: const [],
                engagementScore: 0.5,
                lastActiveDate: DateTime.now(),
              ),
          difficulty: difficulty,
          duration: duration,
        );
      case ChallengeType.discoveryQuest:
        return DiscoveryQuestChallenge.generateChallenge(
          difficulty: difficulty,
          duration: duration,
        );
    }
  }

  /// Select difficulty based on user engagement
  ChallengeDifficulty _selectDifficultyForUser() {
    if (_userBehavior == null) return ChallengeDifficulty.easy;

    final engagement = _userBehavior?.engagementScore ?? 0.5;

    if (engagement >= 0.8) return ChallengeDifficulty.expert;
    if (engagement >= 0.6) return ChallengeDifficulty.hard;
    if (engagement >= 0.4) return ChallengeDifficulty.medium;
    return ChallengeDifficulty.easy;
  }

  /// Update challenge progress and handle completion
  void updateChallengeProgress(String challengeId, int progress,
      [BuildContext? context]) {
    final challengeIndex =
        _activeChallenges.indexWhere((c) => c.id == challengeId);
    if (challengeIndex == -1) return;

    final challenge = _activeChallenges[challengeIndex];
    final updatedChallenge = challenge.copyWith(currentProgress: progress);
    _activeChallenges[challengeIndex] = updatedChallenge;

    // Check if challenge is completed
    if (updatedChallenge.isCompleted && !challenge.isCompleted) {
      _handleChallengeCompletion(updatedChallenge, context);
    }

    notifyListeners();
    _saveToStorage();
  }

  /// Generate new challenges based on current state
  Future<void> generateNewChallenges() async {
    _checkAndGenerateChallenges();
    await _saveToStorage();
  }

  /// Start periodic challenge generation
  void startPeriodicChallengeGeneration() {
    _startAutomaticGeneration();
  }

  /// Save challenge data to persistent storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert challenges to JSON
      final challengesJson = _activeChallenges
          .map((c) => {
                'id': c.id,
                'title': c.title,
                'description': c.description,
                'pointsReward': c.pointsReward,
                'startDate': c.startDate.millisecondsSinceEpoch,
                'endDate': c.endDate.millisecondsSinceEpoch,
                'targetValue': c.targetValue,
                'challengeType': c.challengeType,
                'currentProgress': c.currentProgress,
                'isActive': c.isActive,
              })
          .toList();

      await prefs.setString('active_challenges', jsonEncode(challengesJson));
    } catch (e) {
      LoggerFactory.error('Error saving challenges to storage: $e',
          category: LogCategory.general);
    }
  }

  /// Dispose of the challenge system
  @override
  void dispose() {
    _generationTimer?.cancel();
    super.dispose();
  }
}
