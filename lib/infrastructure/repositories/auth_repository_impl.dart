import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../../core/logging/logger_factory.dart';
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
  StreamController<domain.User?>? _authStateController;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<TokenRefreshEvent>? _tokenRefreshSubscription;

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
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _authStateController?.add(UserModel.fromSupabaseUser(user));
        
        // Persistir sesión cuando se autentica
        if (data.session != null) {
          _sessionManager.persistSession(data.session!);
        }
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
          LoggerFactory.info('✅ Token refrescado exitosamente para usuario: ${event.userId}');
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
      LoggerFactory.error('❌ Error inicializando autenticación persistente: $e');
    }
  }

  @override
  Stream<domain.User?> get authStateChanges => _authStateController!.stream;

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

      // Persistir sesión inmediatamente después de login exitoso
      if (response.session != null) {
        await _sessionManager.persistSession(response.session!);
      }

      return UserModel.fromSupabaseUser(response.user!);
    } on AuthException catch (e) {
      // Manejar específicamente el error de email no confirmado
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw EmailConfirmationRequiredException(
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
          if (avatarUrl != null) 'avatar_url': avatarUrl,
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

      // Persistir sesión inmediatamente después de signup exitoso
      await _sessionManager.persistSession(response.session!);

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
  Future<void> signOut() async {
    try {
      // Limpiar datos persistentes antes de cerrar sesión
      await _sessionManager.clearSession();
      
      // Cerrar sesión en Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión');
    }
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
          if (fullName != null) 'full_name': fullName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
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

      if (response == null) return null;

      return UserProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al obtener perfil de usuario');
    }
  }

  @override
  Future<UserProfile> updateUserProfile({
    required String userId,
    String? fullName,
    String? bio,
    String? avatarUrl,
  }) async {
    try {
      final updateData = {
        if (fullName != null) 'full_name': fullName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('user_id', userId)
          .select()
          .single();

      return UserProfileModel.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar perfil');
    }
  }

  @override
  Future<UserStats?> getUserStats(String userId) async {
    try {
      final response = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
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
        if (moviesWatched != null) 'movies_watched': moviesWatched,
        if (favoritesCount != null) 'favorites_count': favoritesCount,
        if (listsCount != null) 'lists_count': listsCount,
        'last_activity': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('user_stats')
          .update(updateData)
          .eq('user_id', userId)
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
  }) async {
    try {
      final file = File(filePath);
      final fileExt = filePath.split('.').last;
      final fileName = '$userId/avatar.$fileExt';

      await _supabase.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(fileName);
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _authStateController?.close();
    _sessionManager.dispose();
    _tokenRefreshService.dispose();
  }
}
