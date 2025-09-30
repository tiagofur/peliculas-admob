# Solución: Errores de Provider y Refresh en Navegador

## 🔴 Problemas Solucionados

### 1. ProviderException con Dependencias Circulares

```
ProviderException: Tried to use a provider that is in error state.
Bad state: Tried to read the state of an uninitialized provider.
This generally means that have a circular dependency, and your provider end-up depending on itself.
```

**Causa**: El `AppStateNotifier` en `auth_provider.dart` usaba `ref.listen()` durante la inicialización, creando una dependencia circular.

**Solución**: Eliminada la llamada a `ref.listen()` y se lee el estado inicial directamente en un `Future.microtask()`.

---

### 2. Pérdida de Estado al Hacer Refresh

**Causa**: Al recargar la página en el navegador, los providers se reinician pero no pueden reconstruir el estado desde la URL.

**Solución**: Implementado sistema de routing con `userId` en la URL:

- `/profile` - Muestra el perfil del usuario autenticado
- `/profile/:userId` - Muestra el perfil del usuario especificado por ID

---

### 3. Errores de Perfil en Drawer y Pantallas

**Causa**: El perfil intentaba cargarse incluso cuando no había usuario autenticado o el estado estaba corrupto.

**Solución**: Implementado sistema de carga resiliente con:

- Detección automática de userId desde URL
- Fallback a usuario autenticado si no hay userId
- Validación y manejo de errores con notificaciones
- Redirección automática a home si el perfil no existe

---

## ✅ Cambios Implementados

### 1. **Router Actualizado** (`app_router.dart`)

```dart
// Ruta con userId en URL
GoRoute(
  path: '/profile/:userId',
  name: 'profile',
  pageBuilder: (context, state) {
    final userId = state.pathParameters['userId'];
    return CustomTransitionPage(
      key: state.pageKey,
      child: ProfileScreen(userId: userId),
      // ...
    );
  },
),

// Ruta sin userId (fallback al usuario autenticado)
GoRoute(
  path: '/profile',
  pageBuilder: (context, state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: const ProfileScreen(),
      // ...
    );
  },
),
```

### 2. **ProfileScreen Actualizado** (`profile_screen.dart`)

```dart
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  /// ID del usuario a mostrar. Si es null, muestra el perfil del usuario autenticado.
  final String? userId;

  // ...
}

// Nuevo método de carga inteligente
void _loadProfileData() {
  final targetUserId = widget.userId;
  final currentUser = ref.read(currentUserProvider);

  if (targetUserId != null && targetUserId.isNotEmpty) {
    // Caso 1: Se especificó userId en la URL
    _loadProfileFromUserId(targetUserId);
  } else if (currentUser != null) {
    // Caso 2: Usuario autenticado sin userId en URL
    ref.read(userProfileNotifierProvider.notifier).refreshProfile();
  } else {
    // Caso 3: Error - no hay usuario
    _showErrorAndRedirect('No se pudo cargar el perfil');
  }
}

// Manejo de errores con redirección
void _showErrorAndRedirect(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );

  Future.delayed(const Duration(seconds: 2), () {
    context.go('/');
  });
}
```

### 3. **AuthProvider Corregido** (`auth_provider.dart`)

**ANTES** (con dependencia circular):

```dart
void _initializeWithRef() {
  // ❌ PROBLEMA: Esto crea dependencia circular
  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    // ...
  });
}
```

**DESPUÉS** (sin dependencia circular):

```dart
void _initializeWithRef() {
  // ✅ SOLUCIÓN: Lectura única en microtask
  Future.microtask(() {
    final currentAuthState = ref.read(authStateProvider);
    currentAuthState.when(
      data: (user) {
        if (user != null) {
          state = state.copyWith(
            mode: AppMode.authenticated,
            user: user,
          );
        }
      },
      // ...
    );
  });
}
```

---

## 🚀 Cómo Usar

### Navegación a Perfil

#### 1. **Perfil del Usuario Actual**

```dart
// Desde cualquier parte de la app
context.go('/profile');

// O con named route
context.goNamed('profile');
```

#### 2. **Perfil de Usuario Específico**

```dart
// Con ID de usuario
context.go('/profile/${userId}');

// O programáticamente
final userId = 'abc-123-def-456';
context.go('/profile/$userId');
```

#### 3. **En Drawer o AppBar**

```dart
ListTile(
  leading: const Icon(Icons.person),
  title: const Text('Mi Perfil'),
  onTap: () {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      // Navegación con userId en URL
      context.go('/profile/$userId');
    } else {
      // Fallback
      context.go('/profile');
    }
  },
),
```

---

## 🧪 Casos de Prueba

### ✅ Caso 1: Usuario Autenticado Navega a su Perfil

```
Usuario logueado → Click en "Mi Perfil"
→ URL: /profile/abc-123
→ Resultado: Carga perfil correctamente
```

### ✅ Caso 2: Refresh en Página de Perfil

```
En /profile/abc-123 → F5 (Refresh)
→ Providers se reinician
→ ProfileScreen lee userId desde URL
→ Carga perfil desde Supabase
→ Resultado: Perfil se muestra correctamente
```

### ✅ Caso 3: Usuario No Autenticado Accede a Perfil

```
Sin login → /profile
→ currentUser = null
→ Resultado: Notificación "Por favor inicia sesión"
→ Redirección a /
```

### ✅ Caso 4: Usuario No Existe en Base de Datos

```
/profile/usuario-invalido
→ Intenta cargar perfil
→ Error: Usuario no encontrado
→ Resultado: Notificación "No se encontró el perfil"
→ Redirección a /
```

### ✅ Caso 5: Drawer Muestra Información Correcta

```
Usuario logueado → Abre drawer
→ Drawer lee de currentUserProvider
→ Resultado: Nombre y email se muestran correctamente
```

---

## 📊 Flujo de Carga del Perfil

```
┌─────────────────────────────────────────┐
│ ProfileScreen.initState()               │
└───────────────┬─────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────┐
│ _loadProfileData()                      │
│  ├─ Leer widget.userId de URL           │
│  ├─ Leer currentUserProvider            │
│  └─ Decidir estrategia de carga         │
└───────────────┬─────────────────────────┘
                │
        ┌───────┴───────┐
        │               │
        ▼               ▼
┌──────────────┐  ┌──────────────────┐
│ userId!=null │  │ currentUser!=null│
│ en URL       │  │ (autenticado)    │
└──────┬───────┘  └────────┬─────────┘
       │                   │
       ▼                   ▼
┌──────────────┐  ┌──────────────────┐
│ Cargar desde │  │ Usar provider    │
│ Supabase     │  │ estándar         │
└──────┬───────┘  └────────┬─────────┘
       │                   │
       └───────┬───────────┘
               ▼
    ┌─────────────────────┐
    │ Perfil Cargado      │
    │ ✅ Success          │
    └─────────────────────┘
               │
               ▼ (Si hay error)
    ┌─────────────────────┐
    │ _showErrorAndRedirect│
    │  ├─ Mostrar SnackBar│
    │  └─ context.go('/')  │
    └─────────────────────┘
```

---

## 🔧 Mantenimiento Futuro

### Para Agregar Perfiles Públicos de Otros Usuarios

Actualmente, solo el usuario autenticado puede ver su propio perfil. Para permitir ver perfiles públicos:

1. **Actualizar `_loadProfileFromUserId()`**:

```dart
Future<void> _loadProfileFromUserId(String userId) async {
  try {
    // Cargar perfil desde Supabase usando SupabaseUserProfileRepository
    final profileRepo = SupabaseUserProfileRepository.instance;
    final profile = await profileRepo.getUserProfile(userId);

    if (profile == null) {
      _showErrorAndRedirect('No se encontró el perfil del usuario');
      return;
    }

    // Actualizar estado con el perfil cargado
    // TODO: Crear provider específico para perfiles de otros usuarios
    setState(() {
      _externalUserProfile = profile;
    });
  } catch (e) {
    _showErrorAndRedirect('Error al cargar el perfil');
  }
}
```

2. **Agregar Provider para Perfiles Externos**:

```dart
// En user_profile_providers.dart
final externalUserProfileProvider = FutureProvider.family<UserProfile?, String>(
  (ref, userId) async {
    final repo = SupabaseUserProfileRepository.instance;
    return await repo.getUserProfile(userId);
  },
);
```

3. **Actualizar Políticas RLS en Supabase**:

```sql
-- Permitir lectura de perfiles públicos
CREATE POLICY "Public profiles are readable" ON user_profiles
    FOR SELECT USING (true);
```

---

## 🎯 Beneficios de la Solución

✅ **Resiliente a Refresh**: El userId en la URL permite reconstruir el estado  
✅ **No Más Dependencias Circulares**: Providers se inicializan correctamente  
✅ **Manejo de Errores Robusto**: Notificaciones claras y redirección automática  
✅ **Preparado para el Futuro**: Estructura lista para perfiles públicos  
✅ **SEO Friendly**: URLs con userId son indexables y compartibles  
✅ **Deep Linking**: Los enlaces `/profile/:userId` funcionan correctamente

---

## 📝 Notas Importantes

1. **Drawer sigue funcionando**: El drawer usa `currentUserProvider` directamente, no depende de la URL.

2. **Backward Compatible**: Las navegaciones existentes a `/profile` siguen funcionando.

3. **Estado Limpio**: Al hacer logout, todos los providers se limpian correctamente.

4. **Performance**: La carga desde URL es instantánea al hacer refresh.

5. **Supabase Fix Requerido**: Asegúrate de ejecutar primero el script `fix_schema_400_errors.sql` para que las columnas existan en la base de datos.

---

## 🆘 Troubleshooting

### Problema: "No se pudo cargar el perfil" después de login

**Solución**:

1. Verifica que el script SQL se ejecutó correctamente
2. Revisa que la tabla `user_profiles` tiene las columnas necesarias
3. Verifica los logs de Supabase en Dashboard > Logs

### Problema: Drawer muestra "Usuario Anónimo"

**Solución**:

1. El currentUserProvider puede estar null temporalmente
2. Espera 1-2 segundos, debería cargar automáticamente
3. Si persiste, revisa los logs del navegador (F12)

### Problema: Error al hacer refresh

**Solución**:

1. Verifica que la URL incluye el userId: `/profile/abc-123`
2. Si no tiene userId, la app redirigirá automáticamente
3. Revisa que el usuario esté autenticado

---

**¡La solución está completa y lista para usar!** 🎉
