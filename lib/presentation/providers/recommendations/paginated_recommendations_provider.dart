import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/recommendation.dart';

/// Estado para las recomendaciones paginadas
class PaginatedRecommendationsState {
  const PaginatedRecommendationsState({
    this.movies = const [],
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.hasReachedMax = false,
    this.currentPage = 0,
  });

  final List<Movie> movies;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final bool hasReachedMax;
  final int currentPage;

  PaginatedRecommendationsState copyWith({
    List<Movie>? movies,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    bool? hasReachedMax,
    int? currentPage,
  }) {
    return PaginatedRecommendationsState(
      movies: movies ?? this.movies,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// Notifier para manejar las recomendaciones paginadas
class PaginatedRecommendationsNotifier
    extends Notifier<PaginatedRecommendationsState> {
  static const int _pageSize = 10;
  List<Recommendation> _allRecommendations = [];

  @override
  PaginatedRecommendationsState build() {
    // Return initial state without loading - let the UI trigger loading
    return const PaginatedRecommendationsState();
  }

  /// Convierte una Recommendation a Movie
  Movie _recommendationToMovie(Recommendation recommendation) {
    return Movie(
      id: recommendation.movieId,
      title: recommendation.title,
      overview: '', // No disponible en Recommendation
      posterPath: recommendation.posterPath,
      backdropPath: '', // No disponible en Recommendation
      releaseDate: DateTime.now(), // Valor por defecto
      genreIds: [], // No disponible en Recommendation
      voteAverage: recommendation.score * 10, // Convertir score a rating
      voteCount: 0, // No disponible en Recommendation
      popularity: recommendation.score * 100, // Usar score como popularidad
      adult: false, // Valor por defecto
      originalLanguage: 'en', // Valor por defecto
      originalTitle: recommendation.title,
      video: false, // Valor por defecto
    );
  }

  /// Load initial page method for compatibility with views
  Future<void> loadInitialPage() async {
    await _loadInitialRecommendations();
  }

  /// Carga las recomendaciones iniciales
  Future<void> _loadInitialRecommendations() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, hasError: false);

    try {
      // Para simplicidad, creamos recomendaciones simuladas
      // En un caso real, esto vendría del servicio de recomendaciones
      _allRecommendations = <Recommendation>[];

      // Convertir las primeras recomendaciones a películas
      final initialMovies = _allRecommendations
          .take(_pageSize)
          .map(_recommendationToMovie)
          .toList();

      state = state.copyWith(
        movies: initialMovies,
        isLoading: false,
        hasReachedMax: _allRecommendations.length <= _pageSize,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Carga la siguiente página
  Future<void> loadNextPage() async {
    if (state.isLoading || state.hasReachedMax) return;

    state = state.copyWith(isLoading: true);

    try {
      final startIndex = state.currentPage * _pageSize;
      final endIndex = startIndex + _pageSize;

      if (startIndex >= _allRecommendations.length) {
        state = state.copyWith(
          isLoading: false,
          hasReachedMax: true,
        );
        return;
      }

      final nextPageRecommendations = _allRecommendations
          .skip(startIndex)
          .take(_pageSize)
          .map(_recommendationToMovie)
          .toList();

      final updatedMovies = [...state.movies, ...nextPageRecommendations];

      state = state.copyWith(
        movies: updatedMovies,
        isLoading: false,
        currentPage: state.currentPage + 1,
        hasReachedMax: endIndex >= _allRecommendations.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refresca las recomendaciones
  Future<void> refresh() async {
    _allRecommendations.clear();
    state = const PaginatedRecommendationsState();
    await _loadInitialRecommendations();
  }
}

final paginatedRecommendationsProvider = NotifierProvider<
    PaginatedRecommendationsNotifier, PaginatedRecommendationsState>(
  () => PaginatedRecommendationsNotifier(),
);
