# Tareas de Media Prioridad - Sistema de Compartir

## Estado Actual del Sistema

✅ **Completado:**

* ShareService completamente implementado con todos los métodos

* ListShareWebView implementada

* RecommendationShareWebView implementada

* Rutas configuradas para listas y recomendaciones

* Integración básica con share\_plus

❌ **Pendiente:**

* MovieShareWebView

* Ruta /movie/:id/share

* Integraciones UI completas

* Optimizaciones de rendimiento

* Configuraciones SEO

## 1. Vistas Web Faltantes

### 1.1 MovieShareWebView (Prioridad: Media-Alta)

**Archivo:** `lib/presentation/views/movie_share_web_view.dart`

**Descripción:** Crear vista web para compartir películas individuales con información detallada.

**Características requeridas:**

* Hero section con poster de la película

* Información detallada (título, descripción, año, género)

* Botones de descarga de la app

* Deep links para abrir en la app

* Diseño responsive

* Meta tags para SEO

**Estructura sugerida:**

```dart
class MovieShareWebView extends ConsumerWidget {
  const MovieShareWebView({super.key, required this.movieId});
  final String movieId;
  
  static const String name = 'movie-share';
}
```

**Componentes necesarios:**

* Header con información de la película

* Sección de detalles (sinopsis, año, géneros)

* Botones de acción (descargar app, abrir en app)

* Footer con información de la app

## 2. Configuración de Rutas

### 2.1 Ruta para MovieShareWebView (Prioridad: Media-Alta)

**Archivo:** `lib/config/router/app_router.dart`

**Descripción:** Agregar ruta `/movie/:id/share` para la vista web de compartir películas.

**Implementación requerida:**

```dart
GoRoute(
  path: '/movie/:id/share',
  name: MovieShareWebView.name,
  pageBuilder: (context, state) {
    final movieId = state.pathParameters['id'] ?? '0';
    
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
```

## 3. Integraciones UI

### 3.1 Botón de Compartir en MovieScreen (Prioridad: Media)

**Archivo:** `lib/presentation/screens/movie/movie_screen.dart`

**Descripción:** Integrar botón de compartir en la pantalla de detalles de película.

**Ubicación sugerida:** AppBar o sección de acciones

**Implementación:**

```dart
IconButton(
  icon: const Icon(Icons.share),
  onPressed: () => ShareService.shareMovie(
    context: context,
    movie: movie,
  ),
)
```

### 3.2 Compartir desde Listas de Películas (Prioridad: Media)

**Archivos afectados:**

* `lib/presentation/views/movies/favorites_view.dart`

* `lib/presentation/views/movies/watched_view.dart`

* `lib/presentation/views/movies/home_view.dart`

**Descripción:** Agregar opciones de compartir en menús contextuales de listas.

### 3.3 Compartir Logros (Prioridad: Media-Baja)

**Archivo:** `lib/presentation/views/movies/achievements_view.dart`

**Descripción:** Mejorar el sistema de compartir logros existente.

## 4. Optimizaciones de Rendimiento

### 4.1 Lazy Loading en Vistas Web (Prioridad: Media)

**Archivos afectados:**

* `lib/presentation/views/movie_share_web_view.dart`

* `lib/presentation/views/list_share_web_view.dart`

* `lib/presentation/views/recommendation_share_web_view.dart`

**Descripción:** Implementar carga diferida de imágenes y contenido.

**Características:**

* Placeholders para imágenes

* Carga progresiva de contenido

* Optimización de imágenes

### 4.2 Caché de Contenido Compartible (Prioridad: Media)

**Archivo:** `lib/services/share_service.dart`

**Descripción:** Implementar sistema de caché para contenido frecuentemente compartido.

**Implementación sugerida:**

```dart
class ShareCache {
  static final Map<String, ShareableContent> _cache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  static ShareableContent? get(String key) { /* ... */ }
  static void set(String key, ShareableContent content) { /* ... */ }
  static void clear() { /* ... */ }
}
```

### 4.3 Rate Limiting (Prioridad: Media-Baja)

**Archivo:** `lib/services/share_service.dart`

**Descripción:** Implementar límites de velocidad para prevenir spam.

## 5. SEO y Meta Tags

### 5.1 Meta Tags Dinámicos (Prioridad: Media)

**Archivos afectados:** Todas las vistas web de compartir

**Descripción:** Implementar meta tags dinámicos para mejor SEO.

**Meta tags requeridos:**

* `og:title`

* `og:description`

* `og:image`

* `og:url`

* `twitter:card`

* `twitter:title`

* `twitter:description`

* `twitter:image`

### 5.2 Structured Data (Prioridad: Media-Baja)

**Descripción:** Agregar datos estructurados JSON-LD para mejor indexación.

**Tipos de datos:**

* Movie (schema.org/Movie)

* ItemList (schema.org/ItemList)

* WebPage (schema.org/WebPage)

## 6. Configuración PWA

### 6.1 Actualizar manifest.json (Prioridad: Media)

**Archivo:** `web/manifest.json`

**Descripción:** Configurar PWA para mejor experiencia de compartir.

**Configuraciones requeridas:**

```json
{
  "share_target": {
    "action": "/share",
    "method": "GET",
    "params": {
      "title": "title",
      "text": "text",
      "url": "url"
    }
  },
  "related_applications": [
    {
      "platform": "play",
      "url": "https://play.google.com/store/apps/details?id=com.example.peliculas",
      "id": "com.example.peliculas"
    }
  ]
}
```

## 7. Testing y Validación

### 7.1 Tests de Integración (Prioridad: Media)

**Archivos:** `test/integration/share_test.dart`

**Descripción:** Crear tests para validar funcionalidad de compartir.

**Casos de prueba:**

* Compartir película desde diferentes pantallas

* Validar URLs generadas

* Probar deep links

* Verificar meta tags

### 7.2 Tests Cross-Platform (Prioridad: Media-Baja)

**Descripción:** Validar funcionalidad en iOS, Android y Web.

## 8. Analytics y Métricas

### 8.1 Tracking de Compartir (Prioridad: Media-Baja)

**Archivo:** `lib/services/analytics_service.dart`

**Descripción:** Implementar tracking de eventos de compartir.

**Eventos a trackear:**

* `share_movie`

* `share_list`

* `share_recommendation`

* `share_achievement`

* `deep_link_opened`

## Cronograma Sugerido

### Sprint 1 (1-2 semanas)

* MovieShareWebView

* Ruta /movie/:id/share

* Integración en MovieScreen

### Sprint 2 (1 semana)

* Optimizaciones de rendimiento

* Meta tags dinámicos

* Integraciones UI adicionales

### Sprint 3 (1 semana)

* Configuración PWA

* Testing y validación

* Analytics básicos

## Estimación de Esfuerzo

* **Total:** \~3-4 semanas

* **Desarrollador:** 1 persona

* **Complejidad:** Media

* **Dependencias:** Ninguna crítica

## Notas Técnicas

* Reutilizar componentes existentes de `ListShareWebView` y `RecommendationShareWebView`

* Mantener consistencia en el diseño y UX

* Considerar limitaciones de cada plataforma

* Optimizar para SEO desde el inicio

* Implementar analytics desde la primera versión

