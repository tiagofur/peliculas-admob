import 'package:flutter_riverpod/legacy.dart';

import '../../../domain/entities/movie.dart';
import '../../../domain/entities/recommendation.dart';
// import 'recommendations_provider.dart'; // Unused import

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
    extends StateNotifier<PaginatedRecommendationsState> {
  PaginatedRecommendationsNotifier(/* this._ref */)
      : super(const PaginatedRecommendationsState()) {
    _loadInitialRecommendations();
  }

  // final Ref _ref; // TODO: Fix legacy compatibility
  static const int _pageSize = 10;
  List<Recommendation> _allRecommendations = [];

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

  /// Carga las recomendaciones iniciales
  Future<void> _loadInitialRecommendations() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, hasError: false);

    try {
      // TODO: Fix legacy compatibility - commented out _ref usage
      // final recommendationsAsync =
      //     _ref.read(personalizedRecommendationsProvider);
      final recommendationsAsync = <Recommendation>[]; // Temporary empty list

      // TODO: Fix legacy compatibility - simplified handling
      final recommendations = recommendationsAsync; // Already a list

      _allRecommendations = recommendations;

      final initialMovies = _allRecommendations
          .take(_pageSize)
          .map(_recommendationToMovie)
          .toList();

      state = state.copyWith(
        movies: initialMovies,
        isLoading: false,
        currentPage: 1,
        hasReachedMax: _allRecommendations.length <= _pageSize,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: error.toString(),
      );
    }
  }

  /// Carga la siguiente página de recomendaciones
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
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: error.toString(),
      );
    }
  }

  /// Carga la página inicial de recomendaciones (método público)
  Future<void> loadInitialPage() async {
    await _loadInitialRecommendations();
  }

  /// Refresca las recomendaciones
  Future<void> refresh() async {
    state = const PaginatedRecommendationsState();
    _allRecommendations = [];
    // _ref.invalidate(personalizedRecommendationsProvider); // TODO: Fix legacy compatibility
    await _loadInitialRecommendations();
  }
}

/// Provider para las recomendaciones paginadas
// TODO: Fix legacy compatibility for StateNotifierProvider
// final paginatedRecommendationsProvider = StateNotifierProvider<
//     PaginatedRecommendationsNotifier, PaginatedRecommendationsState>((ref) {
//   return PaginatedRecommendationsNotifier(ref);
// });
