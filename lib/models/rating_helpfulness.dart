import 'package:equatable/equatable.dart';

/// Modelo para un voto de utilidad sobre una reseña
class RatingHelpfulnessVote extends Equatable {
  const RatingHelpfulnessVote({
    required this.id,
    required this.reviewId,
    required this.voterUserId,
    required this.isHelpful,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingHelpfulnessVote.fromJson(Map<String, dynamic> json) {
    return RatingHelpfulnessVote(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      voterUserId: json['voter_user_id'] as String,
      isHelpful: json['is_helpful'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  final String id;
  final String reviewId;
  final String voterUserId;
  final bool isHelpful;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review_id': reviewId,
      'voter_user_id': voterUserId,
      'is_helpful': isHelpful,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RatingHelpfulnessVote copyWith({
    String? id,
    String? reviewId,
    String? voterUserId,
    bool? isHelpful,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RatingHelpfulnessVote(
      id: id ?? this.id,
      reviewId: reviewId ?? this.reviewId,
      voterUserId: voterUserId ?? this.voterUserId,
      isHelpful: isHelpful ?? this.isHelpful,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        reviewId,
        voterUserId,
        isHelpful,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'RatingHelpfulnessVote(id: $id, reviewId: $reviewId, '
        'voterUserId: $voterUserId, isHelpful: $isHelpful, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// Modelo para estadísticas agregadas de utilidad de una reseña
class RatingHelpfulnessStats extends Equatable {
  const RatingHelpfulnessStats({
    required this.id,
    required this.reviewId,
    required this.helpfulVotes,
    required this.notHelpfulVotes,
    required this.totalVotes,
    required this.helpfulnessScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RatingHelpfulnessStats.fromJson(Map<String, dynamic> json) {
    return RatingHelpfulnessStats(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      helpfulVotes: json['helpful_votes'] as int,
      notHelpfulVotes: json['not_helpful_votes'] as int,
      totalVotes: json['total_votes'] as int,
      helpfulnessScore: (json['helpfulness_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  final String id;
  final String reviewId;
  final int helpfulVotes;
  final int notHelpfulVotes;
  final int totalVotes;
  final double helpfulnessScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review_id': reviewId,
      'helpful_votes': helpfulVotes,
      'not_helpful_votes': notHelpfulVotes,
      'total_votes': totalVotes,
      'helpfulness_score': helpfulnessScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Indica si la reseña tiene suficientes votos para ser considerada confiable
  bool get hasSignificantVotes => totalVotes >= 3;

  /// Indica si la reseña es mayoritariamente útil (> 60%)
  bool get isMostlyHelpful => helpfulnessScore > 0.6;

  /// Obtiene un texto descriptivo del nivel de utilidad
  String get helpfulnessDescription {
    if (totalVotes == 0) return 'Sin votos';
    if (totalVotes < 3) return 'Pocos votos ($totalVotes)';

    if (helpfulnessScore >= 0.8) return 'Muy útil';
    if (helpfulnessScore >= 0.6) return 'Útil';
    if (helpfulnessScore >= 0.4) return 'Moderadamente útil';
    return 'Poco útil';
  }

  RatingHelpfulnessStats copyWith({
    String? id,
    String? reviewId,
    int? helpfulVotes,
    int? notHelpfulVotes,
    int? totalVotes,
    double? helpfulnessScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RatingHelpfulnessStats(
      id: id ?? this.id,
      reviewId: reviewId ?? this.reviewId,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      notHelpfulVotes: notHelpfulVotes ?? this.notHelpfulVotes,
      totalVotes: totalVotes ?? this.totalVotes,
      helpfulnessScore: helpfulnessScore ?? this.helpfulnessScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        reviewId,
        helpfulVotes,
        notHelpfulVotes,
        totalVotes,
        helpfulnessScore,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'RatingHelpfulnessStats(id: $id, reviewId: $reviewId, '
        'helpfulVotes: $helpfulVotes, notHelpfulVotes: $notHelpfulVotes, '
        'totalVotes: $totalVotes, helpfulnessScore: $helpfulnessScore, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
