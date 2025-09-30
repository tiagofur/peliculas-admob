import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../../infrastructure/repositories/user_profile_repository_impl.dart';

/// Estado unificado de la sesión de usuario que combina autenticación y perfil
class UserSessionState {
  const UserSessionState({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.profile,
    this.error,
  });

  /// Estado inicial (antes de cualquier verificación)
  factory UserSessionState.initial() {
    return const UserSessionState(
      isLoading: true,
      isAuthenticated: false,
    );
  }

  /// Estado de invitado (guest mode)
  factory UserSessionState.guest() {
    return const UserSessionState(
      isLoading: false,
      isAuthenticated: false,
    );
  }

  /// Estado autenticado con perfil
  factory UserSessionState.authenticated({
    required User user,
    UserProfile? profile,
  }) {
    return UserSessionState(
      isLoading: false,
      isAuthenticated: true,
      user: user,
      profile: profile,
    );
  }

  /// Estado de error
  factory UserSessionState.error(String message) {
    return UserSessionState(
      isLoading: false,
      isAuthenticated: false,
      error: message,
    );
  }

  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final UserProfile? profile;
  final String? error;

  /// Usuario autenticado con información completa
  bool get hasCompleteProfile => isAuthenticated && profile != null;

  /// ID de usuario garantizado (nunca null cuando está autenticado)
  String? get userId => user?.id;

  /// Email del usuario
  String? get userEmail => user?.email;

  /// Nombre completo del usuario (prioriza profile, luego user)
  String? get displayName => profile?.fullName ?? user?.fullName;

  /// Avatar URL del perfil
  String? get avatarUrl => profile?.avatarUrl;

  /// Avatar hash para cache busting
  String? get avatarHash => profile?.avatarHash;

  /// Username del perfil
  String? get username => profile?.username;

  /// Bio del perfil
  String? get bio => profile?.bio;

  UserSessionState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    User? user,
    UserProfile? profile,
    String? error,
  }) {
    return UserSessionState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'UserSessionState(isLoading: $isLoading, isAuthenticated: $isAuthenticated, userId: $userId, hasProfile: ${profile != null})';
  }
}

/// Notifier que gestiona el estado unificado de la sesión de usuario
class UserSessionNotifier extends Notifier<UserSessionState> {
  UserSessionNotifier();

  late final AuthRepository _authRepository;
  late final UserProfileRepository _profileRepository;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  @override
  UserSessionState build() {
    _authRepository = AuthRepositoryImpl();
    _profileRepository = UserProfileRepositoryImpl();

    // Inicializar en el siguiente frame para evitar setState durante build
    Future.microtask(() => _initialize());

    // Cleanup en dispose
    ref.onDispose(() {
      _authSubscription?.cancel();
      _profileSubscription?.cancel();
    });

    return UserSessionState.initial();
  }

  static const String _cacheKey = 'user_session_cache';

  /// Inicialización: verifica sesión y carga perfil
  Future<void> _initialize() async {
    try {
      LoggerFactory.info(
          '🔐 UserSessionNotifier: Iniciando verificación de sesión');

      // 1. Intentar cargar desde caché primero (para UI inmediata)
      await _loadFromCache();

      // 2. Verificar sesión actual de Supabase (síncrono)
      final currentUser = _authRepository.currentUser;

      if (currentUser != null) {
        LoggerFactory.info(
            '✅ UserSessionNotifier: Sesión activa detectada: ${currentUser.id}');

        // 3. Cargar perfil en paralelo
        await _loadProfile(currentUser);

        // 4. Configurar listeners para actualizaciones en tiempo real
        _setupAuthListener();
        _setupProfileListener(currentUser.id);
      } else {
        LoggerFactory.info(
            '👤 UserSessionNotifier: No hay sesión activa, modo guest');
        state = UserSessionState.guest();

        // Aún así configurar auth listener por si el usuario hace login
        _setupAuthListener();
      }
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ UserSessionNotifier: Error en inicialización: $e',
          stackTrace: stackTrace);
      state = UserSessionState.error('Error al inicializar sesión');
    }
  }

  /// Carga el perfil del usuario desde Supabase
  Future<void> _loadProfile(User user) async {
    try {
      LoggerFactory.info(
          '📥 UserSessionNotifier: Cargando perfil para ${user.id}');

      final profile =
          await _profileRepository.fetchProfile(user.id, ensureExists: true);

      state = UserSessionState.authenticated(
        user: user,
        profile: profile,
      );

      LoggerFactory.info('✅ UserSessionNotifier: Perfil cargado exitosamente');

      // Guardar en caché
      await _saveToCache();
    } catch (e, stackTrace) {
      LoggerFactory.error('⚠️ UserSessionNotifier: Error cargando perfil: $e',
          stackTrace: stackTrace);

      // Mantener autenticado aunque falle el perfil
      state = UserSessionState.authenticated(user: user);
    }
  }

  /// Configura el listener de cambios de autenticación
  void _setupAuthListener() {
    _authSubscription?.cancel();

    _authSubscription = _authRepository.authStateChanges.listen(
      (user) async {
        if (user != null) {
          LoggerFactory.info(
              '🔐 UserSessionNotifier: Usuario autenticado (stream): ${user.id}');

          // Cargar perfil
          await _loadProfile(user);

          // Configurar profile listener
          _setupProfileListener(user.id);
        } else {
          LoggerFactory.info(
              '👤 UserSessionNotifier: Usuario deslogueado (stream)');

          // Limpiar perfil listener
          _profileSubscription?.cancel();
          _profileSubscription = null;

          // Cambiar a guest mode
          state = UserSessionState.guest();

          // Limpiar caché
          await _clearCache();
        }
      },
      onError: (error, stackTrace) {
        LoggerFactory.error(
            '❌ UserSessionNotifier: Error en auth stream: $error',
            stackTrace: stackTrace);
        state = UserSessionState.error('Error de autenticación');
      },
    );
  }

  /// Configura el listener de cambios de perfil en tiempo real
  void _setupProfileListener(String userId) {
    _profileSubscription?.cancel();

    _profileSubscription = _profileRepository.watchProfile(userId).listen(
      (profile) {
        if (profile != null && state.user != null) {
          LoggerFactory.info(
              '🔄 UserSessionNotifier: Perfil actualizado en tiempo real');

          state = state.copyWith(profile: profile);

          // Actualizar caché
          _saveToCache();
        }
      },
      onError: (error, stackTrace) {
        LoggerFactory.error(
            '⚠️ UserSessionNotifier: Error en profile stream: $error',
            stackTrace: stackTrace);
        // No cambiar el estado, mantener el perfil anterior
      },
    );
  }

  /// Recarga el perfil manualmente desde Supabase
  Future<void> refreshProfile() async {
    final user = state.user;
    if (user == null) {
      LoggerFactory.warning(
          '⚠️ UserSessionNotifier.refreshProfile: No hay usuario autenticado');
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      LoggerFactory.info(
          '🔄 UserSessionNotifier: Refrescando perfil para ${user.id}');

      final profile =
          await _profileRepository.fetchProfile(user.id, ensureExists: true);

      state = UserSessionState.authenticated(
        user: user,
        profile: profile,
      );

      await _saveToCache();

      LoggerFactory.info(
          '✅ UserSessionNotifier: Perfil refrescado exitosamente');
    } catch (e, stackTrace) {
      LoggerFactory.error('❌ UserSessionNotifier: Error refrescando perfil: $e',
          stackTrace: stackTrace);

      // Mantener estado anterior pero quitar loading
      state = state.copyWith(isLoading: false);
    }
  }

  /// Actualiza el perfil del usuario
  Future<void> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
  }) async {
    final user = state.user;
    if (user == null) {
      throw Exception('No hay usuario autenticado para actualizar perfil');
    }

    state = state.copyWith(isLoading: true);

    try {
      LoggerFactory.info(
          '💾 UserSessionNotifier: Actualizando perfil para ${user.id}');

      // Actualizar en Supabase usando el método del repositorio
      final updatedProfile = await _profileRepository.updateProfile(
        userId: user.id,
        fullName: fullName,
        username: username,
        bio: bio,
        avatarUrl: avatarUrl,
        avatarHash: avatarHash,
        stats: stats,
        preferences: preferences,
      );

      // Actualizar estado local
      state = UserSessionState.authenticated(
        user: user,
        profile: updatedProfile,
      );

      await _saveToCache();

      LoggerFactory.info(
          '✅ UserSessionNotifier: Perfil actualizado exitosamente');
    } catch (e, stackTrace) {
      LoggerFactory.error(
          '❌ UserSessionNotifier: Error actualizando perfil: $e',
          stackTrace: stackTrace);

      // Mantener estado anterior pero quitar loading
      state = state.copyWith(isLoading: false);

      rethrow;
    }
  }

  /// Guarda el estado en caché local
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (state.isAuthenticated && state.user != null) {
        final cache = {
          'user': {
            'id': state.user!.id,
            'email': state.user!.email,
            'fullName': state.user!.fullName,
          },
          'profile': state.profile != null
              ? {
                  'id': state.profile!.id,
                  'fullName': state.profile!.fullName,
                  'username': state.profile!.username,
                  'bio': state.profile!.bio,
                  'avatarUrl': state.profile!.avatarUrl,
                  'avatarHash': state.profile!.avatarHash,
                }
              : null,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await prefs.setString(_cacheKey, jsonEncode(cache));
        LoggerFactory.info('💾 UserSessionNotifier: Estado guardado en caché');
      }
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ UserSessionNotifier: Error guardando caché: $e');
    }
  }

  /// Carga el estado desde caché local
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_cacheKey);

      if (cacheString != null) {
        final cache = jsonDecode(cacheString) as Map<String, dynamic>;
        final timestamp = DateTime.parse(cache['timestamp'] as String);

        // Solo usar caché si es reciente (menos de 24 horas)
        if (DateTime.now().difference(timestamp).inHours < 24) {
          final userData = cache['user'] as Map<String, dynamic>;
          final profileData = cache['profile'] as Map<String, dynamic>?;

          final user = User(
            id: userData['id'] as String,
            email: userData['email'] as String,
            fullName: userData['fullName'] as String?,
            createdAt: DateTime.now(), // Placeholder desde caché
          );

          UserProfile? profile;
          if (profileData != null) {
            profile = UserProfile(
              id: profileData['id'] as String,
              userId: userData['id'] as String,
              fullName: profileData['fullName'] as String,
              username: profileData['username'] as String?,
              bio: profileData['bio'] as String?,
              avatarUrl: profileData['avatarUrl'] as String?,
              avatarHash: profileData['avatarHash'] as String?,
              stats: const {},
              preferences: const {},
              createdAt: DateTime.now(), // Placeholder desde caché
              updatedAt: DateTime.now(), // Placeholder desde caché
            );
          }

          state = UserSessionState.authenticated(
            user: user,
            profile: profile,
          );

          LoggerFactory.info(
              '📥 UserSessionNotifier: Estado cargado desde caché');
        } else {
          LoggerFactory.info(
              '⏰ UserSessionNotifier: Caché expirado, ignorando');
        }
      }
    } catch (e) {
      LoggerFactory.warning('⚠️ UserSessionNotifier: Error cargando caché: $e');
    }
  }

  /// Limpia el caché local
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      LoggerFactory.info('🗑️ UserSessionNotifier: Caché limpiado');
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ UserSessionNotifier: Error limpiando caché: $e');
    }
  }
}

/// Provider del estado unificado de la sesión de usuario
final userSessionProvider =
    NotifierProvider<UserSessionNotifier, UserSessionState>(() {
  return UserSessionNotifier();
});

/// Providers derivados para facilitar el acceso

/// Provider que indica si el usuario está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref
      .watch(userSessionProvider.select((state) => state.isAuthenticated));
});

/// Provider del usuario actual
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(userSessionProvider.select((state) => state.user));
});

/// Provider del perfil actual
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(userSessionProvider.select((state) => state.profile));
});

/// Provider del ID de usuario (garantizado cuando está autenticado)
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userSessionProvider.select((state) => state.userId));
});

/// Provider del display name (prioriza profile, luego user)
final displayNameProvider = Provider<String?>((ref) {
  return ref.watch(userSessionProvider.select((state) => state.displayName));
});
