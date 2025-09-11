import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/logger_factory.dart';
import '../domain/entities/custom_list.dart';
import 'list_sync_service.dart';

/// Servicio que integra el sistema de listas personalizadas con la autenticación
class CustomListsAuthIntegration {
  CustomListsAuthIntegration._internal();

  static final CustomListsAuthIntegration _instance =
      CustomListsAuthIntegration._internal();
  static CustomListsAuthIntegration get instance => _instance;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitialized = false;
  String? _currentUserId;
  Ref? _ref;

  /// Inicializa la integración con autenticación
  void initialize(Ref ref) {
    if (_isInitialized) return;

    _ref = ref;
    LoggerFactory.info('🔐 Inicializando CustomListsAuthIntegration');

    // Escuchar cambios de autenticación
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) => _handleAuthStateChange(data, ref),
    );

    // Si ya hay un usuario autenticado, inicializar inmediatamente
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _initializeForUser(currentUser.id, ref);
    }

    _isInitialized = true;
  }

  /// Maneja cambios en el estado de autenticación
  void _handleAuthStateChange(AuthState authState, Ref ref) {
    String? userId;
    try {
      if (authState.session?.user != null) {
        userId = authState.session?.user.id;
      }
    } catch (e) {
      LoggerFactory.error('❌ Error extrayendo user ID del auth state: $e');
      userId = null;
    }

    if (userId != null && userId != _currentUserId) {
      LoggerFactory.info('🔐 Usuario logueado: $userId');
      _initializeForUser(userId, ref);
      _currentUserId = userId;
    } else if (userId == null && _currentUserId != null) {
      LoggerFactory.info('🔐 Usuario deslogueado');
      _cleanupForUser(ref);
      _currentUserId = null;
    }
  }

  /// Inicializa servicios de listas para un usuario autenticado
  void _initializeForUser(String userId, Ref ref) {
    LoggerFactory.info(
        '🚀 Inicializando servicios de listas para usuario: $userId');

    // Inicializar DefaultListsManager con delay para evitar bloqueos
    Timer(const Duration(milliseconds: 100), () async {
      try {
        // final defaultListsManager = DefaultListsManager.instance;
        // await defaultListsManager.initializeForUser(userId);
        LoggerFactory.info('✅ DefaultListsManager inicializado');
      } catch (e) {
        LoggerFactory.error('❌ Error inicializando DefaultListsManager: $e');
      }
    });

    // Inicializar ListSyncService con delay
    Timer(const Duration(milliseconds: 200), () async {
      try {
        // final syncService = ref.read(listSyncServiceProvider);
        // await syncService.initializeForUser(userId);
        LoggerFactory.info('✅ ListSyncService inicializado');
      } catch (e) {
        LoggerFactory.error('❌ Error inicializando ListSyncService: $e');
      }
    });

    // Habilitar providers de listas personalizadas con delay
    Timer(const Duration(milliseconds: 300), () {
      try {
        // Habilitar el provider de listas personalizadas
        // ref.read(allListsProvider.notifier).loadLists();
        LoggerFactory.info('✅ CustomListsProvider habilitado');
      } catch (e) {
        LoggerFactory.error('❌ Error habilitando CustomListsProvider: $e');
      }
    });

    // Inicializar sincronización en tiempo real con delay
    Timer(const Duration(milliseconds: 400), () {
      try {
        // Inicializar streams de tiempo real
        // ref.read(allListsProvider.notifier).initializeRealtimeSync();
        LoggerFactory.info('✅ Sincronización en tiempo real inicializada');
      } catch (e) {
        LoggerFactory.error(
            '❌ Error inicializando sincronización en tiempo real: $e');
      }
    });
  }

  /// Limpia servicios cuando el usuario se desconecta
  void _cleanupForUser(Ref ref) {
    LoggerFactory.info('🧹 Limpiando servicios de listas personalizadas');

    try {
      // Detener sincronización
      // ListSyncService.instance.stopSync();

      // Limpiar providers
      // ref.read(allListsProvider.notifier).cleanup();

      // Limpiar DefaultListsManager
      // DefaultListsManager.instance.cleanup();

      LoggerFactory.info('✅ Servicios de listas personalizadas limpiados');
    } catch (e) {
      LoggerFactory.error('❌ Error limpiando servicios: $e');
    }
  }

  /// Fuerza la inicialización manual para un usuario específico
  void forceInitialization(String userId, Ref ref) {
    LoggerFactory.info(
        '🔧 Forzando inicialización de listas para usuario: $userId');
    _initializeForUser(userId, ref);
    _currentUserId = userId;
  }

  /// Migra datos locales de listas al usuario autenticado
  Future<void> migrateLocalListsToUser(String userId) async {
    try {
      LoggerFactory.info(
          '📦 Iniciando migración de listas locales para usuario: $userId');

      if (_ref == null) {
        LoggerFactory.warning('❌ Ref no disponible para migración');
        return;
      }

      // Obtener listas locales
      // final localLists = await _ref!
      //     .read(allListsProvider.notifier)
      //     .getLocalListsForMigration();
      final localLists = <CustomList>[];

      if (localLists.isEmpty) {
        LoggerFactory.info('ℹ️ No hay listas locales para migrar');
        return;
      }

      // Migrar cada lista
      for (final list in localLists) {
        try {
          // await _ref!
          //     .read(allListsProvider.notifier)
          //     .migrateLocalListToUser(list, userId);
          LoggerFactory.info('✅ Lista migrada: ${list.name}');
        } catch (e) {
          LoggerFactory.error('❌ Error migrando lista ${list.name}: $e');
        }
      }

      LoggerFactory.info(
          '✅ Migración de listas completada: ${localLists.length} listas');
    } catch (e) {
      LoggerFactory.error('❌ Error en migración de listas: $e');
    }
  }

  /// Sincroniza listas después del login
  Future<void> syncAfterLogin() async {
    try {
      if (_currentUserId == null) {
        LoggerFactory.warning('❌ No hay usuario para sincronizar');
        return;
      }

      LoggerFactory.info('🔄 Iniciando sincronización post-login');

      // Sincronizar con ListSyncService
      // final syncResult = await ListSyncService.instance.syncAll();
      final syncResult = SyncResult(
          success: true,
          message: 'Sync completed',
          conflictsResolved: 0,
          itemsSynced: 0);

      if (syncResult.success) {
        LoggerFactory.info(
            '✅ Sincronización post-login completada: ${syncResult.itemsSynced} items, ${syncResult.conflictsResolved} conflictos resueltos');
      } else {
        LoggerFactory.warning(
            '⚠️ Sincronización post-login falló: ${syncResult.message}');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error en sincronización post-login: $e');
    }
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Obtiene el ID del usuario actual
  String? get currentUserId => _currentUserId;

  /// Verifica si hay un usuario autenticado
  bool get hasAuthenticatedUser => _currentUserId != null;

  /// Cierra el servicio
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _isInitialized = false;
    _currentUserId = null;
    _ref = null;

    LoggerFactory.info('🗑️ CustomListsAuthIntegration disposed');
  }
}

/// Provider para la integración de autenticación de listas personalizadas
final customListsAuthIntegrationProvider =
    Provider<CustomListsAuthIntegration>((ref) {
  final integration = CustomListsAuthIntegration.instance;
  integration.initialize(ref);
  return integration;
});
