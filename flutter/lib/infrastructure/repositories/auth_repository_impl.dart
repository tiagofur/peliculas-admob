import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/api_keys.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/cache/image_cache_manager.dart';
import '../../core/config/supabase_config.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/uuid_generator.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../models/user_stats_model.dart';
import '../services/auth_session_manager.dart';
import '../services/token_refresh_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl() {
    _initAuthStateStream();
    _initializePersistentAuth();
  }
  final SupabaseClient _supabase = SupabaseConfig.client;
  final AuthSessionManager _sessionManager = AuthSessionManager.instance;
  final TokenRefreshService _tokenRefreshService = TokenRefreshService.instance;
  final ImageCompressor _imageCompressor = const ImageCompressor();
  final UuidGenerator _uuidGenerator = const UuidGenerator();

  // GoogleSignIn v7: singleton + inicialización explícita única
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  StreamController<domain.User?>? _authStateController;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<TokenRefreshEvent>? _tokenRefreshSubscription;

  /// Obtiene el Google Client ID Web desde la configuración
  String? _getGoogleClientId() {
    try {
      return ApiKeys.googleClientIdWeb;
    } catch (e) {
      LoggerFactory.warning(
          '⚠️ Google Client ID not configured. Google Sign-In will not work. '
          'Configure GOOGLE_CLIENT_ID_WEB in .env file');
      return null;
    }
  }

  static const _googleScopes = <String>[
    'email',
    'profile',
    'openid',
  ];

  /// Inicializa el singleton de GoogleSignIn exactamente una vez (v7).
  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    final webClientId = _getGoogleClientId();

    if (kIsWeb) {
      if (webClientId == null) {
        LoggerFactory.error(
          '❌ GOOGLE_CLIENT_ID_WEB requerido para Google Sign-In en Web. '
          'Configura la variable en .env o dart-define.',
        );
      }
      await GoogleSignIn.instance.initialize(clientId: webClientId);
    } else {
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    }
    _googleSignInInitialized = true;
  }

  void _initAuthStateStream() {
    _authStateController = StreamController<domain.User?>.broadcast();

    // Emitir el estado inicial inmediatamente
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      _authStateController?.add(UserModel.fromSupabaseUser(currentUser));
    } else {
      _authStateController?.add(null);
    }

    // Escuchar cambios de estado
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        _authStateController?.add(UserModel.fromSupabaseUser(user));

        // Persistir sesión de forma no bloqueante cuando se autentica
        if (data.session != null) {
          _persistSessionAsync(data.session!);
        }

        // Track onboarding completion for first-time users
        await _trackOnboardingCompletion(user.id);
      } else {
        _authStateController?.add(null);

        // Limpiar datos persistentes cuando se desautentica
        _sessionManager.clearSession();
      }
    });

    // Escuchar eventos de refresco de tokens
    _tokenRefreshSubscription = _tokenRefreshService.events.listen((event) {
      switch (event) {
        case SessionInvalidatedEvent():
          // Notificar que la sesión se invalidó
          _authStateController?.add(null);
          LoggerFactory.warning('⚠️ Sesión invalidada por fallo en refresh');
          break;
        case RefreshFailedEvent():
          LoggerFactory.error('❌ Fallo en refresco de token: ${event.error}');
          break;
        case TokenRefreshedEvent():
          LoggerFactory.info(
              '✅ Token refrescado exitosamente para usuario: ${event.userId}');
          break;
        default:
          break;
      }
    });
  }

  /// Inicializa la autenticación persistente
  Future<void> _initializePersistentAuth() async {
    try {
      // Inicializar gestores de sesión y tokens
      await _sessionManager.initialize();
      await _tokenRefreshService.initialize();

      // Intentar recuperar sesión persistente
      final recovered = await _sessionManager.recoverSession();
      if (recovered) {
        LoggerFactory.info('✅ Sesión persistente recuperada exitosamente');
      }
    } catch (e) {
      LoggerFactory.error(
          '❌ Error inicializando autenticación persistente: $e');
    }
  }

  @override
  Stream<domain.User?> get authStateChanges =>
      _authStateController?.stream ?? const Stream.empty();

  @override
  domain.User? get currentUser {
    final user = _supabase.auth.currentUser;
    return user != null ? UserModel.fromSupabaseUser(user) : null;
  }

  @override
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  @override
  Future<domain.User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al iniciar sesión');
      }

      // Persistir sesión de forma no bloqueante
      // No esperamos la persistencia para no bloquear el login
      if (response.session != null) {
        _persistSessionAsync(response.session!);
      }

      if (response.user == null) {
        throw Exception('Usuario no encontrado en la respuesta');
      }
      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      // Manejar específicamente el error de email no confirmado
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw const EmailConfirmationRequiredException(
          'Tu email aún no ha sido confirmado. '
          'Por favor, revisa tu bandeja de entrada y confirma tu email antes de iniciar sesión.',
        );
      }
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Error inesperado al iniciar sesión');
    }
  }

  @override
  Future<domain.User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'avatar_url': ?avatarUrl,
        },
      );

      if (response.user == null) {
        throw Exception('Error al crear la cuenta');
      }

      // Verificar si el email necesita confirmación
      if (response.session == null) {
        throw EmailConfirmationRequiredException(
          'Se ha enviado un email de confirmación a $email. '
          'Por favor, revisa tu bandeja de entrada y confirma tu email antes de iniciar sesión.',
        );
      }

      // Persistir sesión de forma no bloqueante
      // No esperamos la persistencia para no bloquear el signup
      if (response.session != null) {
        _persistSessionAsync(response.session!);
      }

      if (response.user == null) {
        throw Exception('Usuario no encontrado en la respuesta');
      }
      return UserModel.fromSupabaseUser(response.user!);
    } on EmailConfirmationRequiredException {
      rethrow;
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Error inesperado al crear la cuenta');
    }
  }

  @override
  Future<domain.User> signInWithGoogle() async {
    try {
      // En Web migramos al flujo oficial de Supabase OAuth para Google
      // evitando el uso de google_sign_in_web.signIn() (obsoleto y poco fiable para idToken)
      if (kIsWeb) {
        final redirectOrigin = Uri.base.origin;

        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectOrigin,
        );

        // Esperar a que Supabase complete la sesión (popup/redirect)
        final supabaseUser = await _waitForSupabaseUser();
        if (supabaseUser == null) {
          throw Exception('No se pudo completar la autenticación con Google');
        }

        await _ensureDefaultUserProfile(supabaseUser.id);
        LoggerFactory.info(
            '✅ Autenticación con Google (Web/OAuth) exitosa: ${supabaseUser.email}');
        return UserModel.fromSupabaseUser(supabaseUser);
      }

      // 1. Iniciar el flujo de autenticación de Google (v7: authenticate)
      await _ensureGoogleSignInInitialized();
      late final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate(
          scopeHint: _googleScopes,
        );
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          throw Exception('Autenticación de Google cancelada');
        }
        rethrow;
      }

      // 2. Obtener los detalles de autenticación (v7: getter síncrono)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = await googleUser.authorizationClient
          .authorizationForScopes(_googleScopes)
          .then((auth) => auth?.accessToken);

      if (idToken == null) {
        throw Exception('No se pudo obtener el idToken de Google');
      }

      // 3. Autenticar con Supabase usando el ID token de Google
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw Exception('Error al autenticar con Supabase');
      }

      // 4. Persistir sesión de forma no bloqueante
      // No esperamos la persistencia para no bloquear el login
      // Supabase ya maneja la sesión automáticamente en Web
      if (response.session != null) {
        _persistSessionAsync(response.session!);
      }

      // 5. Asegurar que existe el perfil de usuario
      await _ensureDefaultUserProfile(response.user!.id);

      LoggerFactory.info(
          '✅ Autenticación con Google exitosa: ${response.user!.email}');

      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      LoggerFactory.error('❌ Error de autenticación de Google: ${e.message}');
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      // Fallback solo en Android/iOS: usar OAuth de Supabase con deep link
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        LoggerFactory.warning(
            '⚠️ GoogleSignIn nativo falló, intentando OAuth móvil con deep link: $e');

        final redirectUri = Uri.parse('peliculas://auth-callback');
        try {
          await _supabase.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: redirectUri
                .toString(), // SIEMPRE deep link, nunca Uri.base.origin
          );

          final user = await _waitForSupabaseUser();
          if (user == null) {
            throw Exception('No se completó la autenticación OAuth de Google');
          }

          await _ensureDefaultUserProfile(user.id);
          LoggerFactory.info(
              '✅ Autenticación con Google (OAuth móvil) exitosa: ${user.email}');
          return UserModel.fromSupabaseUser(user);
        } on AuthException catch (e2) {
          LoggerFactory.error(
              '❌ Error de autenticación OAuth (móvil) con Google: ${e2.message}');
          throw Exception(_getAuthErrorMessage(e2.message));
        } catch (e2) {
          LoggerFactory.error(
              '❌ Error inesperado en autenticación OAuth (móvil) con Google: $e2');
          throw Exception('Error al autenticar con Google: ${e2.toString()}');
        }
      }
      // Desktop: mostrar error claro
      else if (!kIsWeb &&
          (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
        LoggerFactory.error(
            '❌ Login con Google no soportado en escritorio nativo. Usa la versión Web.');
        throw Exception(
            'Login con Google no soportado en escritorio nativo. Usa la versión Web.');
      }

      LoggerFactory.error('❌ Error inesperado en autenticación de Google: $e');
      throw Exception('Error al autenticar con Google: ${e.toString()}');
    }
  }

  Future<User?> _waitForSupabaseUser(
      {Duration timeout = const Duration(seconds: 20)}) async {
    // Retornar inmediatamente si ya existe
    final current = _supabase.auth.currentUser;
    if (current != null) return current;

    final completer = Completer<User?>();
    late StreamSubscription<AuthState> sub;
    sub = _supabase.auth.onAuthStateChange.listen((event) {
      final user = event.session?.user;
      if (user != null && !completer.isCompleted) {
        completer.complete(user);
        sub.cancel();
      }
    });

    try {
      return await completer.future
          .timeout(timeout, onTimeout: () => _supabase.auth.currentUser);
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Cerrar sesión de Google (signOut es idempotente en v7)
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();

      // Limpiar datos persistentes antes de cerrar sesión
      await _sessionManager.clearSession();

      // Cerrar sesión en Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión');
    }
  }

  void _persistSessionAsync(Session session) {
    if (kIsWeb) {
      if (kDebugMode) {
        LoggerFactory.debug(
            'AuthRepositoryImpl (Web): se omite persistencia manual de sesión');
      }
      return;
    }

    unawaited(() async {
      try {
        await _sessionManager.persistSession(session);
      } catch (error) {
        LoggerFactory.warning(
            '⚠️ No se pudo persistir sesión localmente (no crítico): $error');
      }
    }());
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Error al enviar email de recuperación');
    }
  }

  @override
  Future<domain.User> updateUser({
    String? fullName,
    String? avatarUrl,
    String? email,
  }) async {
    try {
      final updateAttributes = UserAttributes(
        email: email,
        data: {
          'full_name': ?fullName,
          'display_name': ?fullName,
          'avatar_url': ?avatarUrl,
        },
      );

      final response = await _supabase.auth.updateUser(updateAttributes);

      if (response.user == null) {
        throw Exception('Error al actualizar usuario');
      }

      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Error inesperado al actualizar usuario');
    }
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfileModel.fromJson(response);
      }

      LoggerFactory.warning(
        '🔍 No se encontró user_profiles para $userId, creando registro por defecto',
      );

      return await _ensureDefaultUserProfile(userId);
    } catch (e) {
      LoggerFactory.error(
        '❌ Error al obtener perfil de usuario $userId: $e',
      );
      throw Exception('Error al obtener perfil de usuario');
    }
  }

  @override
  Future<UserProfile> updateUserProfile({
    required String userId,
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
  }) async {
    try {
      final trimmedFullName = fullName?.trim();
      final sanitizedUsername = username?.trim();
      final clearUsername =
          sanitizedUsername != null && sanitizedUsername.isEmpty;
      final normalizedUsername = clearUsername || sanitizedUsername == null
          ? null
          : sanitizedUsername.toLowerCase();
      final sanitizedBio = bio?.trim();

      final updateData = <String, dynamic>{
        if (trimmedFullName != null && trimmedFullName.isNotEmpty)
          'display_name': trimmedFullName,
        if (clearUsername)
          'username': null
        else 'username': ?normalizedUsername,
        if (sanitizedBio != null && sanitizedBio.isNotEmpty)
          'bio': sanitizedBio,
        'avatar_url': ?avatarUrl,
        'avatar_hash': ?avatarHash,
        'stats': ?stats,
        'preferences': ?preferences,
        'updated_at': DateTime.now().toIso8601String(),
        'last_synced_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('user_profiles')
          .upsert(
            {
              'user_id': userId,
              ...updateData,
            },
            onConflict: 'user_id',
          )
          .select()
          .single();

      return UserProfileModel.fromJson(response);
    } catch (e) {
      // Manejo especial para problemas de tabla/estructura
      if (e.toString().contains('400') ||
          e.toString().contains('Bad Request') ||
          e.toString().contains('table') ||
          e.toString().contains('column')) {
        LoggerFactory.warning(
            '⚠️ user_profiles table issue in updateProfile. Please run migration.');
        // Retornar un perfil básico en lugar de fallar
        final now = DateTime.now();
        return UserProfileModel(
          id: 'temp_id',
          userId: userId,
          username: null,
          fullName: 'Usuario Anónimo',
          bio: null,
          avatarUrl: null,
          createdAt: now,
          updatedAt: now,
        );
      }

      throw Exception('Error al actualizar perfil');
    }
  }

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final normalized = username.trim().toLowerCase();
      final response = await _supabase
          .from('user_profiles')
          .select('user_id')
          .ilike('username', normalized)
          .maybeSingle();

      return response == null;
    } catch (e) {
      LoggerFactory.error('❌ Error verificando username $username: $e');
      throw Exception('Error al verificar disponibilidad de usuario');
    }
  }

  Future<UserProfile?> _ensureDefaultUserProfile(String userId) async {
    try {
      final supabaseUser = _supabase.auth.currentUser;
      final metadata = supabaseUser?.userMetadata ?? <String, dynamic>{};

      final resolvedFullName = (() {
        final possibleNames = [
          metadata['full_name'],
          metadata['display_name'],
        ];

        for (final candidate in possibleNames) {
          if (candidate is String && candidate.trim().isNotEmpty) {
            return candidate.trim();
          }
        }

        final email = supabaseUser?.email;
        if (email != null && email.contains('@')) {
          return email.split('@').first;
        }
        return 'Usuario';
      })();

      final profileModel = UserProfileModel.create(
        userId: userId,
        fullName: resolvedFullName,
        avatarUrl: metadata['avatar_url'] as String?,
      );

      final insertedProfile = await _supabase
          .from('user_profiles')
          .upsert(
            profileModel.toInsertJson(),
            onConflict: 'user_id',
          )
          .select()
          .single();

      LoggerFactory.info(
        '✅ Registro user_profiles creado/recuperado automáticamente para $userId',
      );

      return UserProfileModel.fromJson(insertedProfile);
    } catch (e) {
      // Manejo especial para problemas de tabla/estructura
      if (e.toString().contains('400') ||
          e.toString().contains('Bad Request') ||
          e.toString().contains('table') ||
          e.toString().contains('column')) {
        LoggerFactory.warning(
            '⚠️ user_profiles table issue in _createUserProfileRecord. Please run migration.');
        // Retornar un perfil básico en lugar de fallar
        final now = DateTime.now();
        final fallbackMetadata =
            _supabase.auth.currentUser?.userMetadata ?? <String, dynamic>{};
        final fallbackName = fallbackMetadata['full_name'] as String? ??
            fallbackMetadata['display_name'] as String? ??
            'Usuario Anónimo';
        return UserProfileModel(
          id: 'temp_id',
          userId: userId,
          username: null,
          fullName: fallbackName,
          bio: null,
          avatarUrl: fallbackMetadata['avatar_url'] as String?,
          createdAt: now,
          updatedAt: now,
        );
      }

      LoggerFactory.error(
        '❌ No se pudo crear el perfil por defecto para $userId: $e',
      );
      rethrow;
    }
  }

  @override
  Future<UserStats?> getUserStats(String userId) async {
    try {
      final response = await _supabase
          .from('user_stats')
          .select()
          .filter('user_id', 'eq', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserStatsModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al obtener estadísticas de usuario');
    }
  }

  @override
  Future<UserStats> updateUserStats({
    required String userId,
    int? moviesWatched,
    int? favoritesCount,
    int? listsCount,
  }) async {
    try {
      final updateData = {
        'movies_watched': ?moviesWatched,
        'favorites_count': ?favoritesCount,
        'lists_count': ?listsCount,
        'last_activity': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('user_stats')
          .update(updateData)
          .filter('user_id', 'eq', userId)
          .select()
          .single();

      return UserStatsModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar estadísticas');
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
    String? existingUrl,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('Archivo de avatar no encontrado');
      }

      final originalBytes = await file.readAsBytes();
      final compressedBytes = await _imageCompressor.compress(
        originalBytes,
        maxWidth: 800,
        maxHeight: 800,
        quality: 85,
      );

      final fileExt = filePath.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = _uuidGenerator.v4();
      final objectPath = '$userId/${timestamp}_$uuid.$fileExt';

      await _supabase.storage.from('avatars').uploadBinary(
            objectPath,
            compressedBytes,
            fileOptions: const FileOptions(
              upsert: true,
              cacheControl: 'public, max-age=31536000, immutable',
            ),
          );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(objectPath);

      if (existingUrl != null && existingUrl.isNotEmpty) {
        await ImageCacheManager.instance.evictUrl(existingUrl);
        final oldPath = _extractStoragePath(existingUrl);
        if (oldPath != null) {
          await _supabase.storage.from('avatars').remove([oldPath]);
        }
      }

      return publicUrl;
    } catch (e) {
      throw Exception('Error al subir avatar');
    }
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    try {
      final files = await _supabase.storage.from('avatars').list(path: userId);

      for (final file in files) {
        await _supabase.storage
            .from('avatars')
            .remove(['$userId/${file.name}']);
      }
    } catch (e) {
      throw Exception('Error al eliminar avatar');
    }
  }

  String? _extractStoragePath(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final publicIndex = segments.indexOf('public');
      if (publicIndex != -1 && publicIndex + 1 < segments.length) {
        return segments.sublist(publicIndex + 1).join('/');
      }
      if (segments.contains('avatars')) {
        final avatarsIndex = segments.indexOf('avatars');
        return segments.sublist(avatarsIndex).join('/');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    try {
      // Nota: Supabase no tiene una API directa para verificar disponibilidad de email
      // Esta implementación es básica y podría mejorarse
      return true;
    } catch (e) {
      return false;
    }
  }

  // Operaciones de sesión persistente

  @override
  Future<bool> hasPersistedSession() async {
    try {
      return await _sessionManager.hasPersistedSession();
    } catch (e) {
      LoggerFactory.error('❌ Error verificando sesión persistente: $e');
      return false;
    }
  }

  @override
  Future<bool> validateCurrentSession() async {
    try {
      return await _sessionManager.validateCurrentSession();
    } catch (e) {
      LoggerFactory.error('❌ Error validando sesión actual: $e');
      return false;
    }
  }

  @override
  Future<void> refreshToken() async {
    try {
      final success = await _tokenRefreshService.forceRefresh();
      if (!success) {
        throw Exception('No se pudo refrescar el token');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error refrescando token: $e');
      throw Exception('Error al refrescar token de autenticación');
    }
  }

  @override
  Future<Map<String, dynamic>?> getSessionInfo() async {
    try {
      final sessionInfo = await _sessionManager.getSessionInfo();
      final tokenStatus = await _tokenRefreshService.getTokenStatus();

      return {
        'session': sessionInfo,
        'token_status': {
          'has_token': tokenStatus.hasToken,
          'is_valid': tokenStatus.isValid,
          'expires_at': tokenStatus.expiresAt?.toIso8601String(),
          'time_until_expiry_minutes': tokenStatus.timeUntilExpiry?.inMinutes,
          'needs_refresh': tokenStatus.needsRefresh,
          'is_refreshing': tokenStatus.isRefreshing,
          'is_healthy': tokenStatus.isHealthy,
          'error': tokenStatus.error,
        },
      };
    } catch (e) {
      LoggerFactory.error('❌ Error obteniendo información de sesión: $e');
      return null;
    }
  }

  // Método para reenviar email de confirmación
  @override
  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.message));
    } catch (e) {
      throw Exception('Error al reenviar email de confirmación');
    }
  }

  String _getAuthErrorMessage(String error) {
    switch (error.toLowerCase()) {
      case 'invalid login credentials':
        return 'Credenciales inválidas. Verifica tu email y contraseña.';
      case 'email not confirmed':
        return 'Email no confirmado. Revisa tu bandeja de entrada.';
      case 'user not found':
        return 'Usuario no encontrado';
      case 'invalid email':
        return 'Email inválido';
      case 'weak password':
        return 'Contraseña muy débil';
      case 'email already registered':
        return 'Este email ya está registrado';
      case 'signup disabled':
        return 'El registro está temporalmente deshabilitado';
      default:
        return error;
    }
  }

  /// Track onboarding completion for first-time users
  Future<void> _trackOnboardingCompletion(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingKey = 'onboarding_completed_$userId';

      // Check if this user has already completed onboarding
      final hasCompletedOnboarding = prefs.getBool(onboardingKey) ?? false;
      if (!hasCompletedOnboarding) {
        // Mark onboarding as completed for this user
        await prefs.setBool(onboardingKey, true);

        // Track analytics event for onboarding completion
        await AnalyticsService().trackEvent(
          AnalyticsEventType.onboarding,
          {
            'user_id': userId,
            'action': 'onboarding_completed',
            'completion_method': 'authentication',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );

        LoggerFactory.info('✅ Onboarding completion tracked for user: $userId');
      }
    } catch (e) {
      LoggerFactory.error('❌ Error tracking onboarding completion: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _authStateController?.close();
    _sessionManager.dispose();
    _tokenRefreshService.dispose();
  }
}
