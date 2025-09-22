import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/supabase_config.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../infrastructure/datasources/custom_lists_shared_preferences_datasource.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../../infrastructure/services/anonymous_data_migrator.dart';
import '../../services/id_mapping_service.dart';
import '../../services/lists_migration_service.dart';
import '../../services/migration_rollback_service.dart';
import './hybrid_repositories_provider.dart';

// Typedef para los callbacks que necesita AuthNotifier
typedef GetCurrentUserCallback = User? Function();
typedef GetAnonymousDataMigratorCallback = dynamic Function();
typedef SetHasLocalDataCallback = void Function(bool hasData);
typedef ForceSyncCallback = void Function();

// Clase que encapsula todos los callbacks necesarios para AuthNotifier
class AuthCallbacks {
  const AuthCallbacks({
    required this.getCurrentUser,
    required this.getAnonymousDataMigrator,
    required this.setHasLocalData,
    required this.forceSyncFavorites,
    required this.forceSyncWatchlist,
    required this.forceSyncWatched,
    required this.forceSyncCustomLists,
  });

  final GetCurrentUserCallback getCurrentUser;
  final GetAnonymousDataMigratorCallback getAnonymousDataMigrator;
  final SetHasLocalDataCallback setHasLocalData;
  final ForceSyncCallback forceSyncFavorites;
  final ForceSyncCallback forceSyncWatchlist;
  final ForceSyncCallback forceSyncWatched;
  final ForceSyncCallback forceSyncCustomLists;
}

// Enum para definir el modo de la aplicación
enum AppMode {
  guest, // Usuario no autenticado usando datos locales
  authenticated, // Usuario autenticado con sincronización a Supabase
}

// Estado de la aplicación que incluye modo y usuario
class AppState {
  const AppState({
    required this.mode,
    this.user,
    this.hasLocalData = false,
  });
  final AppMode mode;
  final User? user;
  final bool hasLocalData;

  bool get isGuest => mode == AppMode.guest;
  bool get isAuthenticated => mode == AppMode.authenticated && user != null;

  AppState copyWith({
    AppMode? mode,
    User? user,
    bool? hasLocalData,
  }) {
    return AppState(
      mode: mode ?? this.mode,
      user: user,
      hasLocalData: hasLocalData ?? this.hasLocalData,
    );
  }
}

// Provider del repositorio de autenticación
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// Provider del estado de autenticación
final authStateProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

// Provider del usuario actual
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Provider para verificar si el usuario está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

// Provider del estado de la aplicación (guest o authenticated)
final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  // ✅ FIX: Pasar ref solo al constructor, no almacenarlo
  return AppStateNotifier(ref);
});

// Notifier para manejar el estado de la aplicación
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(Ref ref) : super(const AppState(mode: AppMode.guest)) {
    // ✅ Usar ref localmente sin almacenarlo (evita memory leak)
    _initializeWithRef(ref);
  }

  // ✅ FIX: Método que configura listeners sin almacenar ref
  void _initializeWithRef(Ref ref) {
    // Inicializar con el estado actual de autenticación
    final currentAuthState = ref.read(authStateProvider);
    currentAuthState.when(
      data: (user) {
        if (user != null) {
          // Usuario ya autenticado al inicializar
          state = state.copyWith(
            mode: AppMode.authenticated,
            user: user,
          );
        }
        // Si user es null, mantener el estado guest inicial
      },
      loading: () {
        // Mantener estado guest mientras carga
      },
      error: (_, __) {
        // Mantener estado guest en caso de error
      },
    );

    // ✅ Escuchar cambios sin almacenar ref
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            // Usuario autenticado
            state = state.copyWith(
              mode: AppMode.authenticated,
              user: user,
            );
          } else {
            // Usuario no autenticado, modo guest
            state = state.copyWith(
              mode: AppMode.guest,
              user: null,
            );
            // Detectar datos locales cuando no hay usuario autenticado
            _detectLocalDataOnStartup(ref);
          }
        },
        loading: () {},
        error: (_, __) {
          // En caso de error, mantener modo guest
          state = state.copyWith(
            mode: AppMode.guest,
            user: null,
          );
          // También detectar datos locales en caso de error
          _detectLocalDataOnStartup(ref);
        },
      );
    });

    // Detectar datos locales en el startup inicial
    _detectLocalDataOnStartup(ref);
  }

  // Método para cambiar a modo guest manualmente
  void switchToGuestMode() {
    state = state.copyWith(
      mode: AppMode.guest,
      user: null,
    );
  }

  // Método para marcar que hay datos locales
  void setHasLocalData(bool hasData) {
    state = state.copyWith(hasLocalData: hasData);
  }

  // ✅ FIX: Método que detecta datos locales usando ref como parámetro
  void _detectLocalDataOnStartup(Ref ref) {
    // Ejecutar en background para no bloquear la UI
    Future.microtask(() async {
      try {
        final migrator = ref.read(anonymousDataMigratorProvider);
        final detectedData = await migrator.detectAnonymousData();

        final hasLocalData = detectedData.isNotEmpty;
        if (hasLocalData != state.hasLocalData) {
          state = state.copyWith(hasLocalData: hasLocalData);

          if (hasLocalData) {
            final totalItems =
                detectedData.values.fold(0, (sum, count) => sum + count);
            LoggerFactory.info(
                '📱 Datos locales detectados al startup: $totalItems items ($detectedData)');
          }
        }
      } catch (e) {
        LoggerFactory.error('❌ Error detectando datos locales en startup: $e');
      }
    });
  }

  // ✅ FIX: Implementar dispose para limpiar recursos
  @override
  void dispose() {
    LoggerFactory.info('✅ AppStateNotifier disposed');
    super.dispose();
  }
}

// Provider del perfil del usuario actual
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final authRepository = ref.watch(authRepositoryProvider);
  return await authRepository.getUserProfile(user.id);
});

// Provider de las estadísticas del usuario actual
final currentUserStatsProvider = FutureProvider<UserStats?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final authRepository = ref.watch(authRepositoryProvider);
  return await authRepository.getUserStats(user.id);
});

// Notifier para operaciones de autenticación
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._authRepository, this._callbacks)
      : super(const AsyncValue.data(null));
  final AuthRepository _authRepository;

  // ✅ MEMORY LEAK FIX - Usar callbacks en lugar de almacenar _ref
  final AuthCallbacks _callbacks;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ejecutar sincronización después del login exitoso
      _syncDataAfterAuth();

      state = const AsyncValue.data(null);
    } on EmailConfirmationRequiredException catch (e, stackTrace) {
      // Manejar específicamente la excepción de confirmación de email
      state = AsyncValue.error(e, stackTrace);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? avatarUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );

      // Ejecutar sincronización después del registro exitoso
      _syncDataAfterAuth();

      state = const AsyncValue.data(null);
    } on EmailConfirmationRequiredException catch (e, stackTrace) {
      // Manejar específicamente la excepción de confirmación de email
      state = AsyncValue.error(e, stackTrace);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.resetPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateUser({
    String? fullName,
    String? avatarUrl,
    String? email,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.updateUser(
        fullName: fullName,
        avatarUrl: avatarUrl,
        email: email,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> resendConfirmationEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.resendConfirmationEmail(email);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // Método privado para sincronizar datos después de autenticación
  void _syncDataAfterAuth() {
    // Ejecutar sincronización y migración en background sin bloquear la UI
    Future.microtask(() async {
      try {
        final logger = LoggerFactory.getLogger('AuthNotifier');

        final user = _callbacks.getCurrentUser();
        if (user == null) {
          logger.warning('Usuario no disponible para sincronización');
          return;
        }

        logger.info(
            'Iniciando migración y sincronización para usuario: ${user.id}');

        // 1. Ejecutar migración de listas personalizadas (nueva funcionalidad)
        await _executeMigrationPhase(user.id, logger);

        // 2. Detectar y migrar datos locales de usuario anónimo (funcionalidad existente)
        final migrator = _callbacks.getAnonymousDataMigrator();
        final detectedData = await migrator.detectAnonymousData();

        if (detectedData.isNotEmpty) {
          logger.info('Datos anónimos detectados, iniciando migración');
          _callbacks.setHasLocalData(true);

          final migrationResult = await migrator.migrateAllData(user.id);

          if (migrationResult.success) {
            logger.info('Migración de datos anónimos completada exitosamente');
          } else {
            logger.warning(
                'Migración de datos anónimos falló: ${migrationResult.errors}');
          }
        } else {
          logger.info('No se detectaron datos anónimos para migrar');
        }

        // 3. Ejecutar sincronización de todas las entidades en segundo plano
        logger.info('Iniciando sincronización de repositorios');

        // Disparar la sincronización para cada repositorio sin esperar (no await)
        _callbacks.forceSyncFavorites();
        _callbacks.forceSyncWatchlist();
        _callbacks.forceSyncWatched();
        _callbacks.forceSyncCustomLists();

        // Habilitar los providers directos
        // Los providers directos ahora se inicializan automáticamente

        logger.info('Sincronización post-autenticación completada');
      } catch (e) {
        // Log del error pero no afectar la experiencia del usuario
        final logger = LoggerFactory.getLogger('AuthNotifier');
        logger.error('Error durante sincronización post-autenticación: $e');
      }
    });
  }

  /// Ejecuta la fase de migración de listas personalizadas
  Future<void> _executeMigrationPhase(String userId, dynamic logger) async {
    try {
      logger.info('Iniciando migración de listas personalizadas');

      // Obtener instancias de los servicios de migración
      final prefs = await SharedPreferences.getInstance();
      final supabase = SupabaseConfig.client;
      final localDataSource = CustomListsSharedPreferencesDatasource();
      final idMappingService = IdMappingService(prefs);
      final rollbackService = MigrationRollbackService(
        prefs,
        supabase,
        localDataSource,
        idMappingService,
      );

      final migrationService = ListsMigrationService(
        prefs,
        localDataSource,
        supabase,
      );

      // Verificar si la migración ya fue ejecutada
      final migrationCompleted =
          prefs.getBool('lists_migration_completed') ?? false;
      if (migrationCompleted) {
        logger.info('Migración de listas ya completada previamente');
        return;
      }

      // Crear punto de rollback antes de la migración
      final rollbackId = await rollbackService.createRollbackPoint(
        userId,
        'Migración automática de listas personalizadas',
      );

      logger.info('Punto de rollback creado: $rollbackId');

      // Ejecutar análisis de migración
      final analysis = await migrationService.analyzeMigrationNeeds(userId);

      if (analysis.hasWork) {
        logger.info('Migración necesaria');

        // Ejecutar migración completa
        await migrationService.migrateDefaultLists(userId);

        logger.info('Migración de listas completada');

        // Marcar migración como completada
        await migrationService.markMigrationCompleted();
        await prefs.setString(
            'lists_migration_date', DateTime.now().toIso8601String());
      } else {
        logger.info('No se requiere migración de listas');
      }
    } catch (e) {
      logger.error('Error crítico durante migración de listas: $e');

      // Intentar rollback automático en caso de error crítico
      try {
        final prefs = await SharedPreferences.getInstance();
        final supabase = SupabaseConfig.client;
        final localDataSource = CustomListsSharedPreferencesDatasource();
        final idMappingService = IdMappingService(prefs);
        final rollbackService = MigrationRollbackService(
          prefs,
          supabase,
          localDataSource,
          idMappingService,
        );

        await rollbackService.executeAutoRollback(userId);
        logger.info('Rollback automático ejecutado tras error crítico');
      } catch (rollbackError) {
        logger.error('Error durante rollback automático: $rollbackError');
      }
    }
  }
}

// Provider del notifier de autenticación
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);

  // ✅ MEMORY LEAK FIX - Crear callbacks en lugar de pasar ref directamente
  final callbacks = AuthCallbacks(
    getCurrentUser: () => ref.read(currentUserProvider),
    getAnonymousDataMigrator: () => ref.read(anonymousDataMigratorProvider),
    setHasLocalData: (hasData) =>
        ref.read(appStateProvider.notifier).setHasLocalData(hasData),
    forceSyncFavorites: () =>
        ref.read(hybridFavoritesRepositoryProvider).forceSync(),
    forceSyncWatchlist: () =>
        ref.read(hybridWatchlistRepositoryProvider).forceSync(),
    forceSyncWatched: () =>
        ref.read(hybridWatchedRepositoryProvider).forceSync(),
    forceSyncCustomLists: () =>
        ref.read(hybridCustomListsRepositoryProvider).forceSync(),
  );

  return AuthNotifier(authRepository, callbacks);
});

// Notifier para operaciones de perfil
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileNotifier(this._authRepository)
      : super(const AsyncValue.data(null));
  final AuthRepository _authRepository;

  Future<void> loadProfile(String userId) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authRepository.getUserProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    String? avatarUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updatedProfile = await _authRepository.updateUserProfile(
        userId: userId,
        fullName: fullName,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      state = AsyncValue.data(updatedProfile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      return await _authRepository.uploadAvatar(
        userId: userId,
        filePath: filePath,
      );
    } catch (e) {
      rethrow;
    }
  }
}

// Provider del notifier de perfil
final userProfileNotifierProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return UserProfileNotifier(authRepository);
});

// Notifier para operaciones de estadísticas
class UserStatsNotifier extends StateNotifier<AsyncValue<UserStats?>> {
  UserStatsNotifier(this._authRepository) : super(const AsyncValue.data(null));
  final AuthRepository _authRepository;

  Future<void> loadStats(String userId) async {
    state = const AsyncValue.loading();
    try {
      final stats = await _authRepository.getUserStats(userId);
      state = AsyncValue.data(stats);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateStats({
    required String userId,
    int? moviesWatched,
    int? favoritesCount,
    int? listsCount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updatedStats = await _authRepository.updateUserStats(
        userId: userId,
        moviesWatched: moviesWatched,
        favoritesCount: favoritesCount,
        listsCount: listsCount,
      );
      state = AsyncValue.data(updatedStats);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> incrementMoviesWatched(String userId) async {
    final currentStats = state.value;
    if (currentStats != null) {
      await updateStats(
        userId: userId,
        moviesWatched: currentStats.moviesWatched + 1,
      );
    }
  }

  Future<void> incrementFavorites(String userId) async {
    final currentStats = state.value;
    if (currentStats != null) {
      await updateStats(
        userId: userId,
        favoritesCount: currentStats.favoritesCount + 1,
      );
    }
  }

  Future<void> decrementFavorites(String userId) async {
    final currentStats = state.value;
    if (currentStats != null) {
      await updateStats(
        userId: userId,
        favoritesCount: currentStats.favoritesCount > 0
            ? currentStats.favoritesCount - 1
            : 0,
      );
    }
  }

  // ✅ FIX: Implementar dispose para limpiar recursos
  @override
  void dispose() {
    LoggerFactory.info('✅ UserStatsNotifier disposed');
    super.dispose();
  }
}

// Provider del notifier de estadísticas
final userStatsNotifierProvider =
    StateNotifierProvider<UserStatsNotifier, AsyncValue<UserStats?>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return UserStatsNotifier(authRepository);
});
