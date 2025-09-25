import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/actor.dart';
import 'actors_repository_provider.dart';

// Provider optimizado con AutoDispose para liberación automática
final actorsByMovieProvider = NotifierProvider.autoDispose<
    ActorsByMovieNotifier, Map<String, List<Actor>>>(
  () => ActorsByMovieNotifier(),
);

/*
  {
    '505642': <Actor>[],
    '505643': <Actor>[],
    '505645': <Actor>[],
    '501231': <Actor>[],
  }
*/

typedef GetActorsCallback = Future<List<Actor>> Function(String movieId);

class ActorsByMovieNotifier extends Notifier<Map<String, List<Actor>>> {
  GetActorsCallback? _getActors;
  bool _disposed = false;

  @override
  Map<String, List<Actor>> build() {
    final actorsRepository = ref.watch(actorsRepositoryProvider);
    _getActors = actorsRepository.getActorsByMovie;

    // Handle cleanup on dispose
    ref.onDispose(() {
      _disposed = true;
    });

    return <String, List<Actor>>{};
  }

  Future<void> loadActors(String movieId) async {
    if (_disposed || state[movieId] != null || _getActors == null) return;

    try {
      final List<Actor> actors = await _getActors!(movieId);

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
}
