# Gestión de Listas Personalizadas (Opción A)

> **Versión:** Septiembre 2025 \
> **Responsable:** Equipo de listas personalizadas \
> **Estado:** Activo

## 1. Resumen Ejecutivo

La implementación **Opción A** consolida la experiencia de listas en Películas
al enfocarse exclusivamente en listas creadas por la persona usuaria. Las
antiguas listas predeterminadas ("Ver más tarde", "Favoritas", etc.) siguen
existiendo en su módulo original, pero dejan de replicarse automáticamente en la
sección de listas personalizadas. Con esta migración conseguimos:

- UI más simple y directa, centrada en colecciones creadas por el usuario.
- Menor complejidad de sincronización (no se generan listas duplicadas en Supabase).
- Mejor control sobre la voz de la interfaz y los nombres de cada lista.
- Fundamento claro para lanzar recomendaciones y plantillas dinámicas en el
  futuro.

## 2. Alcance Funcional

| Elemento                              | Estado con Opción A                                          |
| ------------------------------------- | ------------------------------------------------------------ |
| Listas predeterminadas (core)         | Se mantienen en sus vistas dedicadas.                        |
| Listas predeterminadas en "Lists"     | **Eliminadas** (solo quedan listas custom).                  |
| Creación automática al iniciar sesión | **Deshabilitada**.                                           |
| Sugerencias rápidas                   | **Nueva** experiencia con chips accionables.                 |
| Métricas iniciales                    | Header con contador de listas, activas y total de películas. |
| Menú contextual                       | Acciones disponibles solo para listas custom.                |

## 3. Cambios Técnicos Clave

### 3.1 Repositorio (`CustomListsRepositoryImpl`)

- `getDefaultLists` y `initializeDefaultLists` ahora retornan sin hacer nada y
  registran el comportamiento vía `AppLogger`.
- No se crean registros en Supabase para listas predeterminadas; esto elimina
  duplicidad y reduce costos de sincronización.

### 3.2 Proveedores Riverpod

- `auto_default_lists_provider.dart` convierte la lógica de arranque en una
  operación no-op para usuarios autenticados.
- `custom_lists_providers.dart` mantiene la API pública, pero al consultar
  `defaultListsProvider` obtenemos una lista vacía, garantizando compatibilidad
  con pantallas legadas.

### 3.3 UI (`CustomListsView`)

- Reemplazo total del TabBar anterior por una única lista enfocada en contenido
  personalizado.
- Nuevo módulo de estadísticas rápidas con tres KPIs (listas totales, activas y
  total de películas almacenadas).
- Chips de sugerencias (`_ListSuggestion`) que precargan nombre, descripción,
  emoji y color en el diálogo de creación.
- Refuerzo visual del branding con tarjetas coloreadas y anuncios ubicados de
  forma estratégica (nativo tras la 4.ª lista y banner al final).
- Diálogo de creación ahora valida en caliente y genera un UUID con `package:uuid`.

## 4. Experiencia de Usuario

1. **Crear lista:** desde app bar o estado vacío, se abre el nuevo diálogo con
   validación inmediata. Las sugerencias rellenan el formulario con un toque.
2. **Explorar listas:** las tarjetas se ordenan alfabéticamente; se muestra
   emoji, descripción, número de películas y fecha de actualización relativa.
3. **Acciones:** el menú contextual sigue ofreciendo editar/duplicar/vaciar/
   eliminar (los handlers finales se conectarán con el notifier en una fase
   posterior).
4. **Sincronización:** `RefreshIndicator` ejecuta invalidación de providers y
   recarga asíncrona del repositorio.

## 5. Consideraciones de Migración

- Personas con listas existentes no requieren pasos manuales; los datos
  personalizados se mantienen intactos.
- Las listas predeterminadas existentes en Supabase dejan de mostrarse en la
  vista, pero se conservan en caso de que otra parte del producto las utilice.
- Si una persona usuaria tenía listas locales sin sincronizar, el repositorio
  las conserva gracias a `_saveListsLocally`.

## 6. Validaciones Recomendadas

Ejecutar antes de crear PR:

```powershell
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

> Nota: a septiembre 2025 el análisis todavía reporta métodos faltantes en el
> subsistema de AdSense. Se priorizará una refactorización específica de esa
> capa antes de cerrar la historia.

## 7. Próximos Pasos Sugeridos

1. Conectar el menú contextual con `ListActions` para habilitar editar/
   duplicar/eliminar en producción.
2. Extender `_suggestions` para que se nutra de analítica y contenido editorial.
3. Añadir pruebas de golden y de integración centradas en el nuevo layout.
4. Documentar escenario de fallback cuando Supabase no está disponible
   (actualmente mostramos snackbars genéricos).

---

**Contacto:** `#equipo-listas` en Slack o abre un issue con la etiqueta
`lists-option-a`.
