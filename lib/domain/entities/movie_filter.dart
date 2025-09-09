import 'package:flutter/material.dart';

class MovieFilter {
  const MovieFilter({
    this.genres = const [],
    this.minYear,
    this.maxYear,
    this.minDuration,
    this.maxDuration,
    this.minRating,
    this.maxRating,
    this.language,
    this.sortBy,
    this.mood,
    this.includeAdult,
    this.minVoteCount,
    this.keywords = const [],
    this.certification,
    this.watchProviders = const [],
  });

  final List<String> genres;
  final int? minYear;
  final int? maxYear;
  final int? minDuration;
  final int? maxDuration;
  final double? minRating;
  final double? maxRating;
  final String? language;
  final String? sortBy;
  final String? mood;
  final bool? includeAdult;
  final int? minVoteCount;
  final List<String> keywords;
  final String? certification;
  final List<String> watchProviders;

  MovieFilter copyWith({
    List<String>? genres,
    int? minYear,
    int? maxYear,
    int? minDuration,
    int? maxDuration,
    double? minRating,
    double? maxRating,
    String? language,
    String? sortBy,
    String? mood,
    bool? includeAdult,
    int? minVoteCount,
    List<String>? keywords,
    String? certification,
    List<String>? watchProviders,
  }) {
    return MovieFilter(
      genres: genres ?? this.genres,
      minYear: minYear ?? this.minYear,
      maxYear: maxYear ?? this.maxYear,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      minRating: minRating ?? this.minRating,
      maxRating: maxRating ?? this.maxRating,
      language: language ?? this.language,
      sortBy: sortBy ?? this.sortBy,
      mood: mood ?? this.mood,
      includeAdult: includeAdult ?? this.includeAdult,
      minVoteCount: minVoteCount ?? this.minVoteCount,
      keywords: keywords ?? this.keywords,
      certification: certification ?? this.certification,
      watchProviders: watchProviders ?? this.watchProviders,
    );
  }

  bool get isEmpty {
    return genres.isEmpty &&
        minYear == null &&
        maxYear == null &&
        minDuration == null &&
        maxDuration == null &&
        minRating == null &&
        maxRating == null &&
        language == null &&
        sortBy == null &&
        mood == null &&
        includeAdult == null &&
        minVoteCount == null &&
        keywords.isEmpty &&
        certification == null &&
        watchProviders.isEmpty;
  }

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{};

    if (genres.isNotEmpty) {
      params['with_genres'] = genres.join(',');
    }

    if (minYear != null) {
      params['primary_release_date.gte'] = '$minYear-01-01';
    }

    if (maxYear != null) {
      params['primary_release_date.lte'] = '$maxYear-12-31';
    }

    if (minDuration != null) {
      params['with_runtime.gte'] = minDuration;
    }

    if (maxDuration != null) {
      params['with_runtime.lte'] = maxDuration;
    }

    if (minRating != null) {
      params['vote_average.gte'] = minRating;
    }

    if (maxRating != null) {
      params['vote_average.lte'] = maxRating;
    }

    if (language != null) {
      params['with_original_language'] = language;
    }

    if (sortBy != null) {
      params['sort_by'] = sortBy;
    }

    if (includeAdult != null) {
      params['include_adult'] = includeAdult;
    }

    if (minVoteCount != null) {
      params['vote_count.gte'] = minVoteCount;
    }

    if (keywords.isNotEmpty) {
      params['with_keywords'] = keywords.join(',');
    }

    if (certification != null) {
      params['certification'] = certification;
    }

    if (watchProviders.isNotEmpty) {
      params['with_watch_providers'] = watchProviders.join(',');
    }

    return params;
  }
}

class GenreOption {
  const GenreOption({
    required this.id,
    required this.name,
    required this.emoji,
    this.isSelected = false,
  });

  final String id;
  final String name;
  final String emoji;
  final bool isSelected;

  GenreOption copyWith({
    String? id,
    String? name,
    String? emoji,
    bool? isSelected,
  }) {
    return GenreOption(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class SortOption {
  const SortOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
}

class MoodOption {
  const MoodOption({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.associatedGenres,
  });

  final String id;
  final String name;
  final String description;
  final String emoji;
  final Color color;
  final List<String> associatedGenres;
}
