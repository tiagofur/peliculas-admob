# 🌐 Guía de Pruebas Manuales Multi-Dispositivo para Sincronización

## Resumen

Esta guía detalla los pasos específicos para realizar pruebas manuales de sincronización entre múltiples dispositivos, complementando la SYNC_VERIFICATION_CHECKLIST.md con escenarios prácticos.

## 🎯 Objetivos

- Validar sincronización en tiempo real entre dispositivos
- Verificar resolución de conflictos multi-dispositivo  
- Comprobar funcionalidad offline y recuperación
- Asegurar latencia ≤ 3 segundos en operaciones críticas

## 📱 Configuración del Entorno Multi-Dispositivo

### Dispositivos Recomendados
1. **Dispositivo Principal (Web)**: Navegador Chrome/Firefox
2. **Dispositivo Secundario (Android)**: Teléfono o emulador
3. **Dispositivo Opcional (iOS)**: iPhone o simulador
4. **Monitoreo**: Supabase Dashboard abierto en otra pestaña

### Preparación Inicial
```bash
# En cada dispositivo:
1. Limpiar datos locales de la app
2. Verificar conectividad a internet estable
3. Confirmar que la app inicia correctamente
4. Login con la misma cuenta de usuario
```

## 🔄 Escenarios de Prueba Manual

### Escenario 1: Sincronización Básica de Favoritos

#### Paso a Paso
1. **Dispositivo Web**:
   - Navegar a una película (ej: "The Matrix")
   - Agregar a favoritos ❤️
   - **⏱️ Verificar**: Operación completa en ≤ 3 segundos
   - **📊 Supabase**: Confirmar entrada en tabla `user_favorites`

2. **Dispositivo Android** (inmediatamente):
   - Abrir sección de favoritos
   - **⏱️ Verificar**: "The Matrix" aparece en ≤ 3 segundos
   - **✅ Validar**: Datos completos (título, poster, fecha)

3. **Resultado Esperado**:
   - ✅ Película sincronizada en ambos dispositivos
   - ✅ Sin duplicados
   - ✅ Latencia total ≤ 3 segundos

#### Logs a Verificar
```
Web Console:
🔄 Iniciando sincronización para usuario: [email]
📤 Favorito agregado: movie_id=12345
✅ Sincronización completada

Android Logs:
📱 Recibido cambio en favoritos
🔄 Actualizando UI con nuevos datos
✅ Favorito sincronizado: The Matrix
```

### Escenario 2: Eliminación Cross-Device

#### Paso a Paso
1. **Dispositivo Android**:
   - Ir a favoritos
   - Eliminar "The Matrix" de favoritos 🗑️
   - **⏱️ Medir tiempo**: Desde tap hasta confirmación

2. **Dispositivo Web** (sin refresh manual):
   - **⏱️ Verificar**: "The Matrix" desaparece en ≤ 3 segundos
   - **📊 Supabase**: Confirmar eliminación en `user_favorites`

3. **Resultado Esperado**:
   - ✅ Eliminación reflejada en ambos dispositivos
   - ✅ Sin rastros de datos huérfanos
   - ✅ Operación completada en ≤ 3 segundos

### Escenario 3: Operaciones Simultáneas

#### Configuración
Dos personas con acceso a dispositivos diferentes, misma cuenta de usuario.

#### Paso a Paso
1. **Coordinación**: Contar "3, 2, 1, ¡YA!"

2. **Dispositivo Web** (simultáneo):
   - Agregar "Inception" a favoritos

3. **Dispositivo Android** (simultáneo):
   - Agregar "Interstellar" a favoritos

4. **Verificación** (después de 5 segundos):
   - **Web**: Debe mostrar ambas películas
   - **Android**: Debe mostrar ambas películas
   - **Supabase**: Debe tener ambas entradas sin duplicados

#### Resultado Esperado
- ✅ Ambas operaciones exitosas
- ✅ Sin conflictos o pérdida de datos
- ✅ Estado final consistente en todos los dispositivos

### Escenario 4: Modo Offline y Recuperación

#### Paso a Paso

**Fase 1: Operaciones Offline**
1. **Dispositivo Android**:
   - Desactivar WiFi y datos móviles ✈️
   - Agregar 3 películas a favoritos:
     - "Dune"
     - "Blade Runner 2049" 
     - "Mad Max: Fury Road"
   - **✅ Verificar**: Operaciones se muestran como "pendientes" o en cola

2. **Dispositivo Web** (online):
   - Agregar "The Dark Knight" a favoritos
   - **✅ Verificar**: Sincronización normal

**Fase 2: Recuperación**
3. **Dispositivo Android**:
   - Reactivar conectividad 📶
   - **⏱️ Medir**: Tiempo hasta completar sincronización
   - **✅ Verificar**: Las 3 películas offline aparecen como sincronizadas

4. **Dispositivo Web**:
   - **✅ Verificar**: Las 3 películas de Android aparecen en favoritos
   - **✅ Verificar**: "The Dark Knight" sigue presente

#### Resultado Esperado
- ✅ Todas las operaciones offline se aplican correctamente
- ✅ Sin pérdida de datos
- ✅ Recuperación completa en ≤ 10 segundos
- ✅ Estado final: 4 películas en favoritos

### Escenario 5: Conflicto de Eliminación vs Adición

#### Configuración
Simular conflicto realista entre dispositivos.

#### Paso a Paso
1. **Preparación**:
   - Ambos dispositivos tienen "Avatar" en favoritos

2. **Dispositivo Web** (offline simulado):
   - Desconectar temporalmente
   - Eliminar "Avatar" de favoritos

3. **Dispositivo Android** (online):
   - Agregar calificación 5⭐ a "Avatar"

4. **Reconexión Web**:
   - Reconectar dispositivo web
   - **⏱️ Medir**: Tiempo de resolución de conflicto

#### Resultado Esperado
- ✅ Resolución de conflicto según política (eliminación gana vs última operación)
- ✅ Estado final consistente en ambos dispositivos
- ✅ Sin datos corruptos o inconsistencias

### Escenario 6: Listas Personalizadas Multi-Device

#### Paso a Paso
1. **Dispositivo Web**:
   - Crear nueva lista "Películas de Terror" 👻
   - Agregar 2 películas: "The Conjuring", "Hereditary"

2. **Dispositivo Android**:
   - **✅ Verificar**: Lista aparece en ≤ 3 segundos
   - Agregar "Get Out" a la misma lista
   - Reordenar películas (cambiar orden)

3. **Dispositivo Web**:
   - **✅ Verificar**: "Get Out" aparece en la lista
   - **✅ Verificar**: Orden actualizado correctamente

#### Resultado Esperado
- ✅ Lista sincronizada con todos los cambios
- ✅ Orden preservado correctamente
- ✅ Operaciones complejas (crear, agregar, reordenar) funcionan

### Escenario 7: Alto Volumen de Operaciones

#### Paso a Paso
1. **Dispositivo Web**:
   - Agregar 10 películas a favoritos rápidamente (una tras otra)
   - **⏱️ Medir**: Tiempo total

2. **Dispositivo Android**:
   - **✅ Verificar**: Las 10 películas aparecen progresivamente
   - **⏱️ Verificar**: Cada película aparece en ≤ 3 segundos de su adición

3. **Validación Final**:
   - **Ambos dispositivos**: Contar total de favoritos
   - **Supabase**: Verificar 10 entradas sin duplicados

#### Resultado Esperado
- ✅ Todas las operaciones se procesan correctamente
- ✅ Sin degradación significativa de rendimiento
- ✅ Estado final consistente

## 📊 Métricas y Logging durante Pruebas

### Métricas a Capturar
- **Latencia de Sync**: Tiempo desde operación hasta aparición en otro dispositivo
- **Tiempo de Recuperación Offline**: Desde reconexión hasta sincronización completa
- **Tasa de Éxito**: Porcentaje de operaciones exitosas
- **Tiempo de Resolución de Conflictos**: Duración de resolución automática

### Logs Críticos a Monitorear

**Dispositivo Web (Console)**:
```javascript
🔄 Iniciando sincronización para usuario: user@example.com
📤 Operación CRUD: add_favorite, movie_id: 12345
⏱️ Latencia: 1.2s
✅ Sincronización completada
```

**Dispositivo Android (Logcat)**:
```
I/SyncService: 📱 Datos remotos recibidos: 1 favorito nuevo
I/RealtimeListener: 🔄 Procesando actualización en tiempo real
I/UI: ✅ Interfaz actualizada con nuevos datos
```

**Supabase (Realtime)**:
```sql
-- Verificar en SQL Editor:
SELECT * FROM user_favorites 
WHERE user_id = '[user_uuid]' 
ORDER BY created_at DESC 
LIMIT 10;
```

## 🚨 Casos de Error y Troubleshooting

### Error: Sincronización Lenta (> 3s)
**Síntomas**:
- Operaciones tardan más de 3 segundos en aparecer en otro dispositivo

**Diagnóstico**:
1. Verificar conectividad de red en ambos dispositivos
2. Revisar logs de Supabase para latencia de base de datos
3. Comprobar si hay operaciones en cola acumuladas

**Logs a Revisar**:
```
⚠️ Latencia alta detectada: 5.2s
🔍 Verificar: conectividad de red, servidor Supabase
```

### Error: Datos Duplicados
**Síntomas**:
- Misma película aparece múltiples veces en favoritos

**Diagnóstico**:
1. Verificar logs de conflict resolution
2. Revisar unique constraints en Supabase
3. Verificar implementación de merge logic

**Solución**:
```sql
-- Limpiar duplicados en Supabase:
DELETE FROM user_favorites a USING user_favorites b 
WHERE a.id > b.id 
AND a.user_id = b.user_id 
AND a.movie_id = b.movie_id;
```

### Error: Fallos en Modo Offline
**Síntomas**:
- Operaciones offline no se aplican al reconectar

**Diagnóstico**:
1. Verificar PersistentSyncQueue en logs
2. Comprobar almacenamiento local disponible
3. Revisar retry logic

**Logs a Revisar**:
```
❌ Error en cola offline: Storage full
🔄 Reintentando operación: attempt 2/3
✅ Operación offline recuperada exitosamente
```

## 📋 Template de Reporte de Prueba Manual

### Información General
- **Fecha**: ___________
- **Tester**: ___________
- **Dispositivos Usados**: ___________
- **Versión de la App**: ___________

### Resultados por Escenario

#### Escenario 1: Sincronización Básica
- **Status**: ✅ / ❌
- **Latencia Promedio**: _____ segundos
- **Observaciones**: _________________

#### Escenario 2: Eliminación Cross-Device
- **Status**: ✅ / ❌
- **Latencia Promedio**: _____ segundos
- **Observaciones**: _________________

#### Escenario 3: Operaciones Simultáneas
- **Status**: ✅ / ❌
- **Conflictos Detectados**: _____
- **Resolución Exitosa**: ✅ / ❌
- **Observaciones**: _________________

#### Escenario 4: Modo Offline
- **Status**: ✅ / ❌
- **Operaciones Offline**: _____
- **Tiempo de Recuperación**: _____ segundos
- **Pérdida de Datos**: ✅ / ❌
- **Observaciones**: _________________

#### Escenario 5: Resolución de Conflictos
- **Status**: ✅ / ❌
- **Tipo de Conflicto**: _____
- **Resolución Correcta**: ✅ / ❌
- **Observaciones**: _________________

#### Escenario 6: Listas Personalizadas
- **Status**: ✅ / ❌
- **Operaciones Complejas**: ✅ / ❌
- **Preservación de Orden**: ✅ / ❌
- **Observaciones**: _________________

#### Escenario 7: Alto Volumen
- **Status**: ✅ / ❌
- **Operaciones Procesadas**: _____ / _____
- **Degradación de Rendimiento**: ✅ / ❌
- **Observaciones**: _________________

### Métricas Globales
- **Latencia Promedio Global**: _____ segundos
- **Tasa de Éxito**: _____%
- **Errores Críticos**: _____
- **Tiempo Total de Pruebas**: _____ minutos

### Observaciones Generales
_Documentar cualquier comportamiento inesperado, problemas de usabilidad, o sugerencias de mejora._

### Recomendaciones
_Acciones sugeridas basadas en los resultados de las pruebas._

---

**Nota**: Esta guía debe ejecutarse después de que todos los tests automatizados pasen correctamente. Las pruebas manuales validan la experiencia real del usuario en condiciones de uso típicas.