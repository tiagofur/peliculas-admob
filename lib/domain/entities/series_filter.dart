class SeriesFilter {
  const SeriesFilter({
    this.genres = const [],
    this.minYear,
    this.maxYear,
    this.minRating,
    this.maxRating,
    this.language,
    this.sortBy,
    this.mood,
    this.includeAdult,
    this.minVoteCount,
    this.watchProviders = const [],
    this.status,
    this.networks = const [],
    this.minSeasons,
    this.maxSeasons,
    this.minEpisodes,
    this.maxEpisodes,
    this.minEpisodeRuntime,
    this.maxEpisodeRuntime,
  });

  final List<int> genres;
  final int? minYear;
  final int? maxYear;
  final double? minRating;
  final double? maxRating;
  final String? language;
  final String? sortBy;
  final String? mood;
  final bool? includeAdult;
  final int? minVoteCount;
  final List<String> watchProviders;
  final String? status;
  final List<int> networks;
  final int? minSeasons;
  final int? maxSeasons;
  final int? minEpisodes;
  final int? maxEpisodes;
  final int? minEpisodeRuntime;
  final int? maxEpisodeRuntime;

  SeriesFilter copyWith({
    List<int>? genres,
    int? minYear,
    int? maxYear,
    double? minRating,
    double? maxRating,
    String? language,
    String? sortBy,
    String? mood,
    bool? includeAdult,
    int? minVoteCount,
    List<String>? watchProviders,
    String? status,
    List<int>? networks,
    int? minSeasons,
    int? maxSeasons,
    int? minEpisodes,
    int? maxEpisodes,
    int? minEpisodeRuntime,
    int? maxEpisodeRuntime,
  }) {
    return SeriesFilter(
      genres: genres ?? this.genres,
      minYear: minYear ?? this.minYear,
      maxYear: maxYear ?? this.maxYear,
      minRating: minRating ?? this.minRating,
      maxRating: maxRating ?? this.maxRating,
      language: language ?? this.language,
      sortBy: sortBy ?? this.sortBy,
      mood: mood ?? this.mood,
      includeAdult: includeAdult ?? this.includeAdult,
      minVoteCount: minVoteCount ?? this.minVoteCount,
      watchProviders: watchProviders ?? this.watchProviders,
      status: status ?? this.status,
      networks: networks ?? this.networks,
      minSeasons: minSeasons ?? this.minSeasons,
      maxSeasons: maxSeasons ?? this.maxSeasons,
      minEpisodes: minEpisodes ?? this.minEpisodes,
      maxEpisodes: maxEpisodes ?? this.maxEpisodes,
      minEpisodeRuntime: minEpisodeRuntime ?? this.minEpisodeRuntime,
      maxEpisodeRuntime: maxEpisodeRuntime ?? this.maxEpisodeRuntime,
    );
  }

  SeriesFilter clearYearRange() => SeriesFilter(
        genres: genres,
        minRating: minRating,
        maxRating: maxRating,
        language: language,
        sortBy: sortBy,
        mood: mood,
        includeAdult: includeAdult,
        minVoteCount: minVoteCount,
        watchProviders: watchProviders,
        status: status,
        networks: networks,
        minSeasons: minSeasons,
        maxSeasons: maxSeasons,
        minEpisodes: minEpisodes,
        maxEpisodes: maxEpisodes,
        minEpisodeRuntime: minEpisodeRuntime,
        maxEpisodeRuntime: maxEpisodeRuntime,
      );

  bool get isEmpty {
    return genres.isEmpty &&
        minYear == null &&
        maxYear == null &&
        minRating == null &&
        maxRating == null &&
        language == null &&
        sortBy == null &&
        mood == null &&
        includeAdult == null &&
        minVoteCount == null &&
        watchProviders.isEmpty &&
        status == null &&
        networks.isEmpty &&
        minSeasons == null &&
        maxSeasons == null &&
        minEpisodes == null &&
        maxEpisodes == null &&
        minEpisodeRuntime == null &&
        maxEpisodeRuntime == null;
  }

  static String? statusToDiscoverValue(String? status) {
    switch (status) {
      case 'Returning Series':
        return '0';
      case 'In Production':
        return '1';
      case 'Planned':
        return '2';
      case 'Cancelled':
        return '3';
      case 'Ended':
        return '4';
      case 'Pilot':
        return '5';
      default:
        return status;
    }
  }

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{};

    if (genres.isNotEmpty) {
      params['with_genres'] = genres.join(',');
    }
    if (minYear != null) {
      params['first_air_date.gte'] = '$minYear-01-01';
    }
    if (maxYear != null) {
      params['first_air_date.lte'] = '$maxYear-12-31';
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
    if (watchProviders.isNotEmpty) {
      params['with_watch_providers'] = watchProviders.join(',');
    }
    final discoverStatus = statusToDiscoverValue(status);
    if (discoverStatus != null) {
      params['with_status'] = discoverStatus;
    }
    if (networks.isNotEmpty) {
      params['with_networks'] = networks.join(',');
    }
    if (minEpisodeRuntime != null) {
      params['with_episode_runtime.gte'] = minEpisodeRuntime;
    }
    if (maxEpisodeRuntime != null) {
      params['with_episode_runtime.lte'] = maxEpisodeRuntime;
    }

    return params;
  }
}
