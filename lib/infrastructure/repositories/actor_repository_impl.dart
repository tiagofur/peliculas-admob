import '../../domain/datasources/actors_datasource.dart';
import '../../domain/entities/actor.dart';
import '../../domain/entities/actor_details.dart';
import '../../domain/repositories/actors_repository.dart';

class ActorRepositoryImpl extends ActorsRepository {
  ActorRepositoryImpl(this.datasource);

  final ActorsDatasource datasource;

  @override
  Future<List<Actor>> getActorsByMovie(String movieId) {
    return datasource.getActorsByMovie(movieId);
  }

  @override
  Future<ActorDetails> getActorDetails(String personId) {
    return datasource.getActorDetails(personId);
  }

  @override
  Future<List<ActorMovieCredit>> getActorMovieCredits(String personId) {
    return datasource.getActorMovieCredits(personId);
  }
}
