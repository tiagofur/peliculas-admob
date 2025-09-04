import '../../core/sync/conflict_resolution/soft_delete_manager.dart';
import '../../core/sync/sync_utilities.dart';
import '../repositories/syncable_repository.dart';
import 'custom_list.dart';
import 'movie.dart';
import 'syncable_entity.dart' as new_sync;
import 'syncable_entity.dart';
import 'watched_movie.dart';

// Enum para identificar la fuente de datos de la película
enum MovieDataSource {
  tmdb,
  trakt,
}

// Modelo base para elementos sincronizables
// NOTA: Esta implementación mantiene compatibilidad hacia atrás mientras
// migra gradualmente a la nueva interfaz SyncableEntity
abstract class SyncableEntity
    implements
        Syncable,
        Identifiable,
        Timestamped,
        SoftDeletable,
        new_sync.SyncableEntity {
  const SyncableEntity({
    required this.id,
    required this.updatedAt,
    required this.createdAt,
    this.deletedAt, // ✅ Soft delete support (backwards compatible)
    this.syncStatus = SyncItemStatus.synced,
    this.syncVersion = 1, // ✅ Nueva funcionalidad de versionado
    this.deviceId, // ✅ Tracking de dispositivo
  });

  @override
  final String id;
  @override
  final DateTime updatedAt;
  @override
  final SyncItemStatus syncStatus;
  @override
  final DateTime createdAt;
  final DateTime?
      deletedAt; // ✅ Soft delete timestamp (mantener por compatibilidad)
  @override
  final int syncVersion; // ✅ Nuevo campo para control de versiones
  @override
  final String? deviceId; // ✅ Nuevo campo para tracking de dispositivo

  // ✅ Helper methods for soft delete (compatibilidad hacia atrás)
  @override
  bool get isDeleted => deletedAt != null;
  bool get isActive => deletedAt == null;

  // ✅ Implementación de nueva interfaz SyncableEntity
  @override
  String get userId; // Debe ser implementado por subclases específicas

  @override
  DateTime get lastModifiedAt => updatedAt; // Mapeo por compatibilidad

  @override
  String get entityType; // Debe ser implementado por subclases específicas

  @override
  bool get needsSync => syncStatus == SyncItemStatus.pendingUpload;

  @override
  bool get canAutoSync => !isDeleted && syncStatus != SyncItemStatus.error;

  @override
  int get syncPriority => 3; // Prioridad media por defecto

  // ✅ Implementación de SoftDeletable - debe ser sobrescrita por subclases
  @override
  SoftDeletable copyWithDeleted(bool isDeleted, DateTime updatedAt);

  // ✅ Implementación de nueva interfaz - métodos de sync
  @override
  bool hasChangedSince(DateTime timestamp) {
    return lastModifiedAt.isAfter(timestamp);
  }

  @override
  String generateChecksum() {
    return SyncUtilities.generateChecksum(toSupabaseJson());
  }

  @override
  bool hasSameContentAs(new_sync.SyncableEntity other) {
    return generateChecksum() == other.generateChecksum();
  }

  @override
  bool hasPrecedenceOver(new_sync.SyncableEntity other) {
    return SyncUtilities.hasLocalPrecedence(
      localVersion: syncVersion,
      remoteVersion: other.syncVersion,
      localTimestamp: lastModifiedAt,
      remoteTimestamp: other.lastModifiedAt,
      localId: id,
      remoteId: other.id,
    );
  }

  @override
  new_sync.SyncableEntity mergeWith(new_sync.SyncableEntity other) {
    return hasPrecedenceOver(other) ? this : other;
  }

  @override
  bool isValidForSync() {
    return id.isNotEmpty && userId.isNotEmpty && syncVersion > 0;
  }

  @override
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (id.isEmpty) {
      errors.add('ID cannot be empty');
    }

    if (userId.isEmpty) {
      errors.add('User ID cannot be empty');
    }

    if (syncVersion <= 0) {
      errors.add('Sync version must be greater than 0');
    }

    return errors;
  }

  // ✅ Métodos de serialización - deben ser implementados por subclases
  @override
  Map<String, dynamic> toSupabaseJson();

  @override
  Map<String, dynamic> toLocalStorage() {
    return toSupabaseJson();
  }

  @override
  new_sync.SyncableEntity copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }); // Debe ser implementado por subclases
}

// Modelo para favoritos con información de sincronización
class SyncableFavorite extends SyncableEntity {
  const SyncableFavorite({
    required String id,
    required this.userId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    SyncItemStatus syncStatus = SyncItemStatus.synced,
    int syncVersion = 1,
    String? deviceId,
    required this.movieId,
    required this.movieTitle,
    required this.addedAt,
    this.traktId, // ✅ Trakt ID for hybrid support
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
  }) : super(
         id: id,
         createdAt: createdAt,
         updatedAt: updatedAt,
         deletedAt: deletedAt,
         syncStatus: syncStatus,
         syncVersion: syncVersion,
         deviceId: deviceId,
       );

  @override
  final String userId;

  // Crear desde JSON
  factory SyncableFavorite.fromJson(Map<String, dynamic> json) {
    return SyncableFavorite(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['last_modified_at'] as String),
      deletedAt: json['is_deleted'] == true ? DateTime.parse(json['deleted_at'] as String? ?? DateTime.now().toIso8601String()) : null,
      syncStatus: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncItemStatus.synced,
      ),
      syncVersion: json['sync_version'] as int? ?? 1,
      deviceId: json['device_id'] as String?,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      traktId: json['trakt_id'] as int?,
      moviePosterPath: json['movie_poster_path'] as String?,
      movieBackdropPath: json['movie_backdrop_path'] as String?,
      movieOverview: json['movie_overview'] as String?,
      movieReleaseDate: json['movie_release_date'] != null
          ? DateTime.parse(json['movie_release_date'] as String)
          : null,
      movieVoteAverage: json['movie_vote_average'] as double?,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  // Crear desde Movie
  factory SyncableFavorite.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    int? traktId, // ✅ Optional Trakt ID
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? deviceId,
  }) {
    final now = DateTime.now();
    return SyncableFavorite(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      deviceId: deviceId,
      movieId: movie.id,
      movieTitle: movie.title,
      traktId: traktId, // ✅ Include Trakt ID
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      addedAt: addedAt ?? now, // Usar timestamp real si está disponible
    );
  }

  final int movieId;
  final String movieTitle;
  final int? traktId; // ✅ Nullable Trakt ID for gradual migration
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime addedAt;

  // ✅ Implementación de métodos requeridos por nueva interfaz
  @override
  String get entityType => 'favorite';

  @override
  int get syncPriority => 2; // Alta prioridad para favoritos

  // ✅ Getter para determinar la fuente de datos preferida
  MovieDataSource get preferredSource =>
      traktId != null ? MovieDataSource.trakt : MovieDataSource.tmdb;

  @override
  SyncableFavorite copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableFavorite(
      id: id,
      userId: userId,
      createdAt: createdAt,
      updatedAt: lastModifiedAt ?? updatedAt,
      deletedAt: isDeleted == true ? (deletedAt ?? DateTime.now()) : (isDeleted == false ? null : deletedAt),
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      movieId: movieId,
      movieTitle: movieTitle,
      traktId: traktId,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      addedAt: addedAt,
    );
  }

  @override
  SyncableFavorite copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return copyWith(
      isDeleted: isDeleted,
      lastModifiedAt: updatedAt,
    );
  }

  // Método copyWith extendido para modificar propiedades específicas de favoritos
  SyncableFavorite copyWithFavorite({
    String? id,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
    String? deviceId,
    int? movieId,
    String? movieTitle,
    int? traktId,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? addedAt,
  }) {
    return SyncableFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      traktId: traktId ?? this.traktId,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'trakt_id': traktId,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String(),
      'movie_vote_average': movieVoteAverage,
      'added_at': addedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': updatedAt.toIso8601String(),
      'is_deleted': deletedAt != null,
      'sync_version': syncVersion,
      'device_id': deviceId,
    };
  }

  // Convertir a JSON (alias para compatibilidad)
  Map<String, dynamic> toJson() => toSupabaseJson();

  // Convertir a modelo de dominio Movie
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [], // Los géneros no se almacenan en favoritos
      adult: false,
      originalLanguage: 'en',
      originalTitle: movieTitle,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }
}

// Modelo para listas personalizadas con información de sincronización
class SyncableCustomList extends SyncableEntity {
  SyncableCustomList({
    required String id,
    required this.userId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    SyncItemStatus syncStatus = SyncItemStatus.synced,
    int syncVersion = 1,
    String? deviceId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.movieIds,
    this.isPublic = false,
  }) : super(
         id: id,
         createdAt: createdAt,
         updatedAt: updatedAt,
         deletedAt: deletedAt,
         syncStatus: syncStatus,
         syncVersion: syncVersion,
         deviceId: deviceId,
       );

  @override
  final String userId;

  @override
  final String id;
  
  @override
  final String userId;
  
  @override
  final DateTime createdAt;
  
  @override
  final DateTime lastModifiedAt;
  


  final String name;
  final String description;
  final String emoji;
  final String color;
  final List<int> movieIds;
  final bool isPublic;

  // Crear desde JSON
  factory SyncableCustomList.fromJson(Map<String, dynamic> json) {
    return SyncableCustomList(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['last_modified_at'] as String),
      deletedAt: json['is_deleted'] == true ? DateTime.parse(json['deleted_at'] as String? ?? DateTime.now().toIso8601String()) : null,
      syncStatus: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncItemStatus.synced,
      ),
      syncVersion: json['sync_version'] as int? ?? 1,
      deviceId: json['device_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      emoji: json['emoji'] as String,
      color: json['color'] as String,
      movieIds: List<int>.from(json['movie_ids'] as List),
      isPublic: json['is_public'] as bool? ?? false,
    );
  }

  // Crear desde CustomList
  factory SyncableCustomList.fromCustomList(
      CustomList customList, String userId) {
    return SyncableCustomList(
      id: customList.id,
      userId: userId,
      createdAt: customList.createdAt,
      updatedAt: customList.lastModifiedAt,
      name: customList.name,
      description: customList.description,
      emoji: customList.emoji,
      color: customList.color,
      movieIds: customList.movieIds,
    );
  }

  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'color': color,
      'movie_ids': movieIds,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': updatedAt.toIso8601String(),
      'is_deleted': deletedAt != null,
      'sync_version': syncVersion,
      'device_id': deviceId,
    };
  }

  // Convertir a JSON (alias para compatibilidad)
  Map<String, dynamic> toJson() => toSupabaseJson();

  // Convertir a modelo de dominio CustomList
  CustomList toCustomList() {
    return CustomList(
      id: id,
      name: name,
      description: description,
      emoji: emoji,
      color: color,
      movieIds: movieIds,
      createdAt: createdAt,
      lastModifiedAt: lastModifiedAt,
      isDefault: false,
    );
  }

  @override
  String get entityType => 'custom_list';

  @override
  SyncableCustomList copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableCustomList(
      id: id,
      userId: userId,
      createdAt: createdAt,
      updatedAt: lastModifiedAt ?? this.updatedAt,
      deletedAt: isDeleted == true ? (deletedAt ?? DateTime.now()) : (isDeleted == false ? null : deletedAt),
      syncStatus: syncStatus,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      name: name,
      description: description,
      emoji: emoji,
      color: color,
      movieIds: movieIds,
      isPublic: isPublic,
    );
  }

  // Método copyWith extendido para modificar propiedades específicas de listas
  SyncableCustomList copyWithCustomList({
    String? id,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
    String? deviceId,
    String? name,
    String? description,
    String? emoji,
    String? color,
    List<int>? movieIds,
    bool? isPublic,
  }) {
    return SyncableCustomList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      movieIds: movieIds ?? this.movieIds,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

// Modelo para películas vistas con información de sincronización
class SyncableWatchedMovie extends SyncableEntity {
  SyncableWatchedMovie({
    required String id,
    required this.userId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
    SyncItemStatus syncStatus = SyncItemStatus.synced,
    int syncVersion = 1,
    String? deviceId,
    required this.movieId,
    required this.movieTitle,
    required this.watchedAt,
    this.traktId, // ✅ Trakt ID for hybrid support
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    this.rating,
    this.review,
  }) : super(
         id: id,
         createdAt: createdAt,
         updatedAt: updatedAt,
         deletedAt: deletedAt,
         syncStatus: syncStatus,
         syncVersion: syncVersion,
         deviceId: deviceId,
       );

  @override
  final String userId;

  final int movieId;
  final String movieTitle;
  final int? traktId; // ✅ Nullable Trakt ID for gradual migration
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime watchedAt;
  final double? rating;
  final String? review;

  // Crear desde JSON
  factory SyncableWatchedMovie.fromJson(Map<String, dynamic> json) {
    return SyncableWatchedMovie(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['last_modified_at'] as String),
      deletedAt: json['is_deleted'] == true ? DateTime.parse(json['deleted_at'] as String? ?? DateTime.now().toIso8601String()) : null,
      syncStatus: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncItemStatus.synced,
      ),
      syncVersion: json['sync_version'] as int? ?? 1,
      deviceId: json['device_id'] as String?,
      movieId: json['movie_id'] as int,
      movieTitle: json['movie_title'] as String,
      traktId: json['trakt_id'] as int?,
      moviePosterPath: json['movie_poster_path'] as String?,
      movieBackdropPath: json['movie_backdrop_path'] as String?,
      movieOverview: json['movie_overview'] as String?,
      movieReleaseDate: json['movie_release_date'] != null
          ? DateTime.parse(json['movie_release_date'] as String)
          : null,
      movieVoteAverage: json['movie_vote_average'] as double?,
      watchedAt: DateTime.parse(json['watched_at'] as String),
      rating: json['rating'] as double?,
      review: json['review'] as String?,
    );
  }

  // Crear desde Movie
  factory SyncableWatchedMovie.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
    int? traktId, // ✅ Optional Trakt ID
    double? rating,
    String? review,
  }) {
    final now = DateTime.now();
    return SyncableWatchedMovie(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncVersion: 1,
      deviceId: null,
      movieId: movie.id,
      movieTitle: movie.title,
      traktId: traktId, // ✅ Include Trakt ID
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      watchedAt: now,
      rating: rating,
      review: review,
    );
  }

  // Crear desde WatchedMovie
  factory SyncableWatchedMovie.fromWatchedMovie(
      WatchedMovie watchedMovie, String userId,
      {int? traktId}) {
    return SyncableWatchedMovie(
      id: '${userId}_${watchedMovie.movie.id}',
      userId: userId,
      createdAt: watchedMovie.watchedDate,
      updatedAt: watchedMovie.lastModifiedAt ?? watchedMovie.watchedDate,
      deletedAt: null,
      syncVersion: 1,
      deviceId: null,
      movieId: watchedMovie.movie.id,
      movieTitle: watchedMovie.movie.title,
      traktId: traktId, // ✅ Include Trakt ID
      moviePosterPath: watchedMovie.movie.posterPath,
      movieBackdropPath: watchedMovie.movie.backdropPath,
      movieOverview: watchedMovie.movie.overview,
      movieReleaseDate: watchedMovie.movie.releaseDate,
      movieVoteAverage: watchedMovie.movie.voteAverage,
      watchedAt: watchedMovie.watchedDate,
    );
  }

  final int movieId;
  final String movieTitle;
  final int? traktId; // ✅ Nullable Trakt ID for gradual migration
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime watchedAt;
  final double? rating;
  final String? review;

   // ✅ Getter para determinar la fuente de datos preferida
  MovieDataSource get preferredSource =>
      traktId != null ? MovieDataSource.trakt : MovieDataSource.tmdb;

  @override
  String get entityType => 'watched_movie';

  // Convertir a JSON para Supabase
  @override
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': userId,
      'movie_id': movieId,
      'movie_title': movieTitle,
      'trakt_id': traktId,
      'movie_poster_path': moviePosterPath,
      'movie_backdrop_path': movieBackdropPath,
      'movie_overview': movieOverview,
      'movie_release_date': movieReleaseDate?.toIso8601String(),
      'movie_vote_average': movieVoteAverage,
      'watched_at': watchedAt.toIso8601String(),
      'rating': rating,
      'review': review,
      'created_at': createdAt.toIso8601String(),
      'last_modified_at': updatedAt.toIso8601String(),
      'is_deleted': deletedAt != null,
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_status': syncStatus.name,
      'sync_version': syncVersion,
      'device_id': deviceId,
    };
  }

  // Convertir a JSON (método de compatibilidad)
  Map<String, dynamic> toJson() {
    return toSupabaseJson();
  }

  @override
  Map<String, dynamic> toLocalStorage() {
    return toSupabaseJson();
  }

  @override
  bool isValidForSync() {
    return super.isValidForSync() && movieId > 0 && movieTitle.isNotEmpty;
  }

  @override
  List<String> getValidationErrors() {
    final errors = super.getValidationErrors();

    if (movieId <= 0) {
      errors.add('Movie ID must be greater than 0');
    }

    if (movieTitle.isEmpty) {
      errors.add('Movie title cannot be empty');
    }

    return errors;
  }

  @override
  SyncableWatchedMovie mergeWith(covariant SyncableWatchedMovie other) {
    if (hasPrecedenceOver(other)) {
      return this;
    }

    // Merge logic: take the other entity but preserve some local data if needed
    return other.copyWith(
      lastModifiedAt: DateTime.now(),
      syncVersion:
          (syncVersion > other.syncVersion ? syncVersion : other.syncVersion) +
              1,
      deviceId: deviceId,
    );
  }

  // Convertir a Movie
  Movie toMovie() {
    return Movie(
      id: movieId,
      title: movieTitle,
      posterPath: moviePosterPath ?? '',
      backdropPath: movieBackdropPath ?? '',
      overview: movieOverview ?? '',
      releaseDate: movieReleaseDate ?? DateTime.now(),
      voteAverage: movieVoteAverage ?? 0.0,
      genreIds: [],
      adult: false,
      originalLanguage: 'en',
      originalTitle: movieTitle,
      popularity: 0.0,
      video: false,
      voteCount: 0,
    );
  }

  // Convertir a modelo de dominio WatchedMovie
  WatchedMovie toWatchedMovie() {
    final movie = toMovie();
    return WatchedMovie(
      movie: movie,
      watchedDate: watchedAt,
      lastModifiedAt: updatedAt,
    );
  }

  @override
  SyncableWatchedMovie copyWith({
    DateTime? lastModifiedAt,
    int? syncVersion,
    String? deviceId,
    bool? isDeleted,
  }) {
    return SyncableWatchedMovie(
      id: id,
      userId: userId,
      createdAt: createdAt,
      updatedAt: lastModifiedAt ?? this.updatedAt,
      deletedAt: isDeleted == true ? DateTime.now() : (isDeleted == false ? null : deletedAt),
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      movieId: movieId,
      movieTitle: movieTitle,
      traktId: traktId,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      watchedAt: watchedAt,
      rating: rating,
      review: review,
    );
  }

  @override
  SyncableWatchedMovie copyWithDeleted(bool isDeleted, DateTime updatedAt) {
    return SyncableWatchedMovie(
      id: id,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: isDeleted ? updatedAt : null,
      syncVersion: syncVersion + 1,
      deviceId: deviceId,
      movieId: movieId,
      movieTitle: movieTitle,
      traktId: traktId,
      moviePosterPath: moviePosterPath,
      movieBackdropPath: movieBackdropPath,
      movieOverview: movieOverview,
      movieReleaseDate: movieReleaseDate,
      movieVoteAverage: movieVoteAverage,
      watchedAt: watchedAt,
      rating: rating,
      review: review,
    );
  }

  // Método copyWith extendido para modificar propiedades específicas de películas vistas
  SyncableWatchedMovie copyWithWatchedMovie({
    String? id,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? syncVersion,
    String? deviceId,
    int? movieId,
    String? movieTitle,
    int? traktId,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? watchedAt,
    double? rating,
    String? review,
  }) {
    return SyncableWatchedMovie(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncVersion: syncVersion ?? this.syncVersion,
      deviceId: deviceId ?? this.deviceId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      traktId: traktId ?? this.traktId,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      watchedAt: watchedAt ?? this.watchedAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
    );
  }
}
