import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/logger_factory.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/hybrid_repositories_provider.dart';
import '../../presentation/providers/storage/favorite_movies_provider.dart';
import '../../presentation/providers/watchlist_provider.dart';

/// Servicio de sincronización en tiempo real que escucha cambios en Supabase
/// y actualiza los datos locales automáticamente para mantener sincronización
/// entre múltiples dispositivos/navegadores
class RealtimeSyncService {
  RealtimeSyncService({required Ref ref}) : _ref = ref {
    _supabase = Supabase.instance.client;
  }

  final Ref _ref;
  late final SupabaseClient _supabase;
  
  // Subscripciones activas por tabla
  final Map<String, RealtimeChannel> _activeChannels = {};
  bool _isInitialized = false;

  /// Inicializar el servicio de tiempo real
  Future<void> initialize() async {
    if (_isInitialized) return;

    LoggerFactory.info('🔄 Inicializando servicio de sincronización en tiempo real...');
    
    // Escuchar cambios en el estado de autenticación
    _ref.listen<AppState>(appStateProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        if (next.isAuthenticated) {
          _startRealtimeSync();
        } else {
          _stopRealtimeSync();
        }
      }
    });

    _isInitialized = true;
    LoggerFactory.info('✅ Servicio de sincronización en tiempo real inicializado');
  }

  /// Iniciar sincronización en tiempo real para usuario autenticado
  Future<void> _startRealtimeSync() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      LoggerFactory.warning('❌ No hay usuario para iniciar realtime sync');
      return;
    }

    LoggerFactory.info('🚀 Iniciando sincronización en tiempo real para usuario: ${user.email}');

    try {
      // Suscribirse a cambios en favoritos
      await _subscribeToFavorites(user.id);
      
      // Suscribirse a cambios en watchlist
      await _subscribeToWatchlist(user.id);
      
      // Suscribirse a cambios en películas vistas
      await _subscribeToWatchedMovies(user.id);
      
      // Suscribirse a cambios en listas personalizadas
      await _subscribeToCustomLists(user.id);

      LoggerFactory.info('✅ Sincronización en tiempo real activa para todas las tablas');
    } catch (e) {
      LoggerFactory.error('❌ Error iniciando sincronización en tiempo real: $e');
    }
  }

  /// Detener sincronización en tiempo real
  void _stopRealtimeSync() {
    LoggerFactory.info('🛑 Deteniendo sincronización en tiempo real...');
    
    for (final channel in _activeChannels.values) {
      _supabase.removeChannel(channel);
    }
    _activeChannels.clear();
    
    LoggerFactory.info('✅ Sincronización en tiempo real detenida');
  }

  /// Suscribirse a cambios en favoritos
  Future<void> _subscribeToFavorites(String userId) async {
    final channel = _supabase
        .channel('favorites_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_favorites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleFavoritesChange(payload),
        );

    channel.subscribe();
    _activeChannels['favorites'] = channel;
    
    LoggerFactory.info('👂 Escuchando cambios en favoritos para usuario: $userId');
  }

  /// Suscribirse a cambios en watchlist
  Future<void> _subscribeToWatchlist(String userId) async {
    final channel = _supabase
        .channel('watchlist_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watchlist',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleWatchlistChange(payload),
        );

    channel.subscribe();
    _activeChannels['watchlist'] = channel;
    
    LoggerFactory.info('👂 Escuchando cambios en watchlist para usuario: $userId');
  }

  /// Suscribirse a cambios en películas vistas
  Future<void> _subscribeToWatchedMovies(String userId) async {
    final channel = _supabase
        .channel('watched_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_watched_movies',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleWatchedMoviesChange(payload),
        );

    channel.subscribe();
    _activeChannels['watched'] = channel;
    
    LoggerFactory.info('👂 Escuchando cambios en películas vistas para usuario: $userId');
  }

  /// Suscribirse a cambios en listas personalizadas
  Future<void> _subscribeToCustomLists(String userId) async {
    final channel = _supabase
        .channel('custom_lists_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_lists',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _handleCustomListsChange(payload),
        );

    channel.subscribe();
    _activeChannels['custom_lists'] = channel;
    
    LoggerFactory.info('👂 Escuchando cambios en listas personalizadas para usuario: $userId');
  }

  /// Manejar cambios en favoritos desde otros dispositivos
  void _handleFavoritesChange(PostgresChangePayload payload) {
    LoggerFactory.info('🔄 Cambio detectado en favoritos: ${payload.eventType}');
    
    // Ejecutar sincronización del repositorio de favoritos en background
    Future.microtask(() async {
      try {
        final favoritesRepo = _ref.read(hybridFavoritesRepositoryProvider);
        await favoritesRepo.syncWithSupabase();
        
        // Actualizar también el provider de UI para que se refleje inmediatamente
        final favoritesNotifier = _ref.read(favoriteMoviesProvider.notifier);
        await favoritesNotifier.refreshFavorites();
        
        LoggerFactory.info('✅ Favoritos sincronizados y UI actualizada por cambio remoto');
      } catch (e) {
        LoggerFactory.error('❌ Error sincronizando favoritos por cambio remoto: $e');
      }
    });
  }

  /// Manejar cambios en watchlist desde otros dispositivos
  void _handleWatchlistChange(PostgresChangePayload payload) {
    LoggerFactory.info('🔄 Cambio detectado en watchlist: ${payload.eventType}');
    
    Future.microtask(() async {
      try {
        final watchlistRepo = _ref.read(hybridWatchlistRepositoryProvider);
        await watchlistRepo.syncWithSupabase();
        
        // Actualizar también el provider de UI para que se refleje inmediatamente
        final watchlistNotifier = _ref.read(watchlistProvider.notifier);
        await watchlistNotifier.refresh();
        
        LoggerFactory.info('✅ Watchlist sincronizada y UI actualizada por cambio remoto');
      } catch (e) {
        LoggerFactory.error('❌ Error sincronizando watchlist por cambio remoto: $e');
      }
    });
  }

  /// Manejar cambios en películas vistas desde otros dispositivos
  void _handleWatchedMoviesChange(PostgresChangePayload payload) {
    LoggerFactory.info('🔄 Cambio detectado en películas vistas: ${payload.eventType}');
    
    Future.microtask(() async {
      try {
        final watchedRepo = _ref.read(hybridWatchedRepositoryProvider);
        await watchedRepo.syncWithSupabase();
        LoggerFactory.info('✅ Películas vistas sincronizadas por cambio remoto');
      } catch (e) {
        LoggerFactory.error('❌ Error sincronizando películas vistas por cambio remoto: $e');
      }
    });
  }

  /// Manejar cambios en listas personalizadas desde otros dispositivos
  void _handleCustomListsChange(PostgresChangePayload payload) {
    LoggerFactory.info('🔄 Cambio detectado en listas personalizadas: ${payload.eventType}');
    
    Future.microtask(() async {
      try {
        final customListsRepo = _ref.read(hybridCustomListsRepositoryProvider);
        await customListsRepo.syncWithSupabase();
        LoggerFactory.info('✅ Listas personalizadas sincronizadas por cambio remoto');
      } catch (e) {
        LoggerFactory.error('❌ Error sincronizando listas personalizadas por cambio remoto: $e');
      }
    });
  }

  /// Disposar recursos
  void dispose() {
    LoggerFactory.info('🧹 Limpiando servicio de sincronización en tiempo real...');
    _stopRealtimeSync();
    _isInitialized = false;
  }
}

/// Provider para el servicio de sincronización en tiempo real
final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService(ref: ref);
  
  // Inicializar automáticamente
  service.initialize();
  
  // Limpiar al disposar
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});