import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/movie.dart';
import 'movies_repository_provider.dart';

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

  Future<void> loadMovie(String movieId) async {
    // No hacer nada si ya existe la película en el estado actual.
    if (state.value?.containsKey(movieId) ?? false) return;

    // Obtener el estado actual para no perder las películas ya cargadas.
    final currentMovies = state.value ?? {};

    // Poner el estado en modo 'loading' pero manteniendo los datos anteriores.
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Obtener la película del repositorio.
      final movieRepository = ref.read(movieRepositoryProvider);
      final movie = await movieRepository.getMovieById(movieId);
      // Retornar el nuevo mapa con la película añadida.
      return {...currentMovies, movieId: movie};
    });
  }
}
