# 🌐 Configuración de AdSense para Web

## Estado Actual: ✅ IMPLEMENTADO - REQUIERE CONFIGURACIÓN

La integración de Google AdSense para la plataforma web está **completamente implementada**. Solo necesitas configurar tus credenciales de AdSense para que funcione en producción.

## 📋 Lo que YA está listo:

### ✅ Widgets AdSense Implementados

- `AdSenseWebWidget` - Widget base para todos los anuncios web
- `AdSenseBannerWidget` - Banners responsivos
- `AdSenseNativeWidget` - Anuncios nativos integrados
- `AdSenseFullWidthWidget` - Anuncios de ancho completo

### ✅ Detección de Plataforma

Todos los widgets de anuncio ahora detectan automáticamente:

- **Móvil (Android/iOS)**: Usa AdMob
- **Web**: Usa AdSense

### ✅ Script AdSense Añadido

El script de AdSense ya está incluido en `web/index.html`

## 🔧 Configuración Requerida

### Paso 1: Configurar AdSense

**ANTES DE USAR EN PRODUCCIÓN, debes:**

1. **Crear cuenta AdSense**: https://adsense.google.com
2. **Verificar tu sitio**: https://peliculas.creapolis.dev
3. **Crear unidades de anuncio**:
   - Banner responsivo (728x90)
   - Nativo/fluido responsivo
   - Ancho completo responsivo

### Paso 2: Actualizar Configuración

Edita `lib/config/helpers/ad_helper.dart`:

```dart
class AdHelper {
  // Reemplaza con TU client ID de AdSense
  static const String adSenseClientId = 'ca-pub-TU_CLIENT_ID_AQUI';

  // Reemplaza con TUS slot IDs
  static const String adSenseBannerSlot = 'TU_BANNER_SLOT_ID';
  static const String adSenseNativeSlot = 'TU_NATIVE_SLOT_ID';
  static const String adSenseFullWidthSlot = 'TU_FULLWIDTH_SLOT_ID';
}
```

### Paso 3: Actualizar index.html

Edita `web/index.html` línea con el script AdSense:

```html
<script
  async
  src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-TU_CLIENT_ID_AQUI"
  crossorigin="anonymous"
></script>
```

## 🚀 Cómo Funciona Ahora

### En Móvil (Android/iOS)

```dart
// Usa AdMob como antes
BannerAdWidget() // -> AdMob banner
NativeAdWidget() // -> AdMob native
```

### En Web

```dart
// Usa AdSense automáticamente
BannerAdWidget() // -> AdSenseBannerWidget
NativeAdWidget() // -> AdSenseNativeWidget
FullWidthAdWidget() // -> AdSenseFullWidthWidget
```

## 🔍 Verificar Implementación

### Para Desarrollo (con IDs de prueba):

```bash
flutter build web --release
flutter run -d web-server --web-port 8080
```

Abre http://localhost:8080 y verifica:

- ✅ Los espacios para anuncios aparecen
- ✅ No hay errores en consola del navegador
- ✅ La etiqueta "Publicidad" se muestra

### Para Producción:

1. Configura tus IDs reales de AdSense
2. Despliega tu sitio web
3. Los anuncios pueden tardar hasta 24 horas en aparecer

## 📍 Ubicaciones de Anuncios

Los anuncios aparecerán automáticamente en:

### 🎬 Listas de Películas

- Entre las tarjetas de películas (cada 8 elementos)
- Como tarjetas nativas integradas

### 📑 Páginas de Contenido

- Banners horizontales entre secciones
- Anuncios de ancho completo en separadores

### 🔍 Resultados de Búsqueda

- Anuncios nativos integrados en resultados

## ⚠️ Consideraciones Importantes

### Políticas AdSense

- **NO** hacer clicks falsos para probar
- Contenido debe cumplir políticas de AdSense
- Revisar términos de uso regularmente

### Rendimiento

- Los anuncios están optimizados para no afectar Core Web Vitals
- Carga lazy implementada
- Fallback graceful si AdSense no está disponible

### Debugging

Si no aparecen anuncios:

1. Verifica IDs en configuración
2. Revisa consola del navegador por errores
3. Confirma que el sitio está aprobado en AdSense
4. Los anuncios nuevos pueden tardar 24h

## 📁 Archivos Modificados

### Widgets Actualizados:

- `lib/presentation/widgets/admob/banner_ad_widget.dart`
- `lib/presentation/widgets/admob/native_ad_widget.dart`
- `lib/presentation/widgets/admob/full_width_ad_widget.dart`
- `lib/presentation/widgets/admob/grid_ad_widget.dart`
- `lib/presentation/widgets/admob/movie_card_ad_widget.dart`

### Nuevos Archivos:

- `lib/presentation/widgets/admob/adsense_web_widget.dart`
- `lib/config/adsense_config.dart`
- `documentation/ADSENSE_WEB_SETUP.md` (este archivo)

### Configuración:

- `lib/config/helpers/ad_helper.dart` (actualizado)
- `web/index.html` (script AdSense añadido)

## ✅ Estado Final

**TODO IMPLEMENTADO** ✅

Solo necesitas:

1. Configurar tu cuenta AdSense
2. Reemplazar IDs placeholder con los reales
3. Desplegar y esperar aprobación

¡Los anuncios aparecerán automáticamente en web con AdSense y seguirán usando AdMob en móvil!
