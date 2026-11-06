import 'package:dio/dio.dart';

import '../../config/constants/environment.dart';
import '../../domain/datasources/actors_datasource.dart';
import '../../domain/entities/actor.dart';
import '../../domain/entities/actor_details.dart';
import '../mappers/actor_mapper.dart';
import '../models/moviedb/credits_response.dart';
import '../models/moviedb/person_details_response.dart';

class ActorMovieDbDatasource extends ActorsDatasource {
  final dio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      queryParameters: {
        'api_key': Environment.theMovieDbKey,
        'language': 'es-MX'
      }));

  @override
  Future<List<Actor>> getActorsByMovie(String movieId) async {
    final response = await dio.get('/movie/$movieId/credits');

    final castResponse = CreditsResponse.fromJson(response.data);

    List<Actor> actors = castResponse.cast
        .map((cast) => ActorMapper.castToEntity(cast))
        .toList();

    return actors;
  }

  @override
  Future<ActorDetails> getActorDetails(String personId) async {
    final response = await dio.get('/person/$personId');

    final detailsResponse = PersonDetailsResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );

    return ActorMapper.personDetailsToEntity(detailsResponse);
  }

  @override
  Future<List<ActorMovieCredit>> getActorMovieCredits(String personId) async {
    final response = await dio.get('/person/$personId/movie_credits');

    final creditsResponse = PersonMovieCreditsResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );

    return ActorMapper.personCreditsToEntities(creditsResponse);
  }
}
