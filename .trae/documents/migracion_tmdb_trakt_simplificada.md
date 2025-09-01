# Migración Simplificada: TMDB → Trakt.tv

## 1. Resumen del Proyecto

Migración directa y completa de TMDB a Trakt.tv para una aplicación Flutter con 1-2 usuarios beta. Prioriza simplicidad sobre preservación perfecta de datos.

**Objetivo**: Reemplazar completamente la infraestructura TMDB por Trakt.tv en 1-2 semanas máximo.

## 2. Estrategia de Migración

### 2.1 Enfoque Directo
- **Sin duplicación de datos**: Eliminamos TMDB completamente
- **Conversión de IDs**: Script automático para convertir movie_id existentes
- **Pérdida aceptable**: Algunos datos pueden perderse temporalmente
- **Rollback simple**: Backup de base de datos antes de migrar

### 2.2 Arquitectura Híbrida Mínima
- **APIs de datos**: 100% Trakt.tv
- **Imágenes**: TMDB como fallback (sin autenticación)
- **Autenticación**: Mantener actual, agregar Trakt OAuth después

## 3. Plan de Implementación

### Semana 1: Preparación y Conversión

#### Día 1-2: Backup y Análisis
```bash
# Backup completo de Supabase
pg_dump -h [host] -U [user] -d [database] > backup_pre_migration.sql
```

#### Día 3-4: Script de Conversión de IDs
```dart
// conversion_script.dart
class TmdbToTraktConverter {
  static Future<void> convertAllMovieIds() async {
    // 1. Obtener todos los movie_id de favorites
    final favorites = await supabase.from('user_favorites').select();
    
    // 2. Convertir cada TMDB ID a Trakt ID
    for (final favorite in favorites) {
      final tmdbId = favorite['movie_id'];
      final traktId = await _getTraktIdFromTmdb(tmdbId);
      
      if (traktId != null) {
        await supabase.from('user_favorites')
          .update({'movie_id': traktId})
          .eq('id', favorite['id']);
      } else {
        // Marcar para eliminación manual
        print('No se pudo convertir TMDB ID: $tmdbId');
      }
    }
  }
  
  static Future<int?> _getTraktIdFromTmdb(int tmdbId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.trakt.tv/search/tmdb/$tmdbId?type=movie'),
        headers: {
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': traktClientId,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data[0]['movie']['ids']['trakt'];
      }
    } catch (e) {
      print('Error converting TMDB $tmdbId: $e');
    }
    return null;
  }
}
```

#### Día 5: Actualizar Providers y Repositorios
```dart
// Reemplazar en movies_repository_provider.dart
final moviesRepositoryProvider = Provider<MoviesRepository>((ref) {
  return TraktMoviesRepositoryImpl(); // Era: MovieRepositoryImpl()
});

// Actualizar hybrid_favorites_repository.dart
class HybridFavoritesRepository {
  final TraktMoviesRepository _traktRepo; // Era: MoviesRepository
  final FavoriteMoviesLocalDatasource _localDatasource;
  
  // Eliminar referencias a TMDB completamente
}
```

### Semana 2: Testing y Refinamiento

#### Día 1-3: Testing Básico
- Verificar que todas las películas se muestren correctamente
- Probar funcionalidad de favoritos y listas
- Validar sincronización con Supabase

#### Día 4-5: Manejo de Imágenes
```dart
// image_service.dart
class HybridImageService {
  static String getMoviePosterUrl(Movie movie) {
    // Prioridad: Trakt fanart → TMDB fallback
    if (movie.images?.poster?.isNotEmpty == true) {
      return movie.images!.poster!;
    }
    
    // Fallback a TMDB usando IMDB ID
    if (movie.imdbId != null) {
      return 'https://image.tmdb.org/t/p/w500${_getTmdbPosterFromImdb(movie.imdbId!)}';
    }
    
    return 'assets/images/no_poster.png';
  }
}
```

## 4. Archivos a Modificar

### 4.1 Repositorios Principales
- `lib/features/movies/data/repositories/movies_repository_provider.dart`
- `lib/features/movies/data/repositories/hybrid_favorites_repository.dart`
- `lib/features/movies/data/repositories/hybrid_watched_repository.dart`

### 4.2 Modelos de Datos
- `lib/features/sync/data/models/sync_models.dart` (ya actualizado)
- `lib/features/movies/domain/entities/movie.dart`

### 4.3 