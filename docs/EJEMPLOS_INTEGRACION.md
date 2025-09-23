# Guía de Integración - Ejemplos de Código

Este documento contiene ejemplos completos de integración de las funcionalidades avanzadas del sistema.

## 🎯 Sistema de Monetización

### Inicialización Básica

```dart
// En main.dart
await MonetizationInitializer.instance.initialize();
```

### Configuraciones Disponibles

```dart
// Conservadora (menos anuncios)
MonetizationInitializer.conservativeConfig

// Balanceada (recomendada)
MonetizationInitializer.balancedConfig

// Agresiva (más anuncios)
MonetizationInitializer.aggressiveConfig
```

### Widgets de Anuncios Controlados

```dart
// Banner con control de frecuencia
ControlledBannerAd(
  onAdShown: () => print('Banner mostrado'),
  onAdBlocked: (reason) => print('Banner bloqueado: $reason'),
)

// Native ad con control
ControlledNativeAd(
  height: 100,
  showLabel: true,
  onAdShown: () => print('Native ad mostrado'),
  onAdBlocked: (reason) => print('Native ad bloqueado: $reason'),
)
```

## 🖼️ Sistema de Cache Adaptativo

### Inicialización

```dart
// En main.dart
await ImageCacheManager.instance.initialize();
```

### Uso (sin cambios necesarios)

```dart
CachedNetworkImageWidget(
  imageUrl: 'https://image.tmdb.org/t/p/w500/movie.jpg',
  placeholder: CircularProgressIndicator(),
  errorWidget: Icon(Icons.error),
  fit: BoxFit.cover,
)
```

### Monitoreo de Performance

```dart
final report = ImageCacheManager.instance.generatePerformanceReport();
final stats = await ImageCacheManager.instance.getEnhancedStats();
```

## 🔧 Providers Optimizados

### Provider Base con Auto-cleanup

```dart
class OptimizedProvider extends BaseProviderWithCleanup<AsyncValue<Data>> {
  @override
  AsyncValue<Data> build() {
    // Timer se cancelará automáticamente
    final timer = Timer.periodic(Duration(minutes: 5), (_) => refresh());
    addTimer(timer);

    // Subscription se cancelará automáticamente
    final subscription = dataStream.listen((data) => state = AsyncValue.data(data));
    addSubscription(subscription);

    return AsyncValue.loading();
  }

  @override
  void onDispose() {
    // Cleanup adicional específico
    repository.clearCache();
  }
}
```

## 📊 Integración de Anuncios en UI

### Lista Horizontal con Anuncios

```dart
MovieHorizontalListviewWithAds(
  movies: moviesList,
  sectionId: 'popular-movies',
  title: 'Películas Populares',
  adFrequency: 5, // Anuncio cada 5 películas
  enableAds: true,
)
```

### Grid con Anuncios

```dart
MovieMasonryWithAds(
  movies: moviesList,
  gridAdFrequency: 9, // Anuncio cada 9 películas
  fullWidthAdFrequency: 15, // Anuncio ancho cada 15 películas
  enableGridAds: true,
  enableFullWidthAds: true,
)
```

## 🔄 Configuración Adaptativa

### Respuesta a Cambios de Red

```dart
// Al detectar cambio de red
await ImageCacheManager.instance.refreshAdaptiveConfiguration();
```

### Limpieza de Cache

```dart
await ImageCacheManager.instance.clearCache();
```

### Métricas de Salud

```dart
final healthCheck = await MonetizationInitializer.instance.performHealthCheck();
print('Estado: ${healthCheck.status}');
print('Puntuación: ${healthCheck.overallScore}');
```

## ⚙️ Configuración Avanzada

### Personalización de Anuncios

```dart
final controller = AdFrequencyController.instance;

// Registrar interacción del usuario (reduce frecuencia temporalmente)
controller.recordUserInteraction();

// Obtener estadísticas de la sesión
final stats = controller.getSessionStats();
print('Anuncios en sesión: ${stats['sessionAdCount']}');
```

### Analytics de Monetización

```dart
final analytics = MonetizationAnalyticsService.instance;
final metrics = await analytics.getDetailedMetrics();

print('CTR: ${(metrics.ctr * 100).toStringAsFixed(2)}%');
print('Revenue estimado: \$${metrics.estimatedRevenue.toStringAsFixed(2)}');
print('UX Score: ${(metrics.userExperienceScore * 100).toStringAsFixed(1)}%');
```

## 🎛️ Configuración de Performance

### Device Capabilities Detection

```dart
final capabilities = AdaptiveCacheConfig.instance.deviceCapabilities;
print('Device: ${capabilities.deviceType}');
print('Performance Tier: ${capabilities.performanceTier}');
print('Memory Cache: ${capabilities.recommendedMemoryCacheSize}MB');
```

### Network-Aware Configuration

```dart
final networkStatus = NetworkAwareStrategy.instance.getNetworkStatus();
print('Network: ${networkStatus.connectionType}');
print('Speed: ${networkStatus.estimatedSpeed} Mbps');
```

---

## 📝 Notas de Implementación

1. **Auto-cleanup**: Todos los providers que heredan de `BaseProviderWithCleanup` limpian automáticamente timers y subscriptions.

2. **Configuración Adaptativa**: El sistema ajusta automáticamente cache y anuncios según el dispositivo y red.

3. **Sin Breaking Changes**: Todos los widgets existentes de imágenes continúan funcionando con mejoras automáticas.

4. **Monitoreo Integrado**: Sistema completo de métricas y health checks para optimización continua.

5. **Control de Frecuencia**: Sistema inteligente que reduce anuncios después de interacciones del usuario.

Para implementación completa, consultar los archivos de ejemplo en:

- `lib/examples/` - Ejemplos funcionales completos
- `lib/presentation/providers/base/` - Ejemplos de providers optimizados
- `lib/presentation/widgets/admob/` - Ejemplos de widgets de anuncios
