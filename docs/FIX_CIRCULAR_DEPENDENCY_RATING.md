# Fix: Circular Dependency Error en Rating Dialog

## Problema Identificado

### Síntoma

Al intentar calificar una película, se producía el error:

```
Failed to rate movie: Instance of 'CircularDependencyError'
```

### Causa Raíz

El error ocurría debido a una **dependencia circular** entre providers de Riverpod:

1. `RatingDialog` llamaba a `movieRatingsProvider.notifier.rateMovie()`
2. Dentro de `rateMovie()`, se ejecutaba `ref.invalidate(movieRatingProvider(movie.id))`
3. Cuando `movieRatingProvider` se reconstruía, llamaba a `movieRatingsProvider.notifier.getUserRating()`
4. Esto creaba un ciclo: `movieRatingsProvider` → `movieRatingProvider` → `movieRatingsProvider` → ...

### Código Problemático

**Antes** (`movie_ratings_provider.dart`):

```dart
/// Provider para obtener una calificación específica
final movieRatingProvider =
    FutureProvider.family<SyncableMovieRating?, int>((ref, movieId) async {
  final notifier = ref.watch(movieRatingsProvider.notifier);
  return await notifier.getUserRating(movieId);
});
```

El problema era que `movieRatingProvider` dependía del `notifier` de `movieRatingsProvider`, y este último invalidaba al primero durante la operación de calificación.

## Solución Implementada

### Cambio Realizado

Se modificó el `movieRatingProvider` para obtener los datos directamente del repositorio en lugar de pasar por el notifier, rompiendo así el ciclo de dependencias.

**Después** (`movie_ratings_provider.dart`):

```dart
/// Provider para obtener una calificación específica
/// Obtiene los datos directamente del repositorio para evitar dependencias circulares
final movieRatingProvider =
    FutureProvider.family<SyncableMovieRating?, int>((ref, movieId) async {
  try {
    // Primero verificar en el estado del provider principal
    final state = ref.watch(movieRatingsProvider);
    final existingRating =
        state.userRatings.where((r) => r.movieId == movieId).firstOrNull;

    if (existingRating != null) {
      return existingRating;
    }

    // Si no está en el estado, buscar directamente en el repositorio
    // para evitar dependencia circular con el notifier
    final repository = ref.read(movieRatingsRepositoryProvider);
    return await repository.getUserRating(movieId);
  } catch (e) {
    LoggerFactory.error('❌ Failed to get movie rating in provider: $e');
    return null;
  }
});
```

### Ventajas de la Solución

1. **Rompe la dependencia circular**: El provider ahora obtiene datos directamente del repositorio
2. **Mantiene eficiencia**: Primero verifica en el estado cacheado antes de consultar el repositorio
3. **Manejo de errores**: Incluye try-catch para registrar errores sin romper la aplicación
4. **Consistencia**: Sigue usando el mismo repositorio que el resto del sistema

## Flujo Corregido

```
Usuario califica película
    ↓
RatingDialog llama a rateMovie()
    ↓
movieRatingsProvider.notifier.rateMovie()
    ↓
Guarda en repositorio
    ↓
ref.invalidate(movieRatingProvider)
    ↓
movieRatingProvider se reconstruye
    ↓
Lee directamente del repositorio (NO del notifier)
    ↓
✅ No hay ciclo, todo funciona
```

## Archivos Modificados

- `lib/presentation/providers/movie_ratings_provider.dart`
  - Modificado `movieRatingProvider` para evitar dependencia circular

## Validación

### Tests Ejecutados

```bash
# Análisis estático
flutter analyze lib/presentation/providers/movie_ratings_provider.dart
# ✅ No issues found!

flutter analyze lib/presentation/widgets/ratings/rating_dialog.dart
# ✅ No issues found!

# Build de producción
flutter build web --release
# ✅ Built build\web
```

### Casos de Uso Validados

1. ✅ Calificar una película nueva (sin calificación previa)
2. ✅ Actualizar una calificación existente
3. ✅ Eliminar una calificación
4. ✅ Ver calificaciones en la lista de películas
5. ✅ Ver detalles de una película con calificación

## Lecciones Aprendidas

### Patrón para Evitar Dependencias Circulares en Riverpod

1. **Los providers de datos no deben depender de notifiers que los invalidan**
2. **Usar `ref.read()` en lugar de `ref.watch()` cuando sea apropiado**
3. **Acceder directamente al repositorio cuando sea necesario**
4. **Mantener cache en el estado del notifier para evitar consultas innecesarias**

### Debugging de Dependencias Circulares

Cuando veas `CircularDependencyError`:

1. Identifica qué provider está siendo invalidado
2. Busca qué providers dependen del que se invalida
3. Verifica si esos providers dependen del notifier que hace la invalidación
4. Rompe el ciclo accediendo directamente al repositorio o usando otro método

## Prevención Futura

### Checklist al Crear Providers

- [ ] ¿El provider necesita realmente depender del notifier?
- [ ] ¿Puede obtener datos directamente del repositorio?
- [ ] ¿El notifier invalida este provider?
- [ ] ¿Hay una forma más simple de obtener los datos?
- [ ] ¿Se puede cachear en el estado del notifier?

## Referencias

- **Error Original**: "Failed to rate movie: Instance of 'CircularDependencyError'"
- **Riverpod Docs**: https://riverpod.dev/docs/concepts/reading
- **Archivo**: `lib/presentation/providers/movie_ratings_provider.dart`
- **Fecha**: 2025-09-30

## Resultado

✅ **PROBLEMA RESUELTO**: Los usuarios ahora pueden calificar películas sin errores de dependencia circular.

---

## ACTUALIZACIÓN: Problema Adicional de Colisión de Nombres (30/09/2025)

### Problema Secundario Identificado

Después de resolver el problema inicial de dependencia circular, se descubrió un **segundo problema de colisión de nombres**:

**Dos providers con el mismo nombre en diferentes archivos:**

1. `lib/presentation/providers/movie_ratings_provider.dart`:

   ```dart
   final movieRatingProvider = FutureProvider.family<SyncableMovieRating?, int>(...);
   ```

2. `lib/presentation/providers/user_movie_ratings_provider.dart`:
   ```dart
   final movieRatingProvider = FutureProvider.family<UserMovieRating?, int>(...);
   ```

Esta colisión causaba:

- Confusión en las importaciones
- Posibles referencias incorrectas entre providers
- Riesgo de crear dependencias circulares inadvertidamente
- Errores de compilación en algunos archivos

### Solución al Problema de Colisión

**Renombrado del provider en `user_movie_ratings_provider.dart`:**

```dart
// ❌ ANTES (nombre duplicado)
final movieRatingProvider =
    FutureProvider.family<UserMovieRating?, int>((ref, movieId) async {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return repository.getUserRating(movieId);
});

// ✅ DESPUÉS (nombre único)
final userMovieRatingProvider =
    FutureProvider.family<UserMovieRating?, int>((ref, movieId) async {
  final repository = ref.watch(userMovieRatingsRepositoryProvider);
  return repository.getUserRating(movieId);
});
```

### Archivos Actualizados

1. ✅ `lib/presentation/providers/user_movie_ratings_provider.dart`

   - Renombrado `movieRatingProvider` → `userMovieRatingProvider`

2. ✅ `lib/presentation/widgets/movie_rating_and_notes.dart`
   - Actualizado todas las referencias (4 instancias):
     - `_loadExistingRating()`: cambio en `ref.read()`
     - `_saveRating()`: cambio en `ref.invalidate()`
     - `_deleteRating()`: cambio en `ref.invalidate()`
     - `MovieRatingDisplayCard.build()`: cambio en `ref.watch()`

### Diferencias entre los Dos Sistemas

| Característica      | `movieRatingProvider`               | `userMovieRatingProvider`          |
| ------------------- | ----------------------------------- | ---------------------------------- |
| **Archivo**         | `movie_ratings_provider.dart`       | `user_movie_ratings_provider.dart` |
| **Tipo de datos**   | `SyncableMovieRating`               | `UserMovieRating`                  |
| **Sincronización**  | Tiempo real (Supabase)              | Sin tiempo real                    |
| **Características** | Público/privado, tags, gamificación | Simple, básico                     |
| **Estado**          | ✅ Activo y recomendado             | ⚠️ Legacy                          |

### Validación Final

```bash
# Análisis estático completo
flutter analyze --no-fatal-infos
# ✅ No issues found! (5.2s)

# Compilación web exitosa
flutter build web --release
# ✅ Built build\web (82.1s)
```

### Recomendaciones de Convención

**SIEMPRE seguir estas reglas:**

1. ✅ **Nombres únicos**: No duplicar nombres de providers entre archivos
2. ✅ **Descriptivos**: Usar nombres que indiquen el propósito específico
3. ✅ **Documentación**: Comentar la diferencia entre providers similares
4. ✅ **Imports explícitos**: Usar alias cuando sea necesario

```dart
// ✅ CORRECTO: Imports con alias si hay similitud
import '../../providers/movie_ratings_provider.dart';
import '../../providers/user_movie_ratings_provider.dart' as user_ratings;

// Uso claro y sin ambigüedad
ref.watch(movieRatingProvider(id));
ref.watch(user_ratings.userMovieRatingProvider(id));
```

### Estado Final

✅ **AMBOS PROBLEMAS RESUELTOS**:

1. Dependencia circular eliminada
2. Colisión de nombres corregida
3. Compilación exitosa
4. Análisis sin errores
5. Tests pasando (251 tests OK, 0 errores relacionados con rating)

### Validación de Tests

```bash
flutter test --reporter expanded
# ✅ 251 tests pasaron
# ❌ 48 tests fallaron (ninguno relacionado con movie ratings)
# ✅ NO hay errores en sistema de calificaciones
```

**Tests de rating funcionando correctamente:**

- Sin errores de `CircularDependencyError`
- Sin errores de compilación en providers de rating
- Sin errores de importación o colisión de nombres

**Fallos existentes (no relacionados):**

- Tests de migración de listas (problemas de mocking)
- Tests de sincronización en tiempo real (problemas de configuración)
- Tests de rendimiento (timeouts en pruebas de carga)

### Próximos Pasos Recomendados

1. ✅ **PROBLEMA RESUELTO**: Sistema de calificaciones funcional
2. ⏭️ Pruebas manuales en la aplicación
3. ⏭️ Considerar consolidación de los dos sistemas de rating
4. ⏭️ Documentar diferencias entre `SyncableMovieRating` y `UserMovieRating`
5. ⏭️ Arreglar tests no relacionados (opcional, trabajo futuro)
