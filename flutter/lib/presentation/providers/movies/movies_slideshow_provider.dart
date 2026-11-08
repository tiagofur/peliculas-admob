import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/movie.dart';
import 'movies_providers.dart';

final moviesSlideshowProvider = Provider<List<Movie>>((ref) {
  try {
    final nowPlayingState = ref.watch(nowPlayingMoviesProvider);
    final nowPlayingMovies = nowPlayingState.movies;

    if (nowPlayingMovies.isEmpty) return [];

    // Return up to 6 movies for slideshow, or less if we have less
    final count = nowPlayingMovies.length < 6 ? nowPlayingMovies.length : 6;
    return nowPlayingMovies.sublist(0, count);
  } catch (e) {
    // If there's any error, return empty list to avoid blocking UI
    return [];
  }
});
