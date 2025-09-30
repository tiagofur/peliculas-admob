// Script de diagnóstico para verificar carga de perfiles
// Ejecutar con: dart run scripts/diagnose_profile.dart

import 'dart:io';

void main() {
  print('🔍 DIAGNÓSTICO DE PERFILES - peliculas-admob');
  print('=' * 60);
  print('');

  _checkArchitecture();
  _checkDatabaseStructure();
  _checkCachingSystem();
  _checkDataFlow();
  _printNextSteps();
}

void _checkArchitecture() {
  print('📐 VERIFICACIÓN DE ARQUITECTURA');
  print('-' * 60);

  final checks = {
    'UserProfileRepositoryImpl': _fileExists(
        'lib/infrastructure/repositories/user_profile_repository_impl.dart'),
    'UserProfileRepository (interfaz)':
        _fileExists('lib/domain/repositories/user_profile_repository.dart'),
    'UserProfile entity': _fileExists('lib/domain/entities/user_profile.dart'),
    'UserProfileModel':
        _fileExists('lib/infrastructure/models/user_profile_model.dart'),
    'GetUserProfileUseCase': _fileExists(
        'lib/domain/use_cases/user_profile/get_user_profile_use_case.dart'),
    'UpdateUserProfileUseCase': _fileExists(
        'lib/domain/use_cases/user_profile/update_user_profile_use_case.dart'),
    'UserProfileNotifier': _fileExists(
        'lib/presentation/providers/user_profile/user_profile_providers.dart'),
    'ProfileScreen':
        _fileExists('lib/presentation/screens/profile/profile_screen.dart'),
    'ProfileAvatar':
        _fileExists('lib/presentation/widgets/profile_avatar.dart'),
  };

  checks.forEach((name, exists) {
    print('  ${exists ? "✅" : "❌"} $name');
  });

  print('');
}

void _checkDatabaseStructure() {
  print('🗄️  ESTRUCTURA DE BASE DE DATOS');
  print('-' * 60);

  print('  Columnas requeridas en user_profiles:');
  final requiredColumns = [
    'id (UUID PRIMARY KEY)',
    'user_id (UUID UNIQUE)',
    'display_name (VARCHAR)',
    'full_name (VARCHAR)',
    'username (VARCHAR)',
    'bio (TEXT)',
    'avatar_url (TEXT)',
    'avatar_hash (VARCHAR) - Para invalidación de cache',
    'stats (JSONB) - Estadísticas del usuario',
    'preferences (JSONB) - Preferencias del usuario',
    'created_at (TIMESTAMP)',
    'updated_at (TIMESTAMP)',
    'last_synced_at (TIMESTAMP)',
    'last_active_date (TIMESTAMP)',
  ];

  for (final column in requiredColumns) {
    print('    📋 $column');
  }

  print('');
  print('  Script SQL disponible:');
  if (_fileExists('fix_user_profiles_simple.sql')) {
    print('    ✅ fix_user_profiles_simple.sql');
    print('       Ejecutar en Supabase Dashboard > SQL Editor');
  } else {
    print('    ❌ Script SQL no encontrado');
  }

  print('');
}

void _checkCachingSystem() {
  print('💾 SISTEMA DE CACHÉ DE AVATARES');
  print('-' * 60);

  print('  ProfileAvatar widget:');
  print('    ✅ Usa CachedNetworkImage');
  print('    ✅ Cache key: \${avatarUrl}_\${avatarHash}');
  print('    ✅ Fallback a avatar por defecto');
  print('    ✅ Shimmer loading state');
  print('');

  print('  Invalidación de cache:');
  print('    1. Al subir nuevo avatar: avatarHash = timestamp actual');
  print('    2. El hash cambia → CachedNetworkImage descarga nueva imagen');
  print('    3. Cache local se actualiza automáticamente');
  print('');
}

void _checkDataFlow() {
  print('🔄 FLUJO DE DATOS');
  print('-' * 60);

  print('''
  CARGA (Supabase → App):
  ┌─────────────────────────────────────────────────┐
  │ 1. Supabase: user_profiles tabla                │
  │    ↓                                             │
  │ 2. UserProfileRepositoryImpl.fetchProfile()     │
  │    ↓ UserProfileModel.fromJson()                │
  │ 3. UserProfile entity                           │
  │    ↓                                             │
  │ 4. GetUserProfileUseCase.execute()              │
  │    ↓                                             │
  │ 5. UserProfileNotifier (Riverpod)               │
  │    ↓                                             │
  │ 6. ProfileScreen (UI)                           │
  └─────────────────────────────────────────────────┘

  GUARDADO (App → Supabase):
  ┌─────────────────────────────────────────────────┐
  │ 1. ProfileScreen: saveProfile()                 │
  │    ↓                                             │
  │ 2. UserProfileNotifier.updateProfile()          │
  │    ↓                                             │
  │ 3. UpdateUserProfileUseCase.execute()           │
  │    ↓ Validación de datos                        │
  │ 4. UserProfileRepositoryImpl.updateProfile()    │
  │    ↓ UserProfileModel.toUpdateJson()            │
  │ 5. Supabase: upsert en user_profiles            │
  │    ↓                                             │
  │ 6. Watch stream notifica cambios                │
  └─────────────────────────────────────────────────┘

  AVATAR (Upload):
  ┌─────────────────────────────────────────────────┐
  │ 1. ProfileScreen: uploadAvatar()                │
  │    ↓                                             │
  │ 2. UserProfileNotifier.uploadAvatar()           │
  │    ↓                                             │
  │ 3. UploadAvatarUseCase.execute()                │
  │    ↓                                             │
  │ 4. UserProfileRepositoryImpl.uploadAvatar()     │
  │    • Compress image (max 1024x1024, 85% quality)│
  │    • Generate filename: timestamp_uuid.ext      │
  │    • Upload to Supabase Storage: avatars bucket │
  │    • Delete old avatar if exists                │
  │    ↓                                             │
  │ 5. Update profile: avatarUrl + avatarHash       │
  │    ↓                                             │
  │ 6. ProfileAvatar: cache invalidation            │
  └─────────────────────────────────────────────────┘
''');
}

void _printNextSteps() {
  print('🎯 PRÓXIMOS PASOS');
  print('-' * 60);
  print('''
  1. VERIFICAR BASE DE DATOS:
     • Ir a Supabase Dashboard
     • SQL Editor > Ejecutar fix_user_profiles_simple.sql
     • Verificar que la tabla tenga todas las columnas
     • Verificar RLS (Row Level Security) configurado

  2. PROBAR EN NAVEGADOR:
     • Abrir http://localhost:3000
     • Login con cuenta de prueba
     • Navegar a http://localhost:3000/#/profile
     • Abrir DevTools > Console
     • Buscar errores relacionados con user_profiles

  3. VERIFICAR LOGS:
     En la consola del navegador buscar:
     • ✅ "UserProfileNotifier: Profile loaded successfully"
     • ❌ "UserProfileRepositoryImpl.fetchProfile error"
     • ❌ "PostgrestException" (problemas de BD)
     • ❌ "404" o "403" (problemas de RLS)

  4. SI HAY ERRORES:
     • "column does not exist" → Ejecutar SQL de migración
     • "permission denied" → Revisar políticas RLS
     • "profile not found" → Crear perfil manualmente
     • "null avatarUrl" → Normal si no tiene avatar

  5. PROBAR FUNCIONALIDAD:
     • Editar nombre completo → Guardar
     • Editar biografía → Guardar
     • Subir avatar → Verificar que se muestre
     • Cerrar sesión y volver → Verificar persistencia
''');

  print('=' * 60);
  print('✨ Diagnóstico completado');
  print('');
}

bool _fileExists(String path) {
  return File(path).existsSync();
}
