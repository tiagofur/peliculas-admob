# Estrategia de Migración Híbrida TMDB → Trakt.tv

## 1. Resumen Ejecutivo

Estrategia de migración gradual que preserva datos existentes de TMDB mientras migra progresivamente a Trakt.tv mediante un sistema de doble fuente de datos con priorización inteligente.

**Ventajas clave:**
- ✅ Preserva 100% de datos existentes
- ✅ Migración sin interrupciones
- ✅ Rollback instantáneo si es necesario
- ✅ Aprovecha ventajas de Trakt.tv gradualmente

## 2. Arquitectura de Datos Híbrida

### 2.1 Esquema de Base de Datos Extendido

```sql
-- Extensión de tablas existentes
ALTER TABLE user_favorites ADD COLUMN trakt_id INTEGER;
ALTER TABLE user_watched_movies ADD COLUMN trakt_id INTEGER;
ALTER TABLE user_list_items ADD COLUMN trakt_id INTEGER;

-- Índices para optimización
CREATE INDEX idx_favorites_trakt_id ON user_favorites(trakt_id);
CREATE INDEX idx_watched_trakt_id ON user_watched_movies(trakt_id);
CREATE INDEX idx_list_items_trakt_id ON user_list_items(trakt_id);

-- Tabla de mapeo para conversiones
CREATE TABLE movie_id_mapping (
    id SERIAL PRIMARY KEY,
    tmdb_id INTEGER NOT NULL,
    trakt_id INTEGER,
    imdb_id VARCHAR(20),
    title VARCHAR(500),
    year INTEGER,
    last_updated TIMESTAMP DEFAULT NOW(),
    mapping_confidence DECIMAL(3,2) DEFAULT 1.0,
    UNIQUE(tmdb_id)
);
```

### 2.2 Modelos de Datos Actualizados

```dart
// sync_models.dart - Extensiones
class SyncableFavorite {
  final String id;
  final String userId;
  final int movieId;        // TMDB ID (existente)
  final int? traktId;       // Nuevo: Trakt ID
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  
  // Método para determinar fuente preferida
  MovieDataSource get preferredSource => 
    traktId != null ? MovieDataSource.trakt : MovieDataSource.tmdb;
}

class SyncableWatchedMovie {
  final String id;
  final String userId;
  final int movieId;        // TMDB ID (existente)
  final int? traktId;       // Nuevo: Trakt ID
  final DateTime watchedAt;
  final DateTime updatedAt;
  final bool isDeleted;
}

enum MovieDataSource { tmdb, trakt }
```

## 3. Servicios de Migración

### 3.1 Servicio de Mapeo de IDs

```dart
class MovieIdMappingService {
  final TraktApiService _traktApi;
  final TmdbApiService _tmdbApi;
  final SupabaseClient _supabase;
  
  // Buscar equivalencia Trakt para un TMDB ID
  Future<int?> findTraktIdForTmdb(int tmdbId) async {
    try {
      // 1. Verificar caché local
      final cached = await _getCachedMapping(tmdbId);
      if (cached != null) return cached.traktId;
      
      // 2. Obtener detalles de TMDB
      final tmdbMovie = await _tmdbApi.getMovieDetails(tmdbId);
      if (tmdbMovie.imdbId == null) return null;
      
      // 3. Buscar en Trakt por IMDB ID
      final traktMovie = await _traktApi.searchByImdbId(tmdbMovie.imdbId!);
      if (traktMovie == null) return null;
      
      // 4. Guardar mapeo para futuras consultas
      await _saveMapping(tmdbId, traktMovie.ids.trakt, tmdbMovie.imdbId!);
      
      return traktMovie.ids.trakt;
    } catch (e) {
      print('Error mapping TMDB $tmdbId to Trakt: $e');
      return null;
    }
  }
  
  // Migración en lote para favoritos existentes
  Future<void> migrateFavoritesToTrakt(String userId) async {
    final favorites = await _supabase
        .from('user_favorites')
        .select()
        .eq('user_id', userId)
        .isFilter('trakt_id', null);
    
    for (final favorite in favorites) {
      final traktId = await findTraktIdForTmdb(favorite['movie_id']);
      if (traktId != null) {
        await _supabase
            .from('user_favorites')
            .update({'trakt_id': traktId})
            .eq('id', favorite['id']);
      }
    }
  }
}
```

### 3.2 Repositorio Híbrido de Películas

```dart
class HybridMoviesRepository {
  final TraktMoviesRepository _traktRepo;
  final TmdbMoviesRepository _tmdbRepo;
  final MovieIdMappingService _mappingService;
  
  // Obtener película con prioridad Trakt > TMDB
  Future<Movie?> getMovie(int movieId, {int? traktId}) async {
    try {
      // 1. Prioridad: usar Trakt si tenemos el ID
      if (traktId != null) {
        final traktMovie = await _traktRepo.getMovieDetails(traktId);
        if (traktMovie != null) return traktMovie;
      }
      
      // 2. Fallback: buscar equivalencia Trakt para TMDB ID
      final mappedTraktId = await _mappingService.findTraktIdForTmdb(movieId);
      if (mappedTraktId != null) {
        final traktMovie = await _traktRepo.getMovieDetails(mappedTraktId);
        if (traktMovie != null) {
          // Actualizar registro con nuevo trakt_id
          _updateRecordWithTraktId(movieId, mappedTraktId);
          return traktMovie;
        }
      }
      
      // 3. Último recurso: usar TMDB
      return await _tmdbRepo.getMovieDetails(movieId);
    } catch (e) {
      print('Error in hybrid movie fetch: $e');
      return await _tmdbRepo.getMovieDetails(movieId); // Fallback seguro
    }
  }
  
  // Obtener lista de películas con migración automática
  Future<List<Movie>> getMoviesHybrid(List<MovieReference> refs) async {
    final movies = <Movie>[];
    
    for (final ref in refs) {
      final movie = await getMovie(ref.tmdbId, traktId: ref.traktId);
      if (movie != null) movies.add(movie);
    }
    
    return movies;
  }
}

class MovieReference {
  final int tmdbId;
  final int? traktId;
  
  MovieReference({required this.tmdbId, this.traktId});
}
```

## 4. Servicio de Migración en Segundo Plano

### 4.1 Migrador Automático

```dart
class BackgroundMigrationService {
  final MovieIdMappingService _mappingService;
  final SupabaseClient _supabase;
  
  // Ejecutar migración gradual
  Future<void> runGradualMigration() async {
    await _migrateFavorites();
    await _migrateWatchedMovies();
    await _migrateCustomLists();
  }
  
  Future<void> _migrateFavorites() async {
    final unmigrated = await _supabase
        .from('user_favorites')
        .select()
        .isFilter('trakt_id', null)
        .limit(50); // Procesar en lotes pequeños
    
    for (final record in unmigrated) {
      final traktId = await _mappingService.findTraktIdForTmdb(
        record['movie_id']
      );
      
      if (traktId != null) {
        await _supabase
            .from('user_favorites')
            .update({'trakt_id': traktId})
            .eq('id', record['id']);
        
        print('Migrated favorite: TMDB ${record['movie_id']} → Trakt $traktId');
      }
      
      // Pausa para no sobrecargar APIs
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
}
```

### 4.2 Programador de Migración

```dart
class MigrationScheduler {
  Timer? _migrationTimer;
  
  void startPeriodicMigration() {
    _migrationTimer = Timer.periodic(
      Duration(hours: 6), // Cada 6 horas
      (_) => BackgroundMigrationService().runGradualMigration()
    );
  }
  
  void stopMigration() {
    _migrationTimer?.cancel();
  }
}
```

## 5. Estrategia de Imágenes Híbrida

### 5.1 Servicio de Imágenes Inteligente

```dart
class HybridImageService {
  // Prioridad: Trakt metadata + TMDB imágenes
  String? getMoviePosterUrl(Movie movie, {String size = 'w500'}) {
    // Siempre usar TMDB para imágenes (mejor calidad)
    if (movie.tmdbId != null) {
      return 'https://image.tmdb.org/t/p/$size${movie.posterPath}';
    }
    
    // Fallback a imagen por defecto
    return 'assets/images/fallback_poster.svg';
  }
  
  String? getMovieBackdropUrl(Movie movie, {String size = 'w1280'}) {
    if (movie.tmdbId != null) {
      return 'https://image.tmdb.org/t/p/$size${movie.backdropPath}';
    }
    return null;
  }
}
```

## 6. Plan de Implementación por Fases

### Fase 1: Preparación (Semana 1)
- ✅ Extender esquema de base de datos
- ✅ Actualizar modelos de datos
- ✅ Crear servicio de mapeo básico
- ✅ Implementar repositorio híbrido

### Fase 2: Migración Gradual (Semana 2-3)
- 🔄 Implementar servicio de migración en segundo plano
- 🔄 Configurar programador automático
- 🔄 Migrar datos existentes por lotes
- 🔄 Monitorear progreso de migración

### Fase 3: Optimización (Semana 4)
- ⏳ Optimizar consultas híbridas
- ⏳ Implementar caché inteligente
- ⏳ Mejorar manejo de errores
- ⏳ Testing exhaustivo

### Fase 4: Finalización (Semana 5-6)
- ⏳ Migrar funcionalidades restantes a Trakt
- ⏳ Implementar nuevas características de Trakt
- ⏳ Documentar proceso completo
- ⏳ Preparar para producción

## 7. Monitoreo y Métricas

### 7.1 Dashboard de Migración

```sql
-- Consultas de monitoreo
-- Progreso de migración de favoritos
SELECT 
  COUNT(*) as total_favorites,
  COUNT(trakt_id) as migrated_favorites,
  ROUND(COUNT(trakt_id) * 100.0 / COUNT(*), 2) as migration_percentage
FROM user_favorites;

-- Películas más populares sin migrar
SELECT 
  movie_id,
  COUNT(*) as favorite_count
FROM user_favorites 
WHERE trakt_id IS NULL
GROUP BY movie_id
ORDER BY favorite_count DESC
LIMIT 20;
```

### 7.2 Métricas de Rendimiento

- **Tasa de migración exitosa**: >95%
- **Tiempo de respuesta híbrido**: <500ms
- **Cobertura de mapeo**: >90% de películas populares
- **Disponibilidad del servicio**: >99.9%

## 8. Estrategia de Rollback

### 8.1 Rollback Inmediato

```dart
class RollbackService {
  // Desactivar Trakt temporalmente
  Future<void> disableTraktTemporarily() async {
    await _supabase.rpc('disable_trakt_globally');
    // La app automáticamente usará solo TMDB
  }
  
  // Rollback completo (si es necesario)
  Future<void> fullRollback() async {
    await _supabase.rpc('clear_all_trakt_ids');
    print('Rollback completo ejecutado');
  }
}
```

## 9. Beneficios de la Estrategia Híbrida

### 9.1 Ventajas Técnicas
- **Cero pérdida de datos**: Todos los datos existentes se preservan
- **Migración gradual**: Sin interrupciones del servicio
- **Rollback seguro**: Vuelta atrás instantánea si es necesario
- **Optimización progresiva**: Mejora continua del rendimiento

### 9.2 Ventajas de Negocio
- **Experiencia de usuario continua**: Sin interrupciones
- **Reducción de riesgo**: Migración controlada y monitoreada
- **Flexibilidad**: Adaptación según resultados
- **Preparación futura**: Base sólida para nuevas características

## 10. Consideraciones Importantes

### 10.1 Limitaciones de APIs
- **TMDB**: 40 requests/10 segundos
- **Trakt**: 1000 requests/5 minutos
- **Estrategia**: Caché agresivo + rate limiting inteligente

### 10.2 Manejo de Errores
- Fallback automático a TMDB en caso de fallo de Trakt
- Retry logic con backoff exponencial
- Logging detallado para debugging

### 10.3 Privacidad y Cumplimiento
- Mantener políticas de privacidad existentes
- Cumplir con GDPR/CCPA
- Auditoría de acceso a datos

---

**Conclusión**: Esta estrategia híbrida permite una migración segura y gradual de TMDB a Trakt.tv, preservando todos los datos existentes mientras se aprovechan progresivamente las ventajas superiores de Trakt.tv en términos de funcionalidades sociales, límites de API y calidad de datos.