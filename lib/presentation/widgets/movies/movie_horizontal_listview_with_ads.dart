import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/custom_scroll_behavior.dart';
import '../../../domain/entities/movie.dart';
import '../../../services/hybrid_image_service.dart';
import '../../providers/storage/direct_favorites_provider.dart';
import '../../providers/watched_movies_provider.dart';
import '../../screens/movies/movie_screen.dart';
import '../admob/ad_integration_helper.dart';
import '../admob/movie_card_ad_widget.dart';
import 'movie_rating.dart';

/// Versión mejorada de MovieHorizontalListview que integra anuncios
/// de forma natural entre las películas
class MovieHorizontalListviewWithAds extends StatefulWidget {
  const MovieHorizontalListviewWithAds({
    super.key,
    required this.movies,
    required this.sectionId,
    this.title,
    this.subTitle,
    this.loadNextPage,
    this.adFrequency = 5, // Mostrar anuncio cada 5 películas
    this.enableAds = true,
  });

  final List<Movie> movies;
  final String sectionId;
  final String? title;
  final String? subTitle;
  final VoidCallback? loadNextPage;
  final int adFrequency;
  final bool enableAds;

  @override
  State<MovieHorizontalListviewWithAds> createState() =>
      _MovieHorizontalListviewWithAdsState();
}

class _MovieHorizontalListviewWithAdsState
    extends State<MovieHorizontalListviewWithAds> {
  final scrollController = ScrollController();
  late List<AdListItem> _mixedItems;

  @override
  void initState() {
    super.initState();
    _updateMixedItems();

    scrollController.addListener(() {
      if (widget.loadNextPage == null) return;

      if ((scrollController.position.pixels + 200) >=
          scrollController.position.maxScrollExtent) {
        widget.loadNextPage!();
      }
    });
  }

  @override
  void didUpdateWidget(MovieHorizontalListviewWithAds oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies != widget.movies ||
        oldWidget.adFrequency != widget.adFrequency ||
        oldWidget.enableAds != widget.enableAds) {
      _updateMixedItems();
    }
  }

  void _updateMixedItems() {
    if (widget.enableAds) {
      _mixedItems = AdIntegrationHelper.createHorizontalAdList(
        widget.movies,
      );
    } else {
      _mixedItems =
          widget.movies.map((movie) => AdListItem.movie(movie)).toList();
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Column(
        children: [
          if (widget.title != null || widget.subTitle != null)
            _Title(title: widget.title, subTitle: widget.subTitle),
          Expanded(
            child: ScrollConfiguration(
              behavior: CustomScrollBehavior(),
              child: ListView.builder(
                controller: scrollController,
                itemCount: _mixedItems.length,
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = _mixedItems[index];

                  if (item.type == AdItemType.horizontalAd) {
                    return FadeInRight(
                      delay: Duration(milliseconds: index * 100),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: MovieCardAdWidget(),
                      ),
                    );
                  } else {
                    return FadeInRight(
                      delay: Duration(milliseconds: index * 100),
                      child: _Slide(
                        movie: item.movie!,
                        index: index,
                        sectionId: widget.sectionId,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends ConsumerStatefulWidget {
  const _Slide(
      {required this.movie, required this.index, required this.sectionId});

  final Movie movie;
  final int index;
  final String sectionId;

  @override
  ConsumerState<_Slide> createState() => _SlideState();
}

class _SlideState extends ConsumerState<_Slide>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  void _toggleFavorite(bool currentValue) {
    ref
        .read(directFavoriteMoviesProvider.notifier)
        .toggleFavorite(widget.movie);
  }

  void _toggleWatched(bool currentValue) {
    if (currentValue) {
      ref
          .read(watchedMoviesProvider.notifier)
          .removeFromWatched(widget.movie.id);
    } else {
      ref.read(watchedMoviesProvider.notifier).markAsWatched(widget.movie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final isWatched = ref.watch(isWatchedProvider(widget.movie.id));
    final isFavorite = ref.watch(directIsFavoriteProvider(widget.movie.id));

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //* Imagen con micro-interacciones
                GestureDetector(
                  onTap: () {
                    if (kIsWeb) {
                      context.go('/movie/${widget.movie.id}');
                    } else {
                      context.push('/movie/${widget.movie.id}');
                    }
                  },
                  child: MouseRegion(
                    onEnter: (_) => _onHover(true),
                    onExit: (_) => _onHover(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: _elevationAnimation.value,
                            offset: Offset(0, _elevationAnimation.value / 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 220,
                              width: 150,
                              child: OptimizedImage(
                                imageUrl: widget.movie.posterPath,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(20),
                                enableHeroAnimation: true,
                                heroTag:
                                    'horizontal-ads-${widget.sectionId}-${widget.movie.id}-${widget.index}',
                                placeholder: Container(
                                  height: 220,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey),
                                    ),
                                  ),
                                ),
                                errorWidget: Container(
                                  height: 220,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.movie,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Imagen no disponible',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Botones de acción
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Column(
                                children: [
                                  // Botón favorito
                                  _buildActionButton(
                                    icon: isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        isFavorite ? Colors.red : Colors.white,
                                    onPressed: () =>
                                        _toggleFavorite(isFavorite),
                                  ),

                                  const SizedBox(height: 4),

                                  // Botón visto
                                  _buildActionButton(
                                    icon: isWatched
                                        ? Icons.visibility
                                        : Icons.visibility_outlined,
                                    color:
                                        isWatched ? Colors.green : Colors.white,
                                    onPressed: () => _toggleWatched(isWatched),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                //* Title con animación
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  transform: Matrix4.translationValues(
                    0,
                    _isHovered ? -2 : 0,
                    0,
                  ),
                  child: Text(
                    widget.movie.title,
                    maxLines: 2,
                    style: textStyles.titleSmall?.copyWith(
                      color: _isHovered
                          ? Theme.of(context).primaryColor
                          : textStyles.titleSmall?.color,
                    ),
                  ),
                ),

                //* Rating con animación
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(
                    0,
                    _isHovered ? -2 : 0,
                    0,
                  ),
                  child: MovieRating(voteAverage: widget.movie.voteAverage),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({this.title, this.subTitle});

  final String? title;
  final String? subTitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return Container(
      padding: const EdgeInsets.only(top: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          if (title != null) Text(title!, style: titleStyle),
          const Spacer(),
          if (subTitle != null)
            FilledButton.tonal(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onPressed: () {},
              child: Text(subTitle!),
            )
        ],
      ),
    );
  }
}
