import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/actor_details.dart';
import 'actors_repository_provider.dart';

final actorDetailsProvider = FutureProvider.autoDispose
    .family<ActorDetails, String>((ref, personId) async {
      final repository = ref.watch(actorsRepositoryProvider);
      return repository.getActorDetails(personId);
    });

final actorMovieCreditsProvider = FutureProvider.autoDispose
    .family<List<ActorMovieCredit>, String>((ref, personId) async {
      final repository = ref.watch(actorsRepositoryProvider);
      return repository.getActorMovieCredits(personId);
    });
