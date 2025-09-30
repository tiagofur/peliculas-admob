# 📘 Guía de Carga de Perfiles de Usuario

## 🎯 Objetivo

Asegurar que los datos del usuario se carguen correctamente desde Supabase a la app y viceversa, con énfasis en:

- ✅ Carga de perfil sin errores
- ✅ Avatar con cache local y actualización automática
- ✅ Guardado bidireccional (App ↔ Supabase)

---

## ✅ Estado Actual del Código

### Arquitectura Verificada

```
┌─────────────────────────────────────────────────────────┐
│                    ARQUITECTURA LIMPIA                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Supabase Database] ← RLS Policies                    │
│           ↕                                            │
│  [UserProfileRepositoryImpl] ← Infrastructure Layer     │
│           ↕                                            │
│  [GetUserProfileUseCase] ← Domain Layer                │
│           ↕                                            │
│  [UserProfileNotifier] ← Riverpod State Management     │
│           ↕                                            │
│  [ProfileScreen + ProfileAvatar] ← Presentation Layer  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Componentes Implementados

| Componente     | Archivo                             | Estado |
| -------------- | ----------------------------------- | ------ |
| **Repository** | `user_profile_repository_impl.dart` | ✅     |
| **Entity**     | `user_profile.dart`                 | ✅     |
| **Model**      | `user_profile_model.dart`           | ✅     |
| **Use Cases**  | `get_user_profile_use_case.dart`    | ✅     |
|                | `update_user_profile_use_case.dart` | ✅     |
|                | `upload_avatar_use_case.dart`       | ✅     |
| **Provider**   | `user_profile_providers.dart`       | ✅     |
| **UI**         | `profile_screen.dart`               | ✅     |
|                | `profile_avatar.dart`               | ✅     |

---

## 🗄️ Paso 1: Verificar Base de Datos

### Estructura Requerida en Supabase

La tabla `user_profiles` debe tener estas columnas:

```sql
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id),

    -- Información básica
    display_name VARCHAR(100) NOT NULL DEFAULT 'Usuario Anónimo',
    full_name VARCHAR(100),
    username VARCHAR(50) UNIQUE,
    bio TEXT CHECK (char_length(bio) <= 500),
    email VARCHAR(255),

    -- Media
    avatar_url TEXT,
    avatar_hash VARCHAR(50),  -- ⚠️ CRÍTICO para cache
    banner_url TEXT,

    -- Datos adicionales
    stats JSONB DEFAULT '{}',
    preferences JSONB DEFAULT '{}',
    custom_fields JSONB DEFAULT '{}',

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_synced_at TIMESTAMP WITH TIME ZONE,
    last_active_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### ⚠️ Columnas Críticas

| Columna        | Propósito                 | ¿Opcional?             |
| -------------- | ------------------------- | ---------------------- |
| `user_id`      | Vínculo con auth.users    | ❌ NO                  |
| `display_name` | Nombre visible            | ❌ NO                  |
| `avatar_url`   | URL del avatar en Storage | ✅ SI                  |
| `avatar_hash`  | **Cache invalidation**    | ✅ SI pero RECOMENDADO |
| `username`     | Nombre de usuario único   | ✅ SI                  |
| `stats`        | Estadísticas (JSONB)      | ✅ SI                  |
| `preferences`  | Preferencias (JSONB)      | ✅ SI                  |

### Ejecutar Migración

1. Ir a **Supabase Dashboard**
2. **SQL Editor** → New Query
3. Copiar contenido de `fix_user_profiles_simple.sql`
4. **RUN**
5. Verificar resultado:

```
✅ Tabla user_profiles: EXISTE
📊 Columnas críticas: 5 de 5
🔑 Índice único user_id: SÍ
👥 Total perfiles: X
🎉 ¡Tabla user_profiles configurada correctamente!
```

### Verificar RLS (Row Level Security)

Deben existir estas políticas:

```sql
-- Lectura pública
CREATE POLICY "Public profiles are readable"
ON user_profiles FOR SELECT
USING (true);

-- Usuario puede ver su perfil
CREATE POLICY "Users can view their own profile"
ON user_profiles FOR SELECT
USING (auth.uid() = user_id);

-- Usuario puede actualizar su perfil
CREATE POLICY "Users can update their own profile"
ON user_profiles FOR UPDATE
USING (auth.uid() = user_id);

-- Usuario puede crear su perfil
CREATE POLICY "Users can insert their own profile"
ON user_profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

---

## 🧪 Paso 2: Probar en el Navegador

### 2.1 Iniciar Aplicación

```powershell
cd c:\Users\tfurt\source\repos\peliculas-admob-clean
flutter run -d chrome --web-port 3000
```

### 2.2 Navegar al Perfil

1. Abrir http://localhost:3000
2. **Login** con cuenta de prueba
3. Navegar a http://localhost:3000/#/profile

### 2.3 Abrir DevTools

**Chrome DevTools** (F12):

- **Console**: Ver logs de carga
- **Network**: Ver requests a Supabase
- **Application** > Storage > Cache Storage: Ver cache de avatares

---

## 🔍 Paso 3: Interpretar Logs

### ✅ Logs Correctos (Éxito)

```
✅ UserProfileNotifier: Loading profile for user: abc123...
✅ UserProfileRepositoryImpl: fetching profile for user abc123
✅ UserProfileModel: Profile loaded with display_name: "Juan Pérez"
✅ UserProfileNotifier: Profile loaded successfully
✅ ProfileAvatar: Loading avatar from cache key: https://.../_1735...
```

### ❌ Logs de Error

#### Error 1: Columna No Existe

```
❌ PostgrestException: column "avatar_hash" does not exist
```

**Solución:**

- Ejecutar `fix_user_profiles_simple.sql` en Supabase
- Reiniciar la aplicación

#### Error 2: Perfil No Encontrado

```
⚠️ UserProfileRepositoryImpl: Profile not found for user abc123
✅ Creating default profile...
```

**Acción:**

- Normal si es primera vez
- El código crea perfil automáticamente con `_ensureDefaultProfile()`

#### Error 3: Permiso Denegado

```
❌ PostgrestException: permission denied for table user_profiles
```

**Solución:**

- Verificar políticas RLS en Supabase
- Verificar que `auth.uid()` coincide con `user_id`

#### Error 4: Avatar No Carga

```
⚠️ CachedNetworkImage: Failed to load image from https://...
❌ HTTP 403 Forbidden
```

**Solución:**

- Verificar bucket `avatars` en Supabase Storage
- Política debe permitir lectura pública:

```sql
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');
```

---

## 🔄 Flujo de Datos Detallado

### Carga (Supabase → App)

```dart
// 1. UserProfileNotifier inicia carga
@override
Future<UserProfile?> build() async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;

  return _loadProfile(user.id);
}

// 2. Llama a use case
Future<UserProfile?> _loadProfile(String userId) async {
  final profile = await _getUserProfileUseCase.execute(userId);
  // ...
  return profile;
}

// 3. Use case llama a repositorio
Future<UserProfile?> execute(String userId, {bool ensureExists = true}) {
  return _repository.fetchProfile(userId, ensureExists: ensureExists);
}

// 4. Repositorio consulta Supabase
Future<UserProfile?> fetchProfile(String userId, {bool ensureExists = true}) async {
  final response = await _supabase
      .from('user_profiles')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  if (response != null) {
    return UserProfileModel.fromJson(response); // 👈 Mapeo aquí
  }

  if (ensureExists) {
    return _ensureDefaultProfile(userId); // Crea si no existe
  }

  return null;
}

// 5. Modelo mapea JSON a Entity
factory UserProfileModel.fromJson(Map<String, dynamic> json) {
  return UserProfileModel(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    fullName: json['display_name'] ?? json['full_name'] ?? 'Usuario',
    username: json['username']?.toString().toLowerCase(),
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    avatarHash: json['avatar_hash'] as String?, // 👈 Para cache
    stats: _parseMap(json['stats']),
    preferences: _parseBoolMap(json['preferences']),
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
  );
}
```

### Guardado (App → Supabase)

```dart
// 1. Usuario edita en ProfileScreen
Future<void> saveProfile() async {
  final request = UpdateUserProfileRequest(
    userId: currentUserId,
    fullName: _fullNameController.text.trim(),
    bio: _bioController.text.trim(),
    username: _usernameController.text.trim(),
  );

  // 2. Llama al provider
  await ref.read(userProfileNotifierProvider.notifier)
      .updateProfile(request);
}

// 3. Provider llama a use case
Future<void> updateProfile(UpdateUserProfileRequest request) async {
  state = const AsyncValue.loading();

  state = await AsyncValue.guard(() async {
    final updated = await _updateUserProfileUseCase.execute(request);
    return updated;
  });
}

// 4. Use case valida y llama a repositorio
Future<UserProfile> execute(UpdateUserProfileRequest request) {
  // Validaciones...
  if (sanitizedFullName != null && sanitizedFullName.isEmpty) {
    throw ArgumentError('El nombre no puede estar vacío.');
  }

  return _repository.updateProfile(
    userId: request.userId,
    fullName: sanitizedFullName,
    bio: sanitizedBio,
    username: normalizedUsername,
    // ...
  );
}

// 5. Repositorio hace upsert en Supabase
Future<UserProfile> updateProfile({...}) async {
  final updatePayload = <String, dynamic>{
    'user_id': userId,
    'display_name': fullName,
    'bio': bio,
    'updated_at': DateTime.now().toIso8601String(),
    'last_synced_at': DateTime.now().toIso8601String(),
  };

  final response = await _supabase
      .from('user_profiles')
      .upsert(updatePayload, onConflict: 'user_id')
      .select()
      .single();

  return UserProfileModel.fromJson(response);
}
```

### Sistema de Cache de Avatares

```dart
// ProfileAvatar widget
Widget build(BuildContext context) {
  // Cache key incluye hash para invalidación
  final cacheKey = avatarUrl != null && avatarHash != null
      ? '${avatarUrl}_$avatarHash'
      : avatarUrl;

  return CachedNetworkImage(
    imageUrl: avatarUrl!,
    cacheKey: cacheKey, // 👈 Cambia cuando avatarHash cambia
    placeholder: (context, url) => _buildShimmer(),
    errorWidget: (context, url, error) => _buildDefaultAvatar(),
  );
}

// Al subir nuevo avatar, se genera nuevo hash
Future<void> uploadAvatar(Uint8List imageBytes) async {
  // 1. Subir a Supabase Storage
  final publicUrl = await _uploadAvatarUseCase.execute(
    userId: currentUserId,
    imageBytes: imageBytes,
    existingUrl: currentProfile.avatarUrl,
  );

  // 2. Actualizar profile con nuevo hash
  final newHash = DateTime.now().millisecondsSinceEpoch.toString();

  await updateProfile(UpdateUserProfileRequest(
    userId: currentUserId,
    avatarUrl: publicUrl,
    avatarHash: newHash, // 👈 Nuevo hash invalida cache
  ));

  // 3. CachedNetworkImage detecta cambio de key y descarga nueva imagen
}
```

---

## ✅ Checklist de Verificación

### Base de Datos

- [ ] Tabla `user_profiles` existe
- [ ] Columnas críticas presentes (display_name, user_id, avatar_url, avatar_hash)
- [ ] Índice único en `user_id`
- [ ] RLS habilitado con políticas correctas
- [ ] Bucket `avatars` en Storage con política de lectura pública

### Aplicación

- [ ] App corre sin errores de compilación
- [ ] Login funciona correctamente
- [ ] Navegación a `/profile` muestra pantalla
- [ ] Perfil se carga sin errores en consola
- [ ] Avatar se muestra (o placeholder si no tiene)
- [ ] Edición de nombre guarda correctamente
- [ ] Edición de bio guarda correctamente
- [ ] Subir avatar funciona y se muestra inmediatamente

### Logs Esperados

```
✅ UserProfileNotifier: Loading profile
✅ UserProfileRepositoryImpl: fetching profile
✅ UserProfileModel: Profile loaded
✅ ProfileAvatar: Loading from cache
✅ UserProfileNotifier: Profile loaded successfully
```

---

## 🐛 Troubleshooting

### Problema: Perfil No Se Carga

**Síntomas:**

- Pantalla de perfil vacía
- Loading infinito
- Error en consola

**Diagnóstico:**

```dart
// Agregar en UserProfileNotifier._loadProfile()
LoggerFactory.info('🔍 Loading profile for userId: $userId');
```

**Soluciones:**

1. Verificar que `userId` no es null
2. Verificar que tabla existe en Supabase
3. Verificar RLS permite lectura
4. Ejecutar SQL de migración

### Problema: Avatar No Se Actualiza

**Síntomas:**

- Avatar nuevo sube pero muestra el anterior
- Cache no se invalida

**Diagnóstico:**

```dart
// Revisar en ProfileAvatar
LoggerFactory.info('🖼️ Avatar cache key: $cacheKey');
LoggerFactory.info('🖼️ Avatar hash: $avatarHash');
```

**Soluciones:**

1. Verificar que `avatar_hash` se actualiza en BD
2. Limpiar cache manualmente: `ImageCacheManager.instance.emptyCache()`
3. Verificar que `cacheKey` incluye el hash

### Problema: Cambios No Se Guardan

**Síntomas:**

- Editar datos pero no persisten
- Refresh muestra datos antiguos

**Diagnóstico:**

```dart
// En UserProfileRepositoryImpl.updateProfile()
LoggerFactory.info('📝 Updating profile with payload: $updatePayload');
```

**Soluciones:**

1. Verificar RLS permite UPDATE para usuario actual
2. Verificar formato de datos (JSONB para stats/preferences)
3. Revisar validaciones en UpdateUserProfileUseCase

---

## 🎯 Resultados Esperados

Después de seguir esta guía:

✅ **Carga de Perfil:**

- Datos se cargan automáticamente al abrir `/profile`
- Fallback a perfil por defecto si no existe
- Sin errores en consola

✅ **Avatar:**

- Descarga desde Supabase Storage
- Cache local con invalidación por hash
- Placeholder mientras carga
- Actualización inmediata al subir nuevo

✅ **Edición:**

- Cambios se guardan en Supabase
- UI se actualiza automáticamente (Riverpod watch)
- Validaciones funcionando

✅ **Persistencia:**

- Cerrar sesión → Login → Datos persisten
- Refresh → Datos se recargan correctamente

---

## 📚 Referencias

- **Código:** `lib/presentation/screens/profile/profile_screen.dart`
- **Repositorio:** `lib/infrastructure/repositories/user_profile_repository_impl.dart`
- **Provider:** `lib/presentation/providers/user_profile/user_profile_providers.dart`
- **SQL:** `fix_user_profiles_simple.sql`
- **Diagnóstico:** `scripts/diagnose_profile.dart`

---

✨ **Próximos Pasos:**

1. Ejecutar SQL de migración en Supabase
2. Probar aplicación en navegador
3. Revisar logs en consola
4. Reportar cualquier error encontrado
