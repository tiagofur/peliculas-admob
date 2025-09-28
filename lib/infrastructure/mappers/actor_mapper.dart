import '../../core/utils/tmdb_image_utils.dart';
import '../../domain/entities/actor.dart';
import '../models/moviedb/credits_response.dart';

class ActorMapper {
  static Actor castToEntity(Cast cast) => Actor(
        id: cast.id,
        name: cast.name,
        profilePath: resolvePosterUrl(
          cast.profilePath,
          size: 'w500',
          fallback:
              'https://st3.depositphotos.com/4111759/13425/v/600/depositphotos_134255710-stock-illustration-avatar-vector-male-profile-gray.jpg',
        ),
        character: cast.character,
      );
}
