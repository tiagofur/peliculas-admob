import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/serie.dart';

class SerieCard extends StatelessWidget {
  const SerieCard({super.key, required this.serie});

  final Serie serie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/serie/${serie.id}'),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                resolvePosterUrl(serie.posterPath),
                width: 130,
                height: 195,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const SizedBox(width: 130, height: 195),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              serie.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
