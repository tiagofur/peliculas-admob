import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cache/image_cache_manager.dart';
import '../../core/config/supabase_config.dart';
import '../../core/logging/logger_factory.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/uuid_generator.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../models/user_profile_model.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({
    SupabaseClient? supabaseClient,
    ImageCompressor? imageCompressor,
    UuidGenerator? uuidGenerator,
  })  : _supabase = supabaseClient ?? SupabaseConfig.client,
        _imageCompressor = imageCompressor ?? const ImageCompressor(),
        _uuidGenerator = uuidGenerator ?? const UuidGenerator();

  final SupabaseClient _supabase;
  final ImageCompressor _imageCompressor;
  final UuidGenerator _uuidGenerator;

  bool _supportsSyncMetadata = true;

  static const String _columnDisplayName = 'display_name';
  static const String _columnLegacyFullName = 'full_name';
  static const String _columnUsername = 'username';
  static const String _columnAvatarHash = 'avatar_hash';
  static const String _columnStats = 'stats';
  static const String _columnPreferences = 'preferences';
  static const String _columnUpdatedAt = 'updated_at';
  static const String _columnLastSyncedAt = 'last_synced_at';
  static const String _columnCreatedAt = 'created_at';
  static const String _columnJoinedDate = 'joined_date';
  static const String _columnLastActiveDate = 'last_active_date';
  static const String _columnEmail = 'email';
  static const String _columnBannerUrl = 'banner_url';
  static const String _columnCustomFields = 'custom_fields';

  static const Set<String> _optionalProfileColumns = {
    _columnDisplayName,
    _columnUsername,
    _columnAvatarHash,
    _columnStats,
    _columnPreferences,
    _columnUpdatedAt,
    _columnLastSyncedAt,
    _columnJoinedDate,
    _columnLastActiveDate,
    _columnEmail,
    _columnBannerUrl,
    _columnCustomFields,
  };

  final Set<String> _availableOptionalColumns = {..._optionalProfileColumns};

  @override
  Future<UserProfile?> fetchProfile(
    String userId, {
    bool ensureExists = true,
  }) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfileModel.fromJson(response);
      }

      if (!ensureExists) {
        return null;
      }

      return _ensureDefaultProfile(userId);
    } catch (error, stackTrace) {
      unawaited(LoggerFactory.error(
        'UserProfileRepositoryImpl.fetchProfile error: $error',
        data: {'userId': userId},
        stackTrace: stackTrace,
      ));
      rethrow;
    }
  }

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return _supabase
        .from('user_profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((records) {
          if (records.isEmpty) {
            return null;
          }
          try {
            return UserProfileModel.fromJson(records.first);
          } catch (error) {
            LoggerFactory.error(
                'UserProfileRepositoryImpl.watchProfile parse error: $error');
            return null;
          }
        });
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
  }) {
    return _updateProfileInternal(
      userId: userId,
      fullName: fullName,
      username: username,
      clearUsername: clearUsername,
      bio: bio,
      avatarUrl: avatarUrl,
      avatarHash: avatarHash,
      stats: stats,
      preferences: preferences,
      includeSyncMetadata: _supportsSyncMetadata,
    );
  }

  Future<UserProfile> _updateProfileInternal({
    required String userId,
    String? fullName,
    String? username,
    bool? clearUsername,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    Map<String, dynamic>? stats,
    Map<String, bool>? preferences,
    required bool includeSyncMetadata,
  }) async {
    try {
      final sanitizedFullName = fullName?.trim();
      final sanitizedBio = bio?.trim();
      final normalizedUsername = username?.trim().toLowerCase();

      final updatePayload = <String, dynamic>{
        'user_id': userId,
      };

      if (sanitizedFullName != null) {
        _assignNameColumns(
          updatePayload,
          sanitizedFullName.isEmpty ? null : sanitizedFullName,
        );
      }

      if (clearUsername == true) {
        if (_canUseColumn(_columnUsername)) {
          updatePayload[_columnUsername] = null;
        }
      } else if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
        if (_canUseColumn(_columnUsername)) {
          updatePayload[_columnUsername] = normalizedUsername;
        }
      }

      if (sanitizedBio != null) {
        updatePayload['bio'] = sanitizedBio.isEmpty ? null : sanitizedBio;
      }

      if (avatarUrl != null) {
        updatePayload['avatar_url'] = avatarUrl;
      }

      if (avatarHash != null && _canUseColumn(_columnAvatarHash)) {
        updatePayload[_columnAvatarHash] = avatarHash;
      }

      if (stats != null && _canUseColumn(_columnStats)) {
        updatePayload[_columnStats] = stats;
      }

      if (preferences != null && _canUseColumn(_columnPreferences)) {
        updatePayload[_columnPreferences] = preferences;
      }

      if (includeSyncMetadata && _supportsSyncMetadata) {
        final now = DateTime.now().toIso8601String();
        if (_canUseColumn(_columnUpdatedAt)) {
          updatePayload[_columnUpdatedAt] = now;
        }
        if (_canUseColumn(_columnLastSyncedAt)) {
          updatePayload[_columnLastSyncedAt] = now;
        }
        if (_canUseColumn(_columnLastActiveDate)) {
          updatePayload[_columnLastActiveDate] = now;
        }
      }

      if (!updatePayload.containsKey(_columnLastActiveDate) &&
          _canUseColumn(_columnLastActiveDate)) {
        updatePayload[_columnLastActiveDate] = DateTime.now().toIso8601String();
      }

      final response = await _supabase
          .from('user_profiles')
          .upsert(updatePayload, onConflict: 'user_id')
          .select()
          .single();

      return UserProfileModel.fromJson(response);
    } catch (error, stackTrace) {
      // Manejo especial para problemas de tabla/estructura
      if (error.toString().contains('400') ||
          error.toString().contains('Bad Request') ||
          error.toString().contains('table') ||
          error.toString().contains('column')) {
        LoggerFactory.warning(
            '⚠️ user_profiles table issue in updateProfile. Please run migration.');
        // Retornar un perfil básico en lugar de fallar
        final now = DateTime.now();
        return UserProfileModel(
          id: 'temp_id',
          userId: userId,
          username: username ?? 'usuario_anonimo',
          fullName: 'Usuario Anónimo',
          bio: null,
          avatarUrl: null,
          createdAt: now,
          updatedAt: now,
        );
      }

      unawaited(LoggerFactory.error(
        'UserProfileRepositoryImpl.updateProfile error: $error',
        data: {
          'userId': userId,
          'username': username,
          'clearUsername': clearUsername,
          'includeSyncMetadata': includeSyncMetadata,
        },
        stackTrace: stackTrace,
      ));

      if (error is PostgrestException) {
        if (_handleMissingOptionalColumns(error)) {
          return _updateProfileInternal(
            userId: userId,
            fullName: fullName,
            username: username,
            clearUsername: clearUsername,
            bio: bio,
            avatarUrl: avatarUrl,
            avatarHash: avatarHash,
            stats: stats,
            preferences: preferences,
            includeSyncMetadata: includeSyncMetadata && _supportsSyncMetadata,
          );
        }
        throw Exception('Error actualizando perfil: ${error.message}');
      }

      throw Exception('Error updating user profile');
    }
  }

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final normalized = username.trim().toLowerCase();
      if (normalized.isEmpty) {
        return true;
      }

      final response = await _supabase
          .from('user_profiles')
          .select('user_id')
          .eq('username', normalized)
          .maybeSingle();

      return response == null;
    } catch (error, stackTrace) {
      unawaited(LoggerFactory.error(
        'UserProfileRepositoryImpl.checkUsernameAvailability error: $error',
        data: {'username': username},
        stackTrace: stackTrace,
      ));
      if (error is PostgrestException) {
        throw Exception('Error verificando usuario: ${error.message}');
      }
      throw Exception('Error checking username availability');
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List imageBytes,
    String? existingUrl,
    String? fileExtension,
  }) async {
    try {
      final compressedBytes = await _imageCompressor.compress(
        imageBytes,
        maxWidth: 1024,
        maxHeight: 1024,
        quality: 85,
      );

      final extension = (fileExtension ?? 'jpg').replaceAll('.', '');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${_uuidGenerator.v4()}.$extension';
      final objectPath = '$userId/$fileName';
      final contentType = _resolveContentType(extension);

      final fileOptions = FileOptions(
        upsert: true,
        cacheControl: 'public, max-age=31536000, immutable',
        contentType: contentType,
      );

      await _supabase.storage.from('avatars').uploadBinary(
            objectPath,
            compressedBytes,
            fileOptions: fileOptions,
          );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(objectPath);

      if (existingUrl != null && existingUrl.isNotEmpty) {
        await ImageCacheManager.instance.evictUrl(existingUrl);
        final previousPath = _extractStoragePath(existingUrl);
        if (previousPath != null) {
          await _supabase.storage.from('avatars').remove([previousPath]);
        }
      }

      return publicUrl;
    } catch (error, stackTrace) {
      unawaited(LoggerFactory.error(
        'UserProfileRepositoryImpl.uploadAvatar error: $error',
        data: {
          'userId': userId,
          'hasExistingUrl': existingUrl != null && existingUrl.isNotEmpty,
        },
        stackTrace: stackTrace,
      ));

      if (error is StorageException) {
        throw Exception('Error subiendo avatar: ${error.message}');
      }

      throw Exception('Error uploading avatar');
    }
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    try {
      final files = await _supabase.storage.from('avatars').list(path: userId);
      if (files.isEmpty) {
        return;
      }

      final paths = files.map((file) => '$userId/${file.name}').toList();
      await _supabase.storage.from('avatars').remove(paths);
    } catch (error, stackTrace) {
      unawaited(LoggerFactory.error(
        'UserProfileRepositoryImpl.deleteAvatar error: $error',
        data: {'userId': userId},
        stackTrace: stackTrace,
      ));

      if (error is StorageException) {
        throw Exception('Error eliminando avatar: ${error.message}');
      }

      throw Exception('Error deleting avatar');
    }
  }

  Future<UserProfile> _ensureDefaultProfile(String userId) {
    return _ensureDefaultProfileInternal(
      userId,
      includeSyncMetadata: _supportsSyncMetadata,
    );
  }

  Future<UserProfile> _ensureDefaultProfileInternal(
    String userId, {
    required bool includeSyncMetadata,
  }) async {
    try {
      final supabaseUser = _supabase.auth.currentUser;
      final metadata = supabaseUser?.userMetadata ?? <String, dynamic>{};

      final resolvedFullName = _resolveFullName(
        metadata,
        supabaseUser?.email,
      );

      final model = UserProfileModel.create(
        userId: userId,
        fullName: resolvedFullName,
        avatarUrl: metadata['avatar_url'] as String?,
      );

      final now = DateTime.now().toIso8601String();
      final payload = <String, dynamic>{
        'user_id': model.userId,
        if (model.avatarUrl != null) 'avatar_url': model.avatarUrl,
      };

      _assignNameColumns(payload, model.fullName);
      _assignCreationTimestamps(payload, now);

      final email = supabaseUser?.email;
      if (email != null && email.isNotEmpty && _canUseColumn(_columnEmail)) {
        payload[_columnEmail] = email;
      }

      final bannerUrl = metadata['banner_url'];
      if (bannerUrl is String &&
          bannerUrl.isNotEmpty &&
          _canUseColumn(_columnBannerUrl)) {
        payload[_columnBannerUrl] = bannerUrl;
      }

      if (_canUseColumn(_columnCustomFields)) {
        final customFields = metadata['custom_fields'];
        if (customFields is Map<String, dynamic>) {
          payload[_columnCustomFields] = customFields;
        } else if (customFields is Map) {
          payload[_columnCustomFields] = customFields.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        } else {
          payload[_columnCustomFields] = <String, dynamic>{};
        }
      }

      if (includeSyncMetadata && _supportsSyncMetadata) {
        if (_canUseColumn(_columnUpdatedAt)) {
          payload[_columnUpdatedAt] = now;
        }
        if (_canUseColumn(_columnLastSyncedAt)) {
          payload[_columnLastSyncedAt] = now;
        }
      }

      final response = await _supabase
          .from('user_profiles')
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      return UserProfileModel.fromJson(response);
    } catch (error, stackTrace) {
      unawaited(LoggerFactory.error(
        'UserProfileRepositoryImpl._ensureDefaultProfile error: $error',
        data: {'userId': userId, 'includeSyncMetadata': includeSyncMetadata},
        stackTrace: stackTrace,
      ));

      if (error is PostgrestException) {
        if (_handleMissingOptionalColumns(error)) {
          return _ensureDefaultProfileInternal(
            userId,
            includeSyncMetadata: includeSyncMetadata && _supportsSyncMetadata,
          );
        }
        throw Exception('Error creando perfil por defecto: ${error.message}');
      }

      throw Exception('Error creating default profile');
    }
  }

  String _resolveFullName(Map<String, dynamic> metadata, String? email) {
    final candidates = <String?>[
      metadata['display_name'] as String?,
      metadata['full_name'] as String?,
      metadata['name'] as String?,
    ];

    for (final candidate in candidates) {
      if (candidate != null) {
        final trimmed = candidate.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }

    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'Usuario';
  }

  bool _canUseColumn(String column) =>
      _availableOptionalColumns.contains(column);

  bool _handleMissingOptionalColumns(PostgrestException error) {
    final missingColumns = _extractMissingColumns(error);
    if (missingColumns.isEmpty) {
      return false;
    }

    for (final column in missingColumns) {
      _disableColumn(column, error);
    }

    _supportsSyncMetadata =
        _availableOptionalColumns.contains(_columnUpdatedAt) &&
            _availableOptionalColumns.contains(_columnLastSyncedAt);

    return true;
  }

  void _assignNameColumns(Map<String, dynamic> payload, String? value) {
    final sanitized = value?.trim();

    if (sanitized == null || sanitized.isEmpty) {
      if (_canUseColumn(_columnDisplayName)) {
        payload[_columnDisplayName] = null;
      }
      if (_canUseColumn(_columnLegacyFullName)) {
        payload[_columnLegacyFullName] = null;
      }
      return;
    }

    if (_canUseColumn(_columnDisplayName)) {
      payload[_columnDisplayName] = sanitized;
    }
    if (_canUseColumn(_columnLegacyFullName)) {
      payload[_columnLegacyFullName] = sanitized;
    }
  }

  void _assignCreationTimestamps(
    Map<String, dynamic> payload,
    String isoTimestamp,
  ) {
    if (_canUseColumn(_columnCreatedAt)) {
      payload[_columnCreatedAt] = isoTimestamp;
    }
    if (_canUseColumn(_columnJoinedDate)) {
      payload[_columnJoinedDate] = isoTimestamp;
    }
    if (_canUseColumn(_columnLastActiveDate)) {
      payload[_columnLastActiveDate] = isoTimestamp;
    }
  }

  void _disableColumn(String column, PostgrestException error) {
    if (_availableOptionalColumns.remove(column)) {
      LoggerFactory.warning(
        'UserProfileRepositoryImpl: disabling profile column "$column" due to schema mismatch (${error.message}).',
      );
    }
  }

  Set<String> _extractMissingColumns(PostgrestException error) {
    final result = <String>{};

    final buffer = StringBuffer(error.message);
    final details = error.details?.toString();
    if (details != null && details.isNotEmpty) {
      buffer.write(' ');
      buffer.write(details);
    }
    final hint = error.hint?.toString();
    if (hint != null && hint.isNotEmpty) {
      buffer.write(' ');
      buffer.write(hint);
    }

    final raw = buffer.toString().toLowerCase();

    for (final column in _optionalProfileColumns) {
      if (raw.contains(column.toLowerCase())) {
        result.add(column);
      }
    }

    return result;
  }

  String? _resolveContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
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
        final index = segments.indexOf('avatars');
        return segments.sublist(index).join('/');
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
