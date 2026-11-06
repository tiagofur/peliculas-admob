import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/datasources/actors_datasource.dart';
import 'package:peliculas/domain/entities/actor.dart';
import 'package:peliculas/domain/entities/actor_details.dart';
import 'package:peliculas/infrastructure/mappers/actor_mapper.dart';
import 'package:peliculas/infrastructure/models/moviedb/person_details_response.dart';
import 'package:peliculas/infrastructure/repositories/actor_repository_impl.dart';
import 'package:peliculas/presentation/providers/actors/actor_details_provider.dart';
import 'package:peliculas/presentation/providers/actors/actors_repository_provider.dart';

class _FakeActorsDatasource extends ActorsDatasource {
  @override
  Future<List<Actor>> getActorsByMovie(String movieId) =>
      throw UnimplementedError();

  @override
  Future<ActorDetails> getActorDetails(String personId) async =>
      const ActorDetails(
        id: 3223,
        name: 'Robert Downey Jr.',
        biography: 'Actor estadounidense.',
        birthday: '1965-04-04',
        placeOfBirth: 'Manhattan, New York, USA',
        profilePath: '/profile.jpg',
        knownForDepartment: 'Acting',
        popularity: 35.5,
      );

  @override
  Future<List<ActorMovieCredit>> getActorMovieCredits(String personId) async =>
      const [
        ActorMovieCredit(
          id: 299534,
          title: 'Avengers: Endgame',
          posterPath: '/endgame.jpg',
          character: 'Tony Stark / Iron Man',
          releaseDate: '2019-04-24',
          voteAverage: 8.2,
        ),
      ];
}

void main() {
  group('PersonDetailsResponse', () {
    test('parsea el detalle de persona de TMDB', () {
      final response = PersonDetailsResponse.fromJson({
        'id': 3223,
        'name': 'Robert Downey Jr.',
        'biography': 'Actor estadounidense.',
        'birthday': '1965-04-04',
        'deathday': null,
        'place_of_birth': 'Manhattan, New York, USA',
        'profile_path': '/profile.jpg',
        'known_for_department': 'Acting',
        'popularity': 35.5,
      });

      final entity = ActorMapper.personDetailsToEntity(response);

      expect(entity.id, 3223);
      expect(entity.name, 'Robert Downey Jr.');
      expect(entity.biography, 'Actor estadounidense.');
      expect(entity.birthday, '1965-04-04');
      expect(entity.placeOfBirth, 'Manhattan, New York, USA');
      expect(entity.profilePath, '/profile.jpg');
      expect(entity.knownForDepartment, 'Acting');
    });

    test('ordena los créditos por popularidad descendente', () {
      final response = PersonMovieCreditsResponse.fromJson({
        'id': 3223,
        'cast': [
          {
            'id': 1,
            'title': 'Peli menor',
            'poster_path': '/menor.jpg',
            'character': 'Extra',
            'release_date': '1990-01-01',
            'vote_average': 5.0,
            'popularity': 2.0,
          },
          {
            'id': 299534,
            'title': 'Avengers: Endgame',
            'poster_path': '/endgame.jpg',
            'character': 'Tony Stark / Iron Man',
            'release_date': '2019-04-24',
            'vote_average': 8.2,
            'popularity': 120.5,
          },
        ],
      });

      final credits = ActorMapper.personCreditsToEntities(response);

      expect(credits.length, 2);
      expect(credits.first.id, 299534);
      expect(credits.first.character, 'Tony Stark / Iron Man');
    });
  });

  group('actorDetailsProvider', () {
    test('expone el detalle y la filmografía del actor', () async {
      final container = ProviderContainer(
        overrides: [
          actorsRepositoryProvider.overrideWithValue(
            ActorRepositoryImpl(_FakeActorsDatasource()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final details = await container.read(actorDetailsProvider('3223').future);
      expect(details.name, 'Robert Downey Jr.');

      final credits = await container.read(
        actorMovieCreditsProvider('3223').future,
      );
      expect(credits.length, 1);
      expect(credits.first.title, 'Avengers: Endgame');
    });
  });
}
