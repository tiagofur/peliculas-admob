# Fix Real-Time Sync - October 1, 2025

## 🐛 Problema Identificado

El sistema de sincronización en tiempo real para **Watched Movies** y **Favorites** no estaba funcionando correctamente después de la actualización del sistema de ratings unificado.

### Causa Raíz

En `base_hybrid_repository.dart`, el método `_setupRealtimeSubscription()` tenía dos problemas críticos:

1. **Filtro incorrecto**: El filtro `user_id=eq.$userId` estaba en el nombre del canal, pero NO se aplicaba realmente a la suscripción de Postgres
2. **Manejo de DELETE incorrecto**: El evento DELETE intentaba usar `payload.oldRecord['movie_id']` sin verificar si existía

### Código Problemático (ANTES)

```dart
void _setupRealtimeSubscription() {
  if (userId == 'anonymous_user') return;

  _realtimeChannel = Supabase.instance.client
      .channel('public:$tableName:user_id=eq.$userId'); // ❌ Filtro no funciona aquí
  _realtimeChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tableName,
        // ❌ Falta el parámetro 'filter' real
        callback: (payload) {
          _handleRealtimePayload(payload);
        },
      )
      .subscribe();
}

void _handleRealtimePayload(PostgresChangePayload payload) {
  switch (payload.eventType) {
    case PostgresChangeEvent.insert:
    case PostgresChangeEvent.update:
      // Funciona OK
      break;
    case PostgresChangeEvent.delete:
      final movieId = payload.oldRecord['movie_id']?.toString(); // ❌ Puede ser null
      if (movieId != null) {
        removeFromLocal(movieId);
      }
      break;
  }
}
```

## ✅ Solución Implementada

### 1. Filtro Correcto con `PostgresChangeFilter`

```dart
void _setupRealtimeSubscription() {
  if (userId == 'anonymous_user') return;

  try {
    // ✅ Canal único identificable
    _realtimeChannel = Supabase.instance.client
        .channel('$entityType-$userId');

    // ✅ Filtro correcto usando PostgresChangeFilter
    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tableName,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleRealtimePayload(payload);
          },
        )
        .subscribe();

    LoggerFactory.info('⚡️ Realtime subscription setup for $tableName (user: $userId)');
  } catch (e) {
    LoggerFactory.error('❌ Failed to setup realtime subscription: $e');
  }
}
```

### 2. Mejor Manejo de Eventos

```dart
void _handleRealtimePayload(PostgresChangePayload payload) {
  final eventType = payload.eventType;
  LoggerFactory.info('⚡️ Realtime event received for $entityType: $eventType');

  try {
    switch (eventType) {
      case PostgresChangeEvent.insert:
        final entity = deserializeFromRemote(payload.newRecord);
        saveToLocal(entity);
        _emitEvent(RepositoryEventType.itemAdded, 'Realtime item added', entity: entity);
        LoggerFactory.info('✅ Realtime INSERT processed: ${entity.id}');
        break;

      case PostgresChangeEvent.update:
        final entity = deserializeFromRemote(payload.newRecord);
        saveToLocal(entity);
        _emitEvent(RepositoryEventType.itemUpdated, 'Realtime item updated', entity: entity);
        LoggerFactory.info('✅ Realtime UPDATE processed: ${entity.id}');
        break;

      case PostgresChangeEvent.delete:
        // ✅ Intenta múltiples campos para obtener ID
        final entityId = payload.oldRecord['id']?.toString() ??
                        payload.oldRecord['movie_id']?.toString();

        if (entityId != null) {
          removeFromLocal(entityId);
          _emitEvent(RepositoryEventType.itemRemoved, 'Realtime item removed', entityId: entityId);
          LoggerFactory.info('✅ Realtime DELETE processed: $entityId');
        } else {
          LoggerFactory.warning('⚠️ Cannot process DELETE - missing ID in oldRecord');
        }
        break;

      case PostgresChangeEvent.all:
        LoggerFactory.debug('ℹ️ Received "all" event type - ignoring');
        break;
    }
  } catch (e, stackTrace) {
    LoggerFactory.error('❌ Error handling realtime payload for $entityType: $e');
    LoggerFactory.error('Stack trace: $stackTrace');
  }
}
```

## 🔧 Cambios Técnicos

### Archivo Modificado

- `lib/infrastructure/repositories/base_hybrid_repository.dart`

### Métodos Actualizados

1. `_setupRealtimeSubscription()` - Líneas ~420
2. `_handleRealtimePayload()` - Líneas ~440

### Mejoras Implementadas

#### 1. PostgresChangeFilter

- **Antes**: Filtro en nombre del canal (no funcional)
- **Ahora**: Filtro usando `PostgresChangeFilter` con `type: PostgresChangeFilterType.eq`
- **Beneficio**: Solo recibe eventos del usuario actual, reduce tráfico y procesamiento

#### 2. Separación de INSERT/UPDATE

- **Antes**: Ambos casos manejados juntos
- **Ahora**: Casos separados con logging específico
- **Beneficio**: Mejor debugging y trazabilidad de eventos

#### 3. Manejo Robusto de DELETE

- **Antes**: Solo verificaba `movie_id`
- **Ahora**: Verifica `id` primero, luego `movie_id` como fallback
- **Beneficio**: Funciona con diferentes estructuras de tablas (user_watched, user_favorites)

#### 4. Try-Catch en Handlers

- **Antes**: Sin manejo de errores
- **Ahora**: Try-catch completo con stack trace
- **Beneficio**: La app no crashea si hay errores en realtime

#### 5. Logging Mejorado

- **Antes**: Logging mínimo
- **Ahora**: Logging detallado de cada operación
- **Beneficio**: Fácil debugging en producción

## 📊 Tablas Afectadas

Este fix aplica a todas las tablas que usan `BaseHybridRepository`:

- ✅ `user_watched` - Películas vistas
- ✅ `user_favorites` - Películas favoritas
- ✅ `user_movie_ratings` - Calificaciones (ya tiene su propio sistema en UnifiedRatingService)

## 🧪 Validación

### Escenario 1: Multi-Device Sync - Watched Movies

**Dispositivo A:**

```dart
// Usuario marca película como vista
await watchedProvider.markAsWatched(movie);
```

**Dispositivo B (Real-Time):**

- ✅ Debe recibir evento INSERT
- ✅ Debe actualizar UI automáticamente
- ✅ Película aparece en lista de vistas sin refresh manual

### Escenario 2: Multi-Device Sync - Favorites

**Dispositivo A:**

```dart
// Usuario agrega película a favoritos
await favoritesProvider.toggleFavorite(movie);
```

**Dispositivo B (Real-Time):**

- ✅ Debe recibir evento INSERT
- ✅ Debe actualizar UI automáticamente
- ✅ Película aparece en favoritos sin refresh manual

### Escenario 3: Delete Sync

**Dispositivo A:**

```dart
// Usuario elimina de favoritos
await favoritesProvider.toggleFavorite(movie); // Segunda llamada = remove
```

**Dispositivo B (Real-Time):**

- ✅ Debe recibir evento DELETE
- ✅ Debe eliminar de UI automáticamente
- ✅ Película desaparece de favoritos sin refresh manual

## 📝 Logs Esperados

### Al Inicializar Repositorio

```
✅ BaseHybridRepository<watched_movie> initialized
⚡️ Realtime subscription setup for user_watched (user: abc123, channel: watched_movie-abc123)
```

### Al Recibir Evento INSERT (otro dispositivo agrega favorito)

```
⚡️ Realtime event received for favorite: PostgresChangeEvent.insert
✅ Realtime INSERT processed: abc123_12345
```

### Al Recibir Evento DELETE (otro dispositivo elimina de watched)

```
⚡️ Realtime event received for watched_movie: PostgresChangeEvent.delete
✅ Realtime DELETE processed: abc123_67890
```

## 🚀 Testing Manual

### Paso 1: Abrir App en 2 Dispositivos/Tabs

```bash
# Terminal 1
flutter run -d chrome --web-port 8080

# Terminal 2
flutter run -d chrome --web-port 8081
```

### Paso 2: Login con Mismo Usuario

- En ambos tabs, login con las mismas credenciales

### Paso 3: Test Watched Movies

1. **Tab 1**: Ve a una película y márcala como vista
2. **Tab 2**: Espera 1-3 segundos
3. **Tab 2**: Verifica que la película aparece en "Watched" sin refresh

### Paso 4: Test Favorites

1. **Tab 1**: Agrega una película a favoritos
2. **Tab 2**: Espera 1-3 segundos
3. **Tab 2**: Verifica que la película aparece en "Favorites" sin refresh

### Paso 5: Test Delete

1. **Tab 1**: Elimina un favorito
2. **Tab 2**: Espera 1-3 segundos
3. **Tab 2**: Verifica que el favorito desaparece sin refresh

## 🔐 Seguridad

### Row Level Security (RLS)

El filtro `user_id=eq.$userId` garantiza que:

- ✅ Solo recibes eventos de TUS datos
- ✅ No puedes ver cambios de otros usuarios
- ✅ Cumple con políticas de privacidad

### Supabase RLS Policies

Asegúrate de que las tablas tienen estas políticas:

```sql
-- user_watched
CREATE POLICY "Users can view their own watched movies"
  ON user_watched FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert their own watched movies"
  ON user_watched FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can delete their own watched movies"
  ON user_watched FOR DELETE
  USING (auth.uid()::text = user_id);

-- user_favorites (similar)
CREATE POLICY "Users can view their own favorites"
  ON user_favorites FOR SELECT
  USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert their own favorites"
  ON user_favorites FOR INSERT
  WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can delete their own favorites"
  ON user_favorites FOR DELETE
  USING (auth.uid()::text = user_id);
```

## ⚠️ Notas Importantes

### 1. Usuario Anónimo

El realtime sync NO se activa para `anonymous_user`:

```dart
if (userId == 'anonymous_user') return;
```

Esto es correcto porque los usuarios anónimos no tienen datos en Supabase.

### 2. Latencia Esperada

- **Típica**: 100-500ms
- **Buena conexión**: < 200ms
- **Mala conexión**: 500-2000ms
- **Timeout**: Si > 5 segundos, verificar conexión

### 3. Reconexión Automática

Supabase maneja reconexión automáticamente:

- Si pierde conexión, intenta reconectar
- Cuando reconecta, recibe eventos perdidos
- No necesitas código adicional

### 4. Compatibilidad con UnifiedRatingService

El `UnifiedRatingService` tiene su propio sistema de realtime que SÍ funciona bien. Este fix solo afecta a Watched y Favorites.

## 📚 Referencias

- [Supabase Realtime Docs](https://supabase.com/docs/guides/realtime)
- [PostgresChangeFilter API](https://supabase.com/docs/reference/dart/subscribe)
- [Flutter Riverpod State Management](https://riverpod.dev/)

## ✅ Checklist de Validación

- [x] Código corregido en `base_hybrid_repository.dart`
- [x] Zero errores de compilación (`get_errors` passed)
- [ ] Test manual con 2 dispositivos - Watched Movies
- [ ] Test manual con 2 dispositivos - Favorites
- [ ] Test de DELETE en ambas tablas
- [ ] Verificar logs en consola muestran eventos realtime
- [ ] Verificar no hay eventos de otros usuarios

## 🎯 Resultado Esperado

Después de este fix:

- ✅ Watched movies se sincronizan en tiempo real entre dispositivos
- ✅ Favorites se sincronizan en tiempo real entre dispositivos
- ✅ Los eventos DELETE se manejan correctamente
- ✅ Solo recibes tus propios eventos (seguridad)
- ✅ Mejor logging para debugging

---

**Creado**: October 1, 2025  
**Autor**: AI Assistant  
**Versión**: 1.0  
**Estado**: ✅ Implementado - Pendiente Testing Manual
