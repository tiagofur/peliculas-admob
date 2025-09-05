import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/logger_factory.dart';
import '../sync/silent_favorites_sync_service.dart';
import '../../presentation/providers/storage/favorite_movies_provider.dart';

/// Servicio que maneja la inicialización de servicios después del login
/// para evitar bloqueos durante la autenticación
class PostLoginInitializationService {
  PostLoginInitializationService._internal();
  
  static final PostLoginInitializationService _instance = PostLoginInitializationService._internal();
  static PostLoginInitializationService get instance => _instance;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitialized = false;
  String? _currentUserId;

  /// Inicializa el servicio
  void initialize(Ref ref) {
    if (_isInitialized) return;
    
    LoggerFactory.info('🚀 Initializing PostLoginInitializationService');
    
    // Escuchar cambios de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => _handleAuthStateChange(data, ref),
    );
    
    // Si ya hay un usuario autenticado, inicializar inmediatamente
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _initializePostLoginServices(currentUser.id, ref);
    }
    
    _isInitialized = true;
  }

  /// Maneja cambios en el estado de autenticación
  void _handleAuthStateChange(AuthState authState, Ref ref) {
    String? userId;
    try {
      if (authState.session != null && authState.session!.user != null) {
        userId = authState.session!.user!.id;
      }
    } catch (e) {
      LoggerFactory.error('❌ Error extracting user ID from auth state: $e');
      userId = null;
    }
    
    if (userId != null && userId != _currentUserId) {
      LoggerFactory.info('🔐 User logged in: $userId');
      _initializePostLoginServices(userId, ref);
      _currentUserId = userId;
    } else if (userId == null && _currentUserId != null) {
      LoggerFactory.info('🔐 User logged out');
      _cleanupServices(ref);
      _currentUserId = null;
    }
  }

  /// Inicializa servicios después del login con delays progresivos
  void _initializePostLoginServices(String userId, Ref ref) {
    LoggerFactory.info('🚀 Starting post-login initialization for user: $userId');

    // Paso 1: Habilitar auto-refresh de favoritos (inmediato)
    Timer(const Duration(milliseconds: 500), () {
      try {
        ref.read(favoriteMoviesProvider.notifier).enableAutoRefresh();
        LoggerFactory.info('✅ Auto-refresh habilitado para favoritos');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando auto-refresh: $e');
      }
    });

    // Paso 2: Inicializar sincronización silenciosa (después de 2 segundos)
    Timer(const Duration(seconds: 2), () {
      try {
        SilentFavoritesSyncService.instance.startSilentSync(userId);
        LoggerFactory.info('✅ Sincronización silenciosa iniciada');
      } catch (e) {
        LoggerFactory.error('❌ Error iniciando sincronización silenciosa: $e');
      }
    });

    // Paso 3: Refrescar datos después de 3 segundos
    Timer(const Duration(seconds: 3), () {
      try {
        ref.read(favoriteMoviesProvider.notifier).refreshFavorites();
        LoggerFactory.info('✅ Favoritos refrescados después del login');
      } catch (e) {
        LoggerFactory.error('❌ Error refrescando favoritos: $e');
      }
    });
  }

  /// Limpia servicios cuando el usuario se desconecta
  void _cleanupServices(Ref ref) {
    LoggerFactory.info('🧹 Cleaning up post-login services');

    try {
      // Deshabilitar auto-refresh
      ref.read(favoriteMoviesProvider.notifier).disableAutoRefresh();
      
      // Detener sincronización silenciosa
      SilentFavoritesSyncService.instance.stopSync();
      
      LoggerFactory.info('✅ Post-login services cleaned up');
    } catch (e) {
      LoggerFactory.error('❌ Error cleaning up services: $e');
    }
  }

  /// Fuerza la inicialización manual para un usuario específico
  void forceInitialization(String userId, Ref ref) {
    LoggerFactory.info('🔧 Force initializing post-login services for: $userId');
    _initializePostLoginServices(userId, ref);
    _currentUserId = userId;
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Obtiene el ID del usuario actual
  String? get currentUserId => _currentUserId;

  /// Cierra el servicio
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _isInitialized = false;
    _currentUserId = null;
    
    LoggerFactory.info('🗑️ PostLoginInitializationService disposed');
  }
}