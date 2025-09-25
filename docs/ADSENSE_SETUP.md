# Configuración de AdSense para Web

Este documento explica cómo configurar AdSense para mostrar anuncios reales en la versión web de la aplicación de películas.

## 🎯 Estado Actual

**✅ CONFIGURADO:**

- Publisher ID: `ca-pub-4576016092724628`
- Script de AdSense cargado en `web/index.html`
- Servicio AdSense implementado (`adsense_service.dart`)
- Widgets web-safe creados que muestran espacios de AdSense

**⚙️ PENDIENTE:**

- Crear slots específicos en Google AdSense Console
- Implementar HtmlElementView para mostrar anuncios reales
- Configurar Auto Ads (opcional)

## 📋 Configuración de Slots de AdSense

### 1. Acceder a Google AdSense

1. Ve a [Google AdSense Console](https://www.google.com/adsense/new/u/0/pub-4576016092724628/home)
2. Inicia sesión con la cuenta asociada al Publisher ID

### 2. Crear Slots de Anuncio

Necesitas crear estos tipos de slots para la aplicación:

#### **Banner Horizontal**

- **Nombre:** "Películas - Banner Principal"
- **Tipo:** Display ads
- **Tamaño:** Responsive (adaptativo)
- **Ubicación:** Entre secciones de películas
- **Slot ID:** Actualizar en `AdSenseSlots.bannerSlot`

#### **Anuncio Nativo/In-feed**

- **Nombre:** "Películas - Lista Nativo"
- **Tipo:** In-feed ads
- **Formato:** Fluid
- **Ubicación:** Dentro de listas de películas
- **Slot ID:** Actualizar en `AdSenseSlots.nativeSlot`

#### **Anuncio de Ancho Completo**

- **Nombre:** "Películas - Separador Completo"
- **Tipo:** Display ads
- **Tamaño:** Responsive
- **Ubicación:** Entre secciones principales
- **Slot ID:** Actualizar en `AdSenseSlots.fullWidthSlot`

#### **Anuncio Grid/Cuadrado**

- **Nombre:** "Películas - Grid Cuadrado"
- **Tipo:** Display ads
- **Tamaño:** 300x250 (Medium Rectangle)
- **Ubicación:** Dentro de grillas de películas
- **Slot ID:** Actualizar en `AdSenseSlots.gridSlot`

### 3. Actualizar Configuración

Una vez creados los slots, actualizar el archivo `lib/core/monetization/adsense_slots.dart`:

```dart
class AdSenseSlots {
  // Reemplazar con slots reales de AdSense Console
  static const String bannerSlot = 'TU_SLOT_BANNER_AQUI';
  static const String nativeSlot = 'TU_SLOT_NATIVO_AQUI';
  static const String fullWidthSlot = 'TU_SLOT_COMPLETO_AQUI';
  static const String gridSlot = 'TU_SLOT_GRID_AQUI';
  // ...
}
```

## 🚀 Implementación de Anuncios Reales

### Opción 1: Auto Ads (Más Simple)

Habilitar Auto Ads en AdSense Console:

1. Ir a "Ads" > "By site"
2. Seleccionar tu sitio web
3. Activar "Auto ads"
4. AdSense colocará anuncios automáticamente

### Opción 2: Anuncios Manuales (Más Control)

Implementar HtmlElementView en los widgets:

```dart
// Ejemplo en _AdSenseBannerWidget
Widget build(BuildContext context) {
  if (kIsWeb) {
    return SizedBox(
      height: 90,
      child: HtmlElementView(
        viewType: 'adsense-banner-$uniqueId',
      ),
    );
  }
  return _MobileBannerAd();
}
```

## 📊 Monitoreo y Métricas

### AdSense Metrics Service

El servicio `AdSenseService` incluye métricas básicas:

```dart
final metrics = AdSenseService.instance.getMetrics();
print('Anuncios activos: ${metrics.activeAdsCount}');
print('Total creados: ${metrics.totalAdsCreated}');
```

### Análisis en AdSense Console

- **Rendimiento:** Ingresos, RPM, CTR
- **Anuncios:** Impresiones por slot
- **Optimización:** Sugerencias automáticas

## 🔧 Configuración de Desarrollo

### Variables de Entorno

Agregar al archivo `.env`:

```env
# AdSense Configuration
ADSENSE_PUBLISHER_ID=ca-pub-4576016092724628
ADSENSE_BANNER_SLOT=tu_banner_slot
ADSENSE_NATIVE_SLOT=tu_native_slot
ADSENSE_FULLWIDTH_SLOT=tu_fullwidth_slot
ADSENSE_GRID_SLOT=tu_grid_slot
```

### Testing Local

Para pruebas locales, AdSense requiere dominio verificado. Usar:

- **Desarrollo:** Placeholders (estado actual)
- **Staging:** Dominio de prueba verificado
- **Producción:** Dominio final verificado

## 🎨 Personalización de Anuncios

### Estilos CSS

Personalizar apariencia en `web/index.html`:

```css
<style>
.adsbygoogle {
  /* Estilos personalizados para anuncios */
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
</style>
```

### Responsive Design

Los anuncios responsive se adaptan automáticamente:

- **Móvil:** 320x50, 300x250
- **Tablet:** 728x90, 300x600
- **Desktop:** 970x250, 728x90

## ⚠️ Políticas de AdSense

### Contenido Permitido

- ✅ Información de películas
- ✅ Reseñas y calificaciones
- ✅ Listas de películas

### Restricciones

- ❌ No hacer clic en propios anuncios
- ❌ No pedir a usuarios hacer clic
- ❌ No colocar anuncios en pop-ups

## 🚀 Despliegue

### Pre-despliegue

1. Verificar Publisher ID correcto
2. Confirmar slots creados en AdSense
3. Probar en dominio de staging

### Post-despliegue

1. Verificar anuncios aparecen correctamente
2. Monitorear métricas en AdSense Console
3. Ajustar posicionamiento según rendimiento

## 📞 Soporte

- **AdSense Help:** https://support.google.com/adsense
- **Publisher ID:** ca-pub-4576016092724628
- **Documentación Flutter Web:** https://flutter.dev/web
