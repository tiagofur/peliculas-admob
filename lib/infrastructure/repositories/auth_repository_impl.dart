import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/exceptions/auth_exceptions.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';
import '../models/user_stats_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;
  StreamController<domain.User?>? _authStateController;
  StreamSubscription<AuthState>? _authSubscription;

  AuthRepositoryImpl() {
    _initAuthStateStream();
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
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        _authStateController?.add(UserModel.fromSupabaseUser(user));
      } else {
        _authStateController?.add(null);
      }
    });
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
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            if (fullName != null) 'full_name': fullName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );

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

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
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
        await _supabase.storage.from('avatars').remove(['$userId/${file.name}']);
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

  // Método para reenviar email de confirmación
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
    _authStateController?.close();
  }
}