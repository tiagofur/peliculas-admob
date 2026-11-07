import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';

class SeriesFilterNotifier extends Notifier<SeriesFilter> {
  @override
  SeriesFilter build() => const SeriesFilter();

  void updateGenres(List<int> genres) {
    state = state.copyWith(genres: genres);
  }

  void updateYearRange(int? minYear, int? maxYear) {
    var next = state.copyWith(minYear: minYear, maxYear: maxYear);
    if (minYear == null && maxYear == null) {
      next = next.clearYearRange();
    }
    state = next;
  }

  void updateRatingRange(double? minRating, double? maxRating) {
    state = state.copyWith(minRating: minRating, maxRating: maxRating);
  }

  void updateSortBy(String? sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void resetFilters() {
    state = const SeriesFilter();
  }

  void clearFilters() {
    resetFilters();
  }

  void updateMood(String? mood) {
    state = state.copyWith(mood: mood);
  }

  void updateLanguage(String? language) {
    state = state.copyWith(language: language);
  }

  void updateIncludeAdult(bool? includeAdult) {
    state = state.copyWith(includeAdult: includeAdult);
  }

  void updateMinVoteCount(int? minVoteCount) {
    state = state.copyWith(minVoteCount: minVoteCount);
  }

  void updateWatchProviders(List<String> watchProviders) {
    state = state.copyWith(watchProviders: watchProviders);
  }

  void updateStatus(String? status) {
    state = state.copyWith(status: status);
  }

  void updateNetworks(List<int> networks) {
    state = state.copyWith(networks: networks);
  }

  void updateSeasonsRange(int? minSeasons, int? maxSeasons) {
    state = state.copyWith(minSeasons: minSeasons, maxSeasons: maxSeasons);
  }

  void updateEpisodesRange(int? minEpisodes, int? maxEpisodes) {
    state =
        state.copyWith(minEpisodes: minEpisodes, maxEpisodes: maxEpisodes);
  }

  void updateEpisodeRuntimeRange(int? minRuntime, int? maxRuntime) {
    state = state.copyWith(
        minEpisodeRuntime: minRuntime, maxEpisodeRuntime: maxRuntime);
  }

  void applyMoodFilter(MoodOption mood) {
    state = state.copyWith(
      mood: mood.id,
      genres: mood.associatedGenres,
    );
  }
}

final seriesFilterProvider =
    NotifierProvider<SeriesFilterNotifier, SeriesFilter>(
  () => SeriesFilterNotifier(),
);

final seriesFiltersNotifierProvider = seriesFilterProvider;

typedef SeriesFiltersNotifier = SeriesFilterNotifier;

class SeriesGenreOptionsNotifier extends Notifier<List<GenreOption>> {
  @override
  List<GenreOption> build() => [
        const GenreOption(id: 10759, name: 'Acción y Aventura', emoji: '💥'),
        const GenreOption(id: 16, name: 'Animación', emoji: '🎨'),
        const GenreOption(id: 35, name: 'Comedia', emoji: '😂'),
        const GenreOption(id: 80, name: 'Crimen', emoji: '🔫'),
        const GenreOption(id: 99, name: 'Documental', emoji: '📹'),
        const GenreOption(id: 18, name: 'Drama', emoji: '🎭'),
        const GenreOption(id: 10751, name: 'Familiar', emoji: '👨‍👩‍👧‍👦'),
        const GenreOption(id: 10762, name: 'Infantil', emoji: '🧸'),
        const GenreOption(id: 9648, name: 'Misterio', emoji: '🔍'),
        const GenreOption(id: 10763, name: 'Noticias', emoji: '📰'),
        const GenreOption(id: 10764, name: 'Reality', emoji: '📺'),
        const GenreOption(id: 10765, name: 'Ciencia Ficción y Fantasía', emoji: '🚀'),
        const GenreOption(id: 10766, name: 'Telenovela', emoji: '💕'),
        const GenreOption(id: 10767, name: 'Talk Show', emoji: '🎙️'),
        const GenreOption(id: 10768, name: 'Bélica y Política', emoji: '⚔️'),
        const GenreOption(id: 37, name: 'Western', emoji: '🤠'),
      ];
}

final seriesGenreOptionsProvider =
    NotifierProvider<SeriesGenreOptionsNotifier, List<GenreOption>>(
  () => SeriesGenreOptionsNotifier(),
);

final seriesSortOptionsProvider = Provider<List<SortOption>>((ref) {
  return [
    const SortOption(
      value: 'popularity.desc',
      label: 'Más Populares',
      description: 'Ordenar por popularidad descendente',
      icon: Icons.trending_up,
    ),
    const SortOption(
      value: 'vote_average.desc',
      label: 'Mejor Calificadas',
      description: 'Ordenar por calificación descendente',
      icon: Icons.star,
    ),
    const SortOption(
      value: 'first_air_date.desc',
      label: 'Más Recientes',
      description: 'Ordenar por fecha de estreno descendente',
      icon: Icons.new_releases,
    ),
    const SortOption(
      value: 'vote_count.desc',
      label: 'Más Votadas',
      description: 'Ordenar por número de votos descendente',
      icon: Icons.how_to_vote,
    ),
    const SortOption(
      value: 'original_title.asc',
      label: 'Alfabético A-Z',
      description: 'Ordenar alfabéticamente',
      icon: Icons.sort_by_alpha,
    ),
  ];
});
