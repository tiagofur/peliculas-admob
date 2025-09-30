# Plan de Mejora del Sistema de Perfil de Usuario

**Fecha**: 2025-09-29
**Versión**: 1.0.0
**Estado**: En Ejecución
**Última actualización**: 2025-09-29

## 🎯 Objetivo Principal

Implementar un sistema robusto y moderno de gestión de perfiles de usuario con almacenamiento en Supabase, caché local optimizado, y una interfaz de usuario atractiva y funcional.

## 📋 Alcance del Proyecto

### Funcionalidades Core

1. **Gestión de Avatar**

   - Upload de imágenes con compresión automática
   - Almacenamiento en Supabase Storage
   - Sistema de caché local inteligente
   - Validación de cambios por hash/UUID

2. **Datos del Perfil**

   - Nombre completo
   - Username único
   - Bio/Descripción
   - Estadísticas de usuario (películas vistas, watchlist, etc.)
   - Preferencias de notificaciones
   - Configuración de privacidad

3. **UI/UX**

   - Pantalla de perfil con diseño moderno
   - Pantalla de edición intuitiva
   - Animaciones y transiciones fluidas
   - Soporte para modo oscuro/claro
   - Responsive design

4. **Performance**
   - Caché de imágenes con invalidación inteligente
   - Lazy loading de datos
   - Optimización de ancho de banda
   - Sincronización en background

## 🚦 Resumen de Progreso (2025-09-29)

### Tareas completadas

- ✅ Normalización integral de usernames en `UserProfileModel`, `AuthRepositoryImpl` y capa de presentación (`profile_screen`, `custom_drawer`).
- ✅ Sincronización de `display_name`/`full_name` y propagación de `avatar_hash` para control de caché.
- ✅ Actualización de la UI (drawer y pantalla de perfil) para mostrar `@username`, shimmer states y claves de caché basadas en hash.
- ✅ Creación de la migración `supabase/migrations/20250929_add_profile_username_avatar_hash.sql` con nuevas columnas, índices y triggers.
- ✅ Cobertura unitaria inicial con `test/infrastructure/models/user_profile_model_test.dart` asegurando normalización y serialización.

### Pendientes inmediatos

- ⏳ Ejecutar la migración en Supabase y validar los triggers en el entorno remoto.
- ⏳ Alinear servicios auxiliares (`EnhancedUserProfileService`, watchers) con los nuevos campos y metadatos.
- ⏳ Completar repositorio/casos de uso dedicados al perfil (migrar lógica fuera de `AuthRepository`).
- ⏳ Expandir tests (repositorio, flujos UI, integración) y documentar escenarios offline.

## 🏗️ Arquitectura Propuesta

### Estructura de Carpetas

```
lib/
├── domain/
│   ├── entities/
│   │   └── user_profile.dart
│   ├── repositories/
│   │   └── user_profile_repository.dart
│   └── use_cases/
│       ├── update_profile_use_case.dart
│       ├── upload_avatar_use_case.dart
│       └── get_profile_use_case.dart
│
├── infrastructure/
│   ├── repositories/
│   │   └── user_profile_repository_impl.dart
│   ├── services/
│   │   ├── image_upload_service.dart
│   │   ├── image_cache_service.dart
│   │   └── supabase_storage_service.dart
│   └── models/
│       └── user_profile_model.dart
│
├── presentation/
│   ├── pages/
│   │   ├── profile_page.dart
│   │   └── edit_profile_page.dart
│   ├── widgets/
│   │   ├── avatar_widget.dart
│   │   ├── profile_stats_card.dart
│   │   ├── profile_header.dart
│   │   └── profile_form.dart
│   └── providers/
│       └── user_profile_provider.dart
│
└── core/
    ├── cache/
    │   ├── image_cache_manager.dart
    │   └── profile_cache_manager.dart
    └── utils/
        ├── image_compressor.dart
        └── uuid_generator.dart
```

## 📊 Modelo de Datos

### UserProfile Entity

```dart
class UserProfile {
  final String id; // UUID
  final String userId; // Supabase auth ID
  final String? username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final String? avatarHash; // Para verificar cambios
  final Map<String, dynamic> stats;
  final Map<String, bool> preferences;
  final DateTime? lastModified;
  final DateTime createdAt;
}
```

### Supabase Schema

```sql
-- Tabla profiles
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  full_name TEXT,
  bio TEXT,
  avatar_url TEXT,
  avatar_hash TEXT,
  stats JSONB DEFAULT '{}',
  preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Storage Bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- RLS Policies
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = user_id);
```

## 🎨 Diseño UI/UX

### Pantalla de Perfil

- **Header**: Avatar circular grande con overlay de cámara
- **Info Section**: Nombre, username, bio
- **Stats Grid**: Películas vistas, En watchlist, Reseñas, etc.
- **Action Buttons**: Editar perfil, Compartir, Configuración
- **Tab View**: Actividad reciente, Listas, Reseñas

### Pantalla de Edición

- **Avatar Section**: Preview con opción de cambiar
- **Form Fields**: Material Design 3 text fields
- **Validation**: En tiempo real con mensajes de error
- **Save Options**: Guardar y Cancelar con confirmación

## 🔧 Implementación Técnica

### 1. Sistema de Upload de Imágenes

```dart
// Proceso de upload
1. Selección de imagen (camera/gallery)
2. Validación (tamaño, formato)
3. Compresión (max 500KB, 800x800px)
4. Generación de UUID para nombre
5. Upload a Supabase Storage
6. Actualización de URL en profile
7. Invalidación de caché local
```

### 2. Sistema de Caché

```dart
// Estrategia de caché
- Usar cached_network_image package
- Almacenar hash de imagen en local
- Verificar hash en cada apertura de perfil
- Revalidar cada 24 horas
- Clear cache on logout
```

### 3. Nomenclatura de Archivos

```
Pattern: {user_id}/{timestamp}_{uuid}.{ext}
Example: 123e4567-e89b/1696012800_550e8400-e29b.jpg

Ventajas:
- Evita colisiones
- Facilita limpieza por usuario
- Permite versionado
```

## 🔍 Validaciones y Seguridad

### Validaciones Frontend

- **Username**: 3-20 caracteres, alfanumérico y underscore
- **Full Name**: Max 50 caracteres
- **Bio**: Max 500 caracteres
- **Avatar**: Max 5MB, formatos: jpg, png, webp

### Seguridad

- RLS en Supabase para acceso a perfiles
- Sanitización de inputs
- Rate limiting en uploads
- Validación de tipos MIME
- Compresión de imágenes para prevenir ataques

## 📈 Métricas de Éxito

### Performance

- [ ] Tiempo de carga de perfil < 500ms
- [ ] Upload de avatar < 3 segundos
- [ ] Caché hit rate > 80%
- [ ] Tamaño de imagen optimizada < 100KB

### UX

- [ ] Proceso de edición en < 3 pasos
- [ ] Feedback visual inmediato
- [ ] Sin pérdida de datos en interrupciones
- [ ] Soporte offline básico

## 🧪 Plan de Testing

### Unit Tests

- Repository methods
- Use cases
- Image compression
- Cache management
- UUID generation

### Integration Tests

- Upload flow completo
- Profile update flow
- Cache invalidation
- Error handling

### Golden Tests

- Profile page UI
- Edit profile page UI
- Avatar widget estados

## 📅 Fases de Implementación

### Fase 1: Backend & Infraestructura (2 días)

- [ ] Configurar Supabase Storage _(pendiente ejecutar migración y bucket en Supabase)_
- [ ] Crear tablas y políticas _(script generado, falta aplicarlo en entorno remoto)_
- [ ] Implementar repositories _(continuar separación desde `AuthRepositoryImpl`)_
- [x] Servicios de upload y caché _(nuevos utilitarios `image_compressor`, `uuid_generator`, invalidación de caché)_

### Fase 2: UI/UX (2 días)

- [x] Diseñar y crear widgets _(avatar con shimmer/hash en `profile_avatar.dart`)_
- [x] Implementar pantallas _(perfil actualizado; falta pantalla de edición dedicada)_
- [ ] Añadir animaciones _(por definir microinteracciones)_
- [ ] Integrar con providers _(migración pendiente a providers específicos de perfil)_

### Fase 3: Testing & Optimización (1 día)

- [ ] Escribir tests _(modelo cubierto; faltan repositorio, flujos UI e integración)_
- [ ] Optimizar performance _(pendiente validar métricas de carga/avatar)_
- [ ] Manejar edge cases _(falta cobertura offline y conflictos)_
- [x] Documentación _(plan, instrucciones y roadmap actualizados al 2025-09-29)_

## 🚀 Siguiente Paso

Ejecutar el script de implementación automatizada con las instrucciones detalladas en `USER-PROFILE-IMPLEMENTATION-INSTRUCTIONS.md`
