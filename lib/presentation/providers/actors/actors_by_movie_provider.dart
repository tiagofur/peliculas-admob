import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/actor.dart';
import 'actors_repository_provider.dart';

// Provider optimizado con AutoDispose para liberación automática
final actorsByMovieProvider =
    StateNotifierProvider.autoDispose<ActorsByMovieNotifier, Map<String, List<Actor>>>(
        (ref) {
  final actorsRepository = ref.watch(actorsRepositoryProvider);

  return ActorsByMovieNotifier(getActors: actorsRepository.getActorsByMovie);
});

/*
  {
    '505642': <Actor>[],
    '505643': <Actor>[],
    '505645': <Actor>[],
    '501231': <Actor>[],
  }
*/

typedef GetActorsCallback = Future<List<Actor>> Function(String movieId);

class ActorsByMovieNotifier extends StateNotifier<Map<String, List<Actor>>> {
  ActorsByMovieNotifier({
    required this.getActors,
  }) : super({});

  final GetActorsCallback getActors;
  bool _disposed = false;

  Future<void> loadActors(String movieId) async {
    if (_disposed || state[movieId] != null) return;

    try {
      final List<Actor> actors = await getActors(movieId);
      
      // Verificar si el notifier fue disposed durante la operación asíncrona
      if (!_disposed) {
        state = {...state, movieId: actors};
      }
    } catch (e) {
      // Si hay error y no estamos disposed, podemos manejarlo
      if (!_disposed) {
        // Mantener el estado actual sin cambios en caso de error
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
