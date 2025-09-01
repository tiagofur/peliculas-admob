# ✅ Checklist de Pruebas Funcionales Rápidas

## 🎯 Información de la Sesión
- **Fecha**: ________________
- **Tester**: ________________
- **Versión**: 1.2.1+6
- **Plataforma**: [ ] Android | [ ] iOS | [ ] Web | [ ] Desktop
- **Duración**: ________________

---

## 🚀 Pruebas de Humo (5 minutos)
*Verificación básica de que la aplicación funciona*

### Inicio y Navegación Básica
- [ ] La app se abre sin crashes
- [ ] Splash screen aparece y desaparece correctamente
- [ ] Pantalla principal carga con contenido
- [ ] Navegación inferior funciona (4 pestañas)
- [ ] Drawer lateral se abre y cierra

### Funcionalidad Crítica
- [ ] Lista de películas se muestra
- [ ] Búsqueda básica funciona
- [ ] Navegación a detalles de película
- [ ] Botón de regreso funciona
- [ ] No hay errores visibles en pantalla

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 🧭 Navegación Completa (10 minutos)

### Navegación Principal
- [ ] **Inicio** → Carga películas populares/trending
- [ ] **Mi Biblioteca** → Acceso a favoritas/vistas/listas
- [ ] **Estadísticas** → Dashboard de estadísticas del usuario
- [ ] **Streaming** → Dashboard de plataformas de streaming
- [ ] Todas las transiciones son fluidas (< 500ms)

### Navegación Detallada
- [ ] Película → Detalles completos
- [ ] Detalles → Regreso a lista
- [ ] Búsqueda → Resultados → Detalles
- [ ] Mi Biblioteca → Favoritas
- [ ] Mi Biblioteca → Vistas  
- [ ] Mi Biblioteca → Listas → Lista específica

### Navegación con Drawer
- [ ] Perfil → Pantalla de perfil del usuario
- [ ] Configuración → Opciones de configuración
- [ ] Otras opciones del menú lateral

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 📺 Anuncios (5 minutos)

### Visualización de Anuncios
- [ ] **Lista**: Anuncios nativos aparecen entre películas
- [ ] **Grid**: Anuncios mantienen proporción en grilla
- [ ] **Etiqueta**: Anuncios marcados claramente como "Anuncio"
- [ ] **Carga**: Anuncios cargan en < 3 segundos

### Comportamiento por Plataforma
- [ ] **Móvil**: Anuncios se muestran correctamente
- [ ] **Web**: Anuncios están deshabilitados (placeholder/sin anuncios)

### Manejo de Errores
- [ ] Sin internet → Placeholder apropiado
- [ ] Error de carga → No rompe la interfaz
- [ ] Funcionalidad principal no afectada

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 💾 Persistencia de Datos (8 minutos)

### Favoritos
- [ ] Marcar película como favorita
- [ ] Aparece en "Mi Biblioteca" > "Favoritas"
- [ ] Persiste después de cerrar/abrir app
- [ ] Desmarcar favorito funciona

### Películas Vistas
- [ ] Marcar como vista funciona
- [ ] Aparece en lista de vistas
- [ ] Estado persiste entre sesiones

### Listas Personalizadas
- [ ] Crear nueva lista
- [ ] Agregar películas a la lista
- [ ] Lista persiste después de reinicio
- [ ] Modificar lista funciona

### Caché y Performance
- [ ] Primera búsqueda: _____ segundos
- [ ] Segunda búsqueda (misma): _____ segundos
- [ ] Navegación a detalles vista previamente es más rápida

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## ⚠️ Manejo de Errores (7 minutos)

### Sin Conexión
- [ ] Desconectar internet
- [ ] Mensaje claro de "Sin conexión"
- [ ] Funciones offline siguen funcionando
- [ ] No crashes ni pantallas en blanco
- [ ] Reconectar → Funcionalidad se restaura

### Errores de Búsqueda
- [ ] Buscar texto inexistente → Mensaje apropiado
- [ ] Caracteres especiales → No causa errores
- [ ] Búsqueda vacía → Manejada correctamente

### Validación de Formularios
- [ ] Lista sin nombre → Validación clara
- [ ] Campos requeridos → Mensajes apropiados
- [ ] Límites de caracteres → Respetados

### Estados de Carga
- [ ] Inicio de app → Loading visible
- [ ] Búsquedas → Indicador de carga
- [ ] Carga de imágenes → Estados intermedios
- [ ] Sin pantallas completamente blancas

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 📊 Performance Rápida (5 minutos)

### Tiempos Críticos
- [ ] **Inicio de app**: _____ seg (objetivo: < 3 seg)
- [ ] **Navegación**: _____ ms (objetivo: < 500ms)
- [ ] **Búsqueda**: _____ seg (objetivo: < 1 seg)
- [ ] **Carga de imagen**: _____ seg (objetivo: < 2 seg)

### Fluidez General
- [ ] Scroll suave en listas
- [ ] Animaciones fluidas
- [ ] Sin lag perceptible
- [ ] Memoria estable (sin crecimiento excesivo)

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 🎨 UI/UX Básica (3 minutos)

### Consistencia Visual
- [ ] Tema aplicado correctamente
- [ ] Iconos y colores consistentes
- [ ] Tipografía legible
- [ ] Espaciado apropiado

### Responsividad
- [ ] Layout se adapta al tamaño de pantalla
- [ ] Elementos táctiles tienen tamaño apropiado
- [ ] Texto se lee correctamente

### Accesibilidad Básica
- [ ] Elementos importantes están etiquetados
- [ ] Contraste suficiente (WCAG AA: 4.5:1 texto normal, 3:1 texto grande)
- [ ] Navegación por teclado (en web/desktop)
- [ ] **NUEVO** Modo alto contraste funciona correctamente
- [ ] **NUEVO** Escalado de texto hasta 200% mantiene usabilidad
- [ ] **NUEVO** Botones de AppBar tienen tooltips y etiquetas semánticas
- [ ] **NUEVO** Star ratings tienen descripciones completas
- [ ] **NUEVO** Elementos táctiles mínimo 44x44dp

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 🔥 Casos Críticos de Usuario (10 minutos)

### Flujo Completo 1: Descubrir y Guardar
1. [ ] Abrir app
2. [ ] Navegar por películas populares
3. [ ] Seleccionar una película interesante
4. [ ] Ver detalles completos
5. [ ] Marcar como favorita
6. [ ] Verificar en Mi Biblioteca

### Flujo Completo 2: Buscar y Organizar
1. [ ] Buscar "Marvel"
2. [ ] Ver resultados
3. [ ] Crear nueva lista "Superhéroes"
4. [ ] Agregar 3 películas Marvel a la lista
5. [ ] Verificar que la lista se guardó

### Flujo Completo 3: Explorar Biblioteca
1. [ ] Ir a Mi Biblioteca
2. [ ] Revisar favoritas
3. [ ] Revisar vistas
4. [ ] Revisar listas personalizadas
5. [ ] Entrar a una lista específica

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## 📱 Pruebas Específicas por Plataforma

### Si es Android/iOS:
- [ ] Notificaciones push funcionan
- [ ] Rotación de pantalla
- [ ] Navegación con gestos
- [ ] Integración con sistema operativo

### Si es Web:
- [ ] URLs funcionan correctamente
- [ ] Botón de regreso del navegador
- [ ] Bookmarks/favoritos del navegador
- [ ] No hay errores en consola

### Si es Desktop:
- [ ] Redimensionar ventana
- [ ] Atajos de teclado
- [ ] Menús contextuales (clic derecho)

**Estado**: [ ] ✅ Aprobado | [ ] ❌ Falla | **Tiempo**: _____ min

---

## ⚡ Resumen Ejecutivo

### Estadísticas Generales
- **Total de checks**: ___/80+
- **Tiempo total**: _____ minutos
- **Errores críticos**: _____
- **Errores menores**: _____

### Estado por Categoría
| Categoría | Estado | Notas |
|-----------|--------|-------|
| Navegación | ✅/❌ | _______ |
| Anuncios | ✅/❌ | _______ |
| Persistencia | ✅/❌ | _______ |
| Errores | ✅/❌ | _______ |
| Performance | ✅/❌ | _______ |
| UI/UX | ✅/❌ | _______ |
| Flujos Críticos | ✅/❌ | _______ |

### Decisión Final
- [ ] ✅ **APROBADO** - Listo para uso/producción
- [ ] ⚠️ **APROBADO CON OBSERVACIONES** - Issues menores detectados
- [ ] ❌ **RECHAZADO** - Problemas críticos requieren corrección

### Top 3 Issues Encontrados
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

### Top 3 Aspectos Positivos
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

---

**Notas Adicionales:**
_________________________________________________________________________
_________________________________________________________________________
_________________________________________________________________________

**Próximos Pasos:**
1. ________________________________________________
2. ________________________________________________
3. ________________________________________________

---
**Ejecutado por**: ________________
**Aprobado por**: ________________
**Fecha**: ________________