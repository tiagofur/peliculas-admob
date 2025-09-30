import '../entities/user.dart';
import '../entities/user_profile.dart';
import '../entities/user_stats.dart';

abstract class AuthRepository {
  // Estado de autenticación
  Stream<User?> get authStateChanges;
  User? get currentUser;
  bool get isAuthenticated;

  // Operaciones de autenticación
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    String? avatarUrl,
  });

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<void> resendConfirmationEmail(String email);

  Future<User> updateUser({
    String? fullName,
    String? avatarUrl,
    String? email,
  });

  // Operaciones de perfil
  Future<UserProfile?> getUserProfile(String userId);

  Future<UserProfile> updateUserProfile({
    required String userId,
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
  });

  Future<bool> checkUsernameAvailability(String username);

  // Operaciones de estadísticas
  Future<UserStats?> getUserStats(String userId);

  Future<UserStats> updateUserStats({
    required String userId,
    int? moviesWatched,
    int? favoritesCount,
    int? listsCount,
  });

  // Operaciones de avatar
  Future<String> uploadAvatar({
    required String userId,
    required String filePath,
    String? existingUrl,
  });

  Future<void> deleteAvatar(String userId);

  // Operaciones de validación
  Future<bool> isEmailAvailable(String email);

  // Operaciones de sesión persistente
  Future<bool> hasPersistedSession();
  Future<bool> validateCurrentSession();
  Future<void> refreshToken();
  Future<Map<String, dynamic>?> getSessionInfo();

  // Limpieza de recursos
  void dispose();
}
