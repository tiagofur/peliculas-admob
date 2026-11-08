import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peliculas/domain/entities/user.dart';
import 'package:peliculas/domain/entities/user_profile.dart';
import 'package:peliculas/domain/repositories/user_profile_repository.dart';
import 'package:peliculas/presentation/providers/auth_provider.dart';
import 'package:peliculas/presentation/providers/user_profile/user_profile_providers.dart';

void main() {
  final sampleUser = User(
    id: 'user-123',
    email: 'user@example.com',
    fullName: 'Sample User',
    createdAt: DateTime.utc(2024, 1, 1),
  );

  final baseProfile = UserProfile(
    id: 'profile-1',
    userId: sampleUser.id,
    fullName: 'Sample User',
    username: 'sampleuser',
    bio: 'Hello there',
    avatarUrl: 'https://example.com/avatar.png',
    avatarHash: 'hash123',
    stats: const {'movies_watched': 5},
    preferences: const {'email_notifications': true},
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 2),
  );

  group('UserProfileNotifier', () {
    test('loads initial profile and receives stream updates', () async {
      final fakeRepository =
          _FakeUserProfileRepository(initialProfile: baseProfile);
      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      final loadedProfile =
          await container.read(userProfileNotifierProvider.future);
      expect(loadedProfile, equals(baseProfile));

      final updatedProfile = baseProfile.copyWith(
        fullName: 'Updated Name',
        bio: 'Updated Bio',
        updatedAt: DateTime.utc(2024, 1, 3),
      );
      fakeRepository.emitProfile(updatedProfile);
      await pumpEventQueue();

      final state = container.read(userProfileNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, equals(updatedProfile));
    });

    test('updateProfileFields clears username when requested', () async {
      final fakeRepository =
          _FakeUserProfileRepository(initialProfile: baseProfile);
      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      await container.read(userProfileNotifierProvider.future);

      final notifier = container.read(userProfileNotifierProvider.notifier);
      final updatedProfile = UserProfile(
        id: baseProfile.id,
        userId: baseProfile.userId,
        fullName: 'Nuevo Nombre',
        username: null,
        bio: baseProfile.bio,
        avatarUrl: baseProfile.avatarUrl,
        avatarHash: baseProfile.avatarHash,
        stats: baseProfile.stats,
        preferences: baseProfile.preferences,
        createdAt: baseProfile.createdAt,
        updatedAt: DateTime.utc(2024, 1, 4),
      );
      fakeRepository.nextUpdateResult = updatedProfile;

      await notifier.updateProfileFields(
        fullName: 'Nuevo Nombre',
        username: '',
        clearUsername: true,
      );

      final lastUpdate = fakeRepository.lastUpdateInvocation;
      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.userId, equals(sampleUser.id));
      expect(lastUpdate.username, isNull);
      expect(lastUpdate.clearUsername, isTrue);
      expect(lastUpdate.fullName, equals('Nuevo Nombre'));

      final state = container.read(userProfileNotifierProvider);
      expect(state.value, equals(updatedProfile));
    });

    test('uploadAvatar uploads bytes and updates profile with new hash',
        () async {
      final fakeRepository =
          _FakeUserProfileRepository(initialProfile: baseProfile);
      fakeRepository.nextUpdateResult = baseProfile.copyWith(
        avatarUrl: 'https://example.com/new-avatar.png',
        avatarHash: 'new-hash',
        updatedAt: DateTime.utc(2024, 1, 5),
      );
      fakeRepository.uploadAvatarResult = 'https://example.com/new-avatar.png';

      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      await container.read(userProfileNotifierProvider.future);

      final notifier = container.read(userProfileNotifierProvider.notifier);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final url = await notifier.uploadAvatar(bytes, fileExtension: 'jpg');

      final uploadInvocation = fakeRepository.lastUploadInvocation;
      expect(uploadInvocation, isNotNull);
      expect(uploadInvocation!.userId, equals(sampleUser.id));
      expect(uploadInvocation.imageBytes, equals(bytes));
      expect(uploadInvocation.fileExtension, equals('jpg'));
      expect(uploadInvocation.existingUrl, equals(baseProfile.avatarUrl));

      expect(url, equals('https://example.com/new-avatar.png'));

      final updateInvocation = fakeRepository.lastUpdateInvocation;
      expect(updateInvocation, isNotNull);
      expect(updateInvocation!.avatarUrl,
          equals('https://example.com/new-avatar.png'));
      expect(updateInvocation.avatarHash, isNotNull);

      final state = container.read(userProfileNotifierProvider);
      expect(
          state.value?.avatarUrl, equals('https://example.com/new-avatar.png'));
      expect(state.value?.avatarHash, equals('new-hash'));
    });

    test('deleteAvatar removes avatar and updates profile', () async {
      final fakeRepository =
          _FakeUserProfileRepository(initialProfile: baseProfile);
      fakeRepository.nextUpdateResult = UserProfile(
        id: baseProfile.id,
        userId: baseProfile.userId,
        fullName: baseProfile.fullName,
        username: baseProfile.username,
        bio: baseProfile.bio,
        avatarUrl: null,
        avatarHash: null,
        stats: baseProfile.stats,
        preferences: baseProfile.preferences,
        createdAt: baseProfile.createdAt,
        updatedAt: DateTime.utc(2024, 1, 6),
      );

      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      await container.read(userProfileNotifierProvider.future);

      final notifier = container.read(userProfileNotifierProvider.notifier);

      await notifier.deleteAvatar();

      expect(fakeRepository.deleteCalls, contains(sampleUser.id));

      final updateInvocation = fakeRepository.lastUpdateInvocation;
      expect(updateInvocation, isNotNull);
      expect(updateInvocation!.avatarUrl, isNull);
      expect(updateInvocation.avatarHash, isNull);

      final state = container.read(userProfileNotifierProvider);
      expect(state.value?.avatarUrl, isNull);
      expect(state.value?.avatarHash, isNull);
    });

    test('isUsernameAvailable delegates to repository', () async {
      final fakeRepository = _FakeUserProfileRepository(
        initialProfile: baseProfile,
        usernameAvailable: false,
      );
      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      await container.read(userProfileNotifierProvider.future);

      final notifier = container.read(userProfileNotifierProvider.notifier);
      final isAvailable = await notifier.isUsernameAvailable('taken');

      expect(fakeRepository.lastCheckedUsername, equals('taken'));
      expect(isAvailable, isFalse);
    });

    test('refreshProfile keeps last cached profile and emits alert on failure',
        () async {
      final fakeRepository =
          _FakeUserProfileRepository(initialProfile: baseProfile);
      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      await container.read(userProfileNotifierProvider.future);

      fakeRepository.nextFetchError = Exception('network-failure');

      await container
          .read(userProfileNotifierProvider.notifier)
          .refreshProfile();

      final state = container.read(userProfileNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, equals(baseProfile));

      final alert = container.read(userProfileAlertProvider);
      expect(alert, isNotNull);
      expect(alert!.kind, UserProfileAlertKind.loadFailure);
    });

    test('realtime errors retain last profile and emit alert', () async {
      final fakeRepository =
          _FakeUserProfileRepository(initialProfile: baseProfile);
      final container = _createContainer(fakeRepository, sampleUser);
      addTearDown(() {
        container.dispose();
        fakeRepository.dispose();
      });

      await container.read(userProfileNotifierProvider.future);

      final updatedProfile = baseProfile.copyWith(
        fullName: 'Realtime Update',
        updatedAt: DateTime.utc(2024, 2, 1),
      );
      fakeRepository.emitProfile(updatedProfile);
      await pumpEventQueue();

      fakeRepository.emitError(Exception('realtime-disconnected'));
      await pumpEventQueue();

      final state = container.read(userProfileNotifierProvider);
      expect(state.value, equals(updatedProfile));

      final alert = container.read(userProfileAlertProvider);
      expect(alert, isNotNull);
      expect(alert!.kind, UserProfileAlertKind.realtimeFailure);
    });
  });
}

ProviderContainer _createContainer(
  _FakeUserProfileRepository fakeRepository,
  User? user,
) {
  return ProviderContainer(overrides: [
    userProfileRepositoryProvider.overrideWithValue(fakeRepository),
    currentUserProvider.overrideWithValue(user),
  ]);
}

class _FakeUserProfileRepository implements UserProfileRepository {
  _FakeUserProfileRepository({
    UserProfile? initialProfile,
    bool usernameAvailable = true,
  })  : _profile = initialProfile,
        _usernameAvailable = usernameAvailable;

  final _profileStreamController = StreamController<UserProfile?>.broadcast();
  UserProfile? _profile;
  final bool _usernameAvailable;

  UpdateProfileInvocation? lastUpdateInvocation;
  UploadAvatarInvocation? lastUploadInvocation;
  final List<String> deleteCalls = <String>[];
  String? lastCheckedUsername;

  UserProfile? nextUpdateResult;
  String? uploadAvatarResult;
  Object? nextFetchError;

  void emitProfile(UserProfile? profile) {
    _profileStreamController.add(profile);
  }

  void emitError(Object error) {
    _profileStreamController.addError(error);
  }

  void dispose() {
    _profileStreamController.close();
  }

  @override
  Future<UserProfile?> fetchProfile(String userId,
      {bool ensureExists = true}) async {
    if (nextFetchError != null) {
      final error = nextFetchError!;
      nextFetchError = null;
      throw error;
    }
    return _profile;
  }

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return _profileStreamController.stream;
  }

  @override
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
  }) async {
    lastUpdateInvocation = UpdateProfileInvocation(
      userId: userId,
      fullName: fullName,
      username: username,
      clearUsername: clearUsername ?? false,
      bio: bio,
      avatarUrl: avatarUrl,
      avatarHash: avatarHash,
      stats: stats,
      preferences: preferences,
    );

    final result = nextUpdateResult ?? _profile;
    if (result == null) {
      throw StateError('nextUpdateResult must be provided for updateProfile');
    }

    _profile = result;
    nextUpdateResult = null;

    return result;
  }

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    lastCheckedUsername = username;
    return _usernameAvailable;
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List imageBytes,
    String? existingUrl,
    String? fileExtension,
  }) async {
    lastUploadInvocation = UploadAvatarInvocation(
      userId: userId,
      imageBytes: imageBytes,
      existingUrl: existingUrl,
      fileExtension: fileExtension,
    );

    final result = uploadAvatarResult;
    if (result == null) {
      throw StateError('uploadAvatarResult must be set for uploadAvatar tests');
    }
    return result;
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    deleteCalls.add(userId);
  }
}

class UpdateProfileInvocation {
  UpdateProfileInvocation({
    required this.userId,
    this.fullName,
    this.username,
    required this.clearUsername,
    this.bio,
    this.avatarUrl,
    this.avatarHash,
    this.stats,
    this.preferences,
  });

  final String userId;
  final String? fullName;
  final String? username;
  final bool clearUsername;
  final String? bio;
  final String? avatarUrl;
  final String? avatarHash;
  final Map<String, dynamic>? stats;
  final Map<String, bool>? preferences;
}

class UploadAvatarInvocation {
  UploadAvatarInvocation({
    required this.userId,
    required this.imageBytes,
    this.existingUrl,
    this.fileExtension,
  });

  final String userId;
  final Uint8List imageBytes;
  final String? existingUrl;
  final String? fileExtension;
}
