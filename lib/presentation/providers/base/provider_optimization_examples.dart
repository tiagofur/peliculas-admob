import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import 'base_provider_with_cleanup.dart';

/// Ejemplo de provider optimizado que previene memory leaks
class OptimizedMovieProvider
    extends BaseProviderWithCleanup<AsyncValue<List<Movie>>> {
  @override
  AsyncValue<List<Movie>> build() {
    _init();
    return const AsyncValue<List<Movie>>.loading();
  }

  void _init() {
    // Timer periódico para actualizar datos
    final timer =
        Timer.periodic(const Duration(minutes: 5), (_) => _refreshData());
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
      LoggerFactory.error('Error refreshing data: $error');
    }
  }

  @override
  void onDispose() {
    // Limpiar recursos adicionales específicos de este provider
    _movieRepository.clearCache();
    LoggerFactory.info('OptimizedMovieProvider disposed successfully');
  }

  // Mock dependencies - replace with actual implementations
  late final _movieRepository = MockMovieRepository();
  late final _movieStream = Stream<List<Movie>>.periodic(
    const Duration(seconds: 30),
    (_) => [Movie(id: 1, title: 'Test Movie')],
  );
}

/// Ejemplo usando el mixin AutoCleanupMixin
class OptimizedSearchProvider extends Notifier<String> with AutoCleanupMixin {
  @override
  String build() {
    _init();
    return '';
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
      debounceTimer = Timer(const Duration(milliseconds: 500), () {
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
    LoggerFactory.info('Searching for: $query');
  }

  void cleanup() {
    LoggerFactory.info('OptimizedSearchProvider disposed successfully');
    cleanupMixin(); // Calls mixin cleanup automatically
  }
}

/// Ejemplo de provider con múltiples suscripciones y timers
class ComplexOptimizedProvider
    extends BaseProviderWithCleanup<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    _setupMultipleSubscriptions();
    return {};
  }

  void _setupMultipleSubscriptions() {
    // Múltiples timers para diferentes tareas
    addTimer(Timer.periodic(const Duration(seconds: 10), (_) => _syncData()));
    addTimer(
        Timer.periodic(const Duration(minutes: 1), (_) => _cleanupCache()));
    addTimer(
        Timer.periodic(const Duration(minutes: 5), (_) => _reportAnalytics()));

    // Múltiples suscripciones a diferentes streams
    addSubscription(_authStream.listen(_handleAuthChange));
    addSubscription(_networkStream.listen(_handleNetworkChange));
    addSubscription(_dataStream.listen(_handleDataChange));

    // Suscripción condicional que se puede cancelar manualmente
    if (_shouldListenToSpecialEvents) {
      final specialSubscription =
          _specialEventStream.listen(_handleSpecialEvent);
      addSubscription(specialSubscription);

      // Después de cierto tiempo, cancelar esta suscripción específica
      Timer(const Duration(minutes: 10), () {
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
    LoggerFactory.info('ComplexOptimizedProvider disposed successfully');
  }

  // Mock streams - replace with actual implementations
  final bool _shouldListenToSpecialEvents = true;
  late final _authStream = Stream<String>.periodic(
      const Duration(seconds: 30), (_) => 'authenticated');
  late final _networkStream =
      Stream<bool>.periodic(const Duration(seconds: 15), (_) => true);
  late final _dataStream = Stream<Map<String, dynamic>>.periodic(
      const Duration(seconds: 45),
      (_) => {'timestamp': DateTime.now().millisecondsSinceEpoch});
  late final _specialEventStream = Stream<String>.periodic(
      const Duration(minutes: 2), (_) => 'special_event');
}

// Mock classes for the examples
class Movie {
  Movie({required this.id, required this.title});
  final int id;
  final String title;
}

class MockMovieRepository {
  Future<List<Movie>> getMovies() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [Movie(id: 1, title: 'Test Movie')];
  }

  void clearCache() {
    LoggerFactory.info('Cache cleared');
  }
}
