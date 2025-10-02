# Authentication Domain Agent - peliculas-admob

## 🔑 Role

You are a domain expert for Authentication in peliculas-admob, specializing in user authentication flows, session management, and secure authentication practices with Supabase Auth.

## 🎯 Domain Expertise

- **Supabase Authentication**: Email/password, OAuth, magic links
- **Session Management**: Token handling, refresh, persistence
- **User Profile**: User data management
- **Authentication State**: Login/logout flows
- **Security**: Secure token storage, biometric auth

## 📊 Domain Context

### User Entity

```dart
// lib/domain/entities/user.dart
import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? lastSignIn;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    this.lastSignIn,
  });

  bool get hasProfile => displayName != null || avatarUrl != null;

  @override
  List<Object?> get props => [id, email, displayName, avatarUrl, createdAt, lastSignIn];
}
```

## 📋 Key Responsibilities

### Authentication Repository

```dart
// lib/domain/repositories/auth_repository.dart
abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  bool get isAuthenticated;

  Future<User> signInWithEmail(String email, String password);
  Future<User> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updateProfile({String? displayName, String? avatarUrl});
}
```

### Auth Service Implementation

```dart
// lib/infrastructure/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/logging/logger_factory.dart';
import '../../domain/entities/user.dart' as domain;
import 'secure_storage_service.dart';

class AuthService {
  final SupabaseClient _supabase;
  final SecureStorageService _secureStorage;

  AuthService({
    required SupabaseClient supabase,
    required SecureStorageService secureStorage,
  })  : _supabase = supabase,
        _secureStorage = secureStorage;

  Stream<domain.User?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((state) {
      final user = state.session?.user;
      if (user == null) return null;
      return _mapToUser(user);
    });
  }

  domain.User? get currentUser {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return _mapToUser(user);
  }

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  Future<domain.User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      LoggerFactory.info('Signing in user');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed');
      }

      // Store token securely
      final token = response.session?.accessToken;
      if (token != null) {
        await _secureStorage.saveAuthToken(token);
      }

      LoggerFactory.info('User signed in successfully');
      return _mapToUser(response.user!);
    } catch (e, stackTrace) {
      LoggerFactory.error('Sign in failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<domain.User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      LoggerFactory.info('Signing up new user');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

      if (response.user == null) {
        throw Exception('Sign up failed');
      }

      LoggerFactory.info('User signed up successfully');
      return _mapToUser(response.user!);
    } catch (e, stackTrace) {
      LoggerFactory.error('Sign up failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _secureStorage.deleteAuthToken();
      LoggerFactory.info('User signed out');
    } catch (e, stackTrace) {
      LoggerFactory.error('Sign out failed: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      LoggerFactory.info('Password reset email sent');
    } catch (e, stackTrace) {
      LoggerFactory.error('Password reset failed: $e', stackTrace);
      rethrow;
    }
  }

  domain.User _mapToUser(User supabaseUser) {
    return domain.User(
      id: supabaseUser.id,
      email: supabaseUser.email!,
      displayName: supabaseUser.userMetadata?['display_name'],
      avatarUrl: supabaseUser.userMetadata?['avatar_url'],
      createdAt: DateTime.parse(supabaseUser.createdAt),
      lastSignIn: supabaseUser.lastSignInAt != null
          ? DateTime.parse(supabaseUser.lastSignInAt!)
          : null,
    );
  }
}
```

## 🎯 Providers

```dart
// lib/presentation/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return AuthService(supabase: supabase, secureStorage: secureStorage);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
```

## 📚 Test Coverage

Key test files:

- `test/persistent_auth_basic_test.dart`
- `test/user_authentication_flow_test.dart`
- `integration_test/user_authentication_flow_test.dart`

---

**Agent Version**: 1.0.0  
**Domain**: Authentication, User Management
