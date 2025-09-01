# ❌ PROBLEMA CRÍTICO: API Key de Trakt.tv Inválida

## 🚨 Estado Actual

- **Problema**: Error 403 al hacer requests a Trakt API
- **Causa**: La API key `8969e2e8dd5d7ca6b3e9a7b5b476c7b7e4f3b1b0ad1d5d2f9e5e4e3c7e9e5b4a` no es válida
- **Efecto**: Las películas no cargan, app muestra loading infinito
- **URL**: `http://localhost:3000` - servidor corriendo pero sin datos

## ✅ Fix Aplicado Pero Necesita API Key Válida

1. ✅ TRAKT_API_KEY agregada al .env
2. ✅ TraktApiService corregido para usar API key correcta
3. ✅ Headers configurados correctamente
4. ❌ **API Key inválida - necesita key real de Trakt.tv**

## 🔧 Solución Inmediata Necesaria

### Opción 1: Conseguir API Key Real de Trakt.tv

1. Ir a https://trakt.tv/oauth/applications
2. Crear nueva aplicación
3. Obtener API key válida
4. Reemplazar en .env

### Opción 2: Rollback Temporal a TMDB

1. Revertir provider a usar TMDB temporalmente
2. Fix urgente para que la app funcione
3. Migrar a Trakt cuando tengamos key válida

## 🚀 Recomendación

**Opción 2 (Rollback)** para restore inmediato, luego Opción 1 para migración completa.

---

# Ideas para App de Películas - Red Social Cinematográfica

## 📱 Textos para Google Play Store

### Descripción Completa (Portada)

¡Descubre la app definitiva para los amantes del cine!

¿Te apasiona el séptimo arte? ¿Quieres tener el poder de explorar, organizar y disfrutar tus películas favoritas como nunca antes? Esta aplicación está diseñada para sorprenderte y convertirse en tu compañera imprescindible.

**¿Qué hace única a nuestra app?**

- **Catálogo Extenso y Actualizado**  
  Accede a miles de películas y series, desde los últimos estrenos hasta clásicos de todos los tiempos. ¡Siempre tendrás algo nuevo para ver!

- **Búsqueda Inteligente y Filtros Avanzados**  
  Encuentra exactamente lo que quieres con filtros por género, año, puntuación, actores, y más. Descubre joyas ocultas que jamás imaginaste.

- **Listas Personalizadas y Favoritos**  
  Crea tus propias listas, organiza tu colección, marca tus favoritas y lleva el control de todo lo que ves. ¡Tu cine, a tu manera!

- **Detalles Completos y Recomendaciones**  
  Consulta sin esfuerzo sinopsis, trailers, críticas, reparto, curiosidades y recomendaciones personalizadas según tus gustos.

- **Interfaz Rápida y Moderna**  
  Disfruta una experiencia visual atractiva, fluida y fácil de usar. Todo está pensado para que te concentres en lo importante: ¡el cine!

- **Sincronización y Acceso Multiplataforma**  
  Lleva tu cuenta y tus listas a cualquier dispositivo. No importa dónde estés, tu pasión por el cine te acompaña.

- **Actualizaciones Constantes**  
  Nuevas funciones y mejoras en cada actualización. ¡Siempre estamos trabajando para darte lo mejor!

**¿Por qué elegirnos?**  
Miles de cinéfilos ya han transformado su forma de disfrutar películas. Nuestra app no solo te ayuda a encontrar qué ver, sino que convierte cada experiencia en algo especial y único.  
Si realmente amas el cine, no puedes quedarte sin probarla.

¡Descárgala ahora y revoluciona tu manera de vivir el cine!  
Haz clic en "Instalar" y descubre por qué esta app es imprescindible para todo verdadero amante de las películas.

### Descripción Breve (80 caracteres)

```
Tu mundo de películas: descubre, organiza y sorpréndete. ¡Instálala ya!
```

## ⭐ Funciones Sencillas y Valiosas para tu App

### 1. **Marcador de "Ver después"**

Permite a los usuarios guardar películas para verlas más tarde. Es fácil de usar y ayuda a mantener organizada su lista de pendientes.

**Características adicionales:**

- Organización por prioridad (alta, media, baja)
- Categorías personalizadas ("Para el fin de semana", "Con pareja", "Solo")
- Recordatorios programables
- Estimación de tiempo total de las películas pendientes
- Sincronización entre dispositivos

### 2. **Historial de vistas**

Lleva el registro de las películas que el usuario ya ha visto. Esto evita repeticiones y puede servir para estadísticas personales.

**Características adicionales:**

- Fecha y hora de visualización
- Análisis de patrones (géneros más vistos, actores favoritos)
- Gráficos de progreso mensual/anual
- Exportar historial como PDF o CSV
- Filtros por año, género, puntuación
- Recuerdos automáticos ("Hace un año viste...")

### 3. **Valoraciones personales**

Los usuarios pueden puntuar las películas que ven, ayudando a recordar cuáles disfrutaron más.

**Características adicionales:**

- Sistema de estrellas (1-5) + comentarios personales
- Etiquetas emocionales ("Divertida", "Épica", "Nostálgica")
- Comparación con puntuaciones críticas y públicas
- Ranking personal de mejores películas del año
- Recomendaciones basadas en valoraciones previas
- Posibilidad de revalorar películas

### 4. **Compartir películas**

Agrega un botón para compartir fichas de películas por WhatsApp, redes o correo. Así pueden recomendar fácilmente lo que les gusta.

**Características adicionales:**

- Plantillas personalizadas para compartir
- Generación automática de tarjetas visuales atractivas
- Compartir listas completas
- Códigos QR para compartir rápidamente
- Integración con stories de Instagram/Facebook
- Estadísticas de cuántas personas vieron tu recomendación

### 5. **Notificaciones de estrenos**

Avisos simples para informar sobre nuevos estrenos en géneros favoritos o películas de directores/actores preferidos.

**Características adicionales:**

- Seguimiento de actores, directores y estudios específicos
- Notificaciones de secuelas de películas que te gustaron
- Avisos de llegada a plataformas de streaming
- Recordatorios de fechas de estreno en cines
- Configuración granular (inmediato, diario, semanal)
- Preview de trailer en la notificación

### 6. **Sugerencias rápidas**

Un botón de "¿Qué ver hoy?" que sugiera una película al azar (o según género preferido) para los indecisos.

**Características adicionales:**

- Filtros de tiempo disponible ("Tengo 90 minutos")
- Sugerencias según estado de ánimo
- Recomendaciones por clima o día de la semana
- Modo "Ruleta": interfaz visual divertida para elegir
- Sugerencias grupales (para ver con amigos/familia)
- Historial de sugerencias rechazadas para evitar repetir

### 7. **Información de plataformas**

Muestra en qué plataformas de streaming está disponible cada película (Netflix, Prime, Disney+…). Puedes usar APIs públicas o dejar que el usuario agregue manualmente.

**Características adicionales:**

- Precio de alquiler/compra en diferentes plataformas
- Alertas cuando una película llegue a tu plataforma favorita
- Comparador de precios automático
- Links directos para ver inmediatamente
- Información de calidad (4K, HDR disponible)
- Indicador de películas que salen pronto de plataformas

### 8. **Modo oscuro**

Permite cambiar la apariencia de la app para una experiencia más cómoda en lugares con poca luz.

**Características adicionales:**

- Activación automática según hora del día
- Múltiples temas de color (azul oscuro, gris, negro puro)
- Sincronización con configuración del sistema
- Modo cine (pantalla extra oscura para usar en salas)
- Personalización de colores de acento
- Ahorro de batería optimizado

### 9. **Mini-perfil de usuario**

Una sección donde el usuario puede personalizar su nombre/avatar y ver estadísticas como cantidad de películas vistas, géneros favoritos, etc.

**Características adicionales:**

- Avatar personalizable o desde galería
- Estadísticas detalladas (tiempo total visto, género favorito, década preferida)
- Insignias y logros desbloqueables
- Progreso hacia metas personales
- Comparación anónima con otros usuarios
- Timeline visual de tu año cinematográfico
- Exportar "reporte anual" estilo Spotify Wrapped

### 10. **Top tendencias**

Muestra un pequeño ranking de películas populares o más vistas entre los usuarios de la app.

**Características adicionales:**

- Rankings por categorías (terror, comedia, acción, etc.)
- Tendencias por región/país
- "Subiendo rápido" para películas en ascenso
- Comparación entre críticas y popularidad
- Rankings históricos (lo más visto del mes/año)
- Tendencias por grupo de edad
- Widget para pantalla principal del móvil

## 👥 Funciones de Mini Red Social para tu App de Películas

### 1. **Perfiles de usuario**

Cada usuario tiene su perfil donde muestra sus listas, películas vistas, valoraciones y géneros favoritos.

**Características adicionales:**

- Bio personalizable con emojis y texto
- Foto de portada temática (póster de película favorita)
- Estadísticas públicas/privadas configurables
- Insignias y logros visibles
- Top 10 películas favoritas destacadas
- Actividad reciente automática
- Opciones de privacidad granulares
- Verificación para críticos o personalidades del cine

### 2. **Seguimiento de amigos**

Permite seguir a otros usuarios para ver sus recomendaciones, listas y actividad reciente.

**Características adicionales:**

- Sugerencias de amigos basadas en gustos similares
- Categorías de seguimiento ("Críticos", "Amigos", "Influencers")
- Notificaciones personalizables por usuario seguido
- Lista de "Amigos cercanos" con actividad prioritaria
- Función "Seguir de vuelta" automática
- Estadísticas de compatibilidad cinematográfica
- Límites configurables para usuarios premium
- Sistema de seguimiento mutuo vs unidireccional

### 3. **Feed social**

Un muro donde aparecen las películas que tus amigos han visto, valorado o recomendado.

**Características adicionales:**

- Algoritmo personalizable (cronológico vs relevancia)
- Filtros por tipo de actividad (solo reseñas, solo valoraciones)
- Reacciones rápidas (👍❤️😂😮😢😡)
- Comentarios en actividades del feed
- Compartir actividades a tu propio feed
- Feed personalizado por temas ("Solo terror", "Solo clásicos")
- Función "Me gusta" y estadísticas de engagement
- Silenciar temporalmente ciertos tipos de spoilers

### 4. **Comentarios y reseñas**

Los usuarios pueden dejar comentarios y reseñas públicas sobre cada película.

**Características adicionales:**

- Editor de texto enriquecido (negrita, cursiva, listas)
- Sistema de votos útil/no útil para reseñas
- Reseñas destacadas por la comunidad
- Filtro anti-spoilers con advertencias
- Respuestas a comentarios (hilos de conversación)
- Moderación comunitaria y reportes
- Reseñas verificadas (para usuarios que comprueban que vieron la película)
- Longitud variable (mini-reseñas de 140 caracteres vs reseñas completas)
- Traducción automática de reseñas internacionales

### 5. **Recomendaciones entre amigos**

Puedes recomendar directamente una película a tus amigos, quienes reciben una notificación o mensaje privado.

**Características adicionales:**

- Mensajes personalizados con la recomendación
- Recomendaciones grupales (a varios amigos a la vez)
- Recordatorios automáticos para ver películas recomendadas
- Feedback cuando tu amigo ve tu recomendación
- Historial de recomendaciones enviadas/recibidas
- Sistema de karma por recomendaciones exitosas
- Recomendaciones inteligentes basadas en gustos del destinatario
- Integración con calendario para programar "cita de cine"

### 6. **Listas colaborativas**

Crea listas de películas junto a tus amigos (por ejemplo: "Para ver este verano", "Las favoritas del grupo", etc.)

**Características adicionales:**

- Roles de administrador/colaborador/espectador
- Votación democrática para agregar/quitar películas
- Chat interno para cada lista colaborativa
- Notificaciones cuando se agregan películas
- Templates de listas populares ("Maratón de Oscar", "Noche de terror")
- Límites de películas por colaborador
- Progreso grupal de visualización
- Integración con eventos de calendario
- Exportar lista como imagen o PDF

### 7. **Desafíos y logros**

Agrega pequeños retos sociales: "Ver 5 películas de ciencia ficción este mes", "Completa una maratón de Oscar", etc. Los usuarios ganan insignias y pueden compartir sus logros.

**Características adicionales:**

- Desafíos semanales/mensuales/anuales
- Competencias entre amigos o grupos
- Logros secretos por descubrir
- Insignias coleccionables con diferentes raridades
- Leaderboards temporales y permanentes
- Desafíos creados por la comunidad
- Recompensas por completar desafíos (monedas virtuales, features premium temporales)
- Progreso visual con barras y porcentajes
- Celebraciones animadas al completar logros
- Desafíos estacionales y temáticos

### 8. **Mensajes privados (opcional y simple)**

Permite enviar mensajes cortos entre usuarios para comentar películas o listas.

**Características adicionales:**

- Mensajes de máximo 280 caracteres (estilo Twitter)
- Envío de GIFs y stickers relacionados con películas
- Referencias rápidas a películas con enlaces internos
- Mensajes que se autodestruyen después de leerse
- Indicadores de mensaje leído/no leído
- Bloqueo y reporte de usuarios problemáticos
- Chat grupal para listas colaborativas
- Mensajes de voz cortos (máximo 30 segundos)
- Reacciones rápidas con emojis

### 9. **Ranking y tendencias comunitarias**

Ranking de las películas más vistas, comentadas o recomendadas por la comunidad.

**Características adicionales:**

- Rankings regionales y globales
- Tendencias por rango de edad y género
- "Subiendo rápido" para detectar películas emergentes
- Rankings históricos (mejor de la década, año, mes)
- Comparación con rankings de críticos profesionales
- Rankings temáticos ("Mejor para ver en pareja", "Más reconfortantes")
- Predicciones de tendencias futuras
- Rankings personalizados según tus gustos
- Alertas cuando tus películas favoritas suben/bajan en rankings

### 10. **Compartir en redes externas**

Botón para compartir listas, perfiles o películas en WhatsApp, Instagram, Facebook, etc., aumentando el alcance de la app.

**Características adicionales:**

- Plantillas optimizadas para cada red social
- Generación automática de historias para Instagram/Facebook
- Códigos QR para compartir perfiles y listas
- Deep links para abrir directamente en la app
- Estadísticas de cuántas personas llegaron por tus compartidos
- Templates de "Mi película del día", "Mi top 5", etc.
- Integración con TikTok para videos cortos de reseñas
- Compartir automático de logros importantes
- Watermark discreto de la app en imágenes compartidas
- Compartir en LinkedIn para películas relacionadas con negocios/documentales

## 💰 Estrategias de Monetización para tu App

### 1. **Publicidad controlada**

Muestra anuncios (banners, intersticiales, o videos) en ciertas secciones, pero nunca de forma invasiva. Ofrécele al usuario la opción de eliminar los anuncios con una suscripción o pago único (modelo "ad-free").

**Características adicionales:**

- Anuncios nativos que se integran naturalmente en el feed
- Publicidad contextual relacionada con películas y entretenimiento
- Anuncios de trailers que cuentan como contenido
- Frecuencia limitada (máximo 1 anuncio cada 10 interacciones)
- Anuncios premium de alta calidad visual
- Opción de ver anuncio voluntariamente para desbloquear función temporal
- Anuncios personalizados basados en géneros favoritos
- Colaboraciones con estudios para promociones exclusivas

### 2. **Suscripción Premium**

Ofrece una versión premium con ventajas exclusivas: Sin anuncios, Acceso anticipado a nuevas funciones, Estadísticas avanzadas sobre las películas vistas, Personalización extra del perfil, Mayor capacidad para listas colaborativas y seguidores.

**Características adicionales:**

- Planes flexibles (mensual, anual, familiar)
- Período de prueba gratuito de 7-14 días
- Descuentos para estudiantes y mayores
- Premium+: tier superior con funciones exclusivas
- Análisis de compatibilidad cinematográfica con amigos
- Backup en la nube ilimitado
- Soporte prioritario
- Acceso a contenido exclusivo (entrevistas, making-of)
- Función de exportar datos personales

### 3. **Funciones exclusivas de pago**

Permite el acceso a ciertas funciones "VIP" pagando: Temas personalizados para la app, Stickers o insignias para el perfil, Reseñas destacadas en el feed, Widgets exclusivos para la pantalla principal.

**Características adicionales:**

- Micropagos de $0.99 - $2.99 por función
- Paquetes de personalización temáticos
- Insignias limitadas por temporada
- Marcos especiales para el avatar
- Efectos de sonido personalizables
- Animaciones exclusivas en la interfaz
- Fuentes tipográficas premium
- Colores de acento únicos
- Wallpapers y fondos HD

### 4. **Venta de recomendaciones patrocinadas**

Permite que estudios, productoras o plataformas de streaming paguen para destacar ciertas películas o series en el feed, siempre identificadas como "patrocinadas".

**Características adicionales:**

- Límite de contenido patrocinado (máximo 10% del feed)
- Marcado claro y transparente como "Patrocinado"
- Relevancia garantizada (solo promocionar contenido afín a los gustos del usuario)
- Opción de usuario para reducir/eliminar contenido patrocinado
- Colaboraciones con festivales de cine independiente
- Promociones de estrenos de películas pequeñas y autores
- Partnerships con servicios de streaming para contenido exclusivo
- CPM premium por targeting específico

### 5. **Micropagos y regalos digitales**

Los usuarios pueden comprar "monedas" o "puntos" para regalar insignias a amigos, destacar listas, o desbloquear logros especiales.

**Características adicionales:**

- Moneda virtual: "CineCoins" o "FilmStars"
- Paquetes de monedas con bonificaciones por volumen
- Formas de ganar monedas gratis (ver anuncios, completar desafíos)
- Regalo de suscripciones premium temporales
- "Destacar" reseñas en resultados de búsqueda
- Boost para aparecer en sugerencias de amistad
- Regalos estacionales y temáticos
- Sistema de intercambio entre usuarios
- Monedas como recompensa por contribuciones valiosas a la comunidad

### 6. **Programa de afiliados**

Si la app muestra dónde ver las películas (Netflix, Prime, etc.), puedes incluir enlaces de afiliado a esas plataformas. Recibes comisión si el usuario se suscribe o alquila la película.

**Características adicionales:**

- Partnerships oficiales con plataformas de streaming
- Comisiones por suscripciones nuevas y renovaciones
- Enlaces de afiliado para compra/alquiler de películas
- Promociones exclusivas para usuarios de la app
- Descuentos negociados con plataformas
- Comisiones por venta de merchandising cinematográfico
- Partnerships con cines para descuentos en entradas
- Afiliaciones con librerías para venta de guiones/libros relacionados

### 7. **Eventos y experiencias exclusivas**

Ofrece acceso a sorteos, preestrenos online, charlas con críticos o cineastas, solo para usuarios premium.

**Características adicionales:**

- Preestrenos virtuales exclusivos
- Q&A en vivo con directores y actores
- Masterclasses de crítica cinematográfica
- Tours virtuales por sets de filmación
- Concursos de guiones y cortometrajes
- Entradas gratuitas para festivales de cine
- Meet & greets virtuales con celebridades
- Contenido behind-the-scenes exclusivo
- Workshops de producción cinematográfica

### 8. **Marketplace social**

Permite que los usuarios vendan o intercambien productos relacionados con el cine (posters, libros, entradas). La app puede cobrar una pequeña comisión por cada venta.

**Características adicionales:**

- Verificación de autenticidad para objetos de colección
- Sistema de ratings para vendedores
- Escrow service para transacciones seguras
- Categorías: pósters, autógrafos, props, libros, DVDs/Blu-rays
- Subasta para objetos raros y valiosos
- Shipping tracking integrado
- Protección del comprador
- Comisión deslizante según valor del item (3-8%)
- Merchandising oficial de películas
- Intercambio gratuito entre usuarios (solo comisión en ventas)

## 🚀 Próximos Pasos

### Desarrollo por Fases

1. **Fase 1:** Funciones básicas + perfil usuario
2. **Fase 2:** Características sociales fundamentales
3. **Fase 3:** Monetización y funciones premium
4. **Fase 4:** Marketplace y eventos exclusivos

### Consideraciones Técnicas

- API de películas (TMDB, OMDB)
- Base de datos para usuarios y relaciones sociales
- Sistema de notificaciones push
- Integración con redes sociales
- Sistema de pagos in-app

## 📊 Métricas de Éxito

- Número de usuarios activos
- Engagement en funciones sociales
- Retención de usuarios
- Conversión a premium
- Reviews y valoraciones en stores

---

**Proyecto:** App de Películas - Red Social  
**Repositorio:** tiagofur/peliculas  
**Fecha:** 2025-08-13 21:13:39 UTC  
**Desarrollador:** @tiagofur
