import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';
import 'movies_repository_provider.dart';

final movieLoadFailuresProvider =
    NotifierProvider<_MovieIdSetNotifier, Set<String>>(_MovieIdSetNotifier.new);

final movieLoadInProgressProvider =
    NotifierProvider<_MovieIdSetNotifier, Set<String>>(_MovieIdSetNotifier.new);

class _MovieIdSetNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool contains(String id) => state.contains(id);

  void add(String id) => state = <String>{...state, id};

  void remove(String id) {
    if (!state.contains(id)) return;
    final updated = <String>{...state}..remove(id);
    state = updated;
  }

  void clear() => state = const <String>{};
}

// El provider ahora es un AsyncNotifierProvider que maneja un mapa de películas (caché).
final movieInfoProvider =
    AsyncNotifierProvider<MovieMapNotifier, Map<String, Movie>>(
  MovieMapNotifier.new,
);

// El Notifier maneja el estado asíncrono del mapa de películas.
class MovieMapNotifier extends AsyncNotifier<Map<String, Movie>> {
  @override
  FutureOr<Map<String, Movie>> build() {
    // El estado inicial es un mapa vacío, disponible síncronamente.
    return {};
  }

  Future<void> loadMovie(String movieId, {bool force = false}) async {
    final failuresNotifier = ref.read(movieLoadFailuresProvider.notifier);
    final loadingNotifier = ref.read(movieLoadInProgressProvider.notifier);

    if (!force && failuresNotifier.contains(movieId)) {
      LoggerFactory.debug(
          '🎬 MovieMapNotifier: omitiendo carga de $movieId por fallo previo');
      return;
    }

    if (loadingNotifier.contains(movieId)) {
      return;
    }

    if (force) {
      failuresNotifier.remove(movieId);
    }

    if (!force && (state.value?.containsKey(movieId) ?? false)) {
      return;
    }

    loadingNotifier.add(movieId);

    final currentMovies = Map<String, Movie>.from(state.value ?? {});

    final movieRepository = ref.read(movieRepositoryProvider);

    try {
      final movie = await movieRepository.getMovieById(movieId);
      failuresNotifier.remove(movieId);

      // Debug: Log movie before saving to state
      if (kDebugMode) {
        print(
            '🎬 MovieInfoProvider: Received movie ${movie.title} from repository');
        print('   Has credits: ${movie.credits != null}');
        if (movie.credits != null) {
          print(
              '   Cast length: ${(movie.credits!['cast'] as List?)?.length ?? 0}');
        }
      }

      final updatedMovies = Map<String, Movie>.from(currentMovies)
        ..[movieId] = movie;

      state = AsyncValue.data(Map<String, Movie>.unmodifiable(updatedMovies));

      // Debug: Verify movie in state
      if (kDebugMode) {
        print('🎬 MovieInfoProvider: Movie saved to state. Verifying...');
        final savedMovie = state.value?[movieId];
        if (savedMovie != null) {
          print('   Saved movie has credits: ${savedMovie.credits != null}');
          if (savedMovie.credits != null) {
            print(
                '   Saved cast length: ${(savedMovie.credits!['cast'] as List?)?.length ?? 0}');
          }
        }
      }
    } on MovieException catch (error, stackTrace) {
      if (error.code == 'MOVIE_NOT_FOUND') {
        LoggerFactory.warning(
            '🎬 MovieMapNotifier: Película no encontrada ($movieId). Se omitirá en la UI.');
        failuresNotifier.add(movieId);
        state = AsyncValue.data(Map<String, Movie>.unmodifiable(currentMovies));
      } else {
        LoggerFactory.error(
            '❌ MovieMapNotifier: Error específico al cargar película $movieId: ${error.message}');
        state = AsyncValue.error(error, stackTrace);
      }
    } catch (error, stackTrace) {
      LoggerFactory.error(
          '❌ MovieMapNotifier: Error inesperado al cargar película $movieId: $error');
      state = AsyncValue.error(error, stackTrace);
    } finally {
      loadingNotifier.remove(movieId);
    }
  }
}
