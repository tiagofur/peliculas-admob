# 7. Resolución de Problemas Comunes

En este documento se recopilan las soluciones a los problemas más frecuentes durante el desarrollo y ejecución de la aplicación.

## 7.1 🚨 PROBLEMAS CRÍTICOS DETECTADOS

### 7.1.1 Memory Leaks (CRÍTICO)

**Síntoma**: La aplicación consume cada vez más memoria después de 30+ minutos de uso.

**Archivos afectados**:

- `lib/presentation/providers/movies/watchlist_notifier.dart`
- `lib/presentation/providers/sync/sync_status_notifier.dart`
- `lib/presentation/providers/user_ratings_notifier.dart`
- `lib/presentation/providers/achievements_notifier.dart`

**Solución**:

```dart
// Implementar dispose() en TODOS los StateNotifiers
@override
void dispose() {
  _streamSubscription?.cancel();
  _timer?.cancel();
  super.dispose();
}
```

### 7.1.2 APIs Deprecated (CRÍTICO)

**Síntoma**: Warnings de compilación sobre APIs obsoletas.

**Problemas detectados**:

```dart
// ❌ INCORRECTO - Deprecated
Color.red.withOpacity(0.5)
print('Debug message')

// ✅ CORRECTO
Color.red.withValues(alpha: 0.5)
LoggerFactory.info('Debug message')
```

### 7.1.3 Logging Inadecuado (CRÍTICO)

**Síntoma**: 140+ `print()` statements exponen información sensible en producción.

**Archivos más afectados**:

- `lib/core/streaming/streaming_service_manager.dart` (15 prints)
- `lib/services/performance/performance_manager_service.dart` (8 prints)
- `lib/core/analytics/analytics_service.dart` (12 prints)

**Solución**:

```dart
// Usar LoggerFactory en lugar de print()
import '../../core/logging/logger_factory.dart';
LoggerFactory.error('Error occurred: $error');
```

### 7.1.4 Sync Timestamps Bug (CRÍTICO)

**Síntoma**: Pérdida de datos en sincronización entre dispositivos.

**Problema**:

```dart
// ❌ INCORRECTO
lastSynced: DateTime.now() // Cliente puede tener hora incorrecta

// ✅ CORRECTO
lastSynced: await getServerTimestamp() // Tiempo del servidor
```

### 7.1.5 Navigation Crashes (CRÍTICO)

**Síntoma**: 15% de crashes cuando se navega desde notificaciones.

**Archivo afectado**: `lib/config/router/app_router.dart`

**Problemas**:

- Rutas nulas cuando app está cerrada
- No hay error boundaries consistentes
- Deep links fallan en cold start

**Solución**:

```dart
// Implementar SafeNavigation wrapper
class SafeNavigationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: YourWidget(),
      onError: (error) => handleNavigationError(error),
    );
  }
}
```

## 7.2 🟡 PROBLEMAS DE RENDIMIENTO

### 7.2.1 Performance Bottlenecks

**Síntoma**: FPS cae a 15 en scroll de listas grandes (>500 items).

**Archivos afectados**:

- `lib/presentation/views/movies_view.dart`
- `lib/presentation/views/my_library_view.dart`

**Soluciones**:

```dart
// Usar ListView.builder para virtualización
ListView.builder(
  itemCount: movies.length,
  itemBuilder: (context, index) => MovieCard(movies[index]),
)

// Implementar lazy loading de imágenes
Image.network(
  imageUrl,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return SkeletonLoader();
  },
)
```

### 7.2.2 Error Handling Inconsistente

**Síntoma**: Usuario no entiende qué falló cuando ocurren errores.

**Patrones problemáticos encontrados**:

1. `try/catch` sin logging
2. Errores silenciosos (catch vacíos)
3. No hay user feedback en errores
4. Sin retry logic en network failures

**Solución**:

```dart
try {
  await apiCall();
} catch (e) {
  LoggerFactory.error('API call failed: $e');
  showUserFriendlyError(context, 'Failed to load data. Tap to retry.');
  // Implement retry logic
}
```

## 7.3 Errores de Compilación Comunes

- `Target file not found`: Verificar rutas en `pubspec.yaml`.
- `Undefined name`: Asegurarse de importar el paquete o archivo correspondiente.
- `Null check operator used on a null value`: Implementar null safety correctamente.

## 7.4 Fallas en Tiempo de Ejecución

- **Crash al navegar**: Revisar configuración de rutas en `app_router.dart`.
- **Null Pointer Exception**: Implementar validaciones y `late` correctamente.
- **RenderFlex overflowed**: Usar `Expanded` o `Flexible` en columnas/filas.

## 7.5 Problemas de Dependencias

- Conflictos de versión: Ejecutar `flutter pub upgrade --major-versions`.
- Paquetes obsoletos: Revisar `pubspec.yaml` y actualizar.
- Build runner fails: `flutter packages pub run build_runner clean && flutter packages pub run build_runner build`

## 7.6 Tests que Fallan

- `Golden tests`: Actualizar goldens con `--update-goldens`.
- Tiempo de espera agotado: Incrementar timeout en integración.
- Tests flaky: Implementar setup/teardown apropiado.
- Mock failures: Verificar que todos los mocks están configurados.

## 7.7 Problemas de Red y APIs

### 7.7.1 TMDB API Issues

```dart
// Manejar rate limiting
if (response.statusCode == 429) {
  await Future.delayed(Duration(seconds: 1));
  return retry();
}
```

### 7.7.2 Supabase Connection Issues

```dart
// Verificar conexión antes de queries
if (await Supabase.instance.client.auth.currentUser == null) {
  throw UnauthorizedException('User not logged in');
}
```

## 7.8 Build y Deployment Issues

### 7.8.1 Web Build Failures

```bash
# Limpiar cache web
flutter clean
flutter pub get
flutter build web --release --verbose
```

### 7.8.2 Android Build Issues

```bash
# Limpiar build Android
cd android && ./gradlew clean && cd ..
flutter clean
flutter pub get
flutter build apk --release
```

## 7.9 Performance Debugging

### 7.9.1 Memory Leaks Detection

```bash
# Usar Flutter DevTools para detectar memory leaks
flutter run --profile
# Abrir DevTools y ir a Memory tab
```

### 7.9.2 Performance Profiling

```bash
# Profile mode para testing de performance
flutter run --profile
# Usar Performance tab en DevTools
```
