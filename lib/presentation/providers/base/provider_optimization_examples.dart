import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_provider_with_cleanup.dart';

/// Ejemplo de provider optimizado que previene memory leaks
class OptimizedMovieProvider extends BaseProviderWithCleanup<AsyncValue<List<Movie>>> {
  OptimizedMovieProvider() : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Timer periódico para actualizar datos
    final timer = Timer.periodic(Duration(minutes: 5), (_) => _refreshData());
    addTimer(timer); // Se cancelará automáticamente al disponer

    // Suscripción a stream de cambios
    final subscription = _movieStream.listen((movies) {
      state = AsyncValue.data(movies);
    });
    addSubscription(subscription); // Se cancelará automáticamente al disponer

    // Cargar datos iniciales
    _loadInitialData();
  }

  void _loadInitialData() async {
    try {
      final movies = await _movieRepository.getMovies();
      state = AsyncValue.data(movies);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void _refreshData() async {
    if (state.isLoading) return; // Evitar múltiples refreshes simultáneos

    try {
      final movies = await _movieRepository.getMovies();
      state = AsyncValue.data(movies);
    } catch (error) {
      // Log error but don't update state to avoid breaking current data
      print('Error refreshing data: $error');
    }
  }

  @override
  void onDispose() {
    // Limpiar recursos adicionales específicos de este provider
    _movieRepository.clearCache();
    print('OptimizedMovieProvider disposed successfully');
  }

  // Mock dependencies - replace with actual implementations
  late final _movieRepository = MockMovieRepository();
  late final _movieStream = Stream<List<Movie>>.periodic(
    Duration(seconds: 30),
    (_) => [Movie(id: 1, title: 'Test Movie')],
  );
}

/// Ejemplo usando el mixin AutoCleanupMixin
class OptimizedSearchProvider extends StateNotifier<String> with AutoCleanupMixin {
  OptimizedSearchProvider() : super('') {
    _init();
  }

  void _init() {
    // Debounce timer para búsquedas
    Timer? debounceTimer;

    // Stream controller para manejar búsquedas
    final controller = StreamController<String>.broadcast();

    // Suscripción al stream de búsquedas con debounce
    final subscription = controller.stream
        .distinct() // Solo procesar valores únicos
        .where((query) => query.length >= 3) // Mínimo 3 caracteres
        .listen((query) {
      debounceTimer?.cancel();
      debounceTimer = Timer(Duration(milliseconds: 500), () {
        _performSearch(query);
      });
      addTimer(debounceTimer!);
    });

    addSubscription(subscription);
  }

  void updateQuery(String query) {
    state = query;
    // Trigger search through stream
  }

  void _performSearch(String query) async {
    // Implement actual search logic here
    print('Searching for: $query');
  }

  @override
  void dispose() {
    print('OptimizedSearchProvider disposed successfully');
    super.dispose(); // Calls mixin cleanup automatically
  }
}

/// Ejemplo de provider con múltiples suscripciones y timers
class ComplexOptimizedProvider extends BaseProviderWithCleanup<Map<String, dynamic>> {
  ComplexOptimizedProvider() : super({}) {
    _setupMultipleSubscriptions();
  }

  void _setupMultipleSubscriptions() {
    // Múltiples timers para diferentes tareas
    addTimer(Timer.periodic(Duration(seconds: 10), (_) => _syncData()));
    addTimer(Timer.periodic(Duration(minutes: 1), (_) => _cleanupCache()));
    addTimer(Timer.periodic(Duration(minutes: 5), (_) => _reportAnalytics()));

    // Múltiples suscripciones a diferentes streams
    addSubscription(_authStream.listen(_handleAuthChange));
    addSubscription(_networkStream.listen(_handleNetworkChange));
    addSubscription(_dataStream.listen(_handleDataChange));

    // Suscripción condicional que se puede cancelar manualmente
    if (_shouldListenToSpecialEvents) {
      final specialSubscription = _specialEventStream.listen(_handleSpecialEvent);
      addSubscription(specialSubscription);

      // Después de cierto tiempo, cancelar esta suscripción específica
      Timer(Duration(minutes: 10), () {
        cancelSubscription(specialSubscription);
      });
    }
  }

  void _syncData() {
    // Sync implementation
  }

  void _cleanupCache() {
    // Cache cleanup implementation
  }

  void _reportAnalytics() {
    // Analytics reporting implementation
  }

  void _handleAuthChange(String authState) {
    state = {...state, 'auth': authState};
  }

  void _handleNetworkChange(bool isConnected) {
    state = {...state, 'network': isConnected};
  }

  void _handleDataChange(Map<String, dynamic> newData) {
    state = {...state, 'data': newData};
  }

  void _handleSpecialEvent(String event) {
    state = {...state, 'specialEvent': event};
  }

  @override
  void onDispose() {
    // Limpiar recursos específicos
    print('ComplexOptimizedProvider disposed with ${_subscriptions.length} subscriptions and ${_timers.length} timers cleaned up');
  }

  // Mock streams - replace with actual implementations
  final bool _shouldListenToSpecialEvents = true;
  late final _authStream = Stream<String>.periodic(Duration(seconds: 30), (_) => 'authenticated');
  late final _networkStream = Stream<bool>.periodic(Duration(seconds: 15), (_) => true);
  late final _dataStream = Stream<Map<String, dynamic>>.periodic(Duration(seconds: 45), (_) => {'timestamp': DateTime.now().millisecondsSinceEpoch});
  late final _specialEventStream = Stream<String>.periodic(Duration(minutes: 2), (_) => 'special_event');
}

// Mock classes for the examples
class Movie {
  final int id;
  final String title;
  Movie({required this.id, required this.title});
}

class MockMovieRepository {
  Future<List<Movie>> getMovies() async {
    await Future.delayed(Duration(milliseconds: 500));
    return [Movie(id: 1, title: 'Test Movie')];
  }

  void clearCache() {
    print('Cache cleared');
  }
}