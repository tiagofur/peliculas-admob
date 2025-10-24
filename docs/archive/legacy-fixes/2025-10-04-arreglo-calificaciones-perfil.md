# Arreglo: Calificaciones no Visibles en Perfil

**Fecha**: 2025-10-04  
**Problema**: Las calificaciones del usuario no aparecían en la tab "Valoraciones" del ProfileScreen  
**Solución**: Migrar ProfileScreen de `movie_ratings_provider` a `unified_ratings_provider`

---

## Problema Reportado

El usuario reportó:

> "ahora en Profile puedes ver que tenemos mis calificaciones, pero no me estan apareciendo mis calificaciones, y al parecer tengo 3 hechas."

**Síntomas**:

- La tab "Valoraciones" en el perfil existe
- Las estadísticas muestran que hay 3 calificaciones
- Pero la lista de calificaciones está vacía

---

## Diagnóstico

### Múltiples Providers de Calificaciones

Se encontraron **3 definiciones diferentes** de `recentRatingsProvider`:

1. **`movie_ratings_provider.dart`**:

   ```dart
   final recentRatingsProvider = FutureProvider<List<SyncableMovieRating>>((ref) async {
     final notifier = ref.read(movieRatingsProvider.notifier);
     return await notifier.getRecentRatings(days: 30);
   });
   ```

   - ❌ Usa `HybridMovieRatingsRepository`
   - ❌ Solo lee desde local (Isar/Hive)
   - ❌ No sincroniza automáticamente con Supabase

2. **`unified_ratings_provider.dart`**:

   ```dart
   final recentRatingsProvider = Provider<List<SyncableMovieRating>>((ref) {
     final state = ref.watch(unifiedRatingsProvider);
     final allRatings = state.ratings.values.toList();
     allRatings.sort((a, b) => b.ratedAt.compareTo(a.ratedAt));
     return allRatings;
   });
   ```

   - ✅ Usa `UnifiedRatingService`
   - ✅ Sincronización real-time con Supabase
   - ✅ Stream de cambios automático

3. **`user_movie_ratings_provider.dart`**:
   ```dart
   final recentRatingsProvider = FutureProvider.family<List<UserMovieRating>, int>((ref, limit) async {
     final repository = ref.watch(userMovieRatingsRepositoryProvider);
     return repository.getRecentRatings(limit: limit);
   });
   ```
   - ❌ Usa tipo diferente (`UserMovieRating` vs `SyncableMovieRating`)
   - ❌ No compatible con ProfileScreen

### Causa Raíz

El `ProfileScreen` estaba importando desde `movie_ratings_provider.dart`:

```dart
import '../../providers/movie_ratings_provider.dart';
```

Este provider usaba `HybridMovieRatingsRepository.getUserRatings()` que **solo lee desde local**:

```dart
@override
Future<List<SyncableMovieRating>> getUserRatings({
  int limit = 50,
  int offset = 0,
}) async {
  try {
    return await _localDatasource.loadUserRatings(
      userId: userId,
      limit: limit,
      offset: offset,
    );
  } catch (e) {
    LoggerFactory.error('❌ Failed to get user ratings: $e');
    return [];
  }
}
```

**Problema**: Si las calificaciones están en Supabase pero NO se han sincronizado a local, no aparecen.

---

## Solución Implementada

### 1. Cambiar Import en ProfileScreen

**Antes**:

```dart
import '../../providers/movie_ratings_provider.dart';
```

**Después**:

```dart
import '../../providers/unified_ratings_provider.dart';
```

### 2. Actualizar `_buildFullRatingsSection`

**Antes** (usando FutureProvider con `.when()`):

```dart
final recentRatingsAsync = ref.watch(recentRatingsProvider);
final ratingStats = ref.watch(userRatingStatsProvider);

// ...

recentRatingsAsync.when(
  data: (ratings) {
    if (ratings.isEmpty) {
      return _buildEmptyRatingsState(theme);
    }
    return _buildRatingsListWithSearch(theme, ratings);
  },
  loading: () => const Center(/* ... */),
  error: (error, stack) => _buildRatingsErrorState(theme, ref),
);
```

**Después** (usando Provider síncrono):

```dart
// Usar unified_ratings_provider que tiene sincronización real-time
final recentRatings = ref.watch(recentRatingsProvider);
final ratingStats = ref.watch(ratingsStatsProvider);
final unifiedState = ref.watch(unifiedRatingsProvider);

// Mostrar loading si está inicializando
if (unifiedState.isLoading && recentRatings.isEmpty) {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

// Mostrar error si hay
if (unifiedState.error != null) {
  return _buildRatingsErrorState(theme, ref);
}

// ...

// Lista de valoraciones
if (recentRatings.isEmpty)
  _buildEmptyRatingsState(theme)
else
  _buildRatingsListWithSearch(theme, recentRatings),
```

---

## Ventajas de la Solución

### 1. **Sincronización Real-Time**

- El `UnifiedRatingService` carga calificaciones desde Supabase automáticamente
- Stream de cambios en tiempo real (cuando el usuario califica en otro dispositivo, se actualiza)

### 2. **Fuente Única de Verdad**

- Un solo servicio (`UnifiedRatingService`) gestiona todas las calificaciones
- No hay duplicación de lógica de carga

### 3. **Mejor Experiencia de Usuario**

- Las calificaciones aparecen inmediatamente después de cargar desde Supabase
- No requiere sincronización manual
- Estados de carga y error mejor manejados

### 4. **Código Más Simple**

- Provider síncrono es más fácil de usar que FutureProvider
- Menos estados intermedios (loading/data/error)

---

## Flujo de Inicialización

```
Usuario abre ProfileScreen
    ↓
ProfileScreen llama ref.watch(recentRatingsProvider)
    ↓
recentRatingsProvider depende de unifiedRatingsProvider
    ↓
unifiedRatingsProvider build() llama _initialize()
    ↓
_initialize() llama UnifiedRatingService.instance.initialize()
    ↓
UnifiedRatingService carga calificaciones desde Supabase
    ↓
UnifiedRatingService configura stream real-time
    ↓
Stream notifica a unifiedRatingsProvider
    ↓
recentRatingsProvider se actualiza automáticamente
    ↓
ProfileScreen muestra las 3 calificaciones
```

---

## Testing Sugerido

1. **Usuario con calificaciones en Supabase**:

   - ✅ Abrir perfil
   - ✅ Ir a tab "Valoraciones"
   - ✅ Verificar que las 3 calificaciones aparecen
   - ✅ Verificar estadísticas (Total, Promedio, etc.)

2. **Usuario sin calificaciones**:

   - ✅ Abrir perfil
   - ✅ Ir a tab "Valoraciones"
   - ✅ Verificar mensaje "Aún no has valorado ninguna película"

3. **Calificación en tiempo real**:
   - ✅ Abrir perfil en tab "Valoraciones"
   - ✅ Calificar una película desde otra pantalla
   - ✅ Volver a tab "Valoraciones"
   - ✅ Verificar que la nueva calificación aparece automáticamente

---

## Archivos Modificados

- ✅ `lib/presentation/screens/profile/profile_screen.dart` - Migrado a unified_ratings_provider

---

## Verificación

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings lib/presentation/screens/profile/profile_screen.dart
# Resultado: No issues found! ✅
```

---

## Próximos Pasos (Opcional)

### Deprecar Providers Antiguos

Considerar deprecar o eliminar:

- `movie_ratings_provider.dart` si ya no se usa en otras partes
- `user_movie_ratings_provider.dart` si es redundante

### Migrar Otras Pantallas

Si otras pantallas usan `movie_ratings_provider`, considerar migrarlas también a `unified_ratings_provider` para:

- Consistencia
- Mejor rendimiento
- Sincronización real-time

---

**Conclusión**: El ProfileScreen ahora muestra correctamente las calificaciones del usuario gracias a la migración al `unified_ratings_provider` que tiene sincronización real-time con Supabase. Las 3 calificaciones del usuario deberían aparecer inmediatamente. 🎉
