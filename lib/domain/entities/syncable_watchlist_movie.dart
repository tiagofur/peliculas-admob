import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../repositories/syncable_repository.dart';
import 'watchlist_movie.dart';

/// Entidad sincronizable para películas en watchlist que incluye metadatos de sincronización
class SyncableWatchlistMovie implements SoftDeletable, Syncable {
  const SyncableWatchlistMovie({
    required this.id,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    required this.priority,
    required this.addedAt,
    required this.updatedAt,
    this.deletedAt,
    this.isSynced = false,
    this.needsSync = true,
    this.syncStatus = SyncStatus.synced,
  });

  /// Convierte de WatchlistMovie local a SyncableWatchlistMovie
  factory SyncableWatchlistMovie.fromWatchlistMovie(
    WatchlistMovie movie,
    String userId, {
    bool isSynced = false,
    bool needsSync = true,
    DateTime? deletedAt,
    SyncStatus syncStatus = SyncStatus.synced,
  }) {
    return SyncableWatchlistMovie(
      id: movie.id,
      userId: userId,
      movieId: movie.movieId,
      movieTitle: movie.movieTitle,
      moviePosterPath: movie.moviePosterPath,
      movieBackdropPath: movie.movieBackdropPath,
      movieOverview: movie.movieOverview,
      movieReleaseDate: movie.movieReleaseDate,
      movieVoteAverage: movie.movieVoteAverage,
      priority: movie.priority,
      addedAt: movie.addedAt,
      updatedAt: movie.updatedAt,
      deletedAt: deletedAt,
      isSynced: isSynced,
      needsSync: needsSync,
      syncStatus: syncStatus,
    );
  }

  /// Convierte de datos de Supabase a SyncableWatchlistMovie
  factory SyncableWatchlistMovie.fromSupabase(Map<String, dynamic> data) {
    return SyncableWatchlistMovie(
      id: data['id'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      movieId: data['movie_id'] as int? ?? 0,
      movieTitle: data['movie_title'] as String? ?? '',
      moviePosterPath: data['movie_poster_path'] as String?,
      movieBackdropPath: data['movie_backdrop_path'] as String?,
      movieOverview: data['movie_overview'] as String?,
      movieReleaseDate: data['movie_release_date'] != null
          ? DateTime.tryParse(data['movie_release_date'] as String? ?? '')
          : null,
      movieVoteAverage: data['movie_vote_average'] != null
          ? (data['movie_vote_average'] as num?)?.toDouble()
          : null,
      priority:
          WatchlistPriority.fromString(data['priority'] as String? ?? 'normal'),
      addedAt: data['added_at'] != null 
          ? DateTime.tryParse(data['added_at'] as String? ?? '') ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null 
          ? DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.now()
          : DateTime.now(),
      deletedAt: data['deleted_at'] != null
          ? DateTime.tryParse(data['deleted_at'] as String? ?? '')
          : null,
      isSynced: true,
      needsSync: false,
      syncStatus: SyncStatus.synced,
    );
  }
  @override
  final String id;
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final WatchlistPriority priority;
  final DateTime addedAt;

  @override
  final DateTime updatedAt;

  final DateTime? deletedAt;
  final bool isSynced;
  final bool needsSync;

  @override
  final SyncStatus syncStatus;

  @override
  DateTime get createdAt =>
      addedAt; // Usar addedAt como createdAt para compatibilidad

  @override
  bool get isDeleted => deletedAt != null;

  /// Convierte a WatchlistMovie local
  WatchlistMovie toWatchlistMovie() {
    return WatchlistMovie(
      id: id,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      priority: priority,
      addedAt: addedAt,
      updatedAt: updatedAt,
    );
  }

  /// Convierte a formato para Supabase
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String().split('T')[0],
      'movie_vote_average': movieVoteAverage,
      'priority': priority.value,
      'added_at': addedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  SyncableWatchlistMovie copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    WatchlistPriority? priority,
    DateTime? addedAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isSynced,
    bool? needsSync,
    SyncStatus? syncStatus,
  }) {
    return SyncableWatchlistMovie(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      priority: priority ?? this.priority,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Implementa SoftDeletable - crea copia marcada como eliminada
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      deletedAt: isDeleted ? updatedAt : null,
      updatedAt: updatedAt,
    );
  }

  /// Indica si este elemento está marcado como eliminado (deprecated, usar isDeleted getter)
  @Deprecated('Use isDeleted getter instead')
  bool get wasDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableWatchlistMovie &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.priority == priority;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ movieId.hashCode ^ priority.hashCode;
  }

  @override
  String toString() {
    return 'SyncableWatchlistMovie(id: $id, userId: $userId, movieId: $movieId, title: $movieTitle, priority: $priority, synced: $isSynced, deleted: $isDeleted)';
  }
}
