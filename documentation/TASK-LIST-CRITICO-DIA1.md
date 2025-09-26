# 📋 TASK LIST - DÍA 1 (CRÍTICO 24H)

**Fecha**: 25 de Septiembre de 2025  
**Objetivo**: Resolver todos los problemas críticos identificados en la auditoría

---

## ⏰ CRONOGRAMA DEL DÍA

### 🌅 MAÑANA (9:00 - 12:00) - 3h

**PRIORIDAD MÁXIMA**: HomeView Freeze

### 🌞 TARDE (13:00 - 17:00) - 4h

**ENFOQUE**: Memory Leaks + Sync Issues

### 🌙 NOCHE (18:00 - 20:00) - 2h

**CLEANUP**: Deprecated Code + Validación

---

## 🚨 TASKS CRÍTICAS - PRIORIDAD P0

### 🚦 Estado actual (26/09 09:30)

- `flutter analyze --fatal-infos --fatal-warnings` **fallando** por API incompleta de `AdSenseService` (métodos `canShowBannerAd`, `canShowInterstitialAd`, `showInterstitialAd`, `showRewardedAd`, `getMetrics`, `dispose` y clase `AdSenseReward`).
- `SimpleHomeView` mantiene `print()` en runtime web (dispara `avoid_print`).
- Se identificaron ≥15 usos de `withAlpha` en vistas compartidas (`movie_share_web_view.dart`, `list_share_web_view.dart`, `challenge_widgets.dart`, etc.) pendientes de migrar a `withValues()`.
- `custom_lists_provider.dart` sigue con `TODO` para integrar `GamificationIntegrationService` (el servicio devuelve `null`).
- Scripts de monetización/ambiente conservan `print`; decidir si se migran a `LoggerFactory` o se excluyen del lint.

### ✅ TASK P0-001: FIX HOMEVIEW FREEZE (EST: 2h)

**📍 ARCHIVO**: `lib/presentation/screens/home_view.dart`  
**🎯 OBJETIVO**: Eliminar bloqueo de 3 segundos en initState  
**⏱️ DEADLINE**: Hoy 11:00

**SUBTASKS**:

- [ ] **[15min]** Analizar código actual de HomeView.initState()
- [ ] **[30min]** Migrar `_loadMovies()` a Future asíncrono
- [ ] **[30min]** Migrar `_loadUserProfile()` a Future asíncrono
- [ ] **[30min]** Migrar `_calculateAchievements()` a compute isolate
- [ ] **[15min]** Implementar loading states con Shimmer

**CÓDIGO DE REFERENCIA**:

```dart
// ANTES (❌)
@override
void initState() {
  super.initState();
  _loadMovies(); // 800ms
  _loadUserProfile(); // 600ms
  _calculateAchievements(); // 1200ms
}

// DESPUÉS (✅)
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeAsync();
  });
}
```

**VALIDACIÓN**:

```bash
# Test startup time
flutter run --release --verbose
# Debe ser < 1.5s cold start
```

---

### ✅ TASK P0-002: SHIMMER LOADING STATES (EST: 30min)

**📍 ARCHIVO**: `lib/widgets/shimmer_loading.dart` (crear)  
**🎯 OBJETIVO**: Mostrar loading mientras carga HomeView  
**⏱️ DEADLINE**: Hoy 11:30

**SUBTASKS**:

- [ ] **[15min]** Crear ShimmerMovieCard widget
- [ ] **[15min]** Integrar en HomeView durante loading

---

### ✅ TASK P0-003: MEMORY LEAKS AUDIT (EST: 1h)

**📍 SCOPE**: Todos los StatefulWidgets  
**🎯 OBJETIVO**: Identificar todos los listeners sin dispose  
**⏱️ DEADLINE**: Hoy 14:00

**SCRIPT DE AUDITORÍA**:

```bash
# Encontrar StatefulWidgets sin dispose
grep -r "StatefulWidget" lib/ -l | xargs grep -L "dispose()"

# Encontrar StreamSubscriptions sin cancel
grep -r "StreamSubscription" lib/ -l | xargs grep -L "cancel()"

# Encontrar AnimationControllers sin dispose
grep -r "AnimationController" lib/ -l | xargs grep -L "dispose()"
```

**SUBTASKS**:

- [ ] **[20min]** Ejecutar script de auditoría
- [ ] **[20min]** Documentar todos los leaks encontrados
- [ ] **[20min]** Priorizar por criticidad

---

### ✅ TASK P0-004: FIX MOVIE PROVIDER MEMORY LEAK (EST: 30min)

**📍 ARCHIVO**: `lib/presentation/providers/movie_provider.dart`  
**🎯 OBJETIVO**: Implementar dispose correcto  
**⏱️ DEADLINE**: Hoy 14:30

**CÓDIGO TARGET**:

```dart
// BUSCAR Y CORREGIR
class MovieNotifier extends StateNotifier<MovieState> {
  StreamSubscription? _movieSubscription;

  @override
  void dispose() {
    _movieSubscription?.cancel();
    super.dispose();
  }
}
```

---

### ✅ TASK P0-005: FIX REALTIME MANAGER LEAK (EST: 30min)

**📍 ARCHIVO**: `lib/infrastructure/realtime_manager.dart`  
**🎯 OBJETIVO**: Dispose WebSocket connections  
**⏱️ DEADLINE**: Hoy 15:00

---

### ✅ TASK P0-006: FIX SYNC CONFLICTS (EST: 2h)

**📍 ARCHIVO**: `lib/services/sync_service.dart`  
**🎯 OBJETIVO**: Implementar merge inteligente  
**⏱️ DEADLINE**: Hoy 17:00

**SUBTASKS**:

- [ ] **[60min]** Implementar 3-way merge algorithm
- [ ] **[30min]** Agregar version tracking
- [ ] **[30min]** Testing de scenarios de conflicto

**CÓDIGO DE REFERENCIA**:

```dart
// Implementar en resolveConflict()
Future<void> resolveConflict(LocalData local, RemoteData remote) async {
  if (remote.updatedAt.isAfter(local.updatedAt)) {
    await _database.save(remote.toLocal());
  } else if (local.updatedAt.isAfter(remote.updatedAt)) {
    await _supabase.update(local.toRemote());
  } else {
    // Merge inteligente
    final merged = _mergeData(local, remote);
    await _saveAndSync(merged);
  }
}
```

---

### ✅ TASK P0-007: DEPRECATED CODE CLEANUP (EST: 1h)

**🎯 OBJETIVO**: Eliminar withOpacity y print statements  
**⏱️ DEADLINE**: Hoy 19:00

**SUBTASKS**:

- [ ] **[20min]** Script para detectar deprecated methods
- [ ] **[20min]** Auto-fix withOpacity → withValues
- [ ] **[20min]** Auto-fix print → LoggerFactory
- [ ] **[10min]** Reemplazar `print` de `lib/presentation/views/movies/simple_home_view.dart` por `LoggerFactory.debug`
- [ ] **[20min]** Migrar usos de `withAlpha` en vistas web (`movie_share_web_view.dart`, `list_share_web_view.dart`, `challenge_widgets.dart`, etc.) a `.withValues(alpha: value / 255)`

**COMANDOS**:

```bash
# Detectar problemas
grep -r "withOpacity\|print(" lib/ --include="*.dart" | wc -l

# Auto-fix (crear scripts)
./scripts/fix_withopacity.sh --fix
./scripts/fix_print_warnings.sh --fix
```

---

### ✅ TASK P0-008: VALIDATION & TESTING (EST: 30min)

**🎯 OBJETIVO**: Validar que todos los fixes funcionan  
**⏱️ DEADLINE**: Hoy 19:30

**COMANDOS DE VALIDACIÓN**:

```bash
# 1. Format check
dart format --set-exit-if-changed .

# 2. Analysis
flutter analyze --fatal-infos --fatal-warnings

# 3. Tests
flutter test

# 4. Build validation
flutter build apk --release
flutter build web --release
```

**MÉTRICAS ESPERADAS**:

- [ ] ✅ HomeView startup: <1.5s (era 3.2s)
- [ ] ✅ Memory usage: <200MB (era 287MB)
- [ ] ✅ Zero print statements (eran 89)
- [ ] ✅ Zero withOpacity (eran 273)
- [ ] ✅ All tests passing
- [ ] ✅ Builds successful

---

## 🛠️ SCRIPTS A CREAR HOY

### Script 1: Memory Leak Detector

```bash
#!/bin/bash
# ./scripts/detect_memory_leaks.sh

echo "🔍 Detecting Memory Leaks..."

echo "📋 StatefulWidgets without dispose():"
grep -r "StatefulWidget" lib/ -l | xargs grep -L "dispose()" | head -10

echo "📋 StreamSubscriptions without cancel():"
grep -r "StreamSubscription" lib/ -l | xargs grep -L "cancel()" | head -10

echo "📋 AnimationControllers without dispose():"
grep -r "AnimationController" lib/ -l | xargs grep -L "dispose()" | head -10
```

### Script 2: Deprecated Code Fixer

```bash
#!/bin/bash
# ./scripts/fix_deprecated_today.sh

echo "🔧 Fixing Deprecated Code..."

# Fix withOpacity
find lib/ -name "*.dart" -exec sed -i 's/\.withOpacity(\([^)]*\))/.withValues(alpha: \1)/g' {} \;

# Fix print statements
find lib/ -name "*.dart" -exec sed -i 's/print(/LoggerFactory.debug(/g' {} \;

echo "✅ Deprecated code fixed!"
```

### Script 3: Today's Validation

```bash
#!/bin/bash
# ./scripts/validate_today_fixes.sh

echo "✅ Validating Today's Fixes..."

# Check HomeView startup
echo "📊 Testing HomeView startup..."
timeout 30 flutter run --profile --verbose | grep "first frame" || echo "Timeout"

# Check memory
echo "📊 Checking memory usage..."
flutter test test/performance/memory_test.dart

# Check deprecated code
echo "📊 Checking deprecated code..."
DEPRECATED=$(grep -r "withOpacity\|print(" lib/ --include="*.dart" | wc -l)
if [ "$DEPRECATED" -eq 0 ]; then
  echo "✅ No deprecated code found"
else
  echo "❌ Still $DEPRECATED deprecated instances"
fi

echo "🎯 Daily validation complete!"
```

---

## 📊 TRACKING DIARIO

### Progress Tracker

```
⬜⬜⬜⬜⬜⬜⬜⬜ (0/8 tasks)

TASK P0-001: HomeView Fix           [⬜]
TASK P0-002: Shimmer Loading        [⬜]
TASK P0-003: Memory Leaks Audit     [⬜]
TASK P0-004: Movie Provider Fix     [⬜]
TASK P0-005: Realtime Manager Fix   [⬜]
TASK P0-006: Sync Conflicts Fix     [⬜]
TASK P0-007: Deprecated Cleanup     [⬜]
TASK P0-008: Validation             [⬜]
```

### Metrics Dashboard (Update cada 2h)

```
⏱️  STARTUP TIME: 3.2s → ___s (objetivo <1.5s)
🧠 MEMORY USAGE: 287MB → ___MB (objetivo <200MB)
🐛 PRINT STATEMENTS: 89 → ___ (objetivo 0)
🎨 DEPRECATED COLORS: 273 → ___ (objetivo 0)
✅ TESTS PASSING: ___% (objetivo 100%)
```

---

## ⚡ ACCIONES INMEDIATAS

### 🚀 EMPEZAR AHORA (Next 30min)

1. **[AHORA]** Crear branch `fix/critical-p0-issues`
2. **[AHORA]** Abrir `lib/presentation/screens/home_view.dart`
3. **[5min]** Leer código actual del initState()
4. **[25min]** Implementar migración asíncrona
5. **[25min]** Definir plan para completar la API de `AdSenseService` antes de la build web (o deshabilitar monetización web temporalmente)

### 📞 COMUNICACIÓN

**Reportar progreso cada 2 horas**:

- 11:00 - Status HomeView fix
- 13:00 - Status Memory leaks
- 15:00 - Status Sync conflicts
- 17:00 - Status Deprecated code
- 19:00 - Status Final validation

---

## 🎯 SUCCESS CRITERIA PARA HOY

### ✅ MUST HAVE (Non-negotiable)

- [ ] HomeView carga en <1.5s
- [ ] Zero memory leaks críticos
- [ ] Sync no pierde datos
- [ ] Zero print statements
- [ ] All tests pass

### 🎉 NICE TO HAVE (Si hay tiempo)

- [ ] Performance benchmark completo
- [ ] Scripts de validation automatizados
- [ ] Documentation updates

---

**📅 FECHA**: 25/09/2025  
**⏰ TIEMPO TOTAL**: 9 horas  
**🎯 OBJETIVO**: Eliminar todos los P0 críticos  
**📊 SUCCESS RATE ESPERADO**: 100% de tasks P0 completadas

---

_Task list actualizable - Marcar ✅ al completar cada task_
