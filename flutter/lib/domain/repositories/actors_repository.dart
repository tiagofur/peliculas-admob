import '../entities/actor.dart';
import '../entities/actor_details.dart';

abstract class ActorsRepository {
  Future<List<Actor>> getActorsByMovie(String movieId);

  Future<ActorDetails> getActorDetails(String personId);

  Future<List<ActorMovieCredit>> getActorMovieCredits(String personId);
}
