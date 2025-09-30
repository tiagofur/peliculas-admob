import 'dart:typed_data';

import '../entities/user_profile.dart';

/// Repository contract dedicated to user profile operations.
///
/// This abstraction allows presentation and application layers to interact with
/// profile data without depending on the authentication repository directly.
abstract class UserProfileRepository {
  /// Loads the profile associated with [userId].
  ///
  /// When [ensureExists] is true the implementation should create a default
  /// profile record if it is missing before returning.
  Future<UserProfile?> fetchProfile(
    String userId, {
    bool ensureExists = true,
  });

  /// Live updates for the profile identified by [userId].
  Stream<UserProfile?> watchProfile(String userId);

  /// Upserts the profile applying the provided fields. Fields omitted will not
  /// be modified.
  Future<UserProfile> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    bool? clearUsername,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
  });

  /// Returns whether the [username] is available.
  Future<bool> checkUsernameAvailability(String username);

  /// Uploads a new avatar for the profile identified by [userId].
  ///
  /// Implementations should be responsible for compressing the incoming bytes
  /// and invalidating any cache when [existingUrl] is provided.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List imageBytes,
    String? existingUrl,
    String? fileExtension,
  });

  /// Removes every avatar object associated with [userId].
  Future<void> deleteAvatar(String userId);
}
