# 📋 Plantilla de Ejecución de Pruebas Manuales

## 📊 Información de la Sesión de Pruebas

- **Fecha de Ejecución**: _____________________
- **Responsable de Pruebas**: _____________________
- **Versión de la App**: 1.2.1+6
- **Entorno de Prueba**: _____________________
- **Dispositivos Utilizados**: _____________________

## 🎯 Resumen Ejecutivo

| Métrica | Resultado |
|---------|-----------|
| **Total de Casos de Prueba** | ___/20 |
| **Casos Exitosos** | ___/20 |
| **Casos Fallidos** | ___/20 |
| **Bugs Críticos Encontrados** | ___ |
| **Bugs Menores Encontrados** | ___ |
| **Tiempo Total de Ejecución** | ___ horas |

### Estado General
- [ ] ✅ **APROBADO** - Todas las funcionalidades críticas funcionan correctamente
- [ ] ⚠️ **APROBADO CON OBSERVACIONES** - Funciona pero hay issues menores
- [ ] ❌ **RECHAZADO** - Hay problemas críticos que impiden el uso

---

## 🧭 1. PRUEBAS DE NAVEGACIÓN

### TC-NAV-001: Navegación Principal
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Tiempo de ejecución**: _____ min
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-NAV-002: Navegación Detallada de Película
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Tiempo de ejecución**: _____ min
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-NAV-003: Navegación en Mi Biblioteca
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Tiempo de ejecución**: _____ min
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-NAV-004: Navegación con Drawer
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Tiempo de ejecución**: _____ min
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

**Resumen Navegación**: ___/4 casos exitosos

---

## 📺 2. PRUEBAS DE ANUNCIOS

### TC-ADS-001: Anuncios Nativos en Lista
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Tiempo de carga promedio**: _____ segundos
- **Anuncios mostrados**: ___/5 intentos
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ADS-002: Anuncios en Grid
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Tiempo de carga promedio**: _____ segundos
- **Proporción correcta**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ADS-003: Manejo de Errores en Anuncios
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Placeholder mostrado**: [ ] Sí | [ ] No
- **App mantiene funcionalidad**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ADS-004: Anuncios en Web vs Móvil
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Web sin anuncios**: [ ] Confirmado | [ ] No confirmado
- **Móvil con anuncios**: [ ] Confirmado | [ ] No confirmado
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

**Resumen Anuncios**: ___/4 casos exitosos

---

## 💾 3. PRUEBAS DE PERSISTENCIA

### TC-DATA-001: Persistencia de Favoritos
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Marcado inmediato**: [ ] Sí | [ ] No
- **Persiste después de reinicio**: [ ] Sí | [ ] No
- **Sincronización**: [ ] Funciona | [ ] No funciona | [ ] N/A
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-DATA-002: Persistencia de Películas Vistas
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Marcado correcto**: [ ] Sí | [ ] No
- **Persiste entre sesiones**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-DATA-003: Persistencia de Listas Personalizadas
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Creación exitosa**: [ ] Sí | [ ] No
- **Agregar películas**: [ ] Sí | [ ] No
- **Persistencia**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-DATA-004: Caché de Películas y Búsquedas
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Primera búsqueda**: _____ segundos
- **Segunda búsqueda**: _____ segundos
- **Mejora observada**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-DATA-005: Sincronización Multi-dispositivo
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado | [ ] N/A
- **Sync dispositivo 1 → 2**: [ ] Funciona | [ ] No funciona
- **Sync dispositivo 2 → 1**: [ ] Funciona | [ ] No funciona
- **Tiempo de sincronización**: _____ segundos
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

**Resumen Persistencia**: ___/5 casos exitosos

---

## ⚠️ 4. PRUEBAS DE MANEJO DE ERRORES

### TC-ERROR-001: Sin Conexión a Internet
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Mensaje claro mostrado**: [ ] Sí | [ ] No
- **Funciones offline funcionan**: [ ] Sí | [ ] No
- **No crashes**: [ ] Confirmado | [ ] Hubo crashes
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ERROR-002: Errores de API
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Búsqueda sin resultados manejada**: [ ] Sí | [ ] No
- **IDs inválidos manejados**: [ ] Sí | [ ] No
- **Navegación no afectada**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ERROR-003: Validación de Formularios
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Validación de campos vacíos**: [ ] Sí | [ ] No
- **Mensajes claros**: [ ] Sí | [ ] No
- **Límites respetados**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ERROR-004: Memoria y Performance
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Fluidez mantenida**: [ ] Sí | [ ] No
- **Sin crashes por memoria**: [ ] Confirmado | [ ] Hubo crashes
- **Animaciones suaves**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

### TC-ERROR-005: Estados de Carga
- **Estado**: [ ] ✅ Pasa | [ ] ❌ Falla | [ ] ⏭️ No ejecutado
- **Estados visibles**: [ ] Todos | [ ] Algunos | [ ] Ninguno
- **Sin pantallas en blanco**: [ ] Confirmado | [ ] Hubo pantallas blancas
- **Claros para usuario**: [ ] Sí | [ ] No
- **Notas**: _________________________________
- **Issues encontrados**: ____________________

**Resumen Manejo de Errores**: ___/5 casos exitosos

---

## 📊 MÉTRICAS DE RENDIMIENTO

### Tiempos Medidos

| Métrica | Objetivo | Resultado | ✅/❌ |
|---------|----------|-----------|--------|
| Inicio de app | < 3 seg | _____ seg | ___ |
| Navegación entre pantallas | < 500ms | _____ ms | ___ |
| Carga de lista de películas | < 2 seg | _____ seg | ___ |
| Búsqueda de películas | < 1 seg | _____ seg | ___ |
| Carga de imagen | < 2 seg | _____ seg | ___ |
| Carga de anuncios | < 3 seg | _____ seg | ___ |

### Análisis de Performance
- **Rendimiento General**: [ ] Excelente | [ ] Bueno | [ ] Regular | [ ] Malo
- **Áreas de Mejora**: _________________________________
- **Cuellos de Botella Identificados**: _________________________________

---

## 🐛 BUGS ENCONTRADOS

### Bug #1
- **ID**: BUG-[FECHA]-001
- **Título**: _________________________________
- **Severidad**: [ ] Critical | [ ] High | [ ] Medium | [ ] Low
- **Caso de Prueba**: _________________________________
- **Descripción**: _________________________________
- **Pasos para Reproducir**: 
  1. _________________________________
  2. _________________________________
  3. _________________________________
- **Esperado vs Actual**: _________________________________
- **Frecuencia**: [ ] Siempre | [ ] A veces | [ ] Rara vez

### Bug #2
- **ID**: BUG-[FECHA]-002
- **Título**: _________________________________
- **Severidad**: [ ] Critical | [ ] High | [ ] Medium | [ ] Low
- **Caso de Prueba**: _________________________________
- **Descripción**: _________________________________

### [Agregar más bugs según sea necesario]

---

## 📝 OBSERVACIONES GENERALES

### Aspectos Positivos
- _________________________________
- _________________________________
- _________________________________

### Áreas de Mejora
- _________________________________
- _________________________________
- _________________________________

### Recomendaciones
- _________________________________
- _________________________________
- _________________________________

---

## ✅ DECISIÓN FINAL

### Criterios de Aceptación
- [ ] **Funcionalidad crítica**: 100% de casos críticos pasan
- [ ] **Performance**: 90% de métricas dentro de objetivo
- [ ] **Estabilidad**: < 5% de operaciones resultan en error
- [ ] **UX**: Navegación fluida sin lag perceptible

### Recomendación
- [ ] ✅ **APROBAR PARA PRODUCCIÓN** - Todas las funcionalidades críticas funcionan
- [ ] ⚠️ **APROBAR CON RESERVAS** - Funciona pero requiere seguimiento de issues menores
- [ ] ❌ **NO APROBAR** - Existen problemas críticos que deben resolverse

### Próximos Pasos
1. _________________________________
2. _________________________________
3. _________________________________

---

**Ejecutado por**: _____________________
**Fecha**: _____________________
**Duración total**: _____ horas
**Firma**: _____________________