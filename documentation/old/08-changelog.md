# 8. Historial de Cambios (Changelog)

Este archivo documenta los cambios significativos en cada versión del proyecto **Películas AdMob**.

## [Unreleased]

### 🚀 **CRÍTICO** - Congelamiento HomeView Resuelto (2025-09-25)

#### Añadido

- Carga lazy de secciones de películas por demanda
- Sistema de logging mejorado con LoggerFactory
- Manejo de errores robusto en providers críticos
- Documentación exhaustiva de la solución implementada

#### Corregido

- **CRÍTICO**: Congelamiento de 15-30 segundos antes de mostrar HomeView
- InitialLoadingProvider con dependencias circulares
- Carga progresiva agresiva que bloqueaba UI principal
- MoviesSlideshowProvider sin manejo de errores
- Performance de startup mejorado en 80-90%

#### Cambiado

- HomeView.initState() simplificado (eliminada carga agresiva)
- InitialLoadingProvider ahora retorna false inmediatamente
- Sección de recomendaciones temporalmente desactivada
- UI se muestra inmediatamente, datos cargan bajo demanda

#### Técnico

- Migración parcial StateNotifier → Notifier completada
- Providers optimizados para evitar bloqueos
- Error boundaries implementados
- NuGet instalado para compilación Windows

### Documentación Actualizada (2025-09-25)

- `SOLUCION-CONGELAMIENTO-HOMEVIEW.md` - Detalles técnicos completos
- `CHECKLIST-CONTINUIDAD-POST-CORRECCION.md` - Plan de siguientes pasos
- `PLAN DE CORRECCIÓN INMEDIATA.md` - Estado actualizado
- Auditoría completa revisada

## [3.0.0] - 2025-09-24

### Añadido

- Arquitectura y estructura del proyecto.
- Guías de configuración, desarrollo, pruebas y despliegue.
- Sección de troubleshooting.

### Corregido

- Enlaces rotos en README de la carpeta `documentation`.

## [2.5.1] - 2025-07-15

### Añadido

- Integración de Supabase.

### Corregido

- Ajustes en rutas de navegación.

_Ver más detalles de versiones anteriores en el repositorio._
