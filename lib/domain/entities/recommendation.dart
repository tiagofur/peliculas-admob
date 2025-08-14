class Recommendation {
  Recommendation({
    required this.movieId,
    required this.title,
    required this.posterPath,
    required this.score,
    required this.reason,
    required this.type,
    required this.tags,
  });

  final int movieId;
  final String title;
  final String posterPath;
  final double score;
  final String reason;
  final RecommendationType type;
  final List<String> tags;
}

enum RecommendationType {
  basedOnFavorites,
  basedOnWatched,
  basedOnGenre,
  trending,
  forYou,
  similar,
  mood
}

class RecommendationCategory {
  RecommendationCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.moods = const [],
    this.genres = const [],
    this.filters = const {},
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> moods;
  final List<String> genres;
  final Map<String, dynamic> filters;
}

class UserPreferences {
  const UserPreferences({
    required this.favoriteGenres,
    required this.favoriteActors,
    required this.favoriteDirectors,
    required this.averageRatingPreference,
    required this.preferredLanguages,
    required this.genreCount,
    required this.genreRating,
    required this.lastUpdated,
  });

  final List<String> favoriteGenres;
  final List<String> favoriteActors;
  final List<String> favoriteDirectors;
  final double averageRatingPreference;
  final List<String> preferredLanguages;
  final Map<String, int> genreCount;
  final Map<String, double> genreRating;
  final DateTime lastUpdated;

  UserPreferences copyWith({
    List<String>? favoriteGenres,
    List<String>? favoriteActors,
    List<String>? favoriteDirectors,
    double? averageRatingPreference,
    List<String>? preferredLanguages,
    Map<String, int>? genreCount,
    Map<String, double>? genreRating,
    DateTime? lastUpdated,
  }) {
    return UserPreferences(
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteActors: favoriteActors ?? this.favoriteActors,
      favoriteDirectors: favoriteDirectors ?? this.favoriteDirectors,
      averageRatingPreference: averageRatingPreference ?? this.averageRatingPreference,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      genreCount: genreCount ?? this.genreCount,
      genreRating: genreRating ?? this.genreRating,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}