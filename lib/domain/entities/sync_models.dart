import '../repositories/syncable_repository.dart';
import 'custom_list.dart';
import 'movie.dart';
import 'watched_movie.dart';

// Modelo base para elementos sincronizables
abstract class SyncableEntity implements Syncable, Identifiable, Timestamped {
  const SyncableEntity({
    required this.id,
    required this.updatedAt,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
  });
  @override
  final String id;
  @override
  final DateTime updatedAt;
  @override
  final SyncStatus syncStatus;
  final DateTime createdAt;
}

// Modelo para favoritos con información de sincronización
class SyncableFavorite extends SyncableEntity {
  const SyncableFavorite({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    required this.addedAt,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    super.syncStatus = SyncStatus.synced,
  });

  // Crear desde Movie
  factory SyncableFavorite.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
  }) {
    final now = DateTime.now();
    return SyncableFavorite(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      addedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime addedAt;

  SyncableFavorite copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? addedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return SyncableFavorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      addedAt: addedAt ?? this.addedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

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
  const SyncableCustomList({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    required this.userId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.movieIds,
    this.isPublic = false,
    super.syncStatus = SyncStatus.synced,
  });

  // Crear desde CustomList
  factory SyncableCustomList.fromCustomList(
      CustomList customList, String userId) {
    return SyncableCustomList(
      id: customList.id,
      userId: userId,
      name: customList.name,
      description: customList.description,
      emoji: customList.emoji,
      color: customList.color,
      movieIds: customList.movieIds,
      createdAt: customList.createdAt,
      updatedAt: customList.updatedAt,
    );
  }
  final String userId;
  final String name;
  final String description;
  final String emoji;
  final String color;
  final List<int> movieIds;
  final bool isPublic;

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
      updatedAt: updatedAt,
      isDefault: false,
    );
  }

  SyncableCustomList copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? emoji,
    String? color,
    List<int>? movieIds,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return SyncableCustomList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      movieIds: movieIds ?? this.movieIds,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

// Modelo para películas vistas con información de sincronización
class SyncableWatchedMovie extends SyncableEntity {
  const SyncableWatchedMovie({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    required this.userId,
    required this.movieId,
    required this.movieTitle,
    required this.watchedAt,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    super.syncStatus = SyncStatus.synced,
  });

  // Crear desde Movie
  factory SyncableWatchedMovie.fromMovie({
    required String userId,
    required Movie movie,
    String? customId,
  }) {
    final now = DateTime.now();
    return SyncableWatchedMovie(
      id: customId ?? '${userId}_${movie.id}',
      userId: userId,
      movieId: movie.id,
      movieTitle: movie.title,
      moviePosterPath: movie.posterPath,
      movieBackdropPath: movie.backdropPath,
      movieOverview: movie.overview,
      movieReleaseDate: movie.releaseDate,
      movieVoteAverage: movie.voteAverage,
      watchedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Crear desde WatchedMovie
  factory SyncableWatchedMovie.fromWatchedMovie(
      WatchedMovie watchedMovie, String userId) {
    return SyncableWatchedMovie(
      id: '${userId}_${watchedMovie.movie.id}',
      userId: userId,
      movieId: watchedMovie.movie.id,
      movieTitle: watchedMovie.movie.title,
      moviePosterPath: watchedMovie.movie.posterPath,
      movieBackdropPath: watchedMovie.movie.backdropPath,
      movieOverview: watchedMovie.movie.overview,
      movieReleaseDate: watchedMovie.movie.releaseDate,
      movieVoteAverage: watchedMovie.movie.voteAverage,
      watchedAt: watchedMovie.watchedDate,
      createdAt: watchedMovie.watchedDate,
      updatedAt: watchedMovie.watchedDate,
    );
  }
  final String userId;
  final int movieId;
  final String movieTitle;
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime watchedAt;

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
    );
  }

  SyncableWatchedMovie copyWith({
    String? id,
    String? userId,
    int? movieId,
    String? movieTitle,
    String? moviePosterPath,
    String? movieBackdropPath,
    String? movieOverview,
    DateTime? movieReleaseDate,
    double? movieVoteAverage,
    DateTime? watchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return SyncableWatchedMovie(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      movieId: movieId ?? this.movieId,
      movieTitle: movieTitle ?? this.movieTitle,
      moviePosterPath: moviePosterPath ?? this.moviePosterPath,
      movieBackdropPath: movieBackdropPath ?? this.movieBackdropPath,
      movieOverview: movieOverview ?? this.movieOverview,
      movieReleaseDate: movieReleaseDate ?? this.movieReleaseDate,
      movieVoteAverage: movieVoteAverage ?? this.movieVoteAverage,
      watchedAt: watchedAt ?? this.watchedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
