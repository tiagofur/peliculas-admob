# Arquitectura Técnica - Funcionalidad de Compartir Películas

## 1. Arquitectura de URLs Web

### 1.1 Estructura de URLs

Base URL: `https://peliculas.creapolis.dev`

**URLs de Compartir:**

* Películas individuales: `/movie/{id}/share`

* Listas personalizadas: `/list/{listId}/share`

* Recomendaciones por categoría: `/recommendations/category/{categoryId}/share`

* Recomendaciones por estado de ánimo: `/recommendations/mood/{mood}/share`

**Ejemplos:**

```
https://peliculas.creapolis.dev/movie/550/share
https://peliculas.creapolis.dev/list/abc123/share
https://peliculas.creapolis.dev/recommendations/category/action/share
```

### 1.2 Configuración GoRouter

```dart
// Nuevas rutas a agregar en app_router.dart
GoRoute(
  path: '/movie/:id/share',
  name: 'MovieShare',
  pageBuilder: (context, state) {
    final movieId = state.pathParameters['id'] ?? 'no-id';
    return CustomTransitionPage(
      key: state.pageKey,
      child: MovieShareWebView(movieId: movieId),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return CinematicPageTransitions.fadeScaleTransition(
          page: child,
          duration: const Duration(milliseconds: 400),
        ).transitionsBuilder(context, animation, secondaryAnimation, child);
      },
    );
  },
),

GoRoute(
  path: '/list/:listId/share',
  name: 'ListShare',
  pageBuilder: (context, state) {
    final listId = state.pathParameters['listId'] ?? '0';
    return CustomTransitionPage(
      key: state.pageKey,
      child: ListShareWebView(listId: listId),
    );
  },
),

GoRoute(
  path: '/recommendations/category/:categoryId/share',
  name: 'RecommendationCategoryShare',
  pageBuilder: (context, state) {
    final categoryId = state.pathParameters['categoryId'] ?? '';
    return CustomTransitionPage(
      key: state.pageKey,
      child: RecommendationShareWebView(
        type: 'category',
        identifier: categoryId,
      ),
    );
  },
),
```

## 2. Servicio de Compartir

### 2.1 ShareService

```dart
// lib/infrastructure/services/share_service.dart
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/entities.dart';

class ShareService {
  static const String baseUrl = 'https://peliculas.creapolis.dev';
  
  // Compartir película individual
  static Future<void> shareMovie(Movie movie) async {
    final url = '$baseUrl/movie/${movie.id}/share';
    final text = '🎬 Mira "${movie.title}" en nuestra app de películas!\n\n'
                '⭐ Calificación: ${movie.voteAverage}/10\n'
                '📅 Año: ${movie.releaseDate?.year ?? 'N/A'}\n\n'
                '📱 Ve más detalles: $url\n\n'
                '🎭 #Películas #Cine #${_getGenreHashtag(movie.genreIds)}';
    
    await Share.share(
      text,
      subject: 'Te recomiendo esta película: ${movie.title}',
    );
  }
  
  // Compartir lista personalizada
  static Future<void> shareList(CustomList list) async {
    final url = '$baseUrl/list/${list.id}/share';
    final movieCount = list.movies.length;
    final text = '📝 Mira mi lista "${list.name}" con $movieCount películas!\n\n'
                '🎬 Incluye: ${_getTopMoviesPreview(list.movies)}\n\n'
                '📱 Ve la lista completa: $url\n\n'
                '#ListasDePelículas #Cine #MisRecomendaciones';
    
    await Share.share(
      text,
      subject: 'Mi lista de películas: ${list.name}',
    );
  }
  
  // Compartir recomendación por categoría
  static Future<void> shareRecommendationCategory(String categoryId, List<Movie> movies) async {
    final url = '$baseUrl/recommendations/category/$categoryId/share';
    final categoryName = _getCategoryDisplayName(categoryId);
    final text = '🎯 Descubre películas de $categoryName!\n\n'
                '🎬 Recomendaciones destacadas:\n${_getMoviesPreview(movies)}\n\n'
                '📱 Ve todas las recomendaciones: $url\n\n'
                '#Recomendaciones #$categoryName #Cine';
    
    await Share.share(
      text,
      subject: 'Recomendaciones de $categoryName',
    );
  }
  
  // Métodos auxiliares
  static String _getGenreHashtag(List<int> genreIds) {
    // Mapear IDs de género a hashtags
    final genreMap = {
      28: 'Acción',
      35: 'Comedia',
      18: 'Drama',
      27: 'Terror',
      // ... más géneros
    };
    return genreIds.isNotEmpty ? genreMap[genreIds.first] ?? 'Película' : 'Película';
  }
  
  static String _getTopMoviesPreview(List<Movie> movies) {
    return movies.take(3).map((m) => '• ${m.title}').join('\n');
  }
  
  static String _getMoviesPreview(List<Movie> movies) {
    return movies.take(2).map((m) => '⭐ ${m.title} (${m.voteAverage}/10)').join('\n');
  }
  
  static String _getCategoryDisplayName(String categoryId) {
    final categories = {
      'action': 'Acción',
      'comedy': 'Comedia',
      'drama': 'Drama',
      // ... más categorías
    };
    return categories[categoryId] ?? categoryId;
  }
}
```

## 3. Páginas Web de Destino

### 3.1 MovieShareWebView

```dart
// lib/presentation/views/share/movie_share_web_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class MovieShareWebView extends ConsumerWidget {
  final String movieId;
  
  const MovieShareWebView({super.key, required this.movieId});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildMovieHero(context, ref),
            _buildMovieDetails(context, ref),
            _buildDownloadSection(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor,
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 40),
          const SizedBox(width: 12),
          Text(
            'Películas App',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMovieHero(BuildContext context, WidgetRef ref) {
    // Cargar datos de la película usando el provider
    final movieAsync = ref.watch(movieInfoProvider(movieId));
    
    return movieAsync.when(
      data: (movie) => Container(
        height: 400,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://image.tmdb.org/t/p/w1280${movie.backdropPath}'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${movie.voteAverage}/10',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${movie.releaseDate?.year ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      loading: () => const SizedBox(height: 400, child: Center(child: CircularProgressIndicator())),
      error: (error, stack) => SizedBox(
        height: 400,
        child: Center(
          child: Text('Error cargando película: $error'),
        ),
      ),
    );
  }
  
  Widget _buildDownloadSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          Text(
            '📱 ¡Descarga nuestra app para la experiencia completa!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '• Crea listas personalizadas\n• Recibe recomendaciones inteligentes\n• Comparte con amigos\n• Modo offline',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDownloadButton(
                'Google Play',
                'https://play.google.com/store/apps/details?id=com.creapolis.peliculas',
                Icons.android,
              ),
              const SizedBox(width: 16),
              _buildDownloadButton(
                'App Store',
                'https://apps.apple.com/app/peliculas-creapolis/id123456789',
                Icons.phone_iphone,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDownloadButton(String text, String url, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _launchUrl(url),
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
  
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
```

## 4. Deep Links y Meta Tags

### 4.1 Configuración Web (index.html)

```html
<!-- Agregar en web/index.html -->
<head>
  <!-- Meta tags básicos -->
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  
  <!-- Meta tags para SEO -->
  <meta name="description" content="Descubre, organiza y comparte tus películas favoritas. Red social de cine con recomendaciones personalizadas.">
  <meta name="keywords" content="películas, cine, recomendaciones, listas, compartir, red social">
  
  <!-- Open Graph para redes sociales -->
  <meta property="og:title" content="Películas - Red Social de Cine">
  <meta property="og:description" content="Descubre, organiza y comparte tus películas favoritas">
  <meta property="og:image" content="https://peliculas.creapolis.dev/icons/og-image.png">
  <meta property="og:url" content="https://peliculas.creapolis.dev">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Películas App">
  
  <!-- Twitter Cards -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Películas - Red Social de Cine">
  <meta name="twitter:description" content="Descubre, organiza y comparte tus películas favoritas">
  <meta name="twitter:image" content="https://peliculas.creapolis.dev/icons/og-image.png">
  
  <!-- Deep Links -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <link rel="manifest" href="manifest.json">
  
  <!-- Script para manejar deep links -->
  <script>
    window.addEventListener('DOMContentLoaded', function() {
      // Detectar si viene de URL de compartir
      const path = window.location.pathname;
      if (path.includes('/share')) {
        // Intentar abrir en app nativa si está instalada
        const deepLink = 'peliculas://share' + path.replace('/share', '');
        
        // Crear enlace temporal para deep link
        const link = document.createElement('a');
        link.href = deepLink;
        link.style.display = 'none';
        document.body.appendChild(link);
        
        // Intentar abrir app nativa
        setTimeout(() => {
          link.click();
          document.body.removeChild(link);
        }, 100);
        
        // Si no se abre la app en 2 segundos, continuar con web
        setTimeout(() => {
          console.log('Continuando con versión web');
        }, 2000);
      }
    });
  </script>
</head>
```

### 4.2 Configuración de Deep Links

```dart
// lib/config/deep_links/deep_link_handler.dart
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:html' as html;

class DeepLinkHandler {
  static void initialize(GoRouter router) {
    if (kIsWeb) {
      _handleWebDeepLinks(router);
    }
  }
  
  static void _handleWebDeepLinks(GoRouter router) {
    final currentUrl = html.window.location.href;
    final uri = Uri.parse(currentUrl);
    
    // Manejar URLs de compartir
    if (uri.path.contains('/share')) {
      final cleanPath = uri.path.replaceAll('/share', '');
      
      // Redirigir a la ruta correspondiente
      if (cleanPath.startsWith('/movie/')) {
        final movieId = cleanPath.split('/')[2];
        router.go('/home/0/movie/$movieId');
      } else if (cleanPath.startsWith('/list/')) {
        final listId = cleanPath.split('/')[2];
        router.go('/lists/$listId');
      }
    }
  }
  
  // Generar URLs de compartir
  static String generateShareUrl(String type, String id) {
    const baseUrl = 'https://peliculas.creapolis.dev';
    return '$baseUrl/$type/$id/share';
  }
}
```

## 5. Integración con UI Existente

### 5.1 Botón de Compartir en MovieScreen

```dart
// Modificar en movie_screen.dart - _CustomSliverAppBar
actions: [
  // Botón existente de favorito
  IconButton(
    onPressed: () {
      ref.read(favoriteMoviesProvider.notifier).toggleFavorite(movie);
    },
    icon: Icon(
      isFavorite ? Icons.favorite : Icons.favorite_border,
      color: Colors.red,
    ),
  ),
  
  // NUEVO: Botón de compartir
  IconButton(
    onPressed: () => ShareService.shareMovie(movie),
    icon: const Icon(Icons.share),
    tooltip: 'Compartir película',
  ),
  
  const SizedBox(width: 8),
],
```

### 5.2 Compartir en Listas

```dart
// Modificar en list_detail_view.dart
// Reemplazar el placeholder "Funcionalidad de compartir próximamente"
IconButton(
  onPressed: () {
    final currentList = ref.read(customListsProvider)
        .firstWhere((list) => list.id == widget.listId);
    ShareService.shareList(currentList);
  },
  icon: const Icon(Icons.share),
  tooltip: 'Compartir lista',
),
```

## 6. Configuración de Manifest

### 6.1 Actualizar manifest.json

```json
{
  "name": "Películas - Red Social de Cine",
  "short_name": "Películas",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#EEBEB8",
  "theme_color": "#EEBEB8",
  "description": "Descubre, organiza y comparte tus películas favoritas",
  "orientation": "portrait-primary",
  "prefer_related_applications": true,
  "related_applications": [
    {
      "platform": "play",
      "url": "https://play.google.com/store/apps/details?id=com.creapolis.peliculas",
      "id": "com.creapolis.peliculas"
    }
  ],
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

## 7. Testing y Validación

### 7.1 URLs de Prueba

```
# Desarrollo local
http://localhost:3000/movie/550/share
http://localhost:3000/list/test123/share

# Producción
https://peliculas.creapolis.dev/movie/550/share
https://peliculas.creapolis.dev/list/abc123/share
```

### 7.2 Validadores

* **Open Graph**: <https://developers.facebook.com/tools/debug/>

* **Twitter Cards**: <https://cards-dev.twitter.com/validator>

* **Structured Data**: <https://search.google.com/test/rich-results>

## 8. Consideraciones de Rendimiento

### 8.1 Optimizaciones

* **Lazy loading** de imágenes en páginas de compartir

* **Caché** de datos de películas en Hive para acceso rápido

* **Compresión** de imágenes para Open Graph

* **Preload** de datos críticos en páginas de compartir

### 8.2 Métricas

* Tiempo de carga de páginas de compartir

* Tasa de conversión de compartir a descarga

* Engagement en redes sociales

* Deep link success rate

