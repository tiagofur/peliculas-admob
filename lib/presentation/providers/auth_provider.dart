import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/auth_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../../infrastructure/services/anonymous_data_migrator.dart';
import './hybrid_repositories_provider.dart';

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
  return AppStateNotifier(ref);
});

// Notifier para manejar el estado de la aplicación
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this._ref) : super(const AppState(mode: AppMode.guest)) {
    // Inicializar con el estado actual de autenticación
    _initializeWithCurrentAuthState();

    // Escuchar cambios en el estado de autenticación
    _ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
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
            _detectLocalDataOnStartup();
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
          _detectLocalDataOnStartup();
        },
      );
    });
    
    // Detectar datos locales en el startup inicial
    _detectLocalDataOnStartup();
  }
  final Ref _ref;

  // Método para inicializar con el estado actual de autenticación
  void _initializeWithCurrentAuthState() {
    final currentAuthState = _ref.read(authStateProvider);
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

  // Método para detectar datos locales en el startup
  void _detectLocalDataOnStartup() {
    // Ejecutar en background para no bloquear la UI
    Future.microtask(() async {
      try {
        final migrator = _ref.read(anonymousDataMigratorProvider);
        final detectedData = await migrator.detectAnonymousData();
        
        final hasLocalData = detectedData.isNotEmpty;
        if (hasLocalData != state.hasLocalData) {
          state = state.copyWith(hasLocalData: hasLocalData);
          
          if (hasLocalData) {
            final totalItems = detectedData.values.fold(0, (sum, count) => sum + count);
            LoggerFactory.info('📱 Datos locales detectados al startup: $totalItems items ($detectedData)');
          }
        }
      } catch (e) {
        LoggerFactory.error('❌ Error detectando datos locales en startup: $e');
      }
    });
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
  AuthNotifier(this._authRepository, this._ref)
      : super(const AsyncValue.data(null));
  final AuthRepository _authRepository;
  final Ref _ref;

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
        LoggerFactory.info('🔄 Iniciando proceso post-autenticación...');
        
        final user = _ref.read(currentUserProvider);
        if (user == null) {
          LoggerFactory.warning('❌ No hay usuario disponible para migración y sincronización');
          return;
        }

        // 1. Detectar y migrar datos locales de usuario anónimo
        final migrator = _ref.read(anonymousDataMigratorProvider);
        final detectedData = await migrator.detectAnonymousData();
        
        if (detectedData.isNotEmpty) {
          LoggerFactory.info('📱 Datos locales detectados: $detectedData');
          _ref.read(appStateProvider.notifier).setHasLocalData(true);
          
          LoggerFactory.info('🔄 Migrando datos locales a usuario: ${user.id}');
          final migrationResult = await migrator.migrateAllData(user.id);
          
          if (migrationResult.success) {
            LoggerFactory.info('✅ Migración completada: ${migrationResult.migratedData}');
          } else {
            LoggerFactory.error('⚠️ Migración completada con errores: ${migrationResult.errors}');
          }
        } else {
          LoggerFactory.info('ℹ️ No hay datos locales para migrar');
        }

        // 2. Ejecutar sincronización de todas las entidades en segundo plano
        LoggerFactory.info('🔄 Iniciando sincronización en segundo plano para todas las entidades...');

        // Disparar la sincronización para cada repositorio sin esperar (no await)
        _ref.read(hybridFavoritesRepositoryProvider).forceSync();
        _ref.read(hybridWatchlistRepositoryProvider).forceSync();
        _ref.read(hybridWatchedRepositoryProvider).forceSync();
        _ref.read(hybridCustomListsRepositoryProvider).forceSync();

        LoggerFactory.info('✅ Sincronización para todas las entidades iniciada en segundo plano.');
        
      } catch (e) {
        // Log del error pero no afectar la experiencia del usuario
        LoggerFactory.error('❌ Error durante proceso post-autenticación: $e');
      }
    });
  }
}

// Provider del notifier de autenticación
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository, ref);
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
}

// Provider del notifier de estadísticas
final userStatsNotifierProvider =
    StateNotifierProvider<UserStatsNotifier, AsyncValue<UserStats?>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return UserStatsNotifier(authRepository);
});
