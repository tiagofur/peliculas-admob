// ignore: depend_on_referenced_packages
import 'package:equatable/equatable.dart';

/// Entidad que representa una calificación de película por parte del usuario
class MovieRating extends Equatable {
  const MovieRating({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.rating,
    this.review,
    required this.createdAt,
    required this.updatedAt,
    this.containsSpoilers = false,
    this.moderationStatus = ReviewModerationStatus.approved,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.isHelpfulByCurrentUser,
  });

  /// Constructor para crear una nueva calificación
  factory MovieRating.create({
    required String userId,
    required int movieId,
    required double rating,
    String? review,
    bool containsSpoilers = false,
  }) {
    final now = DateTime.now();
    return MovieRating(
      id: _generateId(userId, movieId),
      userId: userId,
      movieId: movieId,
      rating: rating,
      review: review,
      createdAt: now,
      updatedAt: now,
      containsSpoilers: containsSpoilers,
      moderationStatus: ReviewModerationStatus.pending,
    );
  }

  /// Constructor desde JSON
  factory MovieRating.fromJson(Map<String, dynamic> json) {
    return MovieRating(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      rating: (json['rating'] as num).toDouble(),
      review: json['review'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      containsSpoilers: json['contains_spoilers'] as bool? ?? false,
      moderationStatus: ReviewModerationStatus.values.byName(
        json['moderation_status'] as String? ?? 'approved',
      ),
      likesCount: json['likes_count'] as int? ?? 0,
      dislikesCount: json['dislikes_count'] as int? ?? 0,
      isHelpfulByCurrentUser: json['is_helpful_by_current_user'] as bool?,
    );
  }

  /// Identificador único de la calificación
  final String id;

  /// ID del usuario que hizo la calificación
  final String userId;

  /// ID de la película calificada
  final int movieId;

  /// Calificación del 1 al 5 (con decimales permitidos)
  final double rating;

  /// Reseña opcional del usuario
  final String? review;

  /// Fecha de creación de la calificación
  final DateTime createdAt;

  /// Fecha de última actualización
  final DateTime updatedAt;

  /// Indica si la reseña está marcada como spoiler
  final bool containsSpoilers;

  /// Estado de moderación de la reseña
  final ReviewModerationStatus moderationStatus;

  /// Número de likes que ha recibido la reseña
  final int likesCount;

  /// Número de dislikes que ha recibido la reseña
  final int dislikesCount;

  /// Indica si la reseña está marcada como útil por el usuario actual
  final bool? isHelpfulByCurrentUser;

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'rating': rating,
      'review': review,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'contains_spoilers': containsSpoilers,
      'moderation_status': moderationStatus.name,
      'likes_count': likesCount,
      'dislikes_count': dislikesCount,
      'is_helpful_by_current_user': isHelpfulByCurrentUser,
    };
  }

  /// Copia con modificaciones
  MovieRating copyWith({
    String? id,
    String? userId,
    int? movieId,
    double? rating,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? containsSpoilers,
    ReviewModerationStatus? moderationStatus,
    int? likesCount,
    int? dislikesCount,
    bool? isHelpfulByCurrentUser,
  }) {
    return MovieRating(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      containsSpoilers: containsSpoilers ?? this.containsSpoilers,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      isHelpfulByCurrentUser:
          isHelpfulByCurrentUser ?? this.isHelpfulByCurrentUser,
    );
  }

  /// Validaciones
  bool get isValidRating => rating >= 1.0 && rating <= 5.0;
  bool get hasReview => review != null && review!.trim().isNotEmpty;
  bool get isApproved => moderationStatus == ReviewModerationStatus.approved;
  bool get isPending => moderationStatus == ReviewModerationStatus.pending;
  bool get isRejected => moderationStatus == ReviewModerationStatus.rejected;

  /// Score de utilidad basado en likes y dislikes
  double get helpfulnessScore {
    final total = likesCount + dislikesCount;
    if (total == 0) return 0.0;
    return likesCount / total;
  }

  /// Genera un ID único basado en usuario y película
  static String _generateId(String userId, int movieId) {
    return '${userId}_${movieId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        movieId,
        rating,
        review,
        createdAt,
        updatedAt,
        containsSpoilers,
        moderationStatus,
        likesCount,
        dislikesCount,
        isHelpfulByCurrentUser,
      ];

  @override
  String toString() {
    return 'MovieRating(id: $id, userId: $userId, movieId: $movieId, rating: $rating, hasReview: $hasReview)';
  }
}

/// Estados de moderación para las reseñas
enum ReviewModerationStatus {
  /// Reseña pendiente de revisión
  pending,

  /// Reseña aprobada
  approved,

  /// Reseña rechazada por contenido inapropiado
  rejected,

  /// Reseña marcada como spam
  spam,

  /// Reseña en revisión por reportes
  underReview,
}

/// Extensión para obtener descripciones legibles de los estados de moderación
extension ReviewModerationStatusExtension on ReviewModerationStatus {
  String get displayName {
    switch (this) {
      case ReviewModerationStatus.pending:
        return 'Pendiente de revisión';
      case ReviewModerationStatus.approved:
        return 'Aprobada';
      case ReviewModerationStatus.rejected:
        return 'Rechazada';
      case ReviewModerationStatus.spam:
        return 'Marcada como spam';
      case ReviewModerationStatus.underReview:
        return 'En revisión';
    }
  }

  String get description {
    switch (this) {
      case ReviewModerationStatus.pending:
        return 'Tu reseña está siendo revisada por nuestro equipo';
      case ReviewModerationStatus.approved:
        return 'Tu reseña está publicada y visible para otros usuarios';
      case ReviewModerationStatus.rejected:
        return 'Tu reseña no cumple con nuestras políticas de contenido';
      case ReviewModerationStatus.spam:
        return 'Tu reseña fue marcada como spam por nuestro sistema';
      case ReviewModerationStatus.underReview:
        return 'Tu reseña está siendo revisada debido a reportes de usuarios';
    }
  }
}
