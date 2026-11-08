import '../../core/utils/tmdb_image_utils.dart';
import '../../domain/entities/actor.dart';
import '../../domain/entities/actor_details.dart';
import '../models/moviedb/credits_response.dart';
import '../models/moviedb/person_details_response.dart';

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

  static ActorDetails personDetailsToEntity(PersonDetailsResponse person) =>
      ActorDetails(
        id: person.id,
        name: person.name,
        biography: person.biography,
        profilePath: person.profilePath,
        knownForDepartment: person.knownForDepartment,
        popularity: person.popularity,
        birthday: person.birthday,
        deathday: person.deathday,
        placeOfBirth: person.placeOfBirth,
      );

  static List<ActorMovieCredit> personCreditsToEntities(
    PersonMovieCreditsResponse credits,
  ) {
    final sorted = List<PersonMovieCredit>.from(credits.cast)
      ..sort((a, b) => b.popularity.compareTo(a.popularity));

    return sorted
        .map(
          (credit) => ActorMovieCredit(
            id: credit.id,
            title: credit.title,
            posterPath: credit.posterPath,
            character: credit.character,
            releaseDate: credit.releaseDate,
            voteAverage: credit.voteAverage,
          ),
        )
        .toList();
  }
}
