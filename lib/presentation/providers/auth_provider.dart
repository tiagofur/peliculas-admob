import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_flow_optimizer.dart';
import '../../core/error_handling/centralized_error_handler.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../../services/data_migration_service.dart';
import '../mixins/error_handling_mixin.dart';

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
final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(() {
  return AppStateNotifier();
});

// Notifier para manejar el estado de la aplicación
class AppStateNotifier extends Notifier<AppState> {
  @override
  AppState build() {
    // Initialize flow optimizer for startup optimization
    _initializeFlowOptimizer();
    // ✅ Usar ref localmente durante initialization
    _initializeWithRef();
    return const AppState(mode: AppMode.guest);
  }

  final AuthFlowOptimizer _flowOptimizer = AuthFlowOptimizer.instance;

  // ✅ FIX: Método que configura listeners usando ref directamente
  void _initializeWithRef() {
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

  // ✅ IMPLEMENTADO: Método que detecta datos locales usando servicio dedicado
  void _detectLocalDataOnStartup(Ref ref) {
    // Ejecutar en background para no bloquear la UI
    Future.microtask(() async {
      try {
        final migrationService = ref.read(dataMigrationServiceProvider);
        final localDataStatus = await migrationService.detectLocalData();

        LoggerFactory.info('📱 Detección de datos locales completada: '
            'Películas vistas: ${localDataStatus.totalWatchedMovies}, '
            'Calificaciones: ${localDataStatus.totalRatings}, '
            'Listas: ${localDataStatus.totalCustomLists}');

        state = state.copyWith(hasLocalData: localDataStatus.hasAnyData);
      } catch (e) {
        LoggerFactory.error('❌ Error detectando datos locales en startup: $e');
        state = state.copyWith(hasLocalData: false);
      }
    });
  }

  /// Inicializa el optimizador de flujos para mejorar el startup
  Future<void> _initializeFlowOptimizer() async {
    try {
      LoggerFactory.info(
          '🚀 Initializing AuthFlowOptimizer for startup optimization');

      // Initialize the optimizer
      await _flowOptimizer.initialize();

      // Optimize startup flow in background
      Future.microtask(() async {
        final sessionRecovered = await _flowOptimizer.optimizeStartupFlow();
        if (sessionRecovered) {
          LoggerFactory.info(
              '✅ Startup optimization: Session recovered successfully');
        } else {
          LoggerFactory.info(
              'ℹ️ Startup optimization: Ready for new authentication');
        }
      });
    } catch (e) {
      LoggerFactory.error('❌ Failed to initialize AuthFlowOptimizer: $e');
      // Continue normal initialization even if optimizer fails
    }
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

/// Callback type for post-authentication operations
typedef PostAuthCallback = Future<void> Function(User user);

// Notifier para operaciones de autenticación
class AuthNotifier extends Notifier<AsyncValue<void>>
    with ErrorHandlingMixin<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    // Configurar callback post-autenticación automáticamente
    _setupPostAuthCallback();
    return const AsyncValue.data(null);
  }

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  PostAuthCallback? _onAuthSuccess;
  AuthFlowOptimizer get _flowOptimizer => AuthFlowOptimizer.instance;

  void setAuthCallback(PostAuthCallback? onAuthSuccess) {
    _onAuthSuccess = onAuthSuccess;
  }

  /// Configura automáticamente el callback post-autenticación para sincronización
  void _setupPostAuthCallback() {
    _onAuthSuccess = (user) async {
      LoggerFactory.info('🔄 Ejecutando sincronización post-autenticación para: ${user.id}');
      
      try {
        // Obtener el servicio de migración
        final migrationService = ref.read(dataMigrationServiceProvider);
        
        // Ejecutar migración y sincronización
        final result = await migrationService.migrateAndSyncData(user.id);
        
        if (result.success) {
          LoggerFactory.info('✅ Sincronización post-autenticación exitosa: '
              'Películas: ${result.migratedWatchedMovies}, '
              'Calificaciones: ${result.migratedRatings}, '
              'Listas: ${result.migratedCustomLists}');
        } else {
          LoggerFactory.error('❌ Error en sincronización post-autenticación: ${result.error}');
        }
      } catch (e) {
        LoggerFactory.error('❌ Fallo crítico en sincronización post-autenticación: $e');
      }
    };
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await safeUpdateState<void>(
      () async {
        LoggerFactory.info('🔑 Attempting direct login for: $email');

        // Try direct Supabase login first (bypass optimizer temporarily)
        try {
          await _authRepository.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          LoggerFactory.info('✅ Direct login successful');
        } catch (e) {
          LoggerFactory.error('❌ Direct login failed: $e');
          rethrow;
        }

        // Ejecutar callback post-autenticación si está disponible
        final user = _authRepository.currentUser;
        if (user != null && _onAuthSuccess != null) {
          await _onAuthSuccess!(user);
        }
      },
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        LoggerFactory.info('✅ Sign in successful (direct flow)');
      },
      onError: (userError) {
        state = AsyncValue.error(userError, StackTrace.current);
        LoggerFactory.warning('❌ Sign in failed: ${userError.title}');
      },
      operationName: 'signIn',
      context: OperationContext.authentication,
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? avatarUrl,
  }) async {
    await safeUpdateState<void>(
      () async {
        await _authRepository.signUpWithEmailAndPassword(
          email: email,
          password: password,
          fullName: fullName,
          avatarUrl: avatarUrl,
        );

        // Ejecutar callback post-autenticación si está disponible
        final user = _authRepository.currentUser;
        if (user != null && _onAuthSuccess != null) {
          await _onAuthSuccess!(user);
        }
      },
      onSuccess: (_) {
        state = const AsyncValue.data(null);
        LoggerFactory.info('✅ Sign up successful');
      },
      onError: (userError) {
        state = AsyncValue.error(userError, StackTrace.current);
        LoggerFactory.warning('❌ Sign up failed: ${userError.title}');
      },
      operationName: 'signUp',
      context: OperationContext.authentication,
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      // Use optimized logout flow
      final success = await _flowOptimizer.optimizeLogoutFlow();
      if (success) {
        state = const AsyncValue.data(null);
        LoggerFactory.info('✅ Sign out successful (optimized flow)');
      } else {
        throw Exception('Logout optimization failed');
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      LoggerFactory.error('❌ Sign out failed: $e');
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
}

// Provider del notifier de autenticación
final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<void>>(() {
  return AuthNotifier();
});

// Notifier para operaciones de perfil
class UserProfileNotifier extends Notifier<AsyncValue<UserProfile?>> {
  @override
  AsyncValue<UserProfile?> build() {
    return const AsyncValue.data(null);
  }

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

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
    NotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>(() {
  return UserProfileNotifier();
});

// Notifier para operaciones de estadísticas
class UserStatsNotifier extends Notifier<AsyncValue<UserStats?>> {
  @override
  AsyncValue<UserStats?> build() {
    return const AsyncValue.data(null);
  }

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

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
}

// Provider del notifier de estadísticas
final userStatsNotifierProvider =
    NotifierProvider<UserStatsNotifier, AsyncValue<UserStats?>>(() {
  return UserStatsNotifier();
});
