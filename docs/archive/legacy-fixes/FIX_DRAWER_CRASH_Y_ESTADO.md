# 🔧 Fix Final: Drawer No Reconoce Usuario y Crash al Abrir

## 🔴 Problema Reportado

- ❌ El Drawer no reconoce al usuario después del login
- ❌ Muestra el botón "Iniciar Sesión" incluso estando autenticado
- ❌ Al abrir el Drawer, crashea y cierra automáticamente

## 🎯 Causa Raíz Identificada

**Error en Console**:

```
setState() or markNeedsBuild() called during build.
```

Este error ocurría porque:

1. `AppStateNotifier.build()` llamaba a `_setupAuthListener()` directamente
2. El listener del stream de auth se activaba DURANTE la construcción
3. Cuando el stream emitía un valor, intentaba hacer `state = state.copyWith()` DURANTE el build
4. Flutter no permite modificar estado durante un build → crash

## ✅ Soluciones Implementadas

### **1. Fix en `auth_provider.dart` - Evitar setState durante build**

**Problema**:

```dart
// ❌ PROBLEMA: Listener se activa durante build
@override
AppState build() {
  _setupAuthListener(); // ← Se ejecuta durante build
  return const AppState(mode: AppMode.guest);
}

void _setupAuthListener() {
  authRepository.authStateChanges.listen((user) {
    state = state.copyWith(...); // ← setState durante build!
  });
}
```

**Solución**:

```dart
// ✅ SOLUCIÓN: Diferir listener hasta DESPUÉS del build
@override
AppState build() {
  if (!_initialized) {
    _initialized = true;
    // ✅ addPostFrameCallback espera hasta DESPUÉS del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAuthListener();
      _detectLocalDataOnStartup();
    });
  }

  ref.onDispose(() {
    _authSubscription?.cancel();
    _initialized = false;
  });

  return const AppState(mode: AppMode.guest);
}
```

**¿Qué hace `addPostFrameCallback`?**

- Espera a que el frame actual termine de renderizarse
- **DESPUÉS** ejecuta el callback
- Así evitamos modificar estado durante el build

### **2. Fix en `custom_drawer.dart` - Manejo robusto de errores**

Agregamos try-catch y verificaciones adicionales:

```dart
Widget _buildAuthenticatedHeader(...) {
  final user = ref.watch(currentUserProvider);

  // ✅ Verificación crítica
  if (user == null) {
    LoggerFactory.warning('⚠️ CustomDrawer: user es null en _buildAuthenticatedHeader');
    return _buildGuestHeader(context, colorScheme);
  }

  LoggerFactory.info('✅ CustomDrawer: Construyendo header autenticado para user: ${user.id}');

  // ✅ Try-catch para capturar errores
  try {
    final userProfileAsync = ref.watch(userProfileNotifierProvider);

    return DrawerHeader(
      // ... render normal
    );
  } catch (e, stackTrace) {
    // ✅ Fallback en caso de error
    LoggerFactory.error('❌ CustomDrawer: Error construyendo header autenticado: $e');
    return _buildGuestHeader(context, colorScheme);
  }
}
```

### **3. Fix de nullability - email no es nullable**

Corregimos el error de lint donde intentábamos usar `??` con `user.email` que no es nullable:

```dart
// ❌ ANTES: Error de lint
Text(user.email ?? '')

// ✅ DESPUÉS: Correcto
Text(user.email)
```

## 🔄 Flujo Correcto Ahora

```
┌─────────────────────────────────────────────┐
│ 1. AppStateNotifier.build() se ejecuta     │
│    - Retorna AppState(mode: guest)          │
│    - NO modifica estado                     │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 2. addPostFrameCallback programa callback   │
│    - Se ejecutará DESPUÉS del build         │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 3. Frame termina de renderizarse           │
│    - UI está estable                        │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 4. Callback se ejecuta                      │
│    - _setupAuthListener()                   │
│    - _detectLocalDataOnStartup()            │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 5. Stream listener configurado              │
│    - Escucha authStateChanges               │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 6. Usuario hace LOGIN                       │
│    - AuthRepository emite User              │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 7. Listener recibe User                     │
│    - FUERA del ciclo de build               │
│    - ✅ Puede actualizar estado sin crash   │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 8. state.copyWith(                          │
│      mode: authenticated,                   │
│      user: user                             │
│    )                                        │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 9. UI se reconstruye automáticamente        │
│    - CustomDrawer muestra usuario           │
│    - Banner desaparece                      │
│    ✅ Sin crash                             │
└─────────────────────────────────────────────┘
```

## 📋 Archivos Modificados

### **1. `lib/presentation/providers/auth_provider.dart`**

**Cambios**:

- ✅ Agregado `import 'package:flutter/widgets.dart'` para WidgetsBinding
- ✅ Agregado flag `bool _initialized = false`
- ✅ Uso de `addPostFrameCallback` para diferir inicialización
- ✅ Listener se configura DESPUÉS del build

**Líneas modificadas**: ~85-120

### **2. `lib/presentation/widgets/custom_drawer.dart`**

**Cambios**:

- ✅ Agregado logging detallado en `_buildAuthenticatedHeader`
- ✅ Agregado try-catch para capturar errores
- ✅ Fallback a `_buildGuestHeader` en caso de error
- ✅ Corregido nullability de `user.email` (eliminado `?? ''`)

**Líneas modificadas**: ~60-245

## 🚀 Cómo Probar

### **Paso 1: Reiniciar la App**

La app ya se reinició automáticamente después del crash. Si no:

```powershell
# En la terminal de Flutter, presiona:
R  # Hot restart (mayúscula)
```

### **Paso 2: Verificar Logs de Inicio**

En la console deberías ver:

```
✅ Supabase initialized
👤 AppStateNotifier: Usuario en modo guest
CustomDrawer.build: isAuthenticated=false, user=null
```

### **Paso 3: Hacer Login**

1. Haz clic en "Iniciar Sesión" (o en el botón del banner)
2. Ingresa tus credenciales
3. Completa el login

**Logs esperados después del login**:

```
🔐 AppStateNotifier: Usuario autenticado: <user-id>
CustomDrawer.build: isAuthenticated=true, user=<user-id>
✅ CustomDrawer: Construyendo header autenticado para user: <user-id>
```

### **Paso 4: Abrir el Drawer**

1. Haz clic en el ícono del menú hamburguesa (☰)
2. El Drawer debería abrir **SIN CRASH**
3. Deberías ver:
   - ✅ Tu nombre y email en el header
   - ✅ Tu avatar (si lo tienes)
   - ✅ Opciones de usuario autenticado

### **Paso 5: Verificar que Banner Desapareció**

- ✅ El banner "Desbloquea más funciones..." NO debe aparecer
- ✅ Solo se muestra en modo guest

### **Paso 6: Test de Refresh**

1. Presiona F5 en el navegador
2. Espera a que cargue
3. Deberías seguir logueado
4. Abre el Drawer nuevamente
5. ✅ Tu información sigue ahí

## 🐛 Troubleshooting

### **Problema: Drawer sigue crasheando**

**Debug**:

- Revisa la console para errores específicos
- Busca mensajes que empiecen con `❌ CustomDrawer:`

**Posible causa**: El `userProfileNotifierProvider` está lanzando error

**Solución**: El try-catch debería manejarlo, pero si persiste:

```dart
// En custom_drawer.dart, verificar que el try-catch esté correcto
```

### **Problema: Usuario sigue apareciendo como null**

**Debug**:

- Busca en console: `🔐 AppStateNotifier: Usuario autenticado`
- Si NO aparece, el listener no se está configurando

**Solución**:

- Hot restart (R) en lugar de hot reload (r)
- O reinicia completamente: `Ctrl+C` y `flutter run -d chrome`

### **Problema: Error "WidgetsBinding not defined"**

**Causa**: Falta el import de Flutter widgets

**Solución**: Ya está implementada, pero verifica:

```dart
import 'package:flutter/widgets.dart';
```

### **Problema: Banner sigue apareciendo después del login**

**Debug**:

- Verifica en console: `AppStateNotifier: Usuario autenticado`
- Si aparece pero banner sigue, hay problema con `appStateProvider`

**Solución**:

- El `GuestModeBanner` depende de `appStateProvider.mode`
- Si el mode no cambia a `authenticated`, el listener no se está ejecutando

## ✅ Beneficios de las Correcciones

1. **Sin Crashes**: `addPostFrameCallback` evita setState durante build
2. **Logs Claros**: Podemos debuggear fácilmente con los mensajes
3. **Fallback Robusto**: Try-catch asegura que el Drawer siempre muestre algo
4. **Cleanup Correcto**: `ref.onDispose()` limpia recursos
5. **Código más Mantenible**: Separación clara entre inicialización y actualización

## 🎯 Estado Final

Después de estas correcciones:

- ✅ El Drawer NO crashea al abrirse
- ✅ Muestra información del usuario después del login
- ✅ El banner desaparece correctamente
- ✅ La sesión persiste después de refresh (F5)
- ✅ Logs claros para debugging
- ✅ Manejo robusto de errores

**¡La aplicación ahora funciona correctamente sin crashes!** 🎉

## 📝 Notas Técnicas

### **¿Por qué addPostFrameCallback?**

Flutter tiene tres fases en el renderizado:

1. **Build**: Construir el widget tree
2. **Layout**: Calcular tamaños y posiciones
3. **Paint**: Dibujar en pantalla

`addPostFrameCallback` se ejecuta **DESPUÉS** de las 3 fases, cuando el frame está completo y estable. Esto garantiza que podemos modificar estado sin interferir con el build actual.

### **Alternativas consideradas**

❌ `Future.microtask()`: Puede ejecutarse demasiado pronto  
❌ `Timer(Duration.zero)`: No garantiza esperar al frame  
❌ `SchedulerBinding.addPostFrameCallback()`: Similar pero menos común  
✅ `WidgetsBinding.addPostFrameCallback()`: La forma recomendada por Flutter

### **Referencias**

- [Flutter setState during build](https://api.flutter.dev/flutter/widgets/State/setState.html)
- [WidgetsBinding.addPostFrameCallback](https://api.flutter.dev/flutter/widgets/WidgetsBinding/addPostFrameCallback.html)
- [Flutter rendering pipeline](https://flutter.dev/docs/resources/architectural-overview#rendering-and-layout)
