import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/services/genre_service.dart';

/// Provider para el servicio de géneros
final genreServiceProvider = Provider<GenreService>((ref) {
  return GenreService.instance;
});

/// Provider para obtener todos los géneros
final genresProvider = FutureProvider<Map<int, String>>((ref) async {
  final genreService = ref.watch(genreServiceProvider);
  return await genreService.getGenres();
});

/// Provider para obtener el nombre de un género específico
final genreNameProvider =
    FutureProvider.family<String, int>((ref, genreId) async {
  final genreService = ref.watch(genreServiceProvider);
  return await genreService.getGenreName(genreId);
});

/// Provider para obtener los nombres de múltiples géneros
final genreNamesProvider =
    FutureProvider.family<List<String>, List<int>>((ref, genreIds) async {
  final genreService = ref.watch(genreServiceProvider);
  return await genreService.getGenreNames(genreIds);
});
