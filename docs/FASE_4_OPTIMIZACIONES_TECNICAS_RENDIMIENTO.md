# ⚡ FASE 4: OPTIMIZACIONES TÉCNICAS Y DE RENDIMIENTO

## 📋 **INFORMACIÓN GENERAL**

| Campo                 | Valor               |
| --------------------- | ------------------- |
| **Duración estimada** | 2 semanas           |
| **Fecha inicio**      | Oct 15, 2025        |
| **Fecha fin**         | Oct 28, 2025        |
| **Recursos**          | 1-2 desarrolladores |
| **Prioridad**         | Alta                |
| **Estado**            | Planificado         |

## 🎯 **OBJETIVOS**

### **Objetivo Principal**

Optimizar la performance, arquitectura y estabilidad de la aplicación para soportar el crecimiento de usuarios y las nuevas funcionalidades implementadas en fases anteriores, garantizando una experiencia fluida y rápida.

### **Objetivos Específicos**

1. **Performance Mobile**: Optimizar renderizado, memoria y batería
2. **Arquitectura Escalable**: Refactorizar componentes críticos para mejor mantenibilidad
3. **Cache Inteligente**: Implementar sistema de cache multinivel eficiente
4. **Conectividad Robusta**: Mejorar manejo de offline/online y sync
5. **Bundle Optimization**: Reducir tamaño de app y tiempo de carga
6. **Monitoring Avanzado**: Implementar observabilidad completa

## 📊 **MÉTRICAS ACTUALES VS OBJETIVOS**

| Métrica             | Estado Actual | Objetivo | Mejora Esperada |
| ------------------- | ------------- | -------- | --------------- |
| **Cold Start Time** | ~4.5s         | <2.5s    | -44%            |
| **Hot Start Time**  | ~1.8s         | <0.8s    | -56%            |
| **Memory Usage**    | ~180MB        | <120MB   | -33%            |
| **Battery Drain**   | ~8%/hora      | <5%/hora | -38%            |
| **Bundle Size**     | ~45MB         | <30MB    | -33%            |
| **First Paint**     | ~2.1s         | <1.2s    | -43%            |
| **Frame Drops**     | ~12%          | <3%      | -75%            |
| **Crash Rate**      | ~1.2%         | <0.5%    | -58%            |

## 📁 **ARCHIVOS A OPTIMIZAR/CREAR**

### **1. Performance Core**

```
📄 lib/core/performance/performance_monitor.dart         [CREAR]
📄 lib/core/performance/memory_manager.dart              [CREAR]
📄 lib/core/performance/frame_metrics_collector.dart     [CREAR]
📄 lib/core/performance/battery_optimizer.dart           [CREAR]
📄 lib/core/performance/network_performance_tracker.dart [CREAR]
```

### **2. Cache System Avanzado**

```
📄 lib/core/cache/multi_level_cache_manager.dart         [CREAR]
📄 lib/core/cache/intelligent_prefetcher.dart            [CREAR]
📄 lib/core/cache/cache_analytics.dart                   [CREAR]
📄 lib/core/cache/adaptive_cache_strategy.dart           [CREAR]
📄 lib/core/cache/cache_compression_service.dart         [CREAR]
```

### **3. State Management Optimizations**

```
📄 lib/presentation/providers/optimized/               [REFACTOR]
   ├── movies_provider_optimized.dart
   ├── search_provider_optimized.dart
   ├── user_provider_optimized.dart
   └── watchlist_provider_optimized.dart
```

### **4. Database & Storage Optimizations**

```
📄 lib/infrastructure/database/query_optimizer.dart      [CREAR]
📄 lib/infrastructure/database/batch_operations.dart     [CREAR]
📄 lib/infrastructure/database/index_manager.dart        [CREAR]
📄 lib/infrastructure/storage/compressed_storage.dart    [CREAR]
```

### **5. Network Layer Improvements**

```
📄 lib/infrastructure/network/adaptive_http_client.dart  [CREAR]
📄 lib/infrastructure/network/request_deduplicator.dart  [CREAR]
📄 lib/infrastructure/network/bandwidth_detector.dart    [CREAR]
📄 lib/infrastructure/network/retry_strategy.dart        [REFACTOR]
```

### **6. UI Performance Optimizations**

```
📄 lib/presentation/widgets/performance/               [CREAR]
   ├── optimized_list_view.dart
   ├── lazy_loading_grid.dart
   ├── cached_network_image_pro.dart
   ├── virtual_scroll_view.dart
   └── performance_overlay.dart
```

### **7. Background Processing**

```
📄 lib/services/background/background_task_manager.dart  [CREAR]
📄 lib/services/background/sync_scheduler.dart           [CREAR]
📄 lib/services/background/maintenance_service.dart      [CREAR]
```

## 🔧 **IMPLEMENTACIÓN DETALLADA**

### **Performance Monitor**

#### **Frame Metrics Collector**

```dart
class FrameMetricsCollector {
  static final FrameMetricsCollector _instance = FrameMetricsCollector._internal();
  factory FrameMetricsCollector() => _instance;
  FrameMetricsCollector._internal();

  final StreamController<FrameMetrics> _frameMetricsController = StreamController.broadcast();
  Stream<FrameMetrics> get frameMetricsStream => _frameMetricsController.stream;

  Timer? _monitoringTimer;
  final List<FrameData> _frameHistory = [];
  static const int maxFrameHistory = 300; // 5 minutos a 60fps

  void startMonitoring() {
    if (_monitoringTimer?.isActive == true) return;

    WidgetsBinding.instance.addPersistentFrameCallback(_onFrameCallback);

    _monitoringTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _analyzePerformance();
    });
  }

  void _onFrameCallback(Duration timestamp) {
    final frameData = FrameData(
      timestamp: timestamp,
      frameDuration: _calculateFrameDuration(timestamp),
      isJanky: false, // Se calculará después
    );

    _frameHistory.add(frameData);

    // Mantener solo los últimos N frames
    if (_frameHistory.length > maxFrameHistory) {
      _frameHistory.removeAt(0);
    }

    // Detectar jank
    if (frameData.frameDuration > Duration(milliseconds: 16.67)) {
      frameData.isJanky = true;
      _reportJankyFrame(frameData);
    }

    WidgetsBinding.instance.addPersistentFrameCallback(_onFrameCallback);
  }

  void _analyzePerformance() {
    if (_frameHistory.isEmpty) return;

    final recentFrames = _frameHistory.take(60).toList(); // Último segundo
    final jankyFrames = recentFrames.where((f) => f.isJanky).length;
    final jankPercentage = (jankyFrames / recentFrames.length) * 100;

    final averageFrameTime = recentFrames
        .map((f) => f.frameDuration.inMicroseconds)
        .reduce((a, b) => a + b) / recentFrames.length;

    final metrics = FrameMetrics(
      jankPercentage: jankPercentage,
      averageFrameTime: Duration(microseconds: averageFrameTime.round()),
      fps: 1000000 / averageFrameTime, // microseconds to FPS
      timestamp: DateTime.now(),
    );

    _frameMetricsController.add(metrics);

    // Alertas automáticas
    if (jankPercentage > 5.0) {
      _triggerPerformanceAlert('High jank detected: ${jankPercentage.toStringAsFixed(1)}%');
    }

    if (metrics.fps < 45) {
      _triggerPerformanceAlert('Low FPS detected: ${metrics.fps.toStringAsFixed(1)}');
    }
  }

  void _reportJankyFrame(FrameData frame) {
    // Report a Firebase Performance o sistema de analytics
    AnalyticsService.track('janky_frame', {
      'duration_ms': frame.frameDuration.inMilliseconds,
      'screen': CurrentScreenTracker.currentScreen,
      'timestamp': frame.timestamp.inMilliseconds,
    });
  }

  void _triggerPerformanceAlert(String message) {
    // Solo en modo debug
    if (kDebugMode) {
      print('🚨 PERFORMANCE ALERT: $message');
    }

    // Log para monitoring
    Logger.performance.warning(message);
  }
}

class FrameData {
  final Duration timestamp;
  final Duration frameDuration;
  bool isJanky;

  FrameData({
    required this.timestamp,
    required this.frameDuration,
    required this.isJanky,
  });
}

class FrameMetrics {
  final double jankPercentage;
  final Duration averageFrameTime;
  final double fps;
  final DateTime timestamp;

  FrameMetrics({
    required this.jankPercentage,
    required this.averageFrameTime,
    required this.fps,
    required this.timestamp,
  });
}
```

### **Multi-Level Cache Manager**

#### **Intelligent Cache System**

```dart
class MultiLevelCacheManager {
  static final MultiLevelCacheManager _instance = MultiLevelCacheManager._internal();
  factory MultiLevelCacheManager() => _instance;
  MultiLevelCacheManager._internal();

  // L1: In-Memory Cache (Fastest, Limited)
  final Map<String, CacheEntry> _memoryCache = {};
  static const int maxMemoryCacheSize = 50 * 1024 * 1024; // 50MB
  int _currentMemoryUsage = 0;

  // L2: Disk Cache (Fast, Larger)
  late final Box<CacheEntry> _diskCache;

  // L3: Database Cache (Slower, Persistent)
  late final DatabaseCacheService _databaseCache;

  // Cache Analytics
  final CacheAnalytics _analytics = CacheAnalytics();

  Future<void> initialize() async {
    await Hive.openBox<CacheEntry>('disk_cache').then((box) => _diskCache = box);
    _databaseCache = DatabaseCacheService();
    await _databaseCache.initialize();

    // Limpiar cache expirado al inicializar
    await _cleanupExpiredEntries();

    // Programar limpieza periódica
    Timer.periodic(Duration(hours: 1), (_) => _cleanupExpiredEntries());
  }

  Future<T?> get<T>(
    String key, {
    CacheStrategy strategy = CacheStrategy.auto,
    Duration? maxAge,
  }) async {
    final cacheKey = _generateCacheKey(key, T);

    _analytics.recordAccess(cacheKey);

    // L1: Memory Cache
    if (strategy != CacheStrategy.diskOnly) {
      final memoryEntry = _memoryCache[cacheKey];
      if (memoryEntry != null && !_isExpired(memoryEntry, maxAge)) {
        _analytics.recordHit(CacheLevel.memory);
        return _deserialize<T>(memoryEntry.data);
      }
    }

    // L2: Disk Cache
    if (strategy != CacheStrategy.memoryOnly) {
      final diskEntry = _diskCache.get(cacheKey);
      if (diskEntry != null && !_isExpired(diskEntry, maxAge)) {
        _analytics.recordHit(CacheLevel.disk);

        // Promote to memory cache si hay espacio
        _promoteToMemory(cacheKey, diskEntry);

        return _deserialize<T>(diskEntry.data);
      }
    }

    // L3: Database Cache
    if (strategy == CacheStrategy.persistent || strategy == CacheStrategy.auto) {
      final dbEntry = await _databaseCache.get(cacheKey);
      if (dbEntry != null && !_isExpired(dbEntry, maxAge)) {
        _analytics.recordHit(CacheLevel.database);

        // Promote to higher levels
        _promoteToMemory(cacheKey, dbEntry);
        _diskCache.put(cacheKey, dbEntry);

        return _deserialize<T>(dbEntry.data);
      }
    }

    _analytics.recordMiss();
    return null;
  }

  Future<void> put<T>(
    String key,
    T value, {
    Duration? ttl,
    CacheStrategy strategy = CacheStrategy.auto,
    CachePriority priority = CachePriority.normal,
  }) async {
    final cacheKey = _generateCacheKey(key, T);
    final serializedData = _serialize(value);
    final entry = CacheEntry(
      key: cacheKey,
      data: serializedData,
      timestamp: DateTime.now(),
      ttl: ttl,
      priority: priority,
      accessCount: 0,
      lastAccessed: DateTime.now(),
      dataSize: serializedData.length,
    );

    // L1: Memory Cache
    if (strategy != CacheStrategy.diskOnly && strategy != CacheStrategy.persistent) {
      if (_canFitInMemory(entry)) {
        _memoryCache[cacheKey] = entry;
        _currentMemoryUsage += entry.dataSize;
      } else {
        await _evictFromMemory();
        if (_canFitInMemory(entry)) {
          _memoryCache[cacheKey] = entry;
          _currentMemoryUsage += entry.dataSize;
        }
      }
    }

    // L2: Disk Cache
    if (strategy != CacheStrategy.memoryOnly) {
      await _diskCache.put(cacheKey, entry);
    }

    // L3: Database Cache
    if (strategy == CacheStrategy.persistent || priority == CachePriority.high) {
      await _databaseCache.put(cacheKey, entry);
    }
  }

  bool _canFitInMemory(CacheEntry entry) {
    return (_currentMemoryUsage + entry.dataSize) <= maxMemoryCacheSize;
  }

  Future<void> _evictFromMemory() async {
    if (_memoryCache.isEmpty) return;

    // LRU eviction con consideración de prioridad
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) {
      // Primero por prioridad (menor prioridad = eviction candidata)
      final priorityComparison = a.value.priority.index.compareTo(b.value.priority.index);
      if (priorityComparison != 0) return priorityComparison;

      // Luego por último acceso (más viejo = eviction candidata)
      return a.value.lastAccessed.compareTo(b.value.lastAccessed);
    });

    // Evict hasta liberar 25% del espacio
    final targetUsage = (maxMemoryCacheSize * 0.75).round();

    for (final entry in entries) {
      if (_currentMemoryUsage <= targetUsage) break;

      _currentMemoryUsage -= entry.value.dataSize;
      _memoryCache.remove(entry.key);

      _analytics.recordEviction(CacheLevel.memory);
    }
  }

  void _promoteToMemory(String key, CacheEntry entry) {
    if (_canFitInMemory(entry)) {
      _memoryCache[key] = entry..lastAccessed = DateTime.now();
      _currentMemoryUsage += entry.dataSize;
    }
  }

  String _generateCacheKey(String key, Type type) {
    return '${type.toString()}_$key';
  }

  bool _isExpired(CacheEntry entry, Duration? maxAge) {
    final age = DateTime.now().difference(entry.timestamp);
    final ttl = maxAge ?? entry.ttl ?? Duration(hours: 24);
    return age > ttl;
  }

  Future<void> _cleanupExpiredEntries() async {
    // Memory cache cleanup
    final expiredMemoryKeys = <String>[];
    for (final entry in _memoryCache.entries) {
      if (_isExpired(entry.value, null)) {
        expiredMemoryKeys.add(entry.key);
      }
    }

    for (final key in expiredMemoryKeys) {
      final entry = _memoryCache.remove(key);
      if (entry != null) {
        _currentMemoryUsage -= entry.dataSize;
      }
    }

    // Disk cache cleanup
    final diskKeys = _diskCache.keys.toList();
    for (final key in diskKeys) {
      final entry = _diskCache.get(key);
      if (entry != null && _isExpired(entry, null)) {
        await _diskCache.delete(key);
      }
    }

    // Database cache cleanup
    await _databaseCache.cleanupExpired();
  }

  List<int> _serialize<T>(T value) {
    // Implementación optimizada de serialización
    if (value is String) {
      return utf8.encode(value);
    } else if (value is Map || value is List) {
      return utf8.encode(jsonEncode(value));
    } else {
      // Para objetos complejos, usar serialización personalizada
      return utf8.encode(jsonEncode(value));
    }
  }

  T _deserialize<T>(List<int> data) {
    final string = utf8.decode(data);

    if (T == String) {
      return string as T;
    } else {
      return jsonDecode(string) as T;
    }
  }

  CacheStats getStats() {
    return CacheStats(
      memoryUsage: _currentMemoryUsage,
      memoryEntries: _memoryCache.length,
      diskEntries: _diskCache.length,
      hitRate: _analytics.hitRate,
      missRate: _analytics.missRate,
      averageAccessTime: _analytics.averageAccessTime,
    );
  }
}

enum CacheStrategy {
  auto,
  memoryOnly,
  diskOnly,
  persistent,
}

enum CachePriority {
  low,
  normal,
  high,
  critical,
}

enum CacheLevel {
  memory,
  disk,
  database,
}

@HiveType(typeId: 1)
class CacheEntry extends HiveObject {
  @HiveField(0)
  final String key;

  @HiveField(1)
  final List<int> data;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final Duration? ttl;

  @HiveField(4)
  final CachePriority priority;

  @HiveField(5)
  int accessCount;

  @HiveField(6)
  DateTime lastAccessed;

  @HiveField(7)
  final int dataSize;

  CacheEntry({
    required this.key,
    required this.data,
    required this.timestamp,
    this.ttl,
    required this.priority,
    required this.accessCount,
    required this.lastAccessed,
    required this.dataSize,
  });
}
```

### **Adaptive HTTP Client**

#### **Network Performance Optimization**

```dart
class AdaptiveHttpClient {
  static final AdaptiveHttpClient _instance = AdaptiveHttpClient._internal();
  factory AdaptiveHttpClient() => _instance;
  AdaptiveHttpClient._internal();

  late final Dio _dio;
  final BandwidthDetector _bandwidthDetector = BandwidthDetector();
  final RequestDeduplicator _deduplicator = RequestDeduplicator();
  final NetworkPerformanceTracker _performanceTracker = NetworkPerformanceTracker();

  // Connection pooling
  final Map<String, ConnectionPool> _connectionPools = {};

  // Adaptive timeouts based on network quality
  Duration get _connectTimeout {
    switch (_bandwidthDetector.currentQuality) {
      case NetworkQuality.excellent:
        return Duration(seconds: 5);
      case NetworkQuality.good:
        return Duration(seconds: 10);
      case NetworkQuality.fair:
        return Duration(seconds: 15);
      case NetworkQuality.poor:
        return Duration(seconds: 30);
    }
  }

  Future<void> initialize() async {
    _dio = Dio(BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: Duration(seconds: 30),
      sendTimeout: Duration(seconds: 30),
    ));

    // Interceptors
    _dio.interceptors.addAll([
      _createPerformanceInterceptor(),
      _createCacheInterceptor(),
      _createRetryInterceptor(),
      _createCompressionInterceptor(),
      _createDeduplicationInterceptor(),
    ]);

    await _bandwidthDetector.initialize();

    // Ajustar timeouts dinámicamente
    _bandwidthDetector.qualityStream.listen((quality) {
      _dio.options.connectTimeout = _connectTimeout;
    });
  }

  Interceptor _createPerformanceInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        _performanceTracker.startRequest(options.path);
        handler.next(options);
      },
      onResponse: (response, handler) {
        _performanceTracker.endRequest(
          response.requestOptions.path,
          success: true,
          responseSize: response.data?.toString().length ?? 0,
        );
        handler.next(response);
      },
      onError: (error, handler) {
        _performanceTracker.endRequest(
          error.requestOptions.path,
          success: false,
          error: error,
        );
        handler.next(error);
      },
    );
  }

  Interceptor _createCacheInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Solo para GET requests
        if (options.method.toUpperCase() != 'GET') {
          handler.next(options);
          return;
        }

        final cacheKey = _generateCacheKey(options);
        final cachedResponse = await MultiLevelCacheManager().get<Map<String, dynamic>>(
          cacheKey,
          maxAge: Duration(minutes: 15), // Cache HTTP por 15 minutos
        );

        if (cachedResponse != null) {
          handler.resolve(Response(
            requestOptions: options,
            data: cachedResponse['data'],
            statusCode: cachedResponse['statusCode'],
            headers: Headers.fromMap(Map<String, List<String>>.from(
              cachedResponse['headers'] ?? {},
            )),
          ));
          return;
        }

        handler.next(options);
      },
      onResponse: (response, handler) async {
        // Cache successful GET responses
        if (response.requestOptions.method.toUpperCase() == 'GET' &&
            response.statusCode == 200) {
          final cacheKey = _generateCacheKey(response.requestOptions);
          await MultiLevelCacheManager().put(
            cacheKey,
            {
              'data': response.data,
              'statusCode': response.statusCode,
              'headers': response.headers.map,
            },
            ttl: Duration(minutes: 15),
          );
        }

        handler.next(response);
      },
    );
  }

  Interceptor _createRetryInterceptor() {
    return RetryInterceptor(
      dio: _dio,
      options: RetryOptions(
        retries: 3,
        retryInterval: Duration(seconds: 1),
        retryEvaluator: (error) {
          // Retry on network errors, timeouts, and 5xx errors
          return error.type == DioErrorType.connectTimeout ||
                 error.type == DioErrorType.receiveTimeout ||
                 error.type == DioErrorType.sendTimeout ||
                 error.type == DioErrorType.other ||
                 (error.response?.statusCode ?? 0) >= 500;
        },
        onRetry: (error, retryCount) {
          Logger.network.info('Retrying request ${error.requestOptions.path} (attempt $retryCount)');
        },
      ),
    );
  }

  Interceptor _createCompressionInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Enable compression for all requests
        options.headers['Accept-Encoding'] = 'gzip, deflate, br';
        handler.next(options);
      },
    );
  }

  Interceptor _createDeduplicationInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final requestKey = _generateRequestKey(options);

        // Check if same request is already in flight
        if (_deduplicator.isRequestInFlight(requestKey)) {
          final result = await _deduplicator.waitForRequest(requestKey);
          handler.resolve(result);
          return;
        }

        _deduplicator.registerRequest(requestKey);
        handler.next(options);
      },
      onResponse: (response, handler) {
        final requestKey = _generateRequestKey(response.requestOptions);
        _deduplicator.completeRequest(requestKey, response);
        handler.next(response);
      },
      onError: (error, handler) {
        final requestKey = _generateRequestKey(error.requestOptions);
        _deduplicator.completeRequest(requestKey, null, error);
        handler.next(error);
      },
    );
  }

  String _generateCacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    final params = options.queryParameters.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$uri?$params';
  }

  String _generateRequestKey(RequestOptions options) {
    return '${options.method.toUpperCase()}_${_generateCacheKey(options)}';
  }

  // High-level API methods
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data!;
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data!;
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleError(dynamic error) {
    if (error is DioError) {
      Logger.network.error('Network error: ${error.message}', error);

      // Analytics
      AnalyticsService.track('network_error', {
        'type': error.type.toString(),
        'status_code': error.response?.statusCode,
        'url': error.requestOptions.path,
      });
    }
  }

  NetworkStats getStats() {
    return _performanceTracker.getStats();
  }
}
```

### **Optimized List View**

#### **Virtual Scrolling for Large Lists**

```dart
class OptimizedListView<T> extends StatefulWidget {
  const OptimizedListView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    this.itemHeight,
    this.bufferSize = 10,
    this.preloadThreshold = 5,
    this.onPreload,
    this.physics,
    this.controller,
  }) : super(key: key);

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double? itemHeight;
  final int bufferSize;
  final int preloadThreshold;
  final VoidCallback? onPreload;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  _OptimizedListViewState<T> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  late ScrollController _scrollController;
  final Map<int, Widget> _cachedWidgets = {};
  final Set<int> _visibleIndices = {};

  // Performance metrics
  int _buildCount = 0;
  DateTime? _lastScrollUpdate;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    final now = DateTime.now();
    _lastScrollUpdate = now;

    // Debounce scroll updates
    Timer(Duration(milliseconds: 16), () {
      if (_lastScrollUpdate == now) {
        _updateVisibleItems();
        _handlePreload();
      }
    });
  }

  void _updateVisibleItems() {
    if (!mounted) return;

    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final itemHeight = widget.itemHeight ?? 100.0;

    final startIndex = math.max(0, (scrollOffset / itemHeight).floor() - widget.bufferSize);
    final endIndex = math.min(
      widget.items.length - 1,
      ((scrollOffset + viewportHeight) / itemHeight).ceil() + widget.bufferSize,
    );

    final newVisibleIndices = Set<int>.from(
      List.generate(endIndex - startIndex + 1, (i) => startIndex + i),
    );

    // Only rebuild if visible indices changed significantly
    if (_visibleIndices.difference(newVisibleIndices).length > widget.bufferSize ~/ 2) {
      setState(() {
        _visibleIndices.clear();
        _visibleIndices.addAll(newVisibleIndices);

        // Clean up cache for non-visible items
        _cachedWidgets.removeWhere((index, widget) => !_visibleIndices.contains(index));
      });
    }
  }

  void _handlePreload() {
    if (widget.onPreload == null) return;

    final scrollOffset = _scrollController.offset;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    // Trigger preload when approaching the end
    if (scrollOffset >= maxScrollExtent - (widget.preloadThreshold * 100)) {
      widget.onPreload!();
    }
  }

  Widget _buildItem(int index) {
    if (_cachedWidgets.containsKey(index)) {
      return _cachedWidgets[index]!;
    }

    final item = widget.items[index];
    final builtWidget = widget.itemBuilder(context, item, index);

    // Cache the built widget
    _cachedWidgets[index] = builtWidget;
    _buildCount++;

    return builtWidget;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemHeight != null) {
      // Fixed height optimization
      return ListView.builder(
        controller: _scrollController,
        physics: widget.physics,
        itemCount: widget.items.length,
        itemExtent: widget.itemHeight,
        itemBuilder: (context, index) {
          if (_visibleIndices.contains(index)) {
            return _buildItem(index);
          } else {
            // Return placeholder for non-visible items
            return SizedBox(height: widget.itemHeight);
          }
        },
      );
    } else {
      // Variable height fallback
      return ListView.builder(
        controller: _scrollController,
        physics: widget.physics,
        itemCount: widget.items.length,
        itemBuilder: (context, index) => _buildItem(index),
      );
    }
  }

  // Debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'total_items': widget.items.length,
      'visible_items': _visibleIndices.length,
      'cached_widgets': _cachedWidgets.length,
      'build_count': _buildCount,
      'scroll_offset': _scrollController.hasClients ? _scrollController.offset : 0,
    };
  }
}
```

### **Battery Optimizer**

#### **Power-Aware Background Processing**

```dart
class BatteryOptimizer {
  static final BatteryOptimizer _instance = BatteryOptimizer._internal();
  factory BatteryOptimizer() => _instance;
  BatteryOptimizer._internal();

  Battery? _battery;
  BatteryState? _currentBatteryState;
  int? _currentBatteryLevel;

  // Performance modes
  PowerMode _currentPowerMode = PowerMode.balanced;

  final StreamController<PowerMode> _powerModeController = StreamController.broadcast();
  Stream<PowerMode> get powerModeStream => _powerModeController.stream;

  Future<void> initialize() async {
    try {
      _battery = Battery();

      _currentBatteryLevel = await _battery!.batteryLevel;
      _currentBatteryState = await _battery!.batteryState;

      // Listen to battery changes
      _battery!.onBatteryStateChanged.listen(_onBatteryStateChanged);

      // Initial power mode calculation
      _updatePowerMode();

      // Periodic power mode evaluation
      Timer.periodic(Duration(minutes: 5), (_) => _updatePowerMode());

    } catch (e) {
      Logger.performance.warning('Battery API not available: $e');
    }
  }

  void _onBatteryStateChanged(BatteryState state) {
    _currentBatteryState = state;
    _updatePowerMode();
  }

  Future<void> _updatePowerMode() async {
    if (_battery == null) return;

    try {
      _currentBatteryLevel = await _battery!.batteryLevel;

      final newPowerMode = _calculateOptimalPowerMode();

      if (newPowerMode != _currentPowerMode) {
        _currentPowerMode = newPowerMode;
        _powerModeController.add(_currentPowerMode);

        await _applyPowerModeSettings(_currentPowerMode);

        Logger.performance.info('Power mode changed to: $_currentPowerMode');
      }
    } catch (e) {
      Logger.performance.error('Error updating power mode: $e');
    }
  }

  PowerMode _calculateOptimalPowerMode() {
    // Battery level considerations
    if (_currentBatteryLevel != null && _currentBatteryLevel! < 20) {
      return PowerMode.battery_saver;
    }

    // Battery state considerations
    if (_currentBatteryState == BatteryState.charging) {
      return PowerMode.performance;
    }

    // Default balanced mode
    return PowerMode.balanced;
  }

  Future<void> _applyPowerModeSettings(PowerMode mode) async {
    switch (mode) {
      case PowerMode.battery_saver:
        await _enableBatterySaverMode();
        break;
      case PowerMode.balanced:
        await _enableBalancedMode();
        break;
      case PowerMode.performance:
        await _enablePerformanceMode();
        break;
    }
  }

  Future<void> _enableBatterySaverMode() async {
    // Reduce background sync frequency
    BackgroundTaskManager().setRefreshInterval(Duration(minutes: 30));

    // Reduce animation durations
    AnimationController.setGlobalDuration(0.5);

    // Disable non-essential features
    MultiLevelCacheManager()._analytics.enabled = false;

    // Reduce image quality
    CachedNetworkImagePro.setQualityMode(ImageQuality.low);

    Logger.performance.info('Battery saver mode enabled');
  }

  Future<void> _enableBalancedMode() async {
    // Normal settings
    BackgroundTaskManager().setRefreshInterval(Duration(minutes: 15));
    AnimationController.setGlobalDuration(1.0);
    MultiLevelCacheManager()._analytics.enabled = true;
    CachedNetworkImagePro.setQualityMode(ImageQuality.medium);

    Logger.performance.info('Balanced mode enabled');
  }

  Future<void> _enablePerformanceMode() async {
    // Optimize for performance
    BackgroundTaskManager().setRefreshInterval(Duration(minutes: 5));
    AnimationController.setGlobalDuration(1.0);
    MultiLevelCacheManager()._analytics.enabled = true;
    CachedNetworkImagePro.setQualityMode(ImageQuality.high);

    // Preload more content
    IntelligentPrefetcher().setAggressiveMode(true);

    Logger.performance.info('Performance mode enabled');
  }

  // Public API
  PowerMode get currentPowerMode => _currentPowerMode;

  int? get batteryLevel => _currentBatteryLevel;

  BatteryState? get batteryState => _currentBatteryState;

  bool get isBatterySaverActive => _currentPowerMode == PowerMode.battery_saver;

  // Optimización específica para tasks
  bool shouldExecuteBackgroundTask(BackgroundTaskPriority priority) {
    switch (_currentPowerMode) {
      case PowerMode.battery_saver:
        return priority == BackgroundTaskPriority.critical;
      case PowerMode.balanced:
        return priority != BackgroundTaskPriority.low;
      case PowerMode.performance:
        return true;
    }
  }

  Duration getOptimalAnimationDuration(Duration baseDuration) {
    switch (_currentPowerMode) {
      case PowerMode.battery_saver:
        return Duration(milliseconds: (baseDuration.inMilliseconds * 0.5).round());
      case PowerMode.balanced:
        return baseDuration;
      case PowerMode.performance:
        return baseDuration;
    }
  }
}

enum PowerMode {
  battery_saver,
  balanced,
  performance,
}

enum BackgroundTaskPriority {
  low,
  normal,
  high,
  critical,
}
```

## 🎯 **OPTIMIZACIONES ESPECÍFICAS**

### **Bundle Size Reduction**

#### **Tree Shaking y Code Splitting**

```yaml
# pubspec.yaml optimizations
dependencies:
  # Core dependencies only
  flutter:
    sdk: flutter
  riverpod: ^2.4.0
  go_router: ^11.1.2

  # Lazy-loaded dependencies
  charts_flutter: ^0.12.0
  video_player: ^2.7.2

dev_dependencies:
  # Build optimization tools
  flutter_launcher_icons: ^0.13.1
  bundle_analyzer: ^1.0.0

flutter:
  # Asset optimization
  assets:
    - assets/images/essential/
    # Lazy load non-essential assets

  # Font subsetting
  fonts:
    - family: NotoSans
      fonts:
        - asset: fonts/NotoSans-Regular.ttf
          weight: 400
        - asset: fonts/NotoSans-Bold.ttf
          weight: 700

  # Enable tree shaking
  uses-material-design: true

# Build optimization flags
flutter build apk --release --shrink --obfuscate --split-debug-info=debug-info/
```

#### **Lazy Loading Strategy**

```dart
class LazyModuleLoader {
  static final Map<String, Future<dynamic> Function()> _modules = {
    'video_player': () => _loadVideoPlayer(),
    'charts': () => _loadCharts(),
    'social_sharing': () => _loadSocialSharing(),
    'advanced_search': () => _loadAdvancedSearch(),
  };

  static final Map<String, dynamic> _loadedModules = {};

  static Future<T> loadModule<T>(String moduleName) async {
    if (_loadedModules.containsKey(moduleName)) {
      return _loadedModules[moduleName] as T;
    }

    final loader = _modules[moduleName];
    if (loader == null) {
      throw Exception('Module $moduleName not found');
    }

    final module = await loader();
    _loadedModules[moduleName] = module;

    return module as T;
  }

  static Future<VideoPlayerService> _loadVideoPlayer() async {
    // Dynamic import when needed
    return VideoPlayerService();
  }

  static Future<ChartsService> _loadCharts() async {
    return ChartsService();
  }
}
```

## 📊 **MONITORING Y OBSERVABILIDAD**

### **Performance Dashboard**

```dart
class PerformanceDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameMetrics = ref.watch(frameMetricsProvider);
    final cacheStats = ref.watch(cacheStatsProvider);
    final networkStats = ref.watch(networkStatsProvider);
    final batteryState = ref.watch(batteryStateProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Performance Monitor')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Frame Performance
            _buildMetricCard(
              'Frame Performance',
              [
                _buildMetric('FPS', '${frameMetrics.fps.toStringAsFixed(1)}'),
                _buildMetric('Jank %', '${frameMetrics.jankPercentage.toStringAsFixed(1)}%'),
                _buildMetric('Frame Time', '${frameMetrics.averageFrameTime.inMilliseconds}ms'),
              ],
            ),

            // Memory Usage
            _buildMetricCard(
              'Memory Usage',
              [
                _buildMetric('Cache Size', '${(cacheStats.memoryUsage / 1024 / 1024).toStringAsFixed(1)} MB'),
                _buildMetric('Hit Rate', '${(cacheStats.hitRate * 100).toStringAsFixed(1)}%'),
                _buildMetric('Entries', '${cacheStats.memoryEntries}'),
              ],
            ),

            // Network Performance
            _buildMetricCard(
              'Network Performance',
              [
                _buildMetric('Requests/min', '${networkStats.requestsPerMinute}'),
                _buildMetric('Avg Response', '${networkStats.averageResponseTime}ms'),
                _buildMetric('Error Rate', '${(networkStats.errorRate * 100).toStringAsFixed(1)}%'),
              ],
            ),

            // Battery Status
            _buildMetricCard(
              'Power Management',
              [
                _buildMetric('Battery', '${batteryState.level}%'),
                _buildMetric('Mode', batteryState.powerMode.toString()),
                _buildMetric('State', batteryState.chargingState.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, List<Widget> metrics) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: metrics,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}
```

## 🧪 **TESTING DE PERFORMANCE**

### **Performance Tests**

```dart
// test/performance/performance_benchmark_test.dart
void main() {
  group('Performance Benchmarks', () {
    testWidgets('List scrolling performance', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: OptimizedListView(
            items: List.generate(10000, (i) => 'Item $i'),
            itemBuilder: (context, item, index) => ListTile(title: Text(item)),
            itemHeight: 56,
          ),
        ),
      );

      // Scroll performance test
      await tester.fling(find.byType(ListView), Offset(0, -1000), 5000);
      await tester.pumpAndSettle();

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should complete in <1s
    });

    test('Cache performance benchmark', () async {
      final cache = MultiLevelCacheManager();
      await cache.initialize();

      final stopwatch = Stopwatch()..start();

      // Write performance
      for (int i = 0; i < 1000; i++) {
        await cache.put('key_$i', 'value_$i');
      }

      final writeTime = stopwatch.elapsedMilliseconds;
      stopwatch.reset();

      // Read performance
      for (int i = 0; i < 1000; i++) {
        final value = await cache.get<String>('key_$i');
        expect(value, equals('value_$i'));
      }

      final readTime = stopwatch.elapsedMilliseconds;

      print('Cache write: ${writeTime}ms, read: ${readTime}ms');
      expect(writeTime, lessThan(2000)); // <2s for 1000 writes
      expect(readTime, lessThan(500));   // <500ms for 1000 reads
    });
  });
}

// integration_test/performance_integration_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App startup performance', (tester) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(MyApp());

    // Measure time to first frame
    await binding.takeScreenshot('app_launch');

    // Wait for app to fully load
    await tester.pumpAndSettle(Duration(seconds: 10));

    // Verify no jank during startup
    final frameStats = await binding.getFrameStats();
    expect(frameStats.missedFrameBudgets.length, lessThan(5));
  });
}
```

## ✅ **PLAN DE IMPLEMENTACIÓN**

### **Semana 1: Core Optimizations**

- **Días 1-2**: Performance monitoring system
- **Días 3-4**: Multi-level cache implementation
- **Días 5-7**: Network layer optimizations

### **Semana 2: UI & Integration**

- **Días 8-10**: UI performance optimizations
- **Días 11-12**: Battery management
- **Días 13-14**: Testing & monitoring dashboard

## 🎯 **CRITERIOS DE ÉXITO**

- [ ] **Cold start < 2.5s** (target achieved)
- [ ] **Memory usage < 120MB** (33% reduction)
- [ ] **Bundle size < 30MB** (33% reduction)
- [ ] **Battery drain < 5%/hour** (38% reduction)
- [ ] **Frame drops < 3%** (75% reduction)
- [ ] **Network cache hit rate > 80%**
- [ ] **Zero memory leaks** in 24h stress test

---

**Documento creado**: Sept 16, 2025  
**Última actualización**: Sept 16, 2025  
**Responsable**: Team Performance  
**Estado**: Ready for Implementation
