# Plan de Limpieza de la Aplicación Flutter - Películas

## Objetivo
Limpiar la aplicación eliminando:
1. Todo el código relacionado con migración
2. Mantener solo TRAKT API con TMDB como respaldo
3. Eliminar logs, pruebas y elementos de debug visibles en la UI
4. Remover código de prueba innecesario

## Fase 1: Análisis y Identificación de Archivos

### 1.1 Archivos de Migración a Eliminar COMPLETAMENTE
- `lib/core/providers/migration_providers.dart`
- `lib/presentation/providers/migration_services_provider.dart`
- `lib/domain/services/background_migration_service.dart`
- `lib/domain/services/migration_monitoring_service.dart`
- `lib/domain/services/migration_scheduler.dart`
- `lib/domain/services/rollback_service.dart`
- `lib/domain/services/migration_logger.dart`
- `lib/domain/services/batch_migration_functions.dart`
- `lib/domain/entities/migration/` (toda la carpeta)
- `lib/domain/entities/migration_state.dart`
- `lib/presentation/screens/migration/` (toda la carpeta)
- `lib/presentation/widgets/migration/` (toda la carpeta)
- `lib/pages/challenge_notifications_page.dart`
- `lib/pages/challenges_page.dart`

### 1.2 Archivos Híbridos a Simplificar
- `lib/infrastructure/repositories/hybrid_movies_repository.dart` → Simplificar a solo TRAKT con TMDB fallback
- `lib/infrastructure/repositories/hybrid_watched_repository.dart` → Simplificar
- `lib/infrastructure/repositories/hybrid_favorites_repository.dart` → Simplificar
- `lib/infrastructure/repositories/hybrid_custom_lists_repository.dart` → Simplificar
- `lib/presentation/providers/hybrid_repositories_provider.dart` → Simplificar

### 1.3 Servicios de Mapeo a Evaluar
- `lib/domain/services/movie_id_mapping_service.dart` → Mantener solo para TRAKT-TMDB

## Fase 2: Limpieza de UI y Elementos de Debug

### 2.1 Elementos UI de Debug/Migración a Remover
**En CustomDrawer:**
- `Administración de Migración` (líneas 295-302)
- `Configuración de Migración` (líneas 303-310)

**Widgets de Debug a Eliminar:**
- `LocalDataIndicator` (widget completo)
- `GuestModeTopBanner` (widget completo)
- Todos los widgets en `lib/presentation/widgets/migration/`
- Elementos de migración en el drawer del menú
- Notificaciones de progreso de migración
- Barras de progreso flotantes de migración

### 2.2 Widgets de Debug a Eliminar
- Widgets de monitoreo de migración
- Indicadores de estado de sincronización
- Botones de prueba en desarrollo
- Logs en tiempo real

## Fase 3: Simplificación de Arquitectura

### 3.1 Providers a Limpiar
- Eliminar todos los providers de migración
- Simplificar providers híbridos
- Mantener solo providers esenciales para TRAKT y TMDB

### 3.2 Servicios a Mantener
- TRAKT API Service (principal)
- TMDB Service (respaldo)
- Movie ID Mapping (solo TRAKT-TMDB)
- Servicios core (auth, cache, logging básico)

## Fase 4: Archivos de Configuración

### 4.1 Documentación a Limpiar
- `docs/` - Eliminar documentos de migración
- Mantener solo documentación esencial

### 4.2 Scripts a Revisar
- `scripts/` - Eliminar scripts de migración y diagnóstico

## Fase 5: Testing y Validación

### 5.1 Tests a Limpiar
- Eliminar tests de migración
- Mantener tests funcionales básicos
- Limpiar `test/` y `tests/` directories

## Plan de Ejecución por Fases

### Fase A: Preparación (5 min)
1. ✅ Crear plan detallado de limpieza
2. Identificar dependencias críticas
3. Verificar estado actual de compilación

### Fase B: Eliminación de Archivos de Migración (15 min)
1. Eliminar carpetas completas:
   - `lib/domain/entities/migration/`
   - `lib/presentation/screens/migration/`
   - `lib/presentation/widgets/migration/`
   - `lib/pages/` (challenge pages)
2. Eliminar archivos individuales de servicios de migración
3. Eliminar providers de migración
4. Verificar compilación básica

### Fase C: Limpieza de UI y Drawer (10 min)
1. Remover elementos de migración del CustomDrawer
2. Eliminar LocalDataIndicator y GuestModeTopBanner
3. Limpiar imports relacionados
4. Verificar UI sin elementos de debug

### Fase D: Simplificación de Repositorios Híbridos (20 min)
1. Simplificar hybrid_movies_repository.dart
2. Simplificar hybrid_watched_repository.dart
3. Simplificar hybrid_favorites_repository.dart
4. Actualizar providers relacionados
5. Mantener solo TRAKT + TMDB fallback

### Fase E: Limpieza de Imports y Referencias (10 min)
1. Buscar y eliminar imports rotos
2. Limpiar referencias a servicios eliminados
3. Actualizar exports en archivos principales

### Fase F: Validación Final (10 min)
1. Ejecutar flutter analyze
2. Probar funcionalidad básica
3. Verificar que TRAKT funciona
4. Confirmar TMDB como fallback
5. Probar navegación sin elementos de migración

## Archivos Críticos a NO Tocar
- `lib/main.dart`
- `lib/config/api_keys.dart`
- `.env` (contiene TRAKT_API_KEY)
- Core services esenciales
- UI principal (screens, widgets principales)

## Resultado Esperado
- Aplicación limpia y organizada
- Solo TRAKT API con TMDB como respaldo
- UI sin elementos de debug
- Código más mantenible
- Mejor rendimiento

## Riesgos y Mitigaciones
- **Riesgo**: Romper funcionalidad existente
- **Mitigación**: Ir por fases, verificar en cada paso
- **Riesgo**: Perder configuración importante
- **Mitigación**: Backup antes de empezar
- **Riesgo**: Dependencias rotas
- **Mitigación**: Verificar imports después de cada eliminación