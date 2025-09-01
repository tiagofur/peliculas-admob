# Migración Completa de TMDB a Trakt.tv - Estrategia y Plan de Implementación

## 🎯 Resumen Ejecutivo

Este documento presenta una estrategia completa para migrar de TMDB a Trakt.tv API, abordando específicamente el problema de compatibilidad con datos existentes de usuarios y proporcionando un plan de implementación por fases que garantiza cero pérdida de datos.

## 🚨 Problema Principal: Compatibilidad de IDs

### Estado Actual
- **Base de datos**: Todas las tablas usan `movie_id INTEGER` (IDs de TMDB)
- **Datos existentes**: Usuarios tienen favoritos, películas vistas y listas con IDs de TMDB
- **Riesgo**: Migración directa causaría pérdida total de datos de usuarios

### Tablas Afectadas
```sql
-- Estructura actual en Supabase
user_favorites (movie_id INTEGER)        -- IDs de TMDB
user_watched_movies (movie_id INTEGER)   -- IDs de TMDB  
user_list_items (movie_id INTEGER)       -- IDs de TMDB
```

## 🔄 Estrategia de Migración: Arquitectura Híbrida

### Fase 1: Extensión de Base de Datos

#### 1.1 Agregar Columnas de Trakt IDs
```sql
-- Migración: Agregar columnas Trakt a tablas existentes
ALTER TABLE user_favorites ADD COLUMN trakt_id INTEGER;
ALTER TABLE user_favorites ADD COLUMN imdb_id VARCHAR(20);
ALTER TABLE user_favorites ADD COLUMN tmdb_id INTEGER; -- Renombrar movie_id

ALTER TABLE user_watched_movies ADD COLUMN trakt_id INTEGER;
ALTER TABLE user_watched_movies ADD COLUMN imdb_id VARCHAR(20);
ALTER TABLE user_watched_movies ADD COLUMN tmdb_id INTEGER;

ALTER TABLE user_list_items ADD COLUMN trakt_id INTEGER;
ALTER TABLE user_list_items ADD COLUMN imdb_id VARCHAR(20);
ALTER TABLE user_list_items ADD COLUMN tmdb_id INTEGER;

-- Migrar datos existentes
UPDATE user_favorites SET tmdb_id = movie_id;
UPDATE user_watched_movies SET tmdb_id = movie_id;
UPDATE user_list_items SET tmdb_id = movie_id;
```

#### 1.2 Servicio de Conversión de IDs
```dart
class IdMappingService {
  final TraktApiService _traktService;
  final Map<int, TraktIds> _idCache = {};
  
  // Convertir TMDB ID a Trakt IDs usando búsqueda
  Future<TraktIds?> convertTmdbToTrakt(int tmdbId) async {
    if (_idCache.containsKey(tmdbId)) {
      return _idCache[tmdbId];
    }
    
    try {
      // Buscar película en Trakt usando TMDB ID
      final searchResults = await _traktService.searchMovieByTmdbId(tmdbId);
      if (searchResults.isNotEmpty) {
        final traktIds = searchResults.first.ids;
        _idCache[tmdbId] = traktIds;
        return traktIds;
      }
    } catch (e) {
      print('Error converting TMDB ID $tmdbId: $e');
    }
    return null;
  }
  
  // Migración masiva de datos existentes
  Future<void> migrateExistingUserData(String userId) async {
    await _migrateFavorites(userId);
    await _migrateWatchedMovies(userId);
    await _migrateListItems(userId);
  }
  
  Future<void> _migrateFavorites(String userId) async {
    final favorites = await _supabase
        .from('user_favorites')
        .select()
        .eq('user_id', userId)
        .isFilter('trakt_id', null);
    
    for (final favorite in favorites) {
      final tmdbId = favorite['tmdb_id'] as int;
      final traktIds = await convertTmdbToTrakt(tmdbId);
      
      if (traktIds != null) {
        await _supabase
            .from('user_favorites')
            .update({
              'trakt_id': traktIds.trakt,
              'imdb_id': traktIds.imdb,
            })
            .eq('id', favorite['id']);
      }
    }
  }
}
```

### Fase 2: Repositorio Híbrido

#### 2.1 Implementación de Repositorio Dual
```dart
class HybridMovieRepository implements MoviesRepository {
  final TraktApiService _traktService;
  final TMDBApiService _tmdbService; // Fallback
  final IdMappingService _idMapping;
  
  @override
  Future<List<Movie>> getNowPlaying({int page = 1}) async {
    try {
      // Priorizar Trakt
      final traktMovies = await _traktService.getTrendingMovies(page: page);
      return await TraktMovieMapper.toEntityList(traktMovies);
    } catch (e) {
      // Fallback a TMDB
      print('Trakt failed, using TMDB fallback: $e');
      final tmdbMovies = await _tmdbService.getNowPlaying(page: page);
      return await TMDBMovieMapper.toEntityList(tmdbMovies);
    }
  }
  
  @override
  Future<Movie> getMovieById(String id) async {
    // Detectar tipo de ID
    if (id.startsWith('tt')) {
      // IMDB ID
      return await _getMovieByImdbId(id);
    } else if (int.tryParse(id) != null) {
      final numericId = int.parse(id);
      if (numericId > 1000000) {
        // Probablemente TMDB ID
        return await _getMovieByTmdbId(numericId);
      } else {
        // Probablemente Trakt ID
        return await _getMovieByTraktId(numericId);
      }
    }
    throw Exception('Invalid movie ID format: $id');
  }
  
  Future<Movie> _getMovieByTraktId(int traktId) async {
    final traktMovie = await _traktService.getMovieDetails(traktId.toString());
    return await TraktMovieMapper.toEntity(traktMovie);
  }
  
  Future<Movie> _getMovieByTmdbId(int tmdbId) async {
    // Intentar convertir a Trakt primero
    final traktIds = await _idMapping.convertTmdbToTrakt(tmdbId);
    if (traktIds != null) {
      return await _getMovieByTraktId(traktIds.trakt!);
    }
    
    // Fallback a TMDB
    final tmdbMovie = await _tmdbService.getMovieById(tmdbId.toString());
    return await TMDBMovieMapper.toEntity(tmdbMovie);
  }
}
```

### Fase 3: Servicio de Imágenes Híbrido

#### 3.1 Problema: Trakt no proporciona imágenes
```dart
class HybridImageService {
  final TraktApiService _traktService;
  final TMDBImageService _tmdbImageService;
  
  Future<String?> getPosterUrl(Movie movie, {String size = 'w500'}) async {
    // Prioridad 1: Usar TMDB ID si está disponible
    if (movie.tmdbId != null) {
      return _tmdbImageService.getPosterUrl(movie.tmdbId!, size: size);
    }
    
    // Prioridad 2: Buscar TMDB ID usando IMDB ID
    if (movie.imdbId != null) {
      final tmdbId = await _findTmdbIdByImdb(movie.imdbId!);
      if (tmdbId != null) {
        return _tmdbImageService.getPosterUrl(tmdbId, size: size);
      }
    }
    
    // Prioridad 3: Buscar usando título y año
    final tmdbId = await _findTmdbIdByTitleAndYear(movie.title, movie.releaseDate?.year);
    if (tmdbId != null) {
      return _tmdbImageService.getPosterUrl(tmdbId, size: size);
    }
    
    // Fallback: Imagen por defecto
    return 'assets/images/fallback_poster.svg';
  }
  
  Future<int?> _findTmdbIdByImdb(String imdbId) async {
    try {
      final response = await _tmdbService.findByExternalId(imdbId);
      return response['movie_results']?.first?['id'];
    } catch (e) {
      return null;
    }
  }
}
```

## 📊 Modelos de Datos Actualizados

### 4.1 Entidad Movie Extendida
```dart
class Movie {
  final int? traktId;      // Nuevo: ID de Trakt
  final int? tmdbId;       // Existente: ID de TMDB
  final String? imdbId;    // Nuevo: ID de IMDB
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final double? voteAverage;
  final int? voteCount;
  final List<String> genres;
  final int? runtime;
  final String? status;
  
  // Nuevos campos de Trakt
  final double? traktRating;
  final int? traktVotes;
  final int? watchers;
  final int? plays;
  final int? collected;
  
  const Movie({
    this.traktId,
    this.tmdbId,
    this.imdbId,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage,
    this.voteCount,
    this.genres = const [],
    this.runtime,
    this.status,
    this.traktRating,
    this.traktVotes,
    this.watchers,
    this.plays,
    this.collected,
  });
  
  // Método para obtener el ID preferido
  String get preferredId {
    if (traktId != null) return traktId.toString();
    if (tmdbId != null) return tmdbId.toString();
    if (imdbId != null) return imdbId!;
    throw Exception('Movie has no valid ID');
  }
}
```

### 4.2 Modelos de Sincronización Actualizados
```dart
class SyncableFavorite extends SyncableEntity {
  final String userId;
  final int? traktId;      // Nuevo
  final int? tmdbId;       // Renombrado de movieId
  final String? imdbId;    // Nuevo
  final String movieTitle;
  final String? moviePosterPath;
  final String? movieBackdropPath;
  final String? movieOverview;
  final DateTime? movieReleaseDate;
  final double? movieVoteAverage;
  final DateTime addedAt;
  
  const SyncableFavorite({
    required super.id,
    required super.updatedAt,
    required super.createdAt,
    super.deletedAt,
    required this.userId,
    this.traktId,
    this.tmdbId,
    this.imdbId,
    required this.movieTitle,
    this.moviePosterPath,
    this.movieBackdropPath,
    this.movieOverview,
    this.movieReleaseDate,
    this.movieVoteAverage,
    required this.addedAt,
    super.syncStatus = SyncStatus.synced,
  });
  
  // Método para obtener el ID de película preferido
  String get moviePreferredId {
    if (traktId != null) return traktId.toString();
    if (tmdbId != null) return tmdbId.toString();
    if (imdbId != null) return imdbId!;
    throw Exception('Favorite has no valid movie ID');
  }
}
```

## 🚀 Plan de Implementación por Fases

### Fase 1: Preparación (Semana 1)
- [x] ✅ Verificar API keys de Trakt
- [ ] 🔄 Extender esquema de base de datos
- [ ] 🔄 Implementar IdMappingService
- [ ] 🔄 Crear tests unitarios

### Fase 2: Implementación Híbrida (Semana 2-3)
- [ ] 📝 Implementar HybridMovieRepository
- [ ] 📝 Crear HybridImageService
- [ ] 📝 Actualizar modelos de datos
- [ ] 📝 Migrar repositorios de sincronización

### Fase 3: Migración de Datos (Semana 4)
- [ ] 📝 Script de migración masiva
- [ ] 📝 Validación de datos migrados
- [ ] 📝 Rollback automático si falla

### Fase 4: Testing y Optimización (Semana 5)
- [ ] 📝 Tests de integración
- [ ] 📝 Performance testing
- [ ] 📝 User acceptance testing

### Fase 5: Despliegue Gradual (Semana 6)
- [ ] 📝 Feature flag para usuarios beta
- [ ] 📝 Monitoreo de errores
- [ ] 📝 Rollout completo

## 🛡️ Estrategia de Rollback

### Rollback Automático
```dart
class MigrationRollbackService {
  Future<bool> validateMigration(String userId) async {
    final originalCount = await _getOriginalDataCount(userId);
    final migratedCount = await _getMigratedDataCount(userId);
    
    // Si perdimos más del 5% de datos, rollback
    final lossPercentage = (originalCount - migratedCount) / originalCount;
    return lossPercentage <= 0.05;
  }
  
  Future<void> rollbackUser(String userId) async {
    // Restaurar datos originales
    await _supabase.from('user_favorites')
        .update({'movie_id': 'tmdb_id'})
        .eq('user_id', userId);
    
    // Limpiar datos de Trakt
    await _supabase.from('user_favorites')
        .update({
          'trakt_id': null,
          'imdb_id': null,
        })
        .eq('user_id', userId);
  }
}
```

### Plan de Contingencia
1. **Detección automática** de fallos de migración
2. **Rollback inmediato** a TMDB para usuarios afectados
3. **Notificación** al equipo de desarrollo
4. **Análisis post-mortem** y corrección

## 📈 Ventajas de Trakt.tv

### Funcionalidades Nuevas
- **Tracking avanzado**: Watched, collected, watchlist
- **Estadísticas personales**: Tiempo visto, géneros favoritos
- **Features sociales**: Seguir usuarios, listas compartidas
- **Scrobbling**: Sincronización automática
- **Check-ins**: "Estoy viendo X ahora"
- **Ratings y reviews**: Sistema más robusto

### Mejoras Técnicas
- **Rate limits más generosos**: 1000 req/5min vs 40 req/10s
- **API más rápida**: ~150ms vs ~200ms
- **Datos más ricos**: Watchers, plays, collected
- **Mejor para descubrimiento**: Trending real-time

## ⚠️ Consideraciones y Riesgos

### Riesgos Técnicos
1. **Pérdida de datos**: Migración de IDs puede fallar
2. **Performance**: Doble lookup durante transición
3. **Imágenes**: Dependencia de TMDB para posters
4. **Rate limiting**: Conversión masiva de IDs

### Mitigaciones
1. **Migración gradual**: Por lotes de usuarios
2. **Cache agresivo**: Para conversiones de ID
3. **Fallbacks múltiples**: TMDB, Fanart.tv, OMDb
4. **Monitoreo continuo**: Alertas automáticas

## 🎯 Métricas de Éxito

### KPIs de Migración
- **Retención de datos**: >95% de favoritos migrados
- **Performance**: <200ms response time promedio
- **Error rate**: <1% de requests fallidos
- **User satisfaction**: >4.5/5 en feedback

### Monitoreo Post-Migración
```dart
class MigrationMetrics {
  static void trackDataLoss(String userId, String dataType, int originalCount, int migratedCount) {
    final lossPercentage = (originalCount - migratedCount) / originalCount * 100;
    Analytics.track('migration_data_loss', {
      'user_id': userId,
      'data_type': dataType,
      'loss_percentage': lossPercentage,
      'original_count': originalCount,
      'migrated_count': migratedCount,
    });
  }
  
  static void trackApiPerformance(String endpoint, Duration responseTime, bool success) {
    Analytics.track('api_performance', {
      'endpoint': endpoint,
      'response_time_ms': responseTime.inMilliseconds,
      'success': success,
      'api_provider': 'trakt',
    });
  }
}
```

## 🔧 Configuración de Desarrollo

### Variables de Entorno
```env
# Trakt.tv API
TRAKT_CLIENT_ID=55a6473c0980bc594588b6c6c2fa28f2a084047f52a7530b0c6a7d3b56d7d131
TRAKT_CLIENT_SECRET=8969e2e8dd5d7ca6b3e9a7b5b476c7b7e4f3b1b0ad1d5d2f9e5e4e3c7e9e5b4a
TRAKT_API_URL=https://api.trakt.tv

# TMDB (para imágenes y fallback)
TMDB_API_KEY=existing_key
TMDB_API_URL=https://api.themoviedb.org/3

# Feature flags
ENABLE_TRAKT_MIGRATION=true
ENABLE_HYBRID_MODE=true
ENABLE_AUTO_ROLLBACK=true
```

### Provider Configuration
```dart
// lib/presentation/providers/movies/movies_repository_provider.dart
final movieRepositoryProvider = Provider<MoviesRepository>((ref) {
  final enableTraktMigration = bool.fromEnvironment('ENABLE_TRAKT_MIGRATION', defaultValue: false);
  
  if (enableTraktMigration) {
    return HybridMovieRepository(
      traktService: ref.read(traktApiServiceProvider),
      tmdbService: ref.read(tmdbApiServiceProvider),
      idMapping: ref.read(idMappingServiceProvider),
    );
  } else {
    // Fallback a TMDB
    return MovieRepositoryImpl(MoviedbDatasource());
  }
});
```

## 📋 Checklist de Pre-Despliegue

### Base de Datos
- [ ] Backup completo de producción
- [ ] Migración de esquema aplicada
- [ ] Índices optimizados creados
- [ ] RLS policies actualizadas

### Código
- [ ] Tests unitarios pasando (>95% coverage)
- [ ] Tests de integración pasando
- [ ] Performance tests validados
- [ ] Code review completado

### Infraestructura
- [ ] Feature flags configurados
- [ ] Monitoreo y alertas activos
- [ ] Rollback scripts probados
- [ ] Rate limiting configurado

### Documentación
- [ ] API documentation actualizada
- [ ] Runbooks para soporte
- [ ] Plan de comunicación a usuarios
- [ ] Training para equipo de soporte

## 🎉 Conclusión

La migración a Trakt.tv es **técnicamente viable** y **estratégicamente beneficiosa**, pero requiere una implementación cuidadosa para preservar los datos existentes de usuarios. La estrategia híbrida propuesta minimiza riesgos mientras maximiza las ventajas de la nueva API.

**Próximos pasos recomendados**:
1. Implementar la extensión de base de datos
2. Desarrollar el IdMappingService
3. Crear el HybridMovieRepository
4. Ejecutar migración piloto con usuarios beta
5. Rollout gradual basado en métricas de éxito

**Tiempo estimado total**: 6 semanas
**Riesgo**: Medio (mitigado por estrategia híbrida)
**Beneficio**: Alto (mejores funcionalidades y performance)