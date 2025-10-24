# Instrucciones de Implementación - Sistema de Perfil de Usuario

**Fecha**: 2025-09-29
**Para**: GitHub Copilot / AI Assistant
**Modo**: Ejecución Automatizada

## 🤖 Instrucciones para el Agente AI

### Contexto

Estás mejorando el sistema de perfil de usuario en una aplicación Flutter con Supabase. La aplicación ya tiene autenticación funcionando y necesita un sistema robusto de perfiles con upload de avatares.

### Pre-requisitos a Verificar

1. ✅ Supabase configurado en el proyecto
2. ✅ Autenticación funcionando
3. ✅ Estructura de carpetas domain-driven design
4. ✅ Riverpod para state management

## 📝 FASE 1: Setup y Dependencias

### Paso 1.1: Agregar Dependencias

```yaml
# Agregar en pubspec.yaml bajo dependencies:
dependencies:
  # ...existing dependencies...
  image_picker: ^1.0.4
  image: ^4.1.3
  cached_network_image: ^3.3.0
  uuid: ^4.2.1
  path_provider: ^2.1.1
  flutter_image_compress: ^2.1.0
  shimmer: ^3.0.0

# Ejecutar:
flutter pub get
```

### Paso 1.2: Configurar Supabase Storage

```sql
-- Ejecutar en Supabase SQL Editor
-- 1. Crear bucket para avatares
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- 2. Crear tabla de perfiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  username TEXT UNIQUE,
  full_name TEXT,
  bio TEXT,
  avatar_url TEXT,
  avatar_hash TEXT,
  stats JSONB DEFAULT '{"movies_watched": 0, "watchlist_count": 0, "reviews_count": 0, "lists_count": 0}'::jsonb,
  preferences JSONB DEFAULT '{"email_notifications": true, "push_notifications": true, "profile_public": true}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Crear función para auto-update de updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 4. Crear trigger
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. RLS Policies
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by everyone" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 6. Storage policies
CREATE POLICY "Avatar images are publicly accessible" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

## 📝 FASE 2: Implementación del Dominio

### Paso 2.1: Crear Entidad UserProfile

```dart
// filepath: lib/domain/entities/user_profile.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? avatarHash,
    @Default({}) Map<String, dynamic> stats,
    @Default({}) Map<String, bool> preferences,
    DateTime? updatedAt,
    required DateTime createdAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

@freezed
class ProfileStats with _$ProfileStats {
  const factory ProfileStats({
    @Default(0) int moviesWatched,
    @Default(0) int watchlistCount,
    @Default(0) int reviewsCount,
    @Default(0) int listsCount,
  }) = _ProfileStats;

  factory ProfileStats.fromJson(Map<String, dynamic> json) =>
      _$ProfileStatsFromJson(json);
}

@freezed
class ProfilePreferences with _$ProfilePreferences {
  const factory ProfilePreferences({
    @Default(true) bool emailNotifications,
    @Default(true) bool pushNotifications,
    @Default(true) bool profilePublic,
  }) = _ProfilePreferences;

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) =>
      _$ProfilePreferencesFromJson(json);
}
```

### Paso 2.2: Crear Repository Interface

```dart
// filepath: lib/domain/repositories/user_profile_repository.dart
import 'dart:typed_data';
import '../entities/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> getProfile(String userId);
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<String> uploadAvatar(String userId, Uint8List imageBytes, String fileName);
  Future<void> deleteAvatar(String userId, String avatarUrl);
  Future<bool> checkUsernameAvailability(String username);
  Stream<UserProfile> watchProfile(String userId);
}
```

### Paso 2.3: Crear Use Cases

```dart
// filepath: lib/domain/use_cases/update_profile_use_case.dart
import '../entities/user_profile.dart';
import '../repositories/user_profile_repository.dart';

class UpdateProfileUseCase {
  final UserProfileRepository _repository;

  UpdateProfileUseCase(this._repository);

  Future<UserProfile> execute(UserProfile profile) async {
    // Validaciones de negocio
    if (profile.username != null) {
      if (profile.username!.length < 3 || profile.username!.length > 20) {
        throw Exception('Username must be between 3 and 20 characters');
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(profile.username!)) {
        throw Exception('Username can only contain letters, numbers and underscore');
      }
    }

    if (profile.fullName != null && profile.fullName!.length > 50) {
      throw Exception('Full name cannot exceed 50 characters');
    }

    if (profile.bio != null && profile.bio!.length > 500) {
      throw Exception('Bio cannot exceed 500 characters');
    }

    return await _repository.updateProfile(profile);
  }
}
```

```dart
// filepath: lib/domain/use_cases/upload_avatar_use_case.dart
import 'dart:typed_data';
import '../repositories/user_profile_repository.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/uuid_generator.dart';

class UploadAvatarUseCase {
  final UserProfileRepository _repository;
  final ImageCompressor _imageCompressor;
  final UuidGenerator _uuidGenerator;

  UploadAvatarUseCase(
    this._repository,
    this._imageCompressor,
    this._uuidGenerator,
  );

  Future<String> execute(String userId, Uint8List imageBytes) async {
    // Validar tamaño
    if (imageBytes.length > 5 * 1024 * 1024) { // 5MB
      throw Exception('Image size cannot exceed 5MB');
    }

    // Comprimir imagen
    final compressedBytes = await _imageCompressor.compress(
      imageBytes,
      maxWidth: 800,
      maxHeight: 800,
      quality: 85,
    );

    // Generar nombre único
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuid = _uuidGenerator.generate();
    final fileName = '${timestamp}_$uuid.jpg';

    // Upload
    return await _repository.uploadAvatar(userId, compressedBytes, fileName);
  }
}
```

## 📝 FASE 3: Implementación de Infraestructura

### Paso 3.1: Implementar Repository

```dart
// filepath: lib/infrastructure/repositories/user_profile_repository_impl.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../core/logging/logger_factory.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final SupabaseClient _supabase;

  UserProfileRepositoryImpl(this._supabase);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserProfile.fromJson(response);
    } catch (e) {
      LoggerFactory.error('Error getting profile: $e');
      rethrow;
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    try {
      final response = await _supabase
          .from('profiles')
          .upsert({
            'user_id': profile.userId,
            'username': profile.username,
            'full_name': profile.fullName,
            'bio': profile.bio,
            'avatar_url': profile.avatarUrl,
            'avatar_hash': profile.avatarHash,
            'stats': profile.stats,
            'preferences': profile.preferences,
          })
          .eq('user_id', profile.userId)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      LoggerFactory.error('Error updating profile: $e');
      rethrow;
    }
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List imageBytes, String fileName) async {
    try {
      final path = '$userId/$fileName';

      await _supabase.storage
          .from('avatars')
          .uploadBinary(path, imageBytes);

      final url = _supabase.storage
          .from('avatars')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      LoggerFactory.error('Error uploading avatar: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAvatar(String userId, String avatarUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(avatarUrl);
      final path = uri.pathSegments.last;

      await _supabase.storage
          .from('avatars')
          .remove(['$userId/$path']);
    } catch (e) {
      LoggerFactory.error('Error deleting avatar: $e');
      rethrow;
    }
  }

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      return response == null;
    } catch (e) {
      LoggerFactory.error('Error checking username: $e');
      rethrow;
    }
  }

  @override
  Stream<UserProfile> watchProfile(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) => data.isEmpty ? null : UserProfile.fromJson(data.first))
        .where((profile) => profile != null)
        .cast<UserProfile>();
  }
}
```

### Paso 3.2: Servicios de Soporte

```dart
// filepath: lib/core/utils/image_compressor.dart
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  Future<Uint8List> compress(
    Uint8List bytes, {
    required int maxWidth,
    required int maxHeight,
    required int quality,
  }) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    return result;
  }
}
```

```dart
// filepath: lib/core/utils/uuid_generator.dart
import 'package:uuid/uuid.dart';

class UuidGenerator {
  final _uuid = const Uuid();

  String generate() => _uuid.v4();
}
```

```dart
// filepath: lib/core/cache/image_cache_manager.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager {
  static const key = 'avatarCacheKey';

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  static Future<void> clearCache() async {
    await instance.emptyCache();
  }

  static Future<void> removeFile(String url) async {
    await instance.removeFile(url);
  }
}
```

## 📝 FASE 4: Implementación de UI

### Paso 4.1: Provider de Estado

```dart
// filepath: lib/presentation/providers/user_profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../../domain/use_cases/update_profile_use_case.dart';
import '../../domain/use_cases/upload_avatar_use_case.dart';
import '../../infrastructure/repositories/user_profile_repository_impl.dart';
import '../../core/utils/image_compressor.dart';
import '../../core/utils/uuid_generator.dart';
import '../../core/cache/image_cache_manager.dart';
import 'dart:typed_data';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(ref.watch(supabaseClientProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(userProfileRepositoryProvider));
});

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>((ref) {
  return UploadAvatarUseCase(
    ref.watch(userProfileRepositoryProvider),
    ImageCompressor(),
    UuidGenerator(),
  );
});

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) async* {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) {
    yield null;
    return;
  }

  yield* ref.watch(userProfileRepositoryProvider).watchProfile(userId);
});

final profileLoadingProvider = StateProvider<bool>((ref) => false);

final profileNotifierProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  return ProfileNotifier(ref);
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref _ref;

  ProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await _ref.read(userProfileRepositoryProvider).getProfile(userId);
      state = AsyncValue.data(profile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    try {
      final updatedProfile = await _ref.read(updateProfileUseCaseProvider).execute(profile);
      state = AsyncValue.data(updatedProfile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> uploadAvatar(Uint8List imageBytes) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    try {
      // Clear old avatar from cache
      if (currentProfile.avatarUrl != null) {
        await ImageCacheManager.removeFile(currentProfile.avatarUrl!);
      }

      final avatarUrl = await _ref.read(uploadAvatarUseCaseProvider).execute(
        currentProfile.userId,
        imageBytes,
      );

      final updatedProfile = currentProfile.copyWith(
        avatarUrl: avatarUrl,
        avatarHash: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      await updateProfile(updatedProfile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
```

### Paso 4.2: Widget de Avatar

```dart
// filepath: lib/presentation/widgets/avatar_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/cache/image_cache_manager.dart';

class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;

  const AvatarWidget({
    Key? key,
    this.avatarUrl,
    this.size = 100,
    this.onTap,
    this.showEditIcon = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      cacheManager: ImageCacheManager.instance,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildDefaultAvatar(context),
                    )
                  : _buildDefaultAvatar(context),
            ),
          ),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.background,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: size * 0.15,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
```

### Paso 4.3: Pantalla de Perfil

> ⚠️ **Actualización importante (septiembre 2025)**: la pantalla de perfil ya no vive en `lib/presentation/pages/profile_page.dart`. Toda la lógica consolidada se encuentra en `lib/presentation/screens/profile/profile_screen.dart` y trabaja en conjunto con los providers de `lib/presentation/providers/user_profile/user_profile_providers.dart`.

Puntos clave de la implementación vigente:

- `ProfileScreen` es un `ConsumerStatefulWidget` que maneja el modo edición, la subida de avatar y las preferencias del usuario sin depender de una pantalla de edición separada.
- El estado principal proviene de `userProfileNotifierProvider` (un `AsyncNotifier` que conserva el último perfil válido) y de `currentUserStatsProvider` para las métricas agregadas.
- Se introdujo `userProfileAlertProvider`, un `NotifierProvider` ligero usado para mostrar _snackbars_ no intrusivos cuando falla la sincronización o la persistencia del perfil. El Drawer (`lib/presentation/widgets/custom_drawer.dart`) también consume `userProfileNotifierProvider`, por lo que **no se debe duplicar lógica ni estado**.
- La pantalla aplica degradación elegante: mientras el perfil real se recupera, se muestran datos básicos del usuario (`currentUserProvider`) y un aviso de sincronización; si ocurre un fallo, se conserva el último perfil en caché y solo se notifica mediante el alert provider.
- La edición inline reutiliza los _use cases_ `UpdateUserProfileUseCase`, `UploadAvatarUseCase` y `DeleteAvatarUseCase`, invocados a través del notifier. Todas las operaciones siguen las reglas de logging (`LoggerFactory`) y evitan `print()`.
- Para personalizar la UI se emplean componentes compartidos (`ProfileAvatar`, `MinimalSyncIndicator`, secciones de estadísticas y valoraciones) ubicados en `lib/presentation/widgets/`.

> **Buenas prácticas de validación**: tras modificar esta pantalla, ejecutar `flutter test test/presentation/providers/user_profile_notifier_test.dart` para validar la lógica del notifier y `flutter analyze --fatal-infos --fatal-warnings` para garantizar que no se introducen regresiones.

El Drawer quedó como referencia de integración correcta (mostrando avatar y username en tiempo real). **No modificar su código**; en su lugar, replicar cualquier ajuste necesario a través de los providers compartidos.

              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.bio != null) ...[
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(profile.bio!),
                  const SizedBox(height: 24),
                ],
                _buildStatsSection(context, profile.stats),
                const SizedBox(height: 24),
                _buildRecentActivity(context),
              ],
            ),
          ),
        ),
      ],
    );

}

Widget \_buildStatsSection(BuildContext context, Map<String, dynamic> stats) {
final statsData = [
{'label': 'Movies', 'value': stats['movies_watched'] ?? 0, 'icon': Icons.movie},
{'label': 'Watchlist', 'value': stats['watchlist_count'] ?? 0, 'icon': Icons.bookmark},
{'label': 'Reviews', 'value': stats['reviews_count'] ?? 0, 'icon': Icons.rate_review},
{'label': 'Lists', 'value': stats['lists_count'] ?? 0, 'icon': Icons.list},
];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
          ),
          itemCount: statsData.length,
          itemBuilder: (context, index) {
            final stat = statsData[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    stat['icon'] as IconData,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${stat['value']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        stat['label'] as String,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );

}

Widget \_buildRecentActivity(BuildContext context) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Recent Activity',
style: Theme.of(context).textTheme.titleMedium,
),
const SizedBox(height: 16),
// TODO: Implement recent activity list
Center(
child: Text(
'No recent activity',
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
),
),
],
);
}

Widget \_buildEmptyProfile(BuildContext context) {
return Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.person_outline,
size: 100,
color: Theme.of(context).colorScheme.onSurfaceVariant,
),
const SizedBox(height: 16),
Text(
'No profile found',
style: Theme.of(context).textTheme.titleLarge,
),
const SizedBox(height: 8),
Text(
'Create your profile to get started',
style: Theme.of(context).textTheme.bodyMedium,
),
const SizedBox(height: 24),
ElevatedButton(
onPressed: () => context.push('/profile/edit'),
child: const Text('Create Profile'),
),
],
),
);
}
}

````

### Paso 4.4: Pantalla de Edición

```dart
// filepath: lib/presentation/pages/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/avatar_widget.dart';
import '../providers/user_profile_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../../core/logging/logger_factory.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _fullNameController = TextEditingController();
    _bioController = TextEditingController();

    // Load existing profile data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileNotifierProvider).value;
      if (profile != null) {
        _usernameController.text = profile.username ?? '';
        _fullNameController.text = profile.fullName ?? '';
        _bioController.text = profile.bio ?? '';
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        setState(() => _isLoading = true);
        await ref.read(profileNotifierProvider.notifier).uploadAvatar(bytes);
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar updated successfully')),
          );
        }
      }
    } catch (e) {
      LoggerFactory.error('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) return;

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final currentProfile = ref.read(profileNotifierProvider).value;
      if (currentProfile?.username == username) {
        setState(() => _isCheckingUsername = false);
        return;
      }

      final isAvailable = await ref.read(userProfileRepositoryProvider)
          .checkUsernameAvailability(username);

      setState(() {
        _usernameError = isAvailable ? null : 'Username is already taken';
        _isCheckingUsername = false;
      });
    } catch (e) {
      setState(() {
        _usernameError = 'Error checking username';
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameError != null) return;

    setState(() => _isLoading = true);

    try {
      final currentProfile = ref.read(profileNotifierProvider).value;
      if (currentProfile == null) {
        // Create new profile
        final userId = ref.read(supabaseClientProvider).auth.currentUser!.id;
        final newProfile = UserProfile(
          id: '', // Will be generated by Supabase
          userId: userId,
          username: _usernameController.text.isEmpty ? null : _usernameController.text,
          fullName: _fullNameController.text.isEmpty ? null : _fullNameController.text,
          bio: _bioController.text.isEmpty ? null : _bioController.text,
          createdAt: DateTime.now(),
        );
        await ref.read(profileNotifierProvider.notifier).updateProfile(newProfile);
      } else {
        // Update existing profile
        final updatedProfile = currentProfile.copyWith(
          username: _usernameController.text.isEmpty ? null : _usernameController.text,
          fullName: _fullNameController.text.isEmpty ? null : _fullNameController.text,
          bio: _bioController.text.isEmpty ? null : _bioController.text,
        );
        await ref.read(profileNotifierProvider.notifier).updateProfile(updatedProfile);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      LoggerFactory.error('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: const Text('Save'),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _buildForm(context, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildForm(BuildContext context, UserProfile? profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Avatar section
            Center(
              child: Stack(
                children: [
                  AvatarWidget(
                    avatarUrl: profile?.avatarUrl,
                    size: 120,
                    showEditIcon: true,
                    onTap: _pickImage,
                  ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : _pickImage,
              child: const Text('Change Avatar'),
            ),
            const SizedBox(height: 24),

            // Username field
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter unique username',
                prefixText: '@',
                errorText: _usernameError,
                suffixIcon: _isCheckingUsername
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _usernameError == null && _usernameController.text.isNotEmpty
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                LengthLimitingTextInputFormatter(20),
              ],
              onChanged: (value) {
                if (value.length >= 3) {
                  _checkUsernameAvailability(value);
                }
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  if (value.length > 20) {
                    return 'Username must be less than 20 characters';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Full name field
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
              ),
              inputFormatters: [
                LengthLimitingTextInputFormatter(50),
              ],
              validator: (value) {
                if (value != null && value.length > 50) {
                  return 'Name must be less than 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bio field
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              inputFormatters: [
                LengthLimitingTextInputFormatter(500),
              ],
              validator: (value) {
                if (value != null && value.length > 500) {
                  return 'Bio must be less than 500 characters';
                }
                return null;
              },
            ),
            Text(
              '${_bioController.text.length}/500',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
````

## 📝 FASE 5: Testing

### Paso 5.1: Tests Unitarios

```dart
// filepath: test/user_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
// Import your domain and infrastructure classes

@GenerateMocks([UserProfileRepository])
void main() {
  group('UserProfile Tests', () {
    test('should update profile successfully', () async {
      // TODO: Implement test
    });

    test('should validate username format', () {
      // TODO: Implement test
    });

    test('should compress and upload avatar', () async {
      // TODO: Implement test
    });

    test('should handle cache invalidation', () async {
      // TODO: Implement test
    });
  });
}
```

### Paso 5.2: Tests de Integración

```dart
// filepath: integration_test/user_profile_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('User Profile Flow', () {
    testWidgets('Complete profile creation and edit flow', (WidgetTester tester) async {
      // TODO: Implement integration test
    });
  });
}
```

## 📝 FASE 6: Configuración de Rutas

### Paso 6.1: Actualizar Router

```dart
// Agregar en tu configuración de GoRouter
GoRoute(
  path: '/profile',
  builder: (context, state) => const ProfilePage(),
  routes: [
    GoRoute(
      path: 'edit',
      builder: (context, state) => const EditProfilePage(),
    ),
  ],
),
```

## ✅ Checklist de Implementación

### Setup Inicial

- [ ] Agregar dependencias en pubspec.yaml
- [ ] Configurar Supabase Storage y tablas
- [ ] Ejecutar migrations SQL

### Dominio

- [ ] Crear entidad UserProfile
- [ ] Crear repository interface
- [ ] Implementar use cases

### Infraestructura

- [ ] Implementar repository con Supabase
- [ ] Crear servicios de imagen
- [ ] Configurar caché manager

### UI/UX

- [ ] Implementar providers
- [ ] Crear widget de avatar
- [ ] Desarrollar ProfilePage
- [ ] Desarrollar EditProfilePage
- [ ] Configurar rutas

### Testing

- [ ] Unit tests para use cases
- [ ] Integration tests para flujo completo
- [ ] Golden tests para UI

### Optimización

- [ ] Verificar performance de caché
- [ ] Optimizar tamaño de imágenes
- [ ] Implementar error handling robusto
- [ ] Añadir analytics

## 🚨 Notas Importantes

1. **Seguridad**: Siempre validar en backend con RLS
2. **Performance**: Comprimir imágenes antes de upload
3. **UX**: Mostrar feedback inmediato al usuario
4. **Cache**: Implementar estrategia de invalidación inteligente
5. **Offline**: Guardar cambios localmente si no hay conexión

## 🎯 Comando de Ejecución

Para ejecutar toda la implementación automáticamente:

```bash
# 1. Instalar dependencias
flutter pub add image_picker image cached_network_image uuid path_provider flutter_image_compress shimmer

# 2. Generar código
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run tests
flutter test

# 4. Verificar implementación
flutter analyze --fatal-infos --fatal-warnings
```

---

**FIN DE LAS INSTRUCCIONES DE IMPLEMENTACIÓN**
