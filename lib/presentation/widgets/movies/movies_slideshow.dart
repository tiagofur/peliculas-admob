import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/movie.dart';
import '../../../generated/app_localizations.dart';
import '../../../services/hybrid_image_service.dart';

class MoviesSlideshow extends StatelessWidget {
  const MoviesSlideshow({super.key, required this.movies});

  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 230,
      width: double.infinity,
      child: Swiper(
        viewportFraction: 0.8,
        scale: 0.9,
        autoplay: true,
        // card_swiper 3.0.1 simula el loop con 2e9 items y rompe la
        // assertion de precisión de scroll en Flutter actual.
        loop: false,
        pagination: SwiperPagination(
            margin: const EdgeInsets.only(top: 0),
            builder: DotSwiperPaginationBuilder(
                activeColor: colors.primary, color: colors.secondary)),
        itemCount: movies.length,
        itemBuilder: (context, index) => _Slide(movie: movies[index]),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    // Cinematic tvOS-style card: 14px radius with a soft lifted shadow.
    final decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 16, offset: Offset(0, 8))
        ]);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: DecoratedBox(
        decoration: decoration,
        child: GestureDetector(
          onTap: () => context.push('/movie/${movie.id}'),
          child: OptimizedImage(
            imageUrl: movie.backdropPath,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(14),
            enableHeroAnimation: true,
            heroTag: 'slideshow-${movie.id}',
            tmdbSize: 'w780',
            placeholder: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            ),
            errorWidget: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_outlined,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.imageNotAvailable,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.connectionError,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
