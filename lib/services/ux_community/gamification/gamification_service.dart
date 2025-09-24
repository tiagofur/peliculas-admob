// lib/services/ux_community/gamification/gamification_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum AchievementType {
  movieWatcher,
  reviewer,
  socialButterfiy,
  genreExplorer,
  trendsetter,
  community,
  special,
}

enum AchievementRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

enum ChallengeType {
  daily,
  weekly,
  monthly,
  special,
  community,
}

enum ChallengeStatus {
  active,
  completed,
  expired,
  locked,
}

class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.type,
    required this.rarity,
    required this.pointsReward,
    required this.requirements,
    this.prerequisites = const [],
    this.isHidden = false,
    this.expiryDate,
    this.metadata = const {},
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'],
      type: AchievementType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => AchievementType.special,
      ),
      rarity: AchievementRarity.values.firstWhere(
        (e) => e.toString() == json['rarity'],
        orElse: () => AchievementRarity.common,
      ),
      pointsReward: json['pointsReward'],
      requirements: Map<String, dynamic>.from(json['requirements']),
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
      isHidden: json['isHidden'] ?? false,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final AchievementType type;
  final AchievementRarity rarity;
  final int pointsReward;
  final Map<String, dynamic> requirements;
  final List<String> prerequisites;
  final bool isHidden;
  final DateTime? expiryDate;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'type': type.toString(),
      'rarity': rarity.toString(),
      'pointsReward': pointsReward,
      'requirements': requirements,
      'prerequisites': prerequisites,
      'isHidden': isHidden,
      'expiryDate': expiryDate?.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class UserAchievement {
  const UserAchievement({
    required this.achievementId,
    required this.userId,
    required this.unlockedAt,
    this.progress = 1.0,
    this.progressData = const {},
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      achievementId: json['achievementId'],
      userId: json['userId'],
      unlockedAt: DateTime.parse(json['unlockedAt']),
      progress: json['progress']?.toDouble() ?? 1.0,
      progressData: Map<String, dynamic>.from(json['progressData'] ?? {}),
    );
  }
  final String achievementId;
  final String userId;
  final DateTime unlockedAt;
  final double progress;
  final Map<String, dynamic> progressData;

  Map<String, dynamic> toJson() {
    return {
      'achievementId': achievementId,
      'userId': userId,
      'unlockedAt': unlockedAt.toIso8601String(),
      'progress': progress,
      'progressData': progressData,
    };
  }
}

class Challenge {
  const Challenge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.type,
    required this.status,
    required this.requirements,
    required this.rewards,
    required this.startDate,
    required this.endDate,
    this.maxParticipants = 0,
    this.currentParticipants = 0,
    this.participantIds = const [],
    this.leaderboard = const {},
    this.metadata = const {},
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'],
      type: ChallengeType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ChallengeType.daily,
      ),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => ChallengeStatus.active,
      ),
      requirements: Map<String, dynamic>.from(json['requirements']),
      rewards: Map<String, dynamic>.from(json['rewards']),
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      maxParticipants: json['maxParticipants'] ?? 0,
      currentParticipants: json['currentParticipants'] ?? 0,
      participantIds: List<String>.from(json['participantIds'] ?? []),
      leaderboard: Map<String, dynamic>.from(json['leaderboard'] ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final ChallengeType type;
  final ChallengeStatus status;
  final Map<String, dynamic> requirements;
  final Map<String, dynamic> rewards;
  final DateTime startDate;
  final DateTime endDate;
  final int maxParticipants;
  final int currentParticipants;
  final List<String> participantIds;
  final Map<String, dynamic> leaderboard;
  final Map<String, dynamic> metadata;

  Challenge copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    ChallengeType? type,
    ChallengeStatus? status,
    Map<String, dynamic>? requirements,
    Map<String, dynamic>? rewards,
    DateTime? startDate,
    DateTime? endDate,
    int? maxParticipants,
    int? currentParticipants,
    List<String>? participantIds,
    Map<String, dynamic>? leaderboard,
    Map<String, dynamic>? metadata,
  }) {
    return Challenge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      requirements: requirements ?? this.requirements,
      rewards: rewards ?? this.rewards,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      participantIds: participantIds ?? this.participantIds,
      leaderboard: leaderboard ?? this.leaderboard,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'type': type.toString(),
      'status': status.toString(),
      'requirements': requirements,
      'rewards': rewards,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'participantIds': participantIds,
      'leaderboard': leaderboard,
      'metadata': metadata,
    };
  }
}

class UserProgress {
  const UserProgress({
    required this.userId,
    this.achievementProgress = const {},
    this.challengeProgress = const {},
    this.statistics = const {},
    required this.lastUpdated,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['userId'],
      achievementProgress:
          Map<String, double>.from(json['achievementProgress'] ?? {}),
      challengeProgress:
          Map<String, double>.from(json['challengeProgress'] ?? {}),
      statistics: Map<String, dynamic>.from(json['statistics'] ?? {}),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
  final String userId;
  final Map<String, double> achievementProgress;
  final Map<String, double> challengeProgress;
  final Map<String, dynamic> statistics;
  final DateTime lastUpdated;

  UserProgress copyWith({
    String? userId,
    Map<String, double>? achievementProgress,
    Map<String, double>? challengeProgress,
    Map<String, dynamic>? statistics,
    DateTime? lastUpdated,
  }) {
    return UserProgress(
      userId: userId ?? this.userId,
      achievementProgress: achievementProgress ?? this.achievementProgress,
      challengeProgress: challengeProgress ?? this.challengeProgress,
      statistics: statistics ?? this.statistics,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'achievementProgress': achievementProgress,
      'challengeProgress': challengeProgress,
      'statistics': statistics,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class Badge {
  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.color,
    required this.rarity,
    required this.earnedAt,
    this.metadata = const {},
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['iconUrl'],
      color: json['color'],
      rarity: AchievementRarity.values.firstWhere(
        (e) => e.toString() == json['rarity'],
        orElse: () => AchievementRarity.common,
      ),
      earnedAt: DateTime.parse(json['earnedAt']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String color;
  final AchievementRarity rarity;
  final DateTime earnedAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'color': color,
      'rarity': rarity.toString(),
      'earnedAt': earnedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class Leaderboard {
  const Leaderboard({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.entries,
    required this.updatedAt,
    this.metadata = const {},
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: json['type'],
      entries: (json['entries'] as List<dynamic>)
          .map((e) => LeaderboardEntry.fromJson(e))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  final String id;
  final String name;
  final String description;
  final String type; // points, achievements, challenges, etc.
  final List<LeaderboardEntry> entries;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'entries': entries.map((e) => e.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl = '',
    required this.rank,
    required this.score,
    this.data = const {},
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId'],
      username: json['username'],
      avatarUrl: json['avatarUrl'] ?? '',
      rank: json['rank'],
      score: json['score']?.toDouble() ?? 0.0,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
  final String userId;
  final String username;
  final String avatarUrl;
  final int rank;
  final double score;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'rank': rank,
      'score': score,
      'data': data,
    };
  }
}

class GamificationService {
  static const String _achievementsKey = 'gamification_achievements';
  static const String _userAchievementsKey = 'user_achievements';
  static const String _challengesKey = 'gamification_challenges';
  static const String _userProgressKey = 'user_progress';
  static const String _badgesKey = 'user_badges';
  static const String _leaderboardsKey = 'leaderboards';
  static const String _userPointsKey = 'user_points';

  SharedPreferences? _prefs;
  final Map<String, Achievement> _achievements = {};
  final Map<String, List<UserAchievement>> _userAchievements =
      {}; // userId -> achievements
  final Map<String, Challenge> _challenges = {};
  final Map<String, UserProgress> _userProgress = {};
  final Map<String, List<Badge>> _userBadges = {}; // userId -> badges
  final Map<String, Leaderboard> _leaderboards = {};
  final Map<String, int> _userPoints = {}; // userId -> points

  final StreamController<List<UserAchievement>> _achievementController =
      StreamController.broadcast();
  final StreamController<List<Challenge>> _challengeController =
      StreamController.broadcast();
  final StreamController<Leaderboard> _leaderboardController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _rewardController =
      StreamController.broadcast();

  // Getters
  Stream<List<UserAchievement>> get achievementStream =>
      _achievementController.stream;
  Stream<List<Challenge>> get challengeStream => _challengeController.stream;
  Stream<Leaderboard> get leaderboardStream => _leaderboardController.stream;
  Stream<Map<String, dynamic>> get rewardStream => _rewardController.stream;

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadAchievements();
      await _loadUserAchievements();
      await _loadChallenges();
      await _loadUserProgress();
      await _loadBadges();
      await _loadLeaderboards();
      await _loadUserPoints();
      await _initializeDefaultAchievements();
      await _initializeDefaultChallenges();
      LoggerFactory.info('GamificationService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing GamificationService: $e');
    }
  }

  // Points System
  Future<void> awardPoints(String userId, int points, String reason) async {
    try {
      final currentPoints = _userPoints[userId] ?? 0;
      _userPoints[userId] = currentPoints + points;

      await _saveUserPoints();
      await _updateLeaderboards();

      _rewardController.add({
        'type': 'points',
        'userId': userId,
        'amount': points,
        'reason': reason,
        'totalPoints': _userPoints[userId],
      });

      LoggerFactory.info('Awarded $points points to user $userId for: $reason');
    } catch (e) {
      LoggerFactory.error('Error awarding points: $e');
    }
  }

  int getUserPoints(String userId) {
    return _userPoints[userId] ?? 0;
  }

  // Achievements System
  Future<bool> unlockAchievement(String userId, String achievementId) async {
    try {
      final achievement = _achievements[achievementId];
      if (achievement == null) return false;

      // Check if already unlocked
      final userAchievements = _userAchievements[userId] ?? [];
      if (userAchievements.any((ua) => ua.achievementId == achievementId)) {
        return false;
      }

      // Check prerequisites
      for (final prerequisiteId in achievement.prerequisites) {
        if (!userAchievements.any((ua) => ua.achievementId == prerequisiteId)) {
          return false;
        }
      }

      final userAchievement = UserAchievement(
        achievementId: achievementId,
        userId: userId,
        unlockedAt: DateTime.now(),
      );

      _userAchievements.putIfAbsent(userId, () => []);
      _userAchievements[userId]!.add(userAchievement);

      // Award points
      await awardPoints(
          userId, achievement.pointsReward, 'Achievement: ${achievement.name}');

      // Create badge if applicable
      await _createBadgeFromAchievement(userId, achievement);

      await _saveUserAchievements();
      _achievementController.add(_userAchievements[userId]!);

      _rewardController.add({
        'type': 'achievement',
        'userId': userId,
        'achievementId': achievementId,
        'achievement': achievement.toJson(),
        'pointsAwarded': achievement.pointsReward,
      });

      LoggerFactory.info('Achievement unlocked: ${achievement.name} for user $userId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error unlocking achievement: $e');
      return false;
    }
  }

  Future<void> updateAchievementProgress(
      String userId, String achievementId, double progress) async {
    try {
      final achievement = _achievements[achievementId];
      if (achievement == null) return;

      final userProgress = _userProgress[userId] ??
          UserProgress(
            userId: userId,
            lastUpdated: DateTime.now(),
          );

      final updatedProgress =
          Map<String, double>.from(userProgress.achievementProgress);
      updatedProgress[achievementId] = progress.clamp(0.0, 1.0);

      _userProgress[userId] = userProgress.copyWith(
        achievementProgress: updatedProgress,
        lastUpdated: DateTime.now(),
      );

      // Check if achievement should be unlocked
      if (progress >= 1.0) {
        await unlockAchievement(userId, achievementId);
      }

      await _saveUserProgress();
    } catch (e) {
      LoggerFactory.error('Error updating achievement progress: $e');
    }
  }

  List<UserAchievement> getUserAchievements(String userId) {
    return _userAchievements[userId] ?? [];
  }

  List<Achievement> getAvailableAchievements(String userId) {
    final userAchievements = getUserAchievements(userId);
    final unlockedIds = userAchievements.map((ua) => ua.achievementId).toSet();

    return _achievements.values
        .where((achievement) => !unlockedIds.contains(achievement.id))
        .where((achievement) =>
            !achievement.isHidden ||
            _canSeeHiddenAchievement(userId, achievement))
        .toList();
  }

  bool _canSeeHiddenAchievement(String userId, Achievement achievement) {
    // Logic to determine if user can see hidden achievements
    // For example, based on progress or other conditions
    return false;
  }

  double getAchievementProgress(String userId, String achievementId) {
    final userProgress = _userProgress[userId];
    return userProgress?.achievementProgress[achievementId] ?? 0.0;
  }

  // Challenges System
  Future<String?> createChallenge({
    required String name,
    required String description,
    String iconUrl = '',
    required ChallengeType type,
    required Map<String, dynamic> requirements,
    required Map<String, dynamic> rewards,
    required DateTime startDate,
    required DateTime endDate,
    int maxParticipants = 0,
  }) async {
    try {
      final challengeId = 'challenge_${DateTime.now().millisecondsSinceEpoch}';

      final challenge = Challenge(
        id: challengeId,
        name: name,
        description: description,
        iconUrl: iconUrl,
        type: type,
        status: ChallengeStatus.active,
        requirements: requirements,
        rewards: rewards,
        startDate: startDate,
        endDate: endDate,
        maxParticipants: maxParticipants,
      );

      _challenges[challengeId] = challenge;
      await _saveChallenges();
      _challengeController.add(_challenges.values.toList());

      LoggerFactory.info('Challenge created: $name');
      return challengeId;
    } catch (e) {
      LoggerFactory.error('Error creating challenge: $e');
      return null;
    }
  }

  Future<bool> joinChallenge(String userId, String challengeId) async {
    try {
      final challenge = _challenges[challengeId];
      if (challenge == null || challenge.status != ChallengeStatus.active) {
        return false;
      }

      if (challenge.maxParticipants > 0 &&
          challenge.currentParticipants >= challenge.maxParticipants) {
        return false;
      }

      if (challenge.participantIds.contains(userId)) return false;

      final updatedParticipants = List<String>.from(challenge.participantIds);
      updatedParticipants.add(userId);

      _challenges[challengeId] = challenge.copyWith(
        participantIds: updatedParticipants,
        currentParticipants: updatedParticipants.length,
      );

      await _saveChallenges();
      _challengeController.add(_challenges.values.toList());

      LoggerFactory.info('User $userId joined challenge $challengeId');
      return true;
    } catch (e) {
      LoggerFactory.error('Error joining challenge: $e');
      return false;
    }
  }

  Future<void> updateChallengeProgress(
      String userId, String challengeId, double progress) async {
    try {
      final userProgress = _userProgress[userId] ??
          UserProgress(
            userId: userId,
            lastUpdated: DateTime.now(),
          );

      final updatedProgress =
          Map<String, double>.from(userProgress.challengeProgress);
      updatedProgress[challengeId] = progress.clamp(0.0, 1.0);

      _userProgress[userId] = userProgress.copyWith(
        challengeProgress: updatedProgress,
        lastUpdated: DateTime.now(),
      );

      await _saveUserProgress();

      // Check if challenge is completed
      if (progress >= 1.0) {
        await _completeChallengeForUser(userId, challengeId);
      }
    } catch (e) {
      LoggerFactory.error('Error updating challenge progress: $e');
    }
  }

  Future<void> _completeChallengeForUser(
      String userId, String challengeId) async {
    try {
      final challenge = _challenges[challengeId];
      if (challenge == null) return;

      // Award rewards
      final pointsReward = challenge.rewards['points'] as int? ?? 0;
      if (pointsReward > 0) {
        await awardPoints(
            userId, pointsReward, 'Challenge Completed: ${challenge.name}');
      }

      // Award badges if specified
      final badges = challenge.rewards['badges'] as List<String>? ?? [];
      for (final badgeId in badges) {
        await _awardBadge(userId, badgeId);
      }

      _rewardController.add({
        'type': 'challenge_completed',
        'userId': userId,
        'challengeId': challengeId,
        'challenge': challenge.toJson(),
        'rewards': challenge.rewards,
      });

      LoggerFactory.info('Challenge completed: ${challenge.name} by user $userId');
    } catch (e) {
      LoggerFactory.error('Error completing challenge: $e');
    }
  }

  List<Challenge> getActiveChallenges() {
    final now = DateTime.now();
    return _challenges.values
        .where((c) => c.status == ChallengeStatus.active)
        .where((c) => now.isAfter(c.startDate) && now.isBefore(c.endDate))
        .toList();
  }

  List<Challenge> getUserChallenges(String userId) {
    return _challenges.values
        .where((c) => c.participantIds.contains(userId))
        .toList();
  }

  double getChallengeProgress(String userId, String challengeId) {
    final userProgress = _userProgress[userId];
    return userProgress?.challengeProgress[challengeId] ?? 0.0;
  }

  // Badges System
  Future<void> _awardBadge(String userId, String badgeId) async {
    try {
      // This would typically create a badge from a predefined badge definition
      final badge = Badge(
        id: badgeId,
        name: 'Badge $badgeId',
        description: 'Badge earned by user',
        iconUrl: '',
        color: '#FFD700',
        rarity: AchievementRarity.common,
        earnedAt: DateTime.now(),
      );

      _userBadges.putIfAbsent(userId, () => []);
      _userBadges[userId]!.add(badge);

      await _saveBadges();

      _rewardController.add({
        'type': 'badge',
        'userId': userId,
        'badge': badge.toJson(),
      });
    } catch (e) {
      LoggerFactory.error('Error awarding badge: $e');
    }
  }

  Future<void> _createBadgeFromAchievement(
      String userId, Achievement achievement) async {
    try {
      final badge = Badge(
        id: 'badge_${achievement.id}',
        name: achievement.name,
        description: achievement.description,
        iconUrl: achievement.iconUrl,
        color: _getRarityColor(achievement.rarity),
        rarity: achievement.rarity,
        earnedAt: DateTime.now(),
        metadata: {'sourceAchievementId': achievement.id},
      );

      _userBadges.putIfAbsent(userId, () => []);
      _userBadges[userId]!.add(badge);

      await _saveBadges();
    } catch (e) {
      LoggerFactory.error('Error creating badge from achievement: $e');
    }
  }

  String _getRarityColor(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return '#9E9E9E';
      case AchievementRarity.uncommon:
        return '#4CAF50';
      case AchievementRarity.rare:
        return '#2196F3';
      case AchievementRarity.epic:
        return '#9C27B0';
      case AchievementRarity.legendary:
        return '#FF9800';
    }
  }

  List<Badge> getUserBadges(String userId) {
    return _userBadges[userId] ?? [];
  }

  // Leaderboards System
  Future<void> _updateLeaderboards() async {
    try {
      await _updatePointsLeaderboard();
      await _updateAchievementsLeaderboard();
      // Add more leaderboard updates as needed
    } catch (e) {
      LoggerFactory.error('Error updating leaderboards: $e');
    }
  }

  Future<void> _updatePointsLeaderboard() async {
    try {
      final entries = <LeaderboardEntry>[];

      // Convert points to leaderboard entries
      final sortedUsers = _userPoints.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedUsers.length; i++) {
        final entry = sortedUsers[i];
        entries.add(LeaderboardEntry(
          userId: entry.key,
          username: 'User ${entry.key}', // Would get from user service
          rank: i + 1,
          score: entry.value.toDouble(),
        ));
      }

      final leaderboard = Leaderboard(
        id: 'points_global',
        name: 'Global Points',
        description: 'Top users by total points earned',
        type: 'points',
        entries: entries.take(100).toList(), // Top 100
        updatedAt: DateTime.now(),
      );

      _leaderboards[leaderboard.id] = leaderboard;
      await _saveLeaderboards();
      _leaderboardController.add(leaderboard);
    } catch (e) {
      LoggerFactory.error('Error updating points leaderboard: $e');
    }
  }

  Future<void> _updateAchievementsLeaderboard() async {
    try {
      final entries = <LeaderboardEntry>[];

      // Count achievements per user
      final achievementCounts = <String, int>{};
      _userAchievements.forEach((userId, achievements) {
        achievementCounts[userId] = achievements.length;
      });

      // Convert to leaderboard entries
      final sortedUsers = achievementCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedUsers.length; i++) {
        final entry = sortedUsers[i];
        entries.add(LeaderboardEntry(
          userId: entry.key,
          username: 'User ${entry.key}', // Would get from user service
          rank: i + 1,
          score: entry.value.toDouble(),
        ));
      }

      final leaderboard = Leaderboard(
        id: 'achievements_global',
        name: 'Achievement Masters',
        description: 'Top users by achievements unlocked',
        type: 'achievements',
        entries: entries.take(100).toList(),
        updatedAt: DateTime.now(),
      );

      _leaderboards[leaderboard.id] = leaderboard;
      await _saveLeaderboards();
      _leaderboardController.add(leaderboard);
    } catch (e) {
      LoggerFactory.error('Error updating achievements leaderboard: $e');
    }
  }

  List<Leaderboard> getLeaderboards() {
    return _leaderboards.values.toList();
  }

  Leaderboard? getLeaderboard(String leaderboardId) {
    return _leaderboards[leaderboardId];
  }

  int getUserRank(String userId, String leaderboardId) {
    final leaderboard = _leaderboards[leaderboardId];
    if (leaderboard == null) return -1;

    final entry = leaderboard.entries.firstWhere(
      (e) => e.userId == userId,
      orElse: () =>
          const LeaderboardEntry(userId: '', username: '', rank: -1, score: 0),
    );

    return entry.rank;
  }

  // Statistics and Progress Tracking
  Future<void> updateUserStatistic(
      String userId, String key, dynamic value) async {
    try {
      final userProgress = _userProgress[userId] ??
          UserProgress(
            userId: userId,
            lastUpdated: DateTime.now(),
          );

      final updatedStats = Map<String, dynamic>.from(userProgress.statistics);
      updatedStats[key] = value;

      _userProgress[userId] = userProgress.copyWith(
        statistics: updatedStats,
        lastUpdated: DateTime.now(),
      );

      await _saveUserProgress();

      // Check for achievement triggers
      await _checkAchievementTriggers(userId, key, value);
    } catch (e) {
      LoggerFactory.error('Error updating user statistic: $e');
    }
  }

  Future<void> incrementUserStatistic(String userId, String key,
      [int increment = 1]) async {
    final userProgress = _userProgress[userId];
    final currentValue = (userProgress?.statistics[key] ?? 0) as int;
    await updateUserStatistic(userId, key, currentValue + increment);
  }

  Map<String, dynamic> getUserStatistics(String userId) {
    final userProgress = _userProgress[userId];
    return userProgress?.statistics ?? {};
  }

  Future<void> _checkAchievementTriggers(
      String userId, String statKey, dynamic value) async {
    // Check if any achievements should be triggered based on the statistic update
    for (final achievement in _achievements.values) {
      if (achievement.requirements.containsKey(statKey)) {
        final requiredValue = achievement.requirements[statKey];
        if (value is int && requiredValue is int && value >= requiredValue) {
          await unlockAchievement(userId, achievement.id);
        } else if (value is double &&
            requiredValue is double &&
            value >= requiredValue) {
          await unlockAchievement(userId, achievement.id);
        }
      }
    }
  }

  // Action Tracking (for triggering achievements and challenges)
  Future<void> trackAction(String userId, String action,
      [Map<String, dynamic>? data]) async {
    try {
      switch (action) {
        case 'movie_watched':
          await incrementUserStatistic(userId, 'moviesWatched');
          await awardPoints(userId, 10, 'Watched a movie');
          break;
        case 'review_created':
          await incrementUserStatistic(userId, 'reviewsCreated');
          await awardPoints(userId, 25, 'Created a review');
          break;
        case 'user_followed':
          await incrementUserStatistic(userId, 'usersFollowed');
          await awardPoints(userId, 5, 'Followed a user');
          break;
        case 'list_created':
          await incrementUserStatistic(userId, 'listsCreated');
          await awardPoints(userId, 20, 'Created a list');
          break;
        case 'daily_login':
          await _handleDailyLogin(userId);
          break;
      }

      // Update challenge progress
      await _updateChallengeProgressForAction(userId, action, data);
    } catch (e) {
      LoggerFactory.error('Error tracking action: $e');
    }
  }

  Future<void> _handleDailyLogin(String userId) async {
    final stats = getUserStatistics(userId);
    final lastLoginDate = stats['lastLoginDate'] as String?;
    final loginStreak = stats['loginStreak'] as int? ?? 0;
    final today = DateTime.now();
    final todayString = today.toIso8601String().split('T')[0];

    if (lastLoginDate != todayString) {
      // New day login
      await updateUserStatistic(userId, 'lastLoginDate', todayString);
      await incrementUserStatistic(userId, 'totalLogins');

      if (lastLoginDate != null) {
        final lastLogin = DateTime.parse('${lastLoginDate}T00:00:00');
        final daysBetween = today.difference(lastLogin).inDays;

        if (daysBetween == 1) {
          // Consecutive day
          await updateUserStatistic(userId, 'loginStreak', loginStreak + 1);
          await awardPoints(
              userId, 5 + (loginStreak * 2), 'Daily login streak');
        } else {
          // Streak broken
          await updateUserStatistic(userId, 'loginStreak', 1);
          await awardPoints(userId, 5, 'Daily login');
        }
      } else {
        await updateUserStatistic(userId, 'loginStreak', 1);
        await awardPoints(userId, 5, 'Daily login');
      }
    }
  }

  Future<void> _updateChallengeProgressForAction(
      String userId, String action, Map<String, dynamic>? data) async {
    final userChallenges = getUserChallenges(userId);

    for (final challenge in userChallenges) {
      if (challenge.status != ChallengeStatus.active) continue;

      final currentProgress = getChallengeProgress(userId, challenge.id);
      if (currentProgress >= 1.0) continue; // Already completed

      // Check if action matches challenge requirements
      final requiredAction = challenge.requirements['action'] as String?;
      if (requiredAction == action) {
        final currentCount =
            (currentProgress * (challenge.requirements['target'] as int? ?? 1))
                .round();
        final newProgress = (currentCount + 1) /
            (challenge.requirements['target'] as int? ?? 1);
        await updateChallengeProgress(userId, challenge.id, newProgress);
      }
    }
  }

  // Initialization Methods
  Future<void> _initializeDefaultAchievements() async {
    if (_achievements.isEmpty) {
      final defaultAchievements = [
        const Achievement(
          id: 'first_movie',
          name: 'Movie Newbie',
          description: 'Watch your first movie',
          iconUrl: '🎬',
          type: AchievementType.movieWatcher,
          rarity: AchievementRarity.common,
          pointsReward: 50,
          requirements: {'moviesWatched': 1},
        ),
        const Achievement(
          id: 'movie_marathon_10',
          name: 'Movie Enthusiast',
          description: 'Watch 10 movies',
          iconUrl: '🍿',
          type: AchievementType.movieWatcher,
          rarity: AchievementRarity.uncommon,
          pointsReward: 200,
          requirements: {'moviesWatched': 10},
        ),
        const Achievement(
          id: 'first_review',
          name: 'Critic in Training',
          description: 'Write your first review',
          iconUrl: '✍️',
          type: AchievementType.reviewer,
          rarity: AchievementRarity.common,
          pointsReward: 75,
          requirements: {'reviewsCreated': 1},
        ),
        const Achievement(
          id: 'social_butterfly',
          name: 'Social Butterfly',
          description: 'Follow 5 users',
          iconUrl: '👥',
          type: AchievementType.socialButterfiy,
          rarity: AchievementRarity.uncommon,
          pointsReward: 100,
          requirements: {'usersFollowed': 5},
        ),
        const Achievement(
          id: 'login_streak_7',
          name: 'Dedicated User',
          description: 'Login for 7 consecutive days',
          iconUrl: '🔥',
          type: AchievementType.community,
          rarity: AchievementRarity.rare,
          pointsReward: 300,
          requirements: {'loginStreak': 7},
        ),
      ];

      for (final achievement in defaultAchievements) {
        _achievements[achievement.id] = achievement;
      }

      await _saveAchievements();
    }
  }

  Future<void> _initializeDefaultChallenges() async {
    // Create daily challenges if none exist or if it's a new day
    await _createDailyChallenges();
    await _createWeeklyChallenges();
  }

  Future<void> _createDailyChallenges() async {
    final today = DateTime.now();
    final todayString = today.toIso8601String().split('T')[0];

    // Check if daily challenge already exists for today
    final existingDailyChallenge = _challenges.values.firstWhere(
      (c) => c.type == ChallengeType.daily && c.metadata['date'] == todayString,
      orElse: () => Challenge(
          id: '',
          name: '',
          description: '',
          iconUrl: '',
          type: ChallengeType.daily,
          status: ChallengeStatus.expired,
          requirements: {},
          rewards: {},
          startDate: DateTime.now(),
          endDate: DateTime.now()),
    );

    if (existingDailyChallenge.id.isEmpty) {
      // Create new daily challenge
      final challengeId = await createChallenge(
        name: 'Daily Movie Goal',
        description: 'Watch 2 movies today',
        type: ChallengeType.daily,
        requirements: {'action': 'movie_watched', 'target': 2},
        rewards: {'points': 50, 'badges': []},
        startDate: DateTime(today.year, today.month, today.day),
        endDate: DateTime(today.year, today.month, today.day, 23, 59, 59),
      );

      if (challengeId != null) {
        _challenges[challengeId] = _challenges[challengeId]!.copyWith(
          metadata: {'date': todayString},
        );
      }
    }
  }

  Future<void> _createWeeklyChallenges() async {
    // Similar logic for weekly challenges
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final weekString = '${startOfWeek.year}-W${_getWeekNumber(startOfWeek)}';

    final existingWeeklyChallenge = _challenges.values.firstWhere(
      (c) => c.type == ChallengeType.weekly && c.metadata['week'] == weekString,
      orElse: () => Challenge(
          id: '',
          name: '',
          description: '',
          iconUrl: '',
          type: ChallengeType.weekly,
          status: ChallengeStatus.expired,
          requirements: {},
          rewards: {},
          startDate: DateTime.now(),
          endDate: DateTime.now()),
    );

    if (existingWeeklyChallenge.id.isEmpty) {
      final challengeId = await createChallenge(
        name: 'Weekly Review Challenge',
        description: 'Write 5 reviews this week',
        type: ChallengeType.weekly,
        requirements: {'action': 'review_created', 'target': 5},
        rewards: {
          'points': 200,
          'badges': ['weekly_reviewer']
        },
        startDate: startOfWeek,
        endDate: endOfWeek,
      );

      if (challengeId != null) {
        _challenges[challengeId] = _challenges[challengeId]!.copyWith(
          metadata: {'week': weekString},
        );
      }
    }
  }

  int _getWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // Persistence Methods
  Future<void> _loadAchievements() async {
    final json = _prefs?.getString(_achievementsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _achievements.clear();
      data.forEach((key, value) {
        _achievements[key] = Achievement.fromJson(value);
      });
    }
  }

  Future<void> _saveAchievements() async {
    final data = <String, dynamic>{};
    _achievements.forEach((key, achievement) {
      data[key] = achievement.toJson();
    });
    await _prefs?.setString(_achievementsKey, jsonEncode(data));
  }

  Future<void> _loadUserAchievements() async {
    final json = _prefs?.getString(_userAchievementsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userAchievements.clear();
      data.forEach((userId, achievementsList) {
        _userAchievements[userId] = (achievementsList as List<dynamic>)
            .map((ua) => UserAchievement.fromJson(ua))
            .toList();
      });
    }
  }

  Future<void> _saveUserAchievements() async {
    final data = <String, dynamic>{};
    _userAchievements.forEach((userId, achievements) {
      data[userId] = achievements.map((ua) => ua.toJson()).toList();
    });
    await _prefs?.setString(_userAchievementsKey, jsonEncode(data));
  }

  Future<void> _loadChallenges() async {
    final json = _prefs?.getString(_challengesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _challenges.clear();
      data.forEach((key, value) {
        _challenges[key] = Challenge.fromJson(value);
      });
    }
  }

  Future<void> _saveChallenges() async {
    final data = <String, dynamic>{};
    _challenges.forEach((key, challenge) {
      data[key] = challenge.toJson();
    });
    await _prefs?.setString(_challengesKey, jsonEncode(data));
  }

  Future<void> _loadUserProgress() async {
    final json = _prefs?.getString(_userProgressKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userProgress.clear();
      data.forEach((key, value) {
        _userProgress[key] = UserProgress.fromJson(value);
      });
    }
  }

  Future<void> _saveUserProgress() async {
    final data = <String, dynamic>{};
    _userProgress.forEach((key, progress) {
      data[key] = progress.toJson();
    });
    await _prefs?.setString(_userProgressKey, jsonEncode(data));
  }

  Future<void> _loadBadges() async {
    final json = _prefs?.getString(_badgesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userBadges.clear();
      data.forEach((userId, badgesList) {
        _userBadges[userId] = (badgesList as List<dynamic>)
            .map((b) => Badge.fromJson(b))
            .toList();
      });
    }
  }

  Future<void> _saveBadges() async {
    final data = <String, dynamic>{};
    _userBadges.forEach((userId, badges) {
      data[userId] = badges.map((b) => b.toJson()).toList();
    });
    await _prefs?.setString(_badgesKey, jsonEncode(data));
  }

  Future<void> _loadLeaderboards() async {
    final json = _prefs?.getString(_leaderboardsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _leaderboards.clear();
      data.forEach((key, value) {
        _leaderboards[key] = Leaderboard.fromJson(value);
      });
    }
  }

  Future<void> _saveLeaderboards() async {
    final data = <String, dynamic>{};
    _leaderboards.forEach((key, leaderboard) {
      data[key] = leaderboard.toJson();
    });
    await _prefs?.setString(_leaderboardsKey, jsonEncode(data));
  }

  Future<void> _loadUserPoints() async {
    final json = _prefs?.getString(_userPointsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userPoints.clear();
      data.forEach((key, value) {
        _userPoints[key] = value as int;
      });
    }
  }

  Future<void> _saveUserPoints() async {
    await _prefs?.setString(_userPointsKey, jsonEncode(_userPoints));
  }

  // Dispose
  void dispose() {
    _achievementController.close();
    _challengeController.close();
    _leaderboardController.close();
    _rewardController.close();
  }
}
