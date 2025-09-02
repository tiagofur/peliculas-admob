# 📋 Checklist Manual de Verificación: Sincronización en Tiempo Real (Supabase Realtime)

## 🎯 Objetivos de Verificación

Este checklist implementa los requisitos específicos del **Issue #69** para verificar exhaustivamente la funcionalidad de sincronización en tiempo real usando Supabase Realtime.

### Criterios de Éxito
- ✅ **Latencia objetivo**: < 1.5 segundos desde evento hasta UI
- ✅ **Resolución de conflictos**: Last-write-wins usando `updated_at`
- ✅ **Estabilidad**: Soporte robusto para múltiples usuarios simultáneos
- ✅ **Cobertura**: Watchlist y ratings completamente verificados

---

## 📱 Preparación del Entorno de Pruebas

### Dispositivos Requeridos (Mínimo 2)
- [ ] **Dispositivo 1**: Navegador web (Chrome/Firefox)
- [ ] **Dispositivo 2**: Aplicación Android/iOS 
- [ ] **Dispositivo 3** (Opcional): Navegador adicional o dispositivo móvil
- [ ] **Dispositivo 4** (Opcional): Desktop app (Windows/macOS/Linux)

### Configuración Inicial
- [ ] Todos los dispositivos conectados a la misma red
- [ ] Usuario de prueba autenticado en todos los dispositivos
- [ ] Dashboard de métricas en tiempo real abierto en un dispositivo
- [ ] Logs de desarrollo activados
- [ ] Verificar conectividad a Supabase

```bash
# Activar dashboard de métricas
flutter run --debug
# Navegar a: /debug/realtime-dashboard
```

---

## 🔄 Sección 1: Verificación de Latencia (< 1.5s)

### 1.1 Test de Latencia Básica - Watchlist

**Objetivo**: Verificar que los eventos de watchlist se reflejan en UI en menos de 1.5 segundos.

#### Procedimiento:
1. **Dispositivo A**: Abrir dashboard de métricas en tiempo real
2. **Dispositivo B**: Abrir lista de películas
3. **Dispositivo A**: Agregar película "Fight Club" a watchlist
4. **Cronómetro**: Iniciar al hacer clic en "Agregar"
5. **Dispositivo B**: Observar actualización automática
6. **Cronómetro**: Detener cuando aparezca en Dispositivo B

#### Criterios de Verificación:
- [ ] **Latencia medida**: _____ ms (debe ser < 1500ms)
- [ ] **Actualización automática**: Sin necesidad de refrescar página
- [ ] **Dashboard muestra evento**: Evento registrado en métricas
- [ ] **Sin errores**: No hay errores en logs

#### Repetir para:
- [ ] **Eliminar película de watchlist**: Latencia _____ ms
- [ ] **Actualizar prioridad**: Latencia _____ ms
- [ ] **Agregar película desde búsqueda**: Latencia _____ ms

### 1.2 Test de Latencia Básica - Ratings

#### Procedimiento:
1. **Dispositivo A**: Calificar película con 4 estrellas
2. **Cronómetro**: Iniciar al confirmar calificación
3. **Dispositivo B**: Observar actualización en detalles de película
4. **Cronómetro**: Detener cuando aparezca calificación

#### Criterios de Verificación:
- [ ] **Latencia medida**: _____ ms (debe ser < 1500ms)
- [ ] **Calificación visible**: Rating actualizado correctamente
- [ ] **Dashboard muestra evento**: Evento de rating registrado
- [ ] **Promedio actualizado**: Si hay múltiples ratings, promedio correcto

#### Repetir para:
- [ ] **Actualizar rating existente**: Latencia _____ ms
- [ ] **Eliminar rating**: Latencia _____ ms
- [ ] **Agregar reseña con rating**: Latencia _____ ms

### 1.3 Test de Latencia con Múltiples Operaciones

#### Procedimiento:
1. **Dispositivo A**: Realizar secuencia rápida:
   - Agregar 3 películas a watchlist
   - Calificar 2 películas
   - Eliminar 1 película de watchlist
2. **Dispositivo B y C**: Observar todas las actualizaciones
3. **Dashboard**: Monitorear latencia de cada operación

#### Criterios de Verificación:
- [ ] **Todas las operaciones < 1.5s**: Cada evento individual
- [ ] **Orden preservado**: Operaciones aparecen en orden correcto
- [ ] **Sin pérdida de eventos**: Todas las 6 operaciones visibles
- [ ] **Throttling efectivo**: No saturación de eventos

---

## ⚔️ Sección 2: Verificación de Resolución de Conflictos

### 2.1 Test de Conflicto Simple - Last Write Wins

**Objetivo**: Verificar que la estrategia last-write-wins funciona correctamente usando `updated_at`.

#### Escenario de Conflicto:
1. **Dispositivo A** y **B**: Abrir misma película (ej: "Inception")
2. **Sincronización**: Desconectar temporalmente Dispositivo B de internet
3. **Dispositivo A**: Agregar a watchlist con prioridad "Alta"
4. **Dispositivo B** (offline): Agregar a watchlist con prioridad "Media"
5. **Reconexión**: Conectar Dispositivo B a internet
6. **Observar**: ¿Cuál prioridad prevalece?

#### Criterios de Verificación:
- [ ] **Conflicto detectado**: Dashboard muestra detección de conflicto
- [ ] **Resolución automática**: Sin intervención manual requerida
- [ ] **Last-write-wins**: La operación más reciente (por `updated_at`) prevalece
- [ ] **Consistencia**: Ambos dispositivos muestran mismo resultado final
- [ ] **Log de conflicto**: Conflict resolver registra la resolución

#### Información del Conflicto:
- **Timestamp Dispositivo A**: _____________
- **Timestamp Dispositivo B**: _____________
- **Ganador esperado**: ________________
- **Resultado real**: ________________
- [ ] **✅ Resolución correcta**

### 2.2 Test de Conflicto Complejo - Múltiples Dispositivos

#### Escenario:
1. **3+ Dispositivos**: Todos abrir misma película
2. **Simultaneidad**: En intervalo de 5 segundos:
   - Dispositivo A: Rating 5 estrellas
   - Dispositivo B: Rating 3 estrellas  
   - Dispositivo C: Rating 4 estrellas
3. **Observar**: Resolución de conflicto múltiple

#### Criterios de Verificación:
- [ ] **Conflicto múltiple detectado**: Dashboard registra múltiples escrituras
- [ ] **Resolución determinística**: Siempre mismo ganador con mismos timestamps
- [ ] **Timestamp más reciente gana**: Verificar en logs cual fue último
- [ ] **Integridad de datos**: No corrupción ni estados inconsistentes

### 2.3 Test de Validación de `updated_at`

#### Procedimiento:
1. **Dashboard**: Abrir herramientas de desarrollo de conflictos
2. **Ejecutar**: Test suite automática de conflictos
3. **Verificar**: Todos los objetos tienen `updated_at` válido

```bash
# Ejecutar test suite de conflictos
flutter test test/conflict_resolution_verifier_test.dart
```

#### Criterios de Verificación:
- [ ] **Todos los objetos tienen `updated_at`**: 100% de cobertura
- [ ] **Timestamps válidos**: No timestamps futuros ni muy antiguos
- [ ] **Resolución correcta**: 100% de tests pasan
- [ ] **Tiempo de resolución**: < 1 segundo promedio

---

## 👥 Sección 3: Verificación de Múltiples Usuarios Simultáneos

### 3.1 Test de Estabilidad - 5 Usuarios Concurrentes

**Objetivo**: Verificar estabilidad con múltiples usuarios realizando operaciones simultáneas.

#### Preparación:
- [ ] **5 dispositivos/sesiones** configurados con usuarios diferentes
- [ ] **Dashboard de métricas** abierto para monitoreo
- [ ] **Lista de 20 películas** preparada para testing

#### Procedimiento Coordinado:
1. **Minuto 1**: Todos los usuarios agregan 3 películas a watchlist
2. **Minuto 2**: Todos califican 2 películas diferentes  
3. **Minuto 3**: Todos eliminan 1 película de watchlist
4. **Minuto 4**: Todos actualizan prioridades de 2 películas
5. **Minuto 5**: Actividad libre - cada usuario hace operaciones aleatorias

#### Métricas a Monitorear:
- [ ] **Score de rendimiento**: Mantener > 80% durante test
- [ ] **Eventos procesados**: 100% de eventos recibidos procesados
- [ ] **Latencia promedio**: < 1.5s durante toda la prueba
- [ ] **Errores de conexión**: 0 desconexiones inesperadas
- [ ] **Conflictos resueltos**: 100% de conflictos resueltos correctamente

#### Resultados:
- **Operaciones totales**: _____
- **Latencia promedio**: _____ ms
- **Conflictos detectados**: _____
- **Conflictos resueltos**: _____
- **Score de rendimiento final**: _____%
- [ ] **✅ Test de estabilidad exitoso**

### 3.2 Test de Estrés - Operaciones Masivas

#### Procedimiento:
1. **Automatización**: Ejecutar test suite de estrés
2. **Monitoreo**: Observar dashboard durante 10 minutos
3. **Verificación**: Sistema mantiene estabilidad

```bash
# Ejecutar test de estrés
flutter test test/multi_user_stress_test.dart
```

#### Criterios de Verificación:
- [ ] **Sin degradación**: Latencia no aumenta >50% bajo carga
- [ ] **Sin pérdida de eventos**: 100% de eventos procesados
- [ ] **Memoria estable**: Sin leaks de memoria en 10 minutos
- [ ] **Reconexiones automáticas**: Recovery automático de desconexiones

---

## 📊 Sección 4: Verificación de Dashboard y Métricas

### 4.1 Validación de Dashboard en Tiempo Real

#### Elementos a Verificar:
- [ ] **Estado del sistema**: Verde/estable durante operaciones normales
- [ ] **Latencia en vivo**: Gráfico actualiza en tiempo real
- [ ] **Eventos por segundo**: Muestra throughput actual
- [ ] **Conflictos detectados**: Contador actualiza correctamente
- [ ] **Alertas de latencia**: Alertas rojas cuando > 1.5s

#### Prueba de Alertas:
1. **Simular alta latencia**: Desconectar/reconectar red
2. **Verificar alertas**: Dashboard debe mostrar alertas rojas
3. **Recovery**: Alertas deben desaparecer al normalizarse

### 4.2 Validación de Métricas por Entidad

#### Watchlist Metrics:
- [ ] **Operaciones sync**: Contador incrementa con cada operación
- [ ] **Eventos realtime**: Registro de INSERT/UPDATE/DELETE
- [ ] **Conflictos**: Específicos de watchlist registrados
- [ ] **Latencia promedio**: Específica para operaciones watchlist

#### Ratings Metrics:
- [ ] **Operaciones sync**: Independientes de watchlist
- [ ] **Eventos realtime**: Específicos de ratings
- [ ] **Tiempo de procesamiento**: Medición por fase
- [ ] **Tasa de éxito**: 100% en condiciones normales

---

## 🔍 Sección 5: Verificación de Casos Edge

### 5.1 Reconexión Automática

#### Procedimiento:
1. **Durante operación activa**: Desconectar internet por 30 segundos
2. **Reconectar**: Automáticamente
3. **Verificar**: Recovery completo

#### Criterios:
- [ ] **Detección de desconexión**: < 10 segundos
- [ ] **Reconexión automática**: Sin intervención manual
- [ ] **Sync de cambios offline**: Todos los cambios se aplican
- [ ] **Sin duplicados**: No se crean entradas duplicadas

### 5.2 Timestamps Muy Cercanos

#### Procedimiento:
1. **Script automatizado**: Generar eventos con timestamps idénticos o muy cercanos
2. **Verificar**: Resolución determinística

```bash
# Test de timestamps cercanos
flutter test test/close_timestamp_conflict_test.dart
```

#### Criterios:
- [ ] **Resolución determinística**: Mismo resultado en múltiples ejecuciones
- [ ] **Sin race conditions**: No comportamiento aleatorio
- [ ] **Fallback robusto**: Si timestamps idénticos, usar criterio secundario

### 5.3 Validación de Integridad de Datos

#### Después de Todos los Tests:
1. **Base de datos Supabase**: Verificar consistencia
2. **Caché local**: Comparar con datos remotos
3. **Sin corrupción**: Todos los datos válidos

#### Checklist Final:
- [ ] **No duplicados**: En watchlist ni ratings
- [ ] **Referencias válidas**: Todos los movie_id existen
- [ ] **Timestamps coherentes**: created_at < updated_at
- [ ] **Integridad referencial**: Foreign keys válidas

---

## ✅ Resumen de Resultados

### Métricas Globales Alcanzadas:
- **Latencia promedio watchlist**: _____ ms (objetivo: < 1500ms)
- **Latencia promedio ratings**: _____ ms (objetivo: < 1500ms)
- **Conflictos resueltos correctamente**: ____% (objetivo: 100%)
- **Estabilidad con 5+ usuarios**: ____% (objetivo: > 90%)
- **Eventos procesados sin pérdida**: ____% (objetivo: 100%)

### Tests Automatizados:
- [ ] `multi_user_stress_test.dart`: **PASSED** / FAILED
- [ ] `conflict_resolution_verifier_test.dart`: **PASSED** / FAILED  
- [ ] `latency_measurement_test.dart`: **PASSED** / FAILED
- [ ] `realtime_sync_complex_test.dart`: **PASSED** / FAILED

### Cumplimiento de Requisitos del Issue #69:
- [ ] **✅ Listeners capturan todos los eventos relevantes**
- [ ] **✅ UI se actualiza sin retrasos perceptibles (< 1.5s)**
- [ ] **✅ Resolución de conflictos last-write-wins validada**
- [ ] **✅ Estabilidad con múltiples usuarios simultáneos**
- [ ] **✅ Watchlist y ratings completamente verificados**

---

## 🚨 Troubleshooting

### Problemas Comunes y Soluciones:

#### Latencia > 1.5s
- **Verificar red**: Ping a Supabase
- **Revisar throttling**: Configuración en RealtimeThrottleService
- **Logs**: Buscar cuellos de botella en logs

#### Conflictos no resueltos
- **Timestamps**: Verificar sincronización de relojes
- **Logs de conflictos**: Revisar ConflictResolutionVerifier
- **RLS Supabase**: Verificar permisos de tablas

#### Dashboard no actualiza
- **WebSocket**: Verificar conexión realtime
- **Permisos**: Verificar acceso a canales
- **Caché**: Limpiar caché del navegador

#### Eventos perdidos
- **Conexión**: Verificar estabilidad de red
- **Filters**: Revisar filtros de usuario en subscriptions
- **Logs**: Verificar RealtimeListenerService logs

---

## 📝 Documentación de Ejecución

**Fecha de ejecución**: _______________  
**Ejecutado por**: _______________  
**Entorno**: Development / Staging / Production  
**Versión de la app**: _______________  

### Notas adicionales:
```
[Espacio para notas específicas de la ejecución]




```

### Archivos de evidencia generados:
- [ ] Screenshots de dashboard durante tests
- [ ] Logs de desarrollo con timestamps
- [ ] Reportes de métricas exportados
- [ ] Videos de tests manuales (opcional)

**Estado final**: ✅ PASSED / ❌ FAILED / ⚠️ PARCIAL

---

*Este checklist garantiza una verificación exhaustiva de la sincronización en tiempo real según los requisitos específicos del Issue #69.*