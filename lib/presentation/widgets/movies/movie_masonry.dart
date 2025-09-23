import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../domain/entities/movie.dart';
import '../admob/grid_ad_widget.dart';
import 'movie_poster_link.dart';

class MovieMasonry extends StatefulWidget {
  const MovieMasonry({super.key, required this.movies, this.loadNextPage});

  final List<Movie> movies;
  final VoidCallback? loadNextPage;

  @override
  State<MovieMasonry> createState() => _MovieMasonryState();
}

class _MovieMasonryState extends State<MovieMasonry> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    scrollController.addListener(() {
      if (widget.loadNextPage == null) return;

      if ((scrollController.position.pixels + 100) >=
          scrollController.position.maxScrollExtent) {
        widget.loadNextPage!();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el número total de items incluyendo anuncios
    final totalItems = _calculateTotalItems(widget.movies.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: MasonryGridView.count(
        controller: scrollController,
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: totalItems,
        // 🚀 PERFORMANCE: Cache widgets para mejor scroll en masonry
        cacheExtent: 500.0,
        itemBuilder: (context, index) {
          // 🚀 PERFORMANCE: RepaintBoundary para cada item del masonry
          return RepaintBoundary(
            child: _buildMasonryItem(index),
          );
        },
      ),
    );
  }

  /// 🚀 PERFORMANCE: Método optimizado para construir items del masonry
  Widget _buildMasonryItem(int index) {
    // Verificar si esta posición debe mostrar un anuncio
    if (_shouldShowAd(index)) {
      return const GridAdWidget(
        aspectRatio: 0.7,
        showLabel: true,
        borderRadius: 12,
      );
    }

    // Calcular el índice real de la película
    final movieIndex = _getMovieIndex(index);

    if (movieIndex == 1) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        child: MoviePosterLink(movie: widget.movies[movieIndex]),
      );
    }

    return MoviePosterLink(movie: widget.movies[movieIndex]);
  }

  /// Calcula el número total de items incluyendo anuncios
  int _calculateTotalItems(int movieCount) {
    if (movieCount <= 6) {
      return movieCount; // No mostrar anuncios si hay pocas películas
    }
    return movieCount + (movieCount ~/ 9); // Un anuncio cada 9 películas
  }

  /// Determina si en esta posición se debe mostrar un anuncio
  bool _shouldShowAd(int index) {
    if (widget.movies.length <= 6) {
      return false; // No mostrar anuncios si hay pocas películas
    }
    return (index + 1) % 10 == 0; // Mostrar anuncio cada 10 posiciones
  }

  /// Calcula el índice real de la película considerando los anuncios insertados
  int _getMovieIndex(int displayIndex) {
    if (widget.movies.length <= 6) return displayIndex;
    final adsBeforeIndex = displayIndex ~/ 10;
    return displayIndex - adsBeforeIndex;
  }
}
