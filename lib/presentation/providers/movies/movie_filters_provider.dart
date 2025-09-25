import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';

// Provider para el filtro actual
class MovieFilterNotifier extends Notifier<MovieFilter> {
  @override
  MovieFilter build() => const MovieFilter();

  void updateGenres(List<String> genres) {
    state = state.copyWith(genres: genres);
  }

  void updateYearRange(int? minYear, int? maxYear) {
    state = state.copyWith(minYear: minYear, maxYear: maxYear);
  }

  void updateDurationRange(int? minDuration, int? maxDuration) {
    state = state.copyWith(minDuration: minDuration, maxDuration: maxDuration);
  }

  void updateRatingRange(double? minRating, double? maxRating) {
    state = state.copyWith(minRating: minRating, maxRating: maxRating);
  }

  void updateSortBy(String? sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void resetFilters() {
    state = const MovieFilter();
  }

  // Alias para compatibilidad con código existente
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

  void updateKeywords(List<String> keywords) {
    state = state.copyWith(keywords: keywords);
  }

  void updateCertification(String? certification) {
    state = state.copyWith(certification: certification);
  }

  void updateWatchProviders(List<String> watchProviders) {
    state = state.copyWith(watchProviders: watchProviders);
  }

  void applyMoodFilter(MoodOption mood) {
    state = state.copyWith(
      mood: mood.id,
      genres: mood.associatedGenres,
    );
  }

  void applyQuickFilter({
    String? type,
    List<String>? genres,
    double? minRating,
    int? minYear,
    String? sortBy,
  }) {
    state = state.copyWith(
      genres: genres ?? state.genres,
      minRating: minRating ?? state.minRating,
      minYear: minYear ?? state.minYear,
      sortBy: sortBy ?? state.sortBy,
    );
  }
}

final movieFilterProvider = NotifierProvider<MovieFilterNotifier, MovieFilter>(
  () => MovieFilterNotifier(),
);

// Alias para compatibilidad con código existente
final movieFiltersNotifierProvider = movieFilterProvider;

// Alias para compatibilidad con código existente
typedef MovieFiltersNotifier = MovieFilterNotifier;

// Provider para las opciones de géneros
class GenreOptionsNotifier extends Notifier<List<GenreOption>> {
  @override
  List<GenreOption> build() => [
        const GenreOption(id: '28', name: 'Acción', emoji: '💥'),
        const GenreOption(id: '12', name: 'Aventura', emoji: '🗺️'),
        const GenreOption(id: '16', name: 'Animación', emoji: '🎨'),
        const GenreOption(id: '35', name: 'Comedia', emoji: '😂'),
        const GenreOption(id: '80', name: 'Crimen', emoji: '🔫'),
        const GenreOption(id: '99', name: 'Documental', emoji: '📹'),
        const GenreOption(id: '18', name: 'Drama', emoji: '🎭'),
        const GenreOption(id: '10751', name: 'Familiar', emoji: '👨‍👩‍👧‍👦'),
        const GenreOption(id: '14', name: 'Fantasía', emoji: '🧙‍♂️'),
        const GenreOption(id: '36', name: 'Historia', emoji: '📜'),
        const GenreOption(id: '27', name: 'Terror', emoji: '👻'),
        const GenreOption(id: '10402', name: 'Música', emoji: '🎵'),
        const GenreOption(id: '9648', name: 'Misterio', emoji: '🔍'),
        const GenreOption(id: '10749', name: 'Romance', emoji: '💕'),
        const GenreOption(id: '878', name: 'Ciencia Ficción', emoji: '🚀'),
        const GenreOption(id: '10770', name: 'Película de TV', emoji: '📺'),
        const GenreOption(id: '53', name: 'Thriller', emoji: '😰'),
        const GenreOption(id: '10752', name: 'Guerra', emoji: '⚔️'),
        const GenreOption(id: '37', name: 'Western', emoji: '🤠'),
      ];
}

final genreOptionsProvider =
    NotifierProvider<GenreOptionsNotifier, List<GenreOption>>(
  () => GenreOptionsNotifier(),
);

// Provider para las opciones de ordenamiento
final sortOptionsProvider = Provider<List<SortOption>>((ref) {
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
      value: 'primary_release_date.desc',
      label: 'Más Recientes',
      description: 'Ordenar por fecha de estreno descendente',
      icon: Icons.new_releases,
    ),
    const SortOption(
      value: 'revenue.desc',
      label: 'Mayor Recaudación',
      description: 'Ordenar por ingresos descendente',
      icon: Icons.attach_money,
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

// Provider para las opciones de estado de ánimo
final moodOptionsProvider = Provider<List<MoodOption>>((ref) {
  return [
    const MoodOption(
      id: 'happy',
      name: 'Feliz',
      description: 'Para cuando quieres reír y pasarla bien',
      emoji: '😄',
      color: Colors.yellow,
      associatedGenres: ['35', '10751', '16'], // Comedia, Familiar, Animación
    ),
    const MoodOption(
      id: 'romantic',
      name: 'Romántico',
      description: 'Para una noche especial con tu pareja',
      emoji: '💕',
      color: Colors.pink,
      associatedGenres: ['10749', '18'], // Romance, Drama
    ),
    const MoodOption(
      id: 'adventurous',
      name: 'Aventurero',
      description: 'Para cuando buscas emociones fuertes',
      emoji: '🗺️',
      color: Colors.orange,
      associatedGenres: [
        '12',
        '28',
        '878'
      ], // Aventura, Acción, Ciencia Ficción
    ),
    const MoodOption(
      id: 'thoughtful',
      name: 'Reflexivo',
      description: 'Para cuando quieres algo profundo',
      emoji: '🤔',
      color: Colors.purple,
      associatedGenres: ['18', '99', '36'], // Drama, Documental, Historia
    ),
    const MoodOption(
      id: 'scary',
      name: 'Escalofriante',
      description: 'Para los amantes del terror',
      emoji: '👻',
      color: Colors.red,
      associatedGenres: ['27', '53'], // Terror, Thriller
    ),
    const MoodOption(
      id: 'nostalgic',
      name: 'Nostálgico',
      description: 'Para recordar los clásicos',
      emoji: '📼',
      color: Colors.brown,
      associatedGenres: ['36', '10402', '37'], // Historia, Música, Western
    ),
    const MoodOption(
      id: 'mysterious',
      name: 'Misterioso',
      description: 'Para resolver enigmas',
      emoji: '🔍',
      color: Colors.indigo,
      associatedGenres: ['9648', '80', '53'], // Misterio, Crimen, Thriller
    ),
    const MoodOption(
      id: 'fantastical',
      name: 'Fantástico',
      description: 'Para escapar a otros mundos',
      emoji: '🧙‍♂️',
      color: Colors.teal,
      associatedGenres: [
        '14',
        '878',
        '16'
      ], // Fantasía, Ciencia Ficción, Animación
    ),
  ];
});

// Provider para verificar si hay filtros activos
final hasActiveFiltersProvider = Provider<bool>((ref) {
  final filter = ref.watch(movieFilterProvider);
  return !filter.isEmpty;
});

// Provider para contar filtros activos
final activeFiltersCountProvider = Provider<int>((ref) {
  final filter = ref.watch(movieFilterProvider);
  int count = 0;

  if (filter.genres.isNotEmpty) count++;
  if (filter.minYear != null || filter.maxYear != null) count++;
  if (filter.minDuration != null || filter.maxDuration != null) count++;
  if (filter.minRating != null || filter.maxRating != null) count++;
  if (filter.language != null) count++;
  if (filter.sortBy != null) count++;
  if (filter.mood != null) count++;
  if (filter.includeAdult != null) count++;
  if (filter.minVoteCount != null) count++;
  if (filter.keywords.isNotEmpty) count++;
  if (filter.certification != null) count++;
  if (filter.watchProviders.isNotEmpty) count++;

  return count;
});
