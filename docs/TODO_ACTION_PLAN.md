# 🚀 Plan de Acción Prioritario - TODOs

## 📋 Resumen Ejecutivo

Este documento proporciona un plan de acción específico y priorizado para resolver los 36 TODOs identificados en la auditoría del código fuente.

**Meta:** Resolver todos los TODOs de alta prioridad en 2-3 semanas y establecer un proceso continuo de gestión.

---

## 🎯 Sprint 1: Fundamentos de Gamificación (Semana 1)

### 🔴 Crítico - Día 1-2

**TAREA 1: Implementar Storage para Gamificación**
- **IDs:** T001, T002
- **Archivos:** `lib/core/gamification/gamification_manager.dart:769,774`
- **Descripción:** Implementar persistencia de datos de gamificación
- **Acción Específica:**
  ```dart
  // Agregar al final de la clase GamificationManager
  Future<void> saveUserProgress(UserProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_progress', jsonEncode(progress.toJson()));
  }
  
  Future<UserProgress?> loadUserProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_progress');
    if (data != null) {
      return UserProgress.fromJson(jsonDecode(data));
    }
    return null;
  }
  ```
- **Estimación:** 4-6 horas
- **Dependencias:** Agregar `shared_preferences` a `pubspec.yaml`
- **Tests:** Crear `test/core/gamification/gamification_storage_test.dart`

### 🟠 Alto - Día 3-4

**TAREA 2: Implementar Progress Streams**
- **IDs:** T003, T004
- **Archivos:** `lib/presentation/providers/progress_providers.dart:6,12`
- **Descripción:** Crear streams para actualizaciones de progreso
- **Acción Específica:**
  ```dart
  // En ProgressTrackingService, agregar:
  final _progressController = StreamController<ProgressUpdate>.broadcast();
  final _milestoneController = StreamController<MilestoneReached>.broadcast();
  
  Stream<ProgressUpdate> get progressUpdateStream => _progressController.stream;
  Stream<MilestoneReached> get milestoneReachedStream => _milestoneController.stream;
  ```
- **Estimación:** 2-3 horas
- **Tests:** Actualizar `test/core/gamification/progress_tracking_test.dart`

**TAREA 3: Recent Achievements Implementation**
- **IDs:** T005, T006
- **Archivos:** `lib/presentation/providers/gamification_providers.dart:17,19`
- **Descripción:** Implementar método getRecentAchievements
- **Acción Específica:**
  ```dart
  // En GamificationManager:
  Future<List<Achievement>> getRecentAchievements({int limit = 5}) async {
    final userAchievements = await getUserAchievements();
    return userAchievements
        .where((a) => a.unlockedAt != null)
        .toList()
        ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!))
        ..take(limit);
  }
  ```
- **Estimación:** 3-4 horas

---

## 🎯 Sprint 2: Navegación y Notificaciones (Semana 2)

### 🟠 Alto - Día 5-7

**TAREA 4: Sistema de Navegación por Notificaciones**
- **IDs:** T007, T008, T009, T010, T011
- **Archivos:** `lib/core/notifications/`
- **Descripción:** Implementar deep linking para notificaciones
- **Acción Específica:**
  ```dart
  // Crear lib/core/navigation/notification_navigator.dart
  class NotificationNavigator {
    static Future<void> handleNotificationTap(String payload) async {
      final data = jsonDecode(payload);
      final type = data['type'];
      
      switch (type) {
        case 'movie':
          await Navigator.pushNamed(context, '/movie/${data['movieId']}');
          break;
        case 'recommendation':
          await Navigator.pushNamed(context, '/recommendations');
          break;
        case 'list':
          await Navigator.pushNamed(context, '/list/${data['listId']}');
          break;
      }
    }
  }
  ```
- **Estimación:** 4-5 horas por archivo
- **Dependencias:** Configurar rutas en main.dart

### 🟡 Medio - Día 8-10

**TAREA 5: Integración Gamificación-Listas**
- **IDs:** T012-T017
- **Archivos:** `lib/presentation/providers/custom_lists_provider.dart`
- **Descripción:** Integrar sistema de logros con listas personalizadas
- **Acción Específica:**
  ```dart
  // En CustomListsProvider:
  Future<void> addMovieToList(Movie movie, String listId) async {
    await _repository.addMovieToList(movie, listId);
    
    // Tracking de gamificación
    final gamificationService = ref.read(gamificationServiceProvider);
    await gamificationService.trackMovieAddedToList(movie.id, listId);
    
    // Actualizar estado
    state = AsyncValue.data([...state.value]);
  }
  ```
- **Estimación:** 2-3 horas

---

## 🎯 Sprint 3: UI/UX y Performance (Semana 3)

### 🟡 Medio - Día 11-13

**TAREA 6: Achievement Widgets Data Binding**
- **IDs:** T018, T019
- **Archivos:** `lib/core/gamification/widgets/achievement_widgets.dart`
- **Descripción:** Conectar widgets con datos reales de progreso
- **Acción Específica:**
  ```dart
  // En AchievementWidget:
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userProgress = ref.watch(userProgressProvider);
        final isUnlocked = userProgress.when(
          data: (progress) => _checkIfUnlocked(progress),
          loading: () => false,
          error: (_, __) => false,
        );
        
        return AchievementCard(
          achievement: achievement,
          isUnlocked: isUnlocked,
        );
      }
    );
  }
  ```
- **Estimación:** 2 horas

**TAREA 7: Dashboard de Gamificación**
- **IDs:** T020, T021
- **Archivos:** `lib/core/gamification/widgets/gamification_dashboard.dart`
- **Descripción:** Implementar badges y mostrar logros desbloqueados
- **Estimación:** 3-4 horas

**TAREA 8: Cache de Streaming**
- **IDs:** T022, T023
- **Archivos:** `lib/core/streaming/availability_checker.dart`
- **Descripción:** Implementar caché para servicios de streaming
- **Acción Específica:**
  ```dart
  // Agregar al inicio de la clase:
  final Map<String, AvailabilityResult> _cache = {};
  final Duration _cacheTimeout = Duration(hours: 1);
  
  Future<AvailabilityResult> checkAvailability(String movieId) async {
    final cacheKey = 'availability_$movieId';
    
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTimeout) {
        return cached;
      }
    }
    
    final result = await _fetchAvailability(movieId);
    _cache[cacheKey] = result;
    return result;
  }
  ```
- **Estimación:** 3-4 horas

---

## 🎯 Sprint 4: Sincronización y Testing (Semana 4)

### 🟡 Medio - Día 14-16

**TAREA 9: Mejoras de Sincronización**
- **IDs:** T024, T025
- **Archivos:** `lib/infrastructure/`
- **Descripción:** Mejorar sincronización Web y conteos Supabase
- **Estimación:** 2-3 horas cada uno

**TAREA 10: Tests de Sincronización**
- **IDs:** T026, T027
- **Archivos:** `test/sync_realtime_test.dart`
- **Descripción:** Implementar tests faltantes de sincronización
- **Estimación:** 4-5 horas

**TAREA 11: Pantallas del Drawer**
- **IDs:** T028, T029, T030
- **Archivos:** `lib/presentation/widgets/custom_drawer.dart`
- **Descripción:** Crear pantallas de configuración, ayuda y acerca de
- **Estimación:** 6-8 horas total

---

## 🎯 Sprint 5: Polishing y Backlog (Semana 5)

### 🟢 Bajo - Día 17-21

**TAREA 12: Mejoras Visuales**
- **IDs:** T031
- **Archivos:** `lib/core/gamification/widgets/challenge_widgets.dart`
- **Descripción:** Agregar animación de confeti
- **Estimación:** 1-2 horas

**TAREA 13: Configuración Regional**
- **IDs:** T032
- **Archivos:** `lib/core/streaming/streaming_service_manager.dart`
- **Descripción:** Configuración de moneda por región
- **Estimación:** 2-3 horas

**TAREA 14: Integración FCM**
- **IDs:** T033
- **Archivos:** `lib/core/notifications/`
- **Descripción:** Enviar tokens FCM al servidor
- **Estimación:** 2-3 horas

**TAREA 15: Actualización de Documentación**
- **IDs:** T034, T035
- **Archivos:** `docs/`
- **Descripción:** Actualizar documentación técnica
- **Estimación:** 1 hora

---

## 📊 Proceso de Implementación

### ✅ Checklist por TODO

Para cada TODO implementado:

1. **Antes de Implementar:**
   - [ ] Leer contexto completo del código
   - [ ] Identificar dependencias
   - [ ] Crear rama específica: `todo/T{ID}-descripcion-corta`
   - [ ] Escribir tests si es necesario

2. **Durante Implementación:**
   - [ ] Seguir convenciones del proyecto
   - [ ] Documentar cambios complejos
   - [ ] Probar localmente
   - [ ] Ejecutar `flutter analyze`

3. **Después de Implementar:**
   - [ ] Ejecutar tests: `flutter test`
   - [ ] Verificar que no se rompió nada
   - [ ] Crear PR con descripción clara
   - [ ] Actualizar tracking matrix
   - [ ] Marcar como completado

### 🔄 Workflow de Desarrollo

```bash
# 1. Crear rama para TODO específico
git checkout -b todo/T001-gamification-storage

# 2. Implementar cambios
# ... desarrollo ...

# 3. Tests y validación
flutter analyze
flutter test

# 4. Commit y push
git add .
git commit -m "T001: Implement gamification storage logic

- Add SharedPreferences for user progress persistence
- Implement saveUserProgress and loadUserProgress methods
- Add error handling for storage operations
- Update GameficationManager to use persistent storage

Resolves TODO at lib/core/gamification/gamification_manager.dart:769,774"

git push origin todo/T001-gamification-storage

# 5. Crear PR y actualizar tracking
# ... crear PR en GitHub ...
# ... actualizar TODO_TRACKING_MATRIX.md ...
```

---

## 🚨 Dependencias y Riesgos

### Dependencias Críticas

1. **Gamificación Storage (T001-T002)**
   - Requiere: `shared_preferences` package
   - Impacta: Todos los TODOs de gamificación

2. **Navigation System (T007-T011)**
   - Requiere: Configuración de rutas
   - Impacta: Experiencia de usuario completa

3. **Progress Streams (T003-T004)**
   - Requiere: T001-T002 completados
   - Impacta: UI reactiva de gamificación

### Riesgos Identificados

1. **🟠 Medio:** Complejidad de navegación por notificaciones
2. **🟡 Bajo:** Compatibilidad de caché entre plataformas
3. **🟡 Bajo:** Performance de streams en dispositivos lentos

### Mitigaciones

- Implementar progresivamente con feature flags
- Tests exhaustivos en múltiples dispositivos
- Documentar decisiones arquitectónicas
- Revisión de código peer-to-peer

---

## 📈 Métricas de Éxito

### KPIs Semanales
- **Velocidad:** 8-10 TODOs resueltos/semana
- **Calidad:** 0 regresiones introducidas
- **Cobertura:** Mantener >80% test coverage
- **Performance:** <10% degradación en tiempo de carga

### Criterios de Aceptación Final
- ✅ Todos los TODOs de alta prioridad resueltos
- ✅ Sistema de gamificación completamente funcional
- ✅ Navegación por notificaciones operativa
- ✅ Tests de regresión pasando
- ✅ Documentación actualizada
- ✅ Performance mantenida o mejorada

---

**Responsable:** Equipo de Desarrollo  
**Inicio:** $(date +"%Y-%m-%d")  
**Meta Finalización:** $(date -d "+5 weeks" +"%Y-%m-%d")  
**Próxima Revisión:** $(date -d "+1 week" +"%Y-%m-%d")