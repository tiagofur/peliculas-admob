import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/repositories/user_profile_repository.dart';
import '../../../domain/use_cases/user_profile/check_username_availability_use_case.dart';
import '../../../domain/use_cases/user_profile/delete_avatar_use_case.dart';
import '../../../domain/use_cases/user_profile/get_user_profile_use_case.dart';
import '../../../domain/use_cases/user_profile/update_user_profile_use_case.dart';
import '../../../domain/use_cases/user_profile/upload_avatar_use_case.dart';
import '../../../domain/use_cases/user_profile/watch_user_profile_use_case.dart';
import '../../../infrastructure/repositories/user_profile_repository_impl.dart';
import '../../providers/auth_provider.dart';

enum UserProfileAlertKind {
  loadFailure,
  saveFailure,
  realtimeFailure,
}

class UserProfileAlert {
  const UserProfileAlert({
    required this.message,
    required this.kind,
    required this.timestamp,
  });

  final String message;
  final UserProfileAlertKind kind;
  final DateTime timestamp;
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl();
});

class UserProfileAlertNotifier extends Notifier<UserProfileAlert?> {
  @override
  UserProfileAlert? build() => null;

  void publish(UserProfileAlert alert) => state = alert;

  void clear() => state = null;
}

final userProfileAlertProvider =
    NotifierProvider<UserProfileAlertNotifier, UserProfileAlert?>(
        UserProfileAlertNotifier.new);

final getUserProfileUseCaseProvider = Provider<GetUserProfileUseCase>((ref) {
  return GetUserProfileUseCase(ref.watch(userProfileRepositoryProvider));
});

final watchUserProfileUseCaseProvider =
    Provider<WatchUserProfileUseCase>((ref) {
  return WatchUserProfileUseCase(ref.watch(userProfileRepositoryProvider));
});

final updateUserProfileUseCaseProvider =
    Provider<UpdateUserProfileUseCase>((ref) {
  return UpdateUserProfileUseCase(ref.watch(userProfileRepositoryProvider));
});

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>((ref) {
  return UploadAvatarUseCase(ref.watch(userProfileRepositoryProvider));
});

final deleteAvatarUseCaseProvider = Provider<DeleteAvatarUseCase>((ref) {
  return DeleteAvatarUseCase(ref.watch(userProfileRepositoryProvider));
});

final checkUsernameAvailabilityUseCaseProvider =
    Provider<CheckUsernameAvailabilityUseCase>((ref) {
  return CheckUsernameAvailabilityUseCase(
    ref.watch(userProfileRepositoryProvider),
  );
});

final userProfileNotifierProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
        UserProfileNotifier.new);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  StreamSubscription<UserProfile?>? _profileSubscription;
  UserProfile? _lastKnownProfile;
  UserProfileAlert? _lastEmittedAlert;

  GetUserProfileUseCase get _getProfile =>
      ref.read(getUserProfileUseCaseProvider);
  WatchUserProfileUseCase get _watchProfile =>
      ref.read(watchUserProfileUseCaseProvider);
  UpdateUserProfileUseCase get _updateProfile =>
      ref.read(updateUserProfileUseCaseProvider);
  UploadAvatarUseCase get _uploadAvatar =>
      ref.read(uploadAvatarUseCaseProvider);
  DeleteAvatarUseCase get _deleteAvatar =>
      ref.read(deleteAvatarUseCaseProvider);
  CheckUsernameAvailabilityUseCase get _checkUsernameAvailability =>
      ref.read(checkUsernameAvailabilityUseCaseProvider);

  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    await _profileSubscription?.cancel();

    if (user == null) {
      _lastKnownProfile = null;
      LoggerFactory.info(
          'UserProfileNotifier: No authenticated user, returning null profile');
      return null;
    }

    LoggerFactory.info(
        'UserProfileNotifier: Building profile for user ${user.id}');
    _listenToRealtimeUpdates(user.id);

    final profile = await _loadProfile(user.id);
    _lastKnownProfile = profile ?? _lastKnownProfile;
    LoggerFactory.info(
        'UserProfileNotifier: Profile loaded successfully: ${profile?.id ?? 'null'}');
    return _lastKnownProfile;
  }

  Future<void> refreshProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = const AsyncValue.data(null);
      _lastKnownProfile = null;
      return;
    }

    state = const AsyncValue.loading();
    final profile = await _loadProfile(user.id);
    if (profile != null) {
      _lastKnownProfile = profile;
    }
    state = AsyncValue.data(_lastKnownProfile);
  }

  Future<void> updateProfile(UpdateUserProfileRequest request) async {
    final previousProfile = _lastKnownProfile;
    state = const AsyncValue.loading();
    try {
      final updatedProfile = await _updateProfile.execute(request);
      _lastKnownProfile = updatedProfile;
      state = AsyncValue.data(updatedProfile);
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'UserProfileNotifier.updateProfile error: $error',
        stackTrace: stackTrace,
      );
      _emitAlert(
        'No se pudo guardar tu perfil. Conservamos la última versión disponible.',
        UserProfileAlertKind.saveFailure,
      );
      state = AsyncValue.data(previousProfile);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> updateProfileFields({
    String? fullName,
    String? username,
    bool clearUsername = false,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('No authenticated user to update profile');
    }

    await updateProfile(
      UpdateUserProfileRequest(
        userId: user.id,
        fullName: fullName,
        username: clearUsername ? '' : username,
        bio: bio,
        avatarUrl: avatarUrl,
        avatarHash: avatarHash,
        stats: stats,
        preferences: preferences,
      ),
    );
  }

  Future<String> uploadAvatar(Uint8List imageBytes,
      {String? fileExtension}) async {
    final user = ref.read(currentUserProvider);
    final currentProfile = state.value;
    if (user == null) {
      throw Exception('No authenticated user to upload avatar');
    }

    state = const AsyncValue.loading();
    try {
      final url = await _uploadAvatar.execute(
        userId: user.id,
        imageBytes: imageBytes,
        existingUrl: currentProfile?.avatarUrl,
        fileExtension: fileExtension,
      );

      await updateProfile(
        UpdateUserProfileRequest(
          userId: user.id,
          avatarUrl: url,
          avatarHash: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      return url;
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'UserProfileNotifier.uploadAvatar error: $error',
        stackTrace: stackTrace,
      );
      _emitAlert(
        'No se pudo actualizar tu avatar. Mantendremos el anterior.',
        UserProfileAlertKind.saveFailure,
      );
      state = AsyncValue.data(_lastKnownProfile);
      rethrow;
    }
  }

  Future<void> deleteAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('No authenticated user to delete avatar');
    }

    try {
      await _deleteAvatar.execute(user.id);
      await updateProfile(
        UpdateUserProfileRequest(
          userId: user.id,
          avatarUrl: null,
          avatarHash: null,
        ),
      );
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'UserProfileNotifier.deleteAvatar error: $error',
        stackTrace: stackTrace,
      );
      _emitAlert(
        'No se pudo eliminar tu avatar. Intenta nuevamente en unos momentos.',
        UserProfileAlertKind.saveFailure,
      );
      state = AsyncValue.data(_lastKnownProfile);
      rethrow;
    }
  }

  Future<bool> isUsernameAvailable(String username) {
    return _checkUsernameAvailability.execute(username);
  }

  void _listenToRealtimeUpdates(String userId) {
    _profileSubscription = _watchProfile.execute(userId).listen(
      (profile) {
        if (profile != null) {
          _lastKnownProfile = profile;
        }
        state = AsyncValue.data(_lastKnownProfile ?? profile);
      },
      onError: (error, stackTrace) {
        LoggerFactory.error(
          'UserProfileNotifier.watch error: $error',
          stackTrace: stackTrace,
        );
        _emitAlert(
          'No se pudo sincronizar tu perfil. Usaremos la última información disponible.',
          UserProfileAlertKind.realtimeFailure,
        );
        state = AsyncValue.data(_lastKnownProfile);
      },
    );

    ref.onDispose(() {
      _profileSubscription?.cancel();
      _profileSubscription = null;
      _lastKnownProfile = null;
      _lastEmittedAlert = null;
    });
  }

  Future<UserProfile?> _loadProfile(String userId) async {
    try {
      LoggerFactory.info(
          'UserProfileNotifier: Loading profile for user $userId');
      final profile = await _getProfile.execute(userId);
      _lastKnownProfile = profile;

      if (profile == null) {
        LoggerFactory.warning(
            'UserProfileNotifier: No profile found for user $userId, profile will be created on first update');
      } else {
        LoggerFactory.info(
            'UserProfileNotifier: Profile loaded successfully for user $userId');
      }

      return profile;
    } catch (error, stackTrace) {
      LoggerFactory.error(
        'UserProfileNotifier.load error: $error',
        data: {'userId': userId},
        stackTrace: stackTrace,
      );

      // Only emit alert if this is not an "expected" error (like profile not found)
      if (!error.toString().toLowerCase().contains('not found') &&
          !error.toString().toLowerCase().contains('no profile')) {
        _emitAlert(
          'No se pudo cargar tu perfil. Mostramos la última versión registrada.',
          UserProfileAlertKind.loadFailure,
        );
      }

      return _lastKnownProfile;
    }
  }

  void _emitAlert(String message, UserProfileAlertKind kind) {
    final now = DateTime.now();
    final lastAlert = _lastEmittedAlert;
    if (lastAlert != null &&
        lastAlert.message == message &&
        now.difference(lastAlert.timestamp) <= const Duration(seconds: 2)) {
      return;
    }

    final alert = UserProfileAlert(
      message: message,
      kind: kind,
      timestamp: now,
    );
    _lastEmittedAlert = alert;
    ref.read(userProfileAlertProvider.notifier).publish(alert);
  }
}
