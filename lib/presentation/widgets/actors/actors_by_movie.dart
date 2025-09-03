import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/hybrid_image_service.dart';
import '../../providers/actors/actors_by_movie_provider.dart';

class ActorsByMovie extends ConsumerWidget {
  const ActorsByMovie({super.key, required this.movieId});

  final String movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorsByMovie = ref.watch(actorsByMovieProvider);

    //* Loading actors
    final actors = actorsByMovie[movieId];
    if (actors == null) {
      return Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 50),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: actors.length,
        itemBuilder: (context, index) {
          final actor = actors[index];

          return Container(
            padding: const EdgeInsets.all(8.0),
            width: 135,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Actor Photo
                FadeInRight(
                  child: SizedBox(
                    height: 180,
                    width: 135,
                    child: OptimizedImage(
                      imageUrl: actor.profilePath,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(20),
                      enableHeroAnimation: true,
                      heroTag: 'actor-${actor.id}',
                      placeholder: Container(
                        height: 180,
                        width: 135,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          ),
                        ),
                      ),
                      errorWidget: Container(
                        height: 180,
                        width: 135,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Perfil no\ndisponible',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Nombre
                const SizedBox(
                  height: 5,
                ),

                Text(actor.name, maxLines: 2),
                Text(
                  actor.character ?? '',
                  maxLines: 2,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
