import '../../entities/user_profile.dart';
import '../../repositories/user_profile_repository.dart';

class UpdateUserProfileRequest {
  const UpdateUserProfileRequest({
    required this.userId,
    this.fullName,
    this.username,
    this.bio,
    this.avatarUrl,
    this.avatarHash,
    this.stats,
    this.preferences,
  });

  final String userId;
  final String? fullName;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? avatarHash;
  final Map<String, dynamic>? stats;
  final Map<String, bool>? preferences;
}

class UpdateUserProfileUseCase {
  const UpdateUserProfileUseCase(this._repository);

  final UserProfileRepository _repository;

  Future<UserProfile> execute(UpdateUserProfileRequest request) {
    final sanitizedFullName = request.fullName?.trim();
    if (sanitizedFullName != null && sanitizedFullName.isEmpty) {
      throw ArgumentError('El nombre no puede estar vacío.');
    }

    final sanitizedBio = request.bio?.trim();
    if (sanitizedBio != null && sanitizedBio.length > 500) {
      throw ArgumentError('La biografía debe tener máximo 500 caracteres.');
    }

    final rawUsername = request.username;
    String? normalizedUsername;
    bool? clearUsername;
    if (rawUsername != null) {
      final trimmed = rawUsername.trim();
      if (trimmed.isEmpty) {
        clearUsername = true;
      } else {
        if (trimmed.length < 3 || trimmed.length > 20) {
          throw ArgumentError(
            'El nombre de usuario debe tener entre 3 y 20 caracteres.',
          );
        }
        final usernameRegex = RegExp(r'^[a-z0-9_]+$');
        if (!usernameRegex.hasMatch(trimmed)) {
          throw ArgumentError(
            'El nombre de usuario solo puede contener minúsculas, números y guion bajo.',
          );
        }
        normalizedUsername = trimmed.toLowerCase();
        clearUsername = false;
      }
    }

    return _repository.updateProfile(
      userId: request.userId,
      fullName: sanitizedFullName,
      username: normalizedUsername,
      clearUsername: clearUsername,
      bio: sanitizedBio,
      avatarUrl: request.avatarUrl,
      avatarHash: request.avatarHash,
      stats: request.stats,
      preferences: request.preferences,
    );
  }
}
