import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../domain/entities/movie.dart';
import '../admob/ad_integration_helper.dart';
import '../admob/full_width_ad_widget.dart';
import '../admob/grid_ad_widget.dart';
import '../admob/web_safe_ad_widgets.dart';
import 'movie_card_with_actions.dart';

/// Versión mejorada de MovieMasonry que integra anuncios
/// tanto como tarjetas individuales como líneas completas
class MovieMasonryWithAds extends StatefulWidget {
  const MovieMasonryWithAds({
    super.key,
    required this.movies,
    required this.loadNextPage,
    this.gridAdFrequency = 9, // Anuncio de tarjeta cada 9 películas
    this.fullWidthAdFrequency =
        15, // Anuncio de línea completa cada 15 películas
    this.enableGridAds = true,
    this.enableFullWidthAds = true,
  });

  final List<Movie> movies;
  final VoidCallback loadNextPage;
  final int gridAdFrequency;
  final int fullWidthAdFrequency;
  final bool enableGridAds;
  final bool enableFullWidthAds;

  @override
  State<MovieMasonryWithAds> createState() => _MovieMasonryWithAdsState();
}

class _MovieMasonryWithAdsState extends State<MovieMasonryWithAds> {
  late List<AdListItem> _mixedItems;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _updateMixedItems();
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(MovieMasonryWithAds oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies != widget.movies ||
        oldWidget.gridAdFrequency != widget.gridAdFrequency ||
        oldWidget.fullWidthAdFrequency != widget.fullWidthAdFrequency ||
        oldWidget.enableGridAds != widget.enableGridAds ||
        oldWidget.enableFullWidthAds != widget.enableFullWidthAds) {
      _updateMixedItems();
    }
  }

  void _updateMixedItems() {
    _mixedItems = AdIntegrationHelper.createGridAdList(
      widget.movies,
    );
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if ((_scrollController.position.pixels + 200) >=
          _scrollController.position.maxScrollExtent) {
        widget.loadNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ RESPONSIVE OPTIMIZATION: Adaptive grid based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth > 1200) {
      crossAxisCount = 6; // Desktop/large tablet
    } else if (screenWidth > 900) {
      crossAxisCount = 5; // Large tablet
    } else if (screenWidth > 600) {
      crossAxisCount = 4; // Tablet portrait
    } else if (screenWidth > 400) {
      crossAxisCount = 3; // Large phone
    } else {
      crossAxisCount = 2; // Small phone
    }

    return MasonryGridView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _mixedItems.length,
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
      ),
      itemBuilder: (context, index) {
        final item = _mixedItems[index];

        switch (item.type) {
          case AdItemType.movie:
            if (item.movie != null) {
              return _MovieCard(movie: item.movie!);
            }
            return const SizedBox.shrink();

          case AdItemType.gridAd:
            return const _GridAdCard();

          case AdItemType.fullWidthAd:
            return const _FullWidthAdCard();

          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Widget que encapsula una película en el grid
class _MovieCard extends StatelessWidget {
  const _MovieCard({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: MovieCardWithActions(movie: movie),
    );
  }
}

/// Widget que encapsula un anuncio de grid
class _GridAdCard extends StatelessWidget {
  const _GridAdCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(4),
      child: kIsWeb
          ? WebSafeGridAdWidget()
          : GridAdWidget(
              aspectRatio: 0.7, // Mismo ratio que los posters de películas
              showLabel: true,
            ),
    );
  }
}

/// Widget que encapsula un anuncio de ancho completo
/// Ocupa las 3 columnas del grid
class _FullWidthAdCard extends StatelessWidget {
  const _FullWidthAdCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Usar el ancho completo disponible
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: kIsWeb
          ? const SizedBox.shrink()
          : const CompactFullWidthAdWidget(
              margin: EdgeInsets.zero,
            ),
    );
  }
}

/// Versión simplificada sin anuncios de línea completa
class MovieMasonryWithGridAdsOnly extends StatelessWidget {
  const MovieMasonryWithGridAdsOnly({
    super.key,
    required this.movies,
    required this.loadNextPage,
    this.adFrequency = 9,
  });

  final List<Movie> movies;
  final VoidCallback loadNextPage;
  final int adFrequency;

  @override
  Widget build(BuildContext context) {
    return MovieMasonryWithAds(
      movies: movies,
      loadNextPage: loadNextPage,
      gridAdFrequency: adFrequency,
      enableGridAds: true,
      enableFullWidthAds: false,
    );
  }
}

/// Versión premium con más anuncios para mayor monetización
class PremiumMovieMasonryWithAds extends StatelessWidget {
  const PremiumMovieMasonryWithAds({
    super.key,
    required this.movies,
    required this.loadNextPage,
  });

  final List<Movie> movies;
  final VoidCallback loadNextPage;

  @override
  Widget build(BuildContext context) {
    return MovieMasonryWithAds(
      movies: movies,
      loadNextPage: loadNextPage,
      gridAdFrequency: 6, // Más frecuentes
      fullWidthAdFrequency: 12, // Más frecuentes
      enableGridAds: true,
      enableFullWidthAds: true,
    );
  }
}

/// Versión conservadora con menos anuncios para mejor UX
class ConservativeMovieMasonryWithAds extends StatelessWidget {
  const ConservativeMovieMasonryWithAds({
    super.key,
    required this.movies,
    required this.loadNextPage,
  });

  final List<Movie> movies;
  final VoidCallback loadNextPage;

  @override
  Widget build(BuildContext context) {
    return MovieMasonryWithAds(
      movies: movies,
      loadNextPage: loadNextPage,
      gridAdFrequency: 12, // Menos frecuentes
      fullWidthAdFrequency: 21, // Menos frecuentes (múltiplo de 3)
      enableGridAds: true,
      enableFullWidthAds: true,
    );
  }
}

/// Widget unificado para mostrar anuncios en cualquier lista de películas
/// Estrategia: Sin anuncios para <4 películas, 1 anuncio al final para 4-6 películas,
/// para 7+ películas: primer anuncio en posiciones 4-6, luego cada 8-10 películas con posicionamiento aleatorio
class MasonryWithAds extends StatefulWidget {
  const MasonryWithAds({
    super.key,
    required this.movies,
    this.loadNextPage,
    this.crossAxisCount = 3,
  });

  final List<Movie> movies;
  final VoidCallback? loadNextPage;
  final int crossAxisCount;

  @override
  State<MasonryWithAds> createState() => _MasonryWithAdsState();
}

/// Alias para compatibilidad con código existente
typedef FavoritesMasonryWithAds = MasonryWithAds;

class _MasonryWithAdsState extends State<MasonryWithAds> {
  final ScrollController _scrollController = ScrollController();
  late List<AdListItem> _mixedItems;

  @override
  void initState() {
    super.initState();
    _updateMixedItems();
    _setupScrollListener();
  }

  @override
  void didUpdateWidget(MasonryWithAds oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies != widget.movies) {
      _updateMixedItems();
    }
  }

  void _updateMixedItems() {
    _mixedItems = _createAdList();
  }

  void _setupScrollListener() {
    if (widget.loadNextPage != null) {
      _scrollController.addListener(() {
        if ((_scrollController.position.pixels + 200) >=
            _scrollController.position.maxScrollExtent) {
          widget.loadNextPage!();
        }
      });
    }
  }

  List<AdListItem> _createAdList() {
    final List<AdListItem> mixedList = [];
    final movieCount = widget.movies.length;

    if (movieCount == 0) {
      return mixedList;
    }

    // Usar Random con seed basado en el número de películas para consistencia
    final random = Random(movieCount);

    // Calcular posiciones de anuncios con lógica simplificada y robusta
    final Set<int> adPositions = <int>{};

    if (movieCount < 4) {
      // Para menos de 4 películas: no mostrar anuncios (muy pocas películas)
      // No se agregan posiciones de anuncios
    } else if (movieCount < 7) {
      // Para 4-6 películas: 1 anuncio al final de la lista
      adPositions.add(movieCount - 1); // Último índice
    } else {
      // Para 7+ películas: primer anuncio entre posiciones 4-6, luego cada 8-10 películas
      int currentPos =
          3 + random.nextInt(3); // índices 3, 4, 5 (posiciones 4, 5, 6)

      while (currentPos < movieCount) {
        adPositions.add(currentPos);
        // Siguiente anuncio en intervalo aleatorio de 8-10 posiciones
        currentPos += 8 + random.nextInt(3);
      }
    }

    // Agregar películas y anuncios en las posiciones calculadas
    for (int i = 0; i < movieCount; i++) {
      mixedList.add(AdListItem.movie(widget.movies[i]));

      if (adPositions.contains(i)) {
        mixedList.add(AdListItem.gridAd());
      }
    }

    return mixedList;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) {
      return const SizedBox.shrink();
    }

    return MasonryGridView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _mixedItems.length,
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
      ),
      itemBuilder: (context, index) {
        final item = _mixedItems[index];

        switch (item.type) {
          case AdItemType.movie:
            if (item.movie != null) {
              return _MovieCard(movie: item.movie!);
            }
            return const SizedBox.shrink();

          case AdItemType.gridAd:
            return const _GridAdCard();

          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// Alias para compatibilidad con código existente
typedef CustomListMasonryWithAds = MasonryWithAds;

/// Alias para compatibilidad con código existente
typedef WatchedMasonryWithAds = MasonryWithAds;
