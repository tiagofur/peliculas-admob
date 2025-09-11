import '../../core/sync/sync_utilities.dart';
import 'movie.dart';
import 'syncable_entity.dart';
import 'watchlist_movie.dart';

/// Entidad de película en watchlist que implementa SyncableEntity
/// para el sistema de sincronización offline-first
class SyncableWatchlistItem extends SyncableEntity {
  SyncableWatchlistItem({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.lastModifiedAt,
    this.isDeleted = false,
    this.syncVersion = 0,
    this.deviceId,
    required this.movieId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    this.priority = WatchlistPriority.normal,
    required this.addedAt,
    this.personalNotes,
    this.reminderDate,
    this.tags = const [],
  });

  /// Factory constructor desde Movie
  factory SyncableWatchlistItem.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    WatchlistPriority priority = WatchlistPriority.normal,
    DateTime? addedAt,
    String? personalNotes,
    DateTime? reminderDate,
    List<String> tags = const [],
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableWatchlistItem(
      id: customId ?? SyncUtilities.generateUuid(),
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      priority: priority,
      addedAt: addedAt ?? now,
      createdAt: now,
      lastModifiedAt: now,
      personalNotes: personalNotes,
      reminderDate: reminderDate,
      tags: tags,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde WatchlistMovie existente
  factory SyncableWatchlistItem.fromWatchlistMovie({
    required String userId,
    required WatchlistMovie watchlistMovie,
    String? deviceId,
  }) {
    final now = SyncUtilities.utcNow();
    return SyncableWatchlistItem(
      id: watchlistMovie.id,
      userId: userId,
      movieId: watchlistMovie.movieId,
      movieTitle: watchlistMovie.movieTitle,
      priority: watchlistMovie.priority,
      addedAt: watchlistMovie.addedAt,
      createdAt: now,
      lastModifiedAt: watchlistMovie.lastModifiedAt,
      isDeleted: watchlistMovie.isDeleted,
      deviceId: deviceId,
    );
  }

  /// Factory constructor desde JSON
  factory SyncableWatchlistItem.fromJson(Map<String, dynamic> json) {
    return SyncableWatchlistItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      moviePosterPath: json['movie_poster_path'] as String?,
      movieBackdropPath: json['movie_backdrop_path'] as String?,
      movieOverview: json['movie_overview'] as String?,
      movieReleaseDate: json['movie_release_date'] != null
          ? DateTime.parse(json['movie_release_date'] as String)
          : null,
      movieVoteAverage: json['movie_vote_average']?.toDouble(),
      priority: WatchlistPriority.values.firstWhere(
        (p) => p.toString().split('.').last == json['priority'],
        orElse: () => WatchlistPriority.normal,
      ),
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : DateTime.now(),
      isDeleted: (json['is_deleted'] as bool?) ?? false,
      syncVersion: (json['sync_version'] as int?) ?? 0,
      deviceId: json['device_id'] as String?,
      personalNotes: json['personal_notes'] as String?,
      reminderDate: json['reminder_date'] != null
          ? DateTime.parse(json['reminder_date'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[],
    );
  }

  /// Factory constructor desde string JSON
  factory SyncableWatchlistItem.fromJsonString(String jsonString) {
    final json = SyncUtilities.decodeJson(jsonString);
    return SyncableWatchlistItem.fromJson(json);
  }

  // Implementación de getters de SyncableEntity
  @override
  final String id;

  @override
  final String userId;

  @override
  final DateTime createdAt;

  @override
  final DateTime lastModifiedAt;

  @override
  final bool isDeleted;

  @override
  final int syncVersion;

  @override
  final String? deviceId;

  /// ID de la película en TMDB
  final int movieId;

  /// Título de la película
  final String movieTitle;

  /// Ruta del poster de la película
  final String? moviePosterPath;

  /// Ruta del backdrop de la película
  final String? movieBackdropPath;

  /// Sinopsis de la película
  final String? movieOverview;

  /// Fecha de lanzamiento de la película
  final DateTime? movieReleaseDate;

  /// Puntuación promedio de la película
  final double? movieVoteAverage;

  /// Prioridad en la watchlist
  final WatchlistPriority priority;

  /// Fecha cuando se agregó a la watchlist
  final DateTime addedAt;

  /// Notas personales del usuario
  final String? personalNotes;

  /// Fecha de recordatorio para ver la película
  final DateTime? reminderDate;

  /// Tags personalizados del usuario
  final List<String> tags;

  @override
  String get entityType => 'watchlist_item';

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String(),
      'movie_vote_average': movieVoteAverage,
      'priority': priority.toString().split('.').last,
      'added_at': addedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': lastModifiedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
      'device_id': deviceId,
      'personal_notes': personalNotes,
      'reminder_date': reminderDate?.toIso8601String(),
      'tags': tags,
    };
  }

  @override
  Map<String, dynamic> toLocalStorage() {
    return {
      'id': id,
      'userId': userId,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterPath': moviePosterPath,
      'movieBackdropPath': movieBackdropPath,
      'movieOverview': movieOverview,
      'movieReleaseDate': movieReleaseDate?.toIso8601String(),
      'movieVoteAverage': movieVoteAverage,
      'priority': priority.toString().split('.').last,
      'addedAt': addedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'syncVersion': syncVersion,
      'deviceId': deviceId,
      'personalNotes': personalNotes,
      'reminderDate': reminderDate?.toIso8601String(),
      'tags': tags,
    };
  }

  @override
  String generateChecksum() {
    final contentData = {
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePosterPath': moviePosterPath,
      'movieBackdropPath': movieBackdropPath,
      'movieOverview': movieOverview,
      'movieReleaseDate': movieReleaseDate?.toIso8601String(),
      'movieVoteAverage': movieVoteAverage,
      'priority': priority.toString().split('.').last,
      'addedAt': addedAt.toIso8601String(),
      'personalNotes': personalNotes,
      'reminderDate': reminderDate?.toIso8601String(),
      'tags': tags,
    };
    return SyncUtilities.generateChecksum(contentData);
  }

  @override
  bool hasSameContentAs(SyncableEntity other) {
    if (other is! SyncableWatchlistItem) return false;
    return movieId == other.movieId &&
        movieTitle == other.movieTitle &&
        moviePosterPath == other.moviePosterPath &&
        movieBackdropPath == other.movieBackdropPath &&
        movieOverview == other.movieOverview &&
        movieReleaseDate == other.movieReleaseDate &&
        movieVoteAverage == other.movieVoteAverage &&
        priority == other.priority &&
        addedAt == other.addedAt &&
        personalNotes == other.personalNotes &&
        reminderDate == other.reminderDate &&
        _listEquals(tags, other.tags);
  }

  @override
  SyncableEntity mergeWith(SyncableEntity other) {
    if (other is! SyncableWatchlistItem) {
      throw ArgumentError(
          'Cannot merge SyncableWatchlistItem with ${other.runtimeType}');
    }

    // Usar la versión más reciente como base
    final newer = lastModifiedAt.isAfter(other.lastModifiedAt) ? this : other;
    final older = lastModifiedAt.isAfter(other.lastModifiedAt) ? other : this;

    return SyncableWatchlistItem(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: newer.movieTitle,
      moviePosterPath: newer.moviePosterPath ?? older.moviePosterPath,
      movieBackdropPath: newer.movieBackdropPath ?? older.movieBackdropPath,
      movieOverview: newer.movieOverview ?? older.movieOverview,
      movieReleaseDate: newer.movieReleaseDate ?? older.movieReleaseDate,
      movieVoteAverage: newer.movieVoteAverage ?? older.movieVoteAverage,
      priority: newer.priority, // Usar la prioridad más reciente
      addedAt: older.addedAt, // Mantener la fecha original
      createdAt: createdAt,
      lastModifiedAt: SyncUtilities.utcNow(),
      isDeleted: newer.isDeleted,
      syncVersion: syncVersion + 1,
      deviceId: deviceId,
      personalNotes: newer.personalNotes ?? older.personalNotes,
      reminderDate: newer.reminderDate ?? older.reminderDate,
      // Combinar tags únicos
      tags: {...older.tags, ...newer.tags}.toList(),
    );
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (movieId <= 0) {
      errors.add('movieId must be positive');
    }

    if (movieTitle.trim().isEmpty) {
      errors.add('movieTitle cannot be empty');
    }

    if (tags.any((tag) => tag.trim().isEmpty)) {
      errors.add('tags cannot contain empty strings');
    }

    if (reminderDate != null && reminderDate!.isBefore(DateTime.now())) {
      errors.add('reminderDate cannot be in the past');
    }

    return errors;
  }

  @override
  int get syncPriority {
    // Prioridad basada en la prioridad de watchlist
    switch (priority) {
      case WatchlistPriority.alta:
        return 8;
      case WatchlistPriority.normal:
        return 6;
      case WatchlistPriority.baja:
        return 4;
    }
  }

  /// Crea una copia con campos modificados (implementación de SyncableEntity)
  @override
  SyncableWatchlistItem copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableWatchlistItem(
      id: id,
      userId: userId,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      priority: priority,
      addedAt: addedAt,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      personalNotes: personalNotes,
      reminderDate: reminderDate,
      tags: tags,
    );
  }

  /// Método copyWith extendido para uso interno
  SyncableWatchlistItem copyWithData({
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
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    int? syncVersion,
    String? deviceId,
    String? personalNotes,
    DateTime? reminderDate,
    List<String>? tags,
  }) {
    return SyncableWatchlistItem(
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
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      personalNotes: personalNotes ?? this.personalNotes,
      reminderDate: reminderDate ?? this.reminderDate,
      tags: tags ?? this.tags,
    );
  }

  /// Convierte a Movie para compatibilidad
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [], // No disponible en watchlist
      adult: false, // Valor por defecto
      originalLanguage: '', // No disponible
      originalTitle: movieTitle, // Usar el título como fallback
      popularity: 0.0, // No disponible
      video: false, // Valor por defecto
      voteCount: 0, // No disponible
    );
  }

  /// Convierte a WatchlistMovie para compatibilidad
  WatchlistMovie toWatchlistMovie() {
    return WatchlistMovie(
      id: id,
      movieId: movieId,
      movieTitle: movieTitle,
      priority: priority,
      addedAt: addedAt,
      lastModifiedAt: lastModifiedAt,
      isDeleted: isDeleted,
    );
  }

  /// Utilidad para comparar listas
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncableWatchlistItem &&
        other.id == id &&
        other.userId == userId &&
        other.movieId == movieId &&
        other.movieTitle == movieTitle &&
        other.moviePosterPath == moviePosterPath &&
        other.movieBackdropPath == movieBackdropPath &&
        other.movieOverview == movieOverview &&
        other.movieReleaseDate == movieReleaseDate &&
        other.movieVoteAverage == movieVoteAverage &&
        other.priority == priority &&
        other.addedAt == addedAt &&
        other.createdAt == createdAt &&
        other.lastModifiedAt == lastModifiedAt &&
        other.isDeleted == isDeleted &&
        other.syncVersion == syncVersion &&
        other.deviceId == deviceId &&
        other.personalNotes == personalNotes &&
        other.reminderDate == reminderDate &&
        _listEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      movieId,
      movieTitle,
      moviePosterPath,
      movieBackdropPath,
      movieOverview,
      movieReleaseDate,
      movieVoteAverage,
      priority,
      addedAt,
      createdAt,
      lastModifiedAt,
      isDeleted,
      syncVersion,
      deviceId,
      personalNotes,
      reminderDate,
      Object.hashAll(tags),
    );
  }

  @override
  String toString() {
    return 'SyncableWatchlistItem(id: $id, userId: $userId, movieId: $movieId, '
        'movieTitle: $movieTitle, priority: $priority, addedAt: $addedAt, '
        'isDeleted: $isDeleted, syncVersion: $syncVersion, lastModifiedAt: $lastModifiedAt)';
  }

  // =============================================
  // CONVERSIÓN PARA REPOSITORIOS HÍBRIDOS
  // =============================================

  /// Convierte a string JSON para almacenamiento local
  String toJsonString() {
    return SyncUtilities.encodeJson(toLocalStorage());
  }

  // Propiedades de conveniencia para compatibilidad
  String? get posterPath => moviePosterPath;
  String? get overview => movieOverview;
  DateTime? get releaseDate => movieReleaseDate;
  double? get rating => movieVoteAverage;
}
