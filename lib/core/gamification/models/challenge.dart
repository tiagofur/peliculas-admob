import 'challenge_enums.dart';

class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsReward,
    required this.startDate,
    required this.endDate,
    required this.targetValue,
    required this.challengeType,
    this.difficulty = ChallengeDifficulty.medium,
    this.isActive = true,
    this.currentProgress = 0,
    this.rewardBadges = const [],
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      pointsReward: json['pointsReward'],
      startDate: DateTime.fromMillisecondsSinceEpoch(json['startDate']),
      endDate: DateTime.fromMillisecondsSinceEpoch(json['endDate']),
      targetValue: json['targetValue'],
      challengeType: json['challengeType'],
      difficulty: ChallengeDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == (json['difficulty'] ?? 'medium'),
        orElse: () => ChallengeDifficulty.medium,
      ),
      isActive: json['isActive'] ?? true,
      currentProgress: json['currentProgress'] ?? 0,
      rewardBadges: List<String>.from(json['rewardBadges'] ?? []),
    );
  }
  final String id;
  final String title;
  final String description;
  final int pointsReward;
  final DateTime startDate;
  final DateTime endDate;
  final int targetValue;
  final String challengeType;
  final ChallengeDifficulty difficulty;
  final bool isActive;
  final int currentProgress;
  final List<String> rewardBadges;

  // Getter for backward compatibility
  int get rewardPoints => pointsReward;
  
  // Additional getters
  ChallengeType get type => ChallengeType.values.firstWhere(
    (e) => e.toString().split('.').last == challengeType,
    orElse: () => ChallengeType.genreExplorer,
  );
  
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) {
      return Duration.zero;
    }
    return endDate.difference(now);
  }

  bool get isCompleted => currentProgress >= targetValue;
  bool get isExpired => DateTime.now().isAfter(endDate);
  double get progressPercentage =>
      targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    int? pointsReward,
    DateTime? startDate,
    DateTime? endDate,
    int? targetValue,
    String? challengeType,
    ChallengeDifficulty? difficulty,
    bool? isActive,
    int? currentProgress,
    List<String>? rewardBadges,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      pointsReward: pointsReward ?? this.pointsReward,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetValue: targetValue ?? this.targetValue,
      challengeType: challengeType ?? this.challengeType,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      currentProgress: currentProgress ?? this.currentProgress,
      rewardBadges: rewardBadges ?? this.rewardBadges,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'pointsReward': pointsReward,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'targetValue': targetValue,
      'challengeType': challengeType,
      'difficulty': difficulty.toString().split('.').last,
      'isActive': isActive,
      'currentProgress': currentProgress,
      'rewardBadges': rewardBadges,
    };
  }
}
