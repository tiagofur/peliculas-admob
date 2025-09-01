# 📋 Plan de Pruebas Funcionales Manuales - Peliculas AdMob

## 🎯 Objetivo

Definir y ejecutar casos de prueba manuales para validar las funcionalidades principales de la aplicación de películas, incluyendo navegación, anuncios, persistencia de datos y manejo de errores en la UI.

## 📱 Configuración del Entorno de Prueba

### Plataformas de Prueba
- **Android**: Versiones 8.0+ (API 26+)
- **iOS**: Versiones 12.0+
- **Web**: Chrome, Firefox, Safari
- **Desktop**: Windows, macOS, Linux

### Datos de Prueba
- Usuario de prueba con datos existentes
- Películas favoritas guardadas
- Listas personalizadas creadas
- Configuraciones personalizadas

## 🧪 Casos de Prueba por Funcionalidad

### 1. 🧭 Navegación entre Pantallas

#### TC-NAV-001: Navegación Principal
**Descripción**: Verificar la navegación básica entre las pantallas principales

**Pasos**:
1. Abrir la aplicación
2. Verificar que aparece la pantalla principal (Home)
3. Tocar "Mi Biblioteca" en la barra de navegación inferior
4. Verificar navegación a la pantalla de biblioteca
5. Tocar "Estadísticas" en la barra de navegación
6. Verificar navegación a estadísticas
7. Tocar "Streaming" en la barra de navegación
8. Verificar navegación a dashboard de streaming
9. Tocar "Inicio" para regresar

**Resultado Esperado**: 
- ✅ Todas las transiciones son fluidas (< 500ms)
- ✅ No hay errores visuales o de carga
- ✅ El indicador de la pestaña activa se actualiza correctamente

#### TC-NAV-002: Navegación Detallada de Película
**Descripción**: Verificar navegación hacia detalles de película

**Pasos**:
1. En la pantalla principal, seleccionar una película del carrusel
2. Tocar en la película
3. Verificar que se abre la pantalla de detalles
4. Usar botón de regreso para volver
5. Repetir con búsqueda: buscar "Matrix" y tocar resultado

**Resultado Esperado**:
- ✅ La pantalla de detalles carga completamente
- ✅ Información de la película es correcta
- ✅ El botón de regreso funciona correctamente
- ✅ La navegación desde búsqueda funciona igual

#### TC-NAV-003: Navegación en Mi Biblioteca
**Descripción**: Verificar navegación entre subsecciones de Mi Biblioteca

**Pasos**:
1. Ir a "Mi Biblioteca"
2. Tocar "Favoritas"
3. Verificar lista de películas favoritas
4. Tocar "Vistas"
5. Verificar lista de películas vistas
6. Tocar "Listas"
7. Verificar listas personalizadas
8. Tocar una lista específica
9. Verificar que abre el detalle de la lista

**Resultado Esperado**:
- ✅ Cada subsección carga correctamente
- ✅ Los datos persisten entre navegaciones
- ✅ La navegación jerárquica funciona (lista → detalle → lista)

#### TC-NAV-004: Navegación con Drawer
**Descripción**: Verificar funcionamiento del menú lateral

**Pasos**:
1. Abrir el drawer (menú hamburguesa)
2. Tocar "Perfil"
3. Verificar navegación a pantalla de perfil
4. Abrir drawer nuevamente
5. Tocar "Configuración"
6. Verificar navegación a configuración
7. Probar otras opciones del drawer

**Resultado Esperado**:
- ✅ El drawer se abre y cierra correctamente
- ✅ Todas las opciones navegan a sus respectivas pantallas
- ✅ El drawer se cierra automáticamente al navegar

### 2. 📺 Carga y Visualización de Anuncios

#### TC-ADS-001: Anuncios Nativos en Lista
**Descripción**: Verificar que los anuncios nativos se cargan en las listas de películas

**Pasos**:
1. Ir a la pantalla principal
2. Observar la lista de películas populares
3. Buscar elementos marcados como "Anuncio"
4. Verificar que los anuncios se integran naturalmente en la lista
5. Hacer scroll para verificar más anuncios

**Resultado Esperado**:
- ✅ Los anuncios aparecen integrados en la lista
- ✅ Están claramente marcados como "Anuncio"
- ✅ El diseño es consistente con el resto de la app
- ✅ Los anuncios cargan en < 3 segundos

#### TC-ADS-002: Anuncios en Grid
**Descripción**: Verificar anuncios en vista de grilla

**Pasos**:
1. Navegar a una sección con vista de grilla
2. Observar los anuncios insertados en la grilla
3. Verificar que mantienen la proporción correcta
4. Tocar en un anuncio (si es interactivo)

**Resultado Esperado**:
- ✅ Los anuncios mantienen la proporción de la grilla
- ✅ No rompen el layout de la grilla
- ✅ Son visualmente identificables como anuncios

#### TC-ADS-003: Manejo de Errores en Anuncios
**Descripción**: Verificar comportamiento cuando los anuncios fallan

**Pasos**:
1. Desconectar internet temporalmente
2. Abrir la aplicación
3. Observar las áreas donde deberían aparecer anuncios
4. Reconectar internet
5. Verificar recuperación de anuncios

**Resultado Esperado**:
- ✅ En caso de error, muestra un placeholder apropiado
- ✅ No afecta la funcionalidad principal de la app
- ✅ Los anuncios se recuperan al restaurar conectividad

#### TC-ADS-004: Anuncios en Web vs Móvil
**Descripción**: Verificar diferencias entre plataformas

**Pasos**:
1. Probar la app en móvil
2. Documentar donde aparecen anuncios
3. Probar la misma app en web
4. Comparar comportamiento

**Resultado Esperado**:
- ✅ En web, los anuncios están deshabilitados (según código)
- ✅ En móvil, los anuncios funcionan normalmente
- ✅ La experiencia de usuario es consistente en ambas plataformas

### 3. 💾 Persistencia de Datos

#### TC-DATA-001: Persistencia de Favoritos
**Descripción**: Verificar que los favoritos se guardan y persisten

**Pasos**:
1. Seleccionar una película no marcada como favorita
2. Marcar como favorita
3. Ir a "Mi Biblioteca" > "Favoritas"
4. Verificar que aparece la película
5. Cerrar completamente la aplicación
6. Reabrir la aplicación
7. Verificar que el favorito persiste

**Resultado Esperado**:
- ✅ La película se marca como favorita inmediatamente
- ✅ Aparece en la lista de favoritas
- ✅ Persiste después de cerrar/abrir la app
- ✅ La sincronización con servidor funciona (si aplica)

#### TC-DATA-002: Persistencia de Películas Vistas
**Descripción**: Verificar tracking de películas vistas

**Pasos**:
1. Seleccionar una película no marcada como vista
2. Marcarla como vista
3. Verificar que aparece en "Mi Biblioteca" > "Vistas"
4. Reiniciar la aplicación
5. Verificar persistencia

**Resultado Esperado**:
- ✅ La película se marca como vista
- ✅ Aparece en la lista de vistas
- ✅ El estado persiste entre sesiones

#### TC-DATA-003: Persistencia de Listas Personalizadas
**Descripción**: Verificar creación y persistencia de listas

**Pasos**:
1. Ir a "Mi Biblioteca" > "Listas"
2. Crear una nueva lista personalizada
3. Agregar 3 películas a la lista
4. Cerrar la aplicación
5. Reabrir y verificar que la lista persiste
6. Agregar una película más
7. Verificar que se guarda el cambio

**Resultado Esperado**:
- ✅ La lista se crea correctamente
- ✅ Las películas se agregan a la lista
- ✅ Todo persiste entre sesiones
- ✅ Los cambios se guardan inmediatamente

#### TC-DATA-004: Caché de Películas y Búsquedas
**Descripción**: Verificar funcionamiento del sistema de caché

**Pasos**:
1. Buscar "Batman" por primera vez
2. Medir tiempo de respuesta
3. Volver a buscar "Batman"
4. Medir tiempo de respuesta (debería ser más rápido)
5. Navegar a detalles de una película
6. Regresar y volver a entrar (verificar caché de detalles)

**Resultado Esperado**:
- ✅ Primera búsqueda toma tiempo normal
- ✅ Segunda búsqueda es más rápida (caché funcionando)
- ✅ Los detalles de película se cargan más rápido en segunda visita

#### TC-DATA-005: Sincronización Multi-dispositivo
**Descripción**: Verificar sincronización entre dispositivos (si está disponible)

**Pasos**:
1. En dispositivo 1: Agregar película a favoritos
2. En dispositivo 2: Iniciar sesión con misma cuenta
3. Verificar que el favorito aparece
4. En dispositivo 2: Crear nueva lista
5. En dispositivo 1: Verificar que la lista aparece
6. Verificar sincronización bidireccional

**Resultado Esperado**:
- ✅ Los favoritos se sincronizan entre dispositivos
- ✅ Las listas se sincronizan correctamente
- ✅ La sincronización es bidireccional

### 4. ⚠️ Manejo de Errores en la UI

#### TC-ERROR-001: Sin Conexión a Internet
**Descripción**: Verificar comportamiento sin internet

**Pasos**:
1. Desconectar internet completamente
2. Abrir la aplicación
3. Intentar navegar entre secciones
4. Intentar buscar películas
5. Intentar realizar acciones que requieren internet
6. Verificar mensajes de error mostrados

**Resultado Esperado**:
- ✅ La app muestra un mensaje claro de "Sin conexión"
- ✅ Las funciones offline siguen funcionando
- ✅ No hay crashes ni pantallas en blanco
- ✅ Se muestra cómo recuperar la conectividad

#### TC-ERROR-002: Errores de API
**Descripción**: Verificar manejo de errores de servicios externos

**Pasos**:
1. Buscar una película que no existe: "xkjsdfkjsdf123"
2. Verificar el mensaje de error
3. Intentar navegar a una película con ID inválido
4. Verificar manejo de datos incompletos/corruptos

**Resultado Esperado**:
- ✅ Búsquedas sin resultados muestran mensaje apropiado
- ✅ IDs inválidos muestran página de error clara
- ✅ Los errores no rompen la navegación general

#### TC-ERROR-003: Validación de Formularios
**Descripción**: Verificar validación en formularios de usuario

**Pasos**:
1. Ir a crear nueva lista personalizada
2. Intentar crear lista con nombre vacío
3. Intentar crear lista con caracteres especiales
4. Probar límites de caracteres
5. Verificar mensajes de validación

**Resultado Esperado**:
- ✅ Nombres vacíos no se permiten
- ✅ Mensajes de validación son claros
- ✅ Los límites se respetan y comunican

#### TC-ERROR-004: Memoria y Performance
**Descripción**: Verificar comportamiento con uso intensivo

**Pasos**:
1. Navegar rápidamente entre muchas pantallas
2. Abrir y cerrar detalles de películas repetidamente
3. Hacer scroll rápido en listas largas
4. Cargar muchas imágenes simultáneamente
5. Verificar que no hay memory leaks evidentes

**Resultado Esperado**:
- ✅ La app mantiene fluidez con uso intensivo
- ✅ No hay crashes por memoria
- ✅ Las animaciones siguen siendo suaves

#### TC-ERROR-005: Estados de Carga
**Descripción**: Verificar que todos los estados de carga son apropiados

**Pasos**:
1. Observar estado de carga al iniciar la app
2. Verificar loaders durante búsquedas
3. Observar carga de imágenes
4. Verificar carga de listas largas
5. Documentar todos los tipos de loading states

**Resultado Esperado**:
- ✅ Todos los estados de carga son visibles y apropiados
- ✅ No hay pantallas completamente en blanco durante cargas
- ✅ Los usuarios entienden que algo está pasando

## 📊 Métricas de Rendimiento

### Tiempos Objetivo
- **Inicio de app**: < 3 segundos
- **Navegación entre pantallas**: < 500ms
- **Carga de lista de películas**: < 2 segundos
- **Búsqueda de películas**: < 1 segundo
- **Carga de imagen**: < 2 segundos
- **Carga de anuncios**: < 3 segundos

### Criterios de Éxito
- **Funcionalidad**: 100% de casos críticos pasan
- **Performance**: 90% de métricas dentro de objetivo
- **Errores**: < 5% de operaciones resultan en error
- **UX**: Navegación fluida sin lag perceptible

## 🐛 Plantilla de Reporte de Bugs

### Información del Bug
- **ID**: BUG-[FECHA]-[NUMERO]
- **Título**: [Descripción breve del problema]
- **Severidad**: Critical/High/Medium/Low
- **Prioridad**: P1/P2/P3/P4

### Detalles del Entorno
- **Plataforma**: Android/iOS/Web/Desktop
- **Versión del OS**: 
- **Versión de la App**: 1.2.1+6
- **Dispositivo**: 

### Descripción del Problema
- **Pasos para Reproducir**:
  1. [Paso 1]
  2. [Paso 2]
  3. [Paso 3]

- **Resultado Esperado**: [Lo que debería pasar]
- **Resultado Actual**: [Lo que realmente pasa]
- **Frecuencia**: Siempre/A veces/Rara vez

### Evidencia
- **Capturas de pantalla**: [Adjuntar si aplica]
- **Logs de error**: [Copiar logs relevantes]
- **Video**: [Link si es necesario]

### Impacto
- **Usuarios afectados**: [Porcentaje estimado]
- **Funciones afectadas**: [Lista de funciones]
- **Workaround disponible**: Sí/No [Describir si existe]

## 📈 Plan de Ejecución

### Fase 1: Preparación (30 min)
1. Configurar entornos de prueba
2. Preparar datos de prueba
3. Configurar herramientas de documentación

### Fase 2: Pruebas de Navegación (45 min)
1. Ejecutar TC-NAV-001 a TC-NAV-004
2. Documentar resultados
3. Reportar bugs encontrados

### Fase 3: Pruebas de Anuncios (30 min)
1. Ejecutar TC-ADS-001 a TC-ADS-004
2. Verificar en múltiples plataformas
3. Documentar comportamiento

### Fase 4: Pruebas de Persistencia (60 min)
1. Ejecutar TC-DATA-001 a TC-DATA-005
2. Verificar sincronización
3. Probar en múltiples dispositivos

### Fase 5: Pruebas de Manejo de Errores (45 min)
1. Ejecutar TC-ERROR-001 a TC-ERROR-005
2. Simular condiciones adversas
3. Verificar recuperación

### Fase 6: Documentación y Reporte (30 min)
1. Compilar todos los resultados
2. Generar reporte ejecutivo
3. Priorizar bugs encontrados

## 🎯 Entregables

1. **Reporte de Ejecución de Pruebas**: Documento con todos los casos ejecutados y sus resultados
2. **Lista de Bugs Encontrados**: Catálogo detallado de problemas identificados
3. **Métricas de Performance**: Datos de tiempos de respuesta y rendimiento
4. **Recomendaciones de Mejora**: Sugerencias para optimizar la experiencia de usuario

## 🔄 Frecuencia de Ejecución

- **Completa**: Antes de cada release mayor
- **Regression**: Después de fixes importantes
- **Smoke**: Después de cada deployment
- **Ad-hoc**: Cuando se reporten bugs críticos

---

**Fecha de Creación**: [FECHA]
**Versión del Plan**: 1.0
**Responsable**: [NOMBRE]
**Aprobado por**: [NOMBRE]