# Configuración de Publisher IDs: AdMob vs AdSense

## 🔍 Diferencias Clave entre AdMob y AdSense

### ❌ **NO son el mismo Publisher ID**

AdMob y AdSense usan sistemas de identificación completamente diferentes, aunque pueden estar vinculados bajo la misma cuenta.

## 📱 AdMob (Móvil) - IDs Actuales

### **Application ID** (SDK Initialization)

```dart
// Para Android (AndroidManifest.xml)
ca-app-pub-XXXXXXXXXXXXXXXXX~XXXXXXXXXX

// Para iOS (Info.plist)
ca-app-pub-XXXXXXXXXXXXXXXXX~XXXXXXXXXX
```

### **Ad Unit IDs** (Por cada tipo de anuncio)

```dart
// Banner
ca-app-pub-XXXXXXXXXXXXXXXXX/XXXXXXXXXX

// Intersticial
ca-app-pub-XXXXXXXXXXXXXXXXX/XXXXXXXXXX

// Rewarded Video
ca-app-pub-XXXXXXXXXXXXXXXXX/XXXXXXXXXX

// Native
ca-app-pub-XXXXXXXXXXXXXXXXX/XXXXXXXXXX
```

## 🌐 AdSense (Web/Desktop) - Configuración Requerida

### **Publisher ID** (Más corto que AdMob)

```dart
// Format: ca-pub-XXXXXXXXXXXXXXXXX (16 dígitos)
ca-pub-1234567890123456

// Ejemplo real:
ca-pub-3940256099942544
```

### **Ad Slot IDs** (Solo números)

```dart
// Para cada tipo de anuncio en web
1234567890  // Banner
9876543210  // Native
5555555555  // Display
```

## 🔗 Vinculación de Cuentas

### ✅ **Configuración Recomendada**

1. **Tener UNA cuenta principal de AdSense**
2. **Vincular AdMob a esa cuenta de AdSense**
3. **Gestionar pagos centralizadamente**

### 🏗️ **Proceso de Vinculación**

#### **Paso 1: Crear cuenta AdSense**

```
1. Ir a: https://www.google.com/adsense/
2. Registrar sitio web (donde se ejecutará versión web)
3. Obtener Publisher ID: ca-pub-XXXXXXXXXXXXXXXXX
```

#### **Paso 2: Vincular AdMob existente**

```
1. Ir a AdMob Console: https://apps.admob.com/
2. Configuración → Información de pagos
3. "Vincular a cuenta de AdSense existente"
4. Usar misma cuenta Google de AdSense
```

## 🔧 Configuración en el Código

### **Actualización Requerida en AdSenseService**

```dart
// En lib/services/monetization/adsense_service.dart
static const String _defaultPublisherId = 'ca-pub-TU_PUBLISHER_ID_ADSENSE';

// Ejemplo con ID real:
static const String _defaultPublisherId = 'ca-pub-3940256099942544';
```

### **Verificación en AdMobService**

```dart
// En lib/services/monetization/advanced_admob_service.dart
// Los IDs de AdMob deben mantenerse como están
static const String _bannerAdUnitId = kDebugMode
    ? 'ca-app-pub-3940256099942544/6300978111' // Test
    : 'ca-app-pub-TU_APP_ID_ADMOB/TU_BANNER_ID'; // Producción
```

## 🎯 IDs de Prueba vs Producción

### **AdMob Test IDs** (Para desarrollo)

```dart
// Application ID
ca-app-pub-3940256099942544~3347511713

// Banner
ca-app-pub-3940256099942544/6300978111

// Intersticial
ca-app-pub-3940256099942544/1033173712

// Rewarded
ca-app-pub-3940256099942544/5224354917
```

### **AdSense Test ID** (Para desarrollo)

```dart
// Publisher ID de prueba
ca-pub-3940256099942544
```

## 🔒 Configuración de Seguridad

### **Variables de Entorno Recomendadas**

Crear archivo `.env` con:

```env
# AdMob IDs (Móvil)
ADMOB_APP_ID_ANDROID=ca-app-pub-XXXXXXXXX~XXXXXXXXX
ADMOB_APP_ID_IOS=ca-app-pub-XXXXXXXXX~XXXXXXXXX
ADMOB_BANNER_ID=ca-app-pub-XXXXXXXXX/XXXXXXXXX
ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXX/XXXXXXXXX
ADMOB_REWARDED_ID=ca-app-pub-XXXXXXXXX/XXXXXXXXX

# AdSense ID (Web/Desktop)
ADSENSE_PUBLISHER_ID=ca-pub-XXXXXXXXXXXXXXXXX

# Flags de configuración
USE_TEST_ADS=false
ENABLE_DEBUG_LOGGING=false
```

### **Carga de Variables de Entorno**

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdConfig {
  static String get adMobAppId => dotenv.env['ADMOB_APP_ID_ANDROID'] ?? 'test-id';
  static String get adSensePublisherId => dotenv.env['ADSENSE_PUBLISHER_ID'] ?? 'test-id';
  static bool get useTestAds => dotenv.env['USE_TEST_ADS'] == 'true';
}
```

## 📊 Diferencias en Reporting

### **AdMob Dashboard**

- Ubicación: https://apps.admob.com/
- Métricas: eCPM, Fill Rate, Revenue por app
- Enfoque: Performance por aplicación móvil

### **AdSense Dashboard**

- Ubicación: https://www.google.com/adsense/
- Métricas: RPM, CTR, Revenue por sitio
- Enfoque: Performance por sitio web

### **Dashboard Consolidado** (Si están vinculados)

- Vista unificada en AdSense
- Reportes separados por canal (móvil vs web)
- Pagos centralizados

## ⚠️ Errores Comunes

### **❌ Error 1: Usar AdMob ID en AdSense**

```dart
// INCORRECTO
ca-app-pub-XXXXXXXXX~XXXXXXXXX  // AdMob App ID en AdSense

// CORRECTO
ca-pub-XXXXXXXXXXXXXXXXX        // AdSense Publisher ID
```

### **❌ Error 2: Usar AdSense ID en AdMob**

```dart
// INCORRECTO
ca-pub-XXXXXXXXXXXXXXXXX        // AdSense Publisher ID en AdMob

// CORRECTO
ca-app-pub-XXXXXXXXX/XXXXXXXXX  // AdMob Ad Unit ID
```

### **❌ Error 3: Configuración de dominio**

```
Error: "AdSense ads not loading"
Solución: Verificar que el dominio esté aprobado en AdSense Console
```

## 🚀 Configuración Paso a Paso

### **1. Verificar AdMob Actual**

```bash
# Verificar AndroidManifest.xml
grep "com.google.android.gms.ads.APPLICATION_ID" android/app/src/main/AndroidManifest.xml

# Verificar iOS Info.plist
grep -A1 "GADApplicationIdentifier" ios/Runner/Info.plist
```

### **2. Configurar AdSense**

```dart
// 1. Obtener Publisher ID de AdSense Console
// 2. Actualizar AdSenseService con ID real
// 3. Agregar script a web/index.html
```

### **3. Probar Configuración**

```bash
# Test móvil (AdMob)
flutter run -d android
flutter run -d ios

# Test web (AdSense)
flutter run -d chrome
flutter run -d edge

# Test desktop (AdSense)
flutter run -d windows
flutter run -d macos
```

## 📈 Optimización de Revenue

### **Estrategia Multi-Plataforma**

```dart
// Móvil: AdMob optimizado para apps nativas
- Mayor eCPM en móvil
- Mejor targeting basado en app behavior
- Integración nativa con Android/iOS

// Web/Desktop: AdSense optimizado para contenido web
- Mejor performance en navegadores
- Anuncios más relevantes para contenido web
- Integración con Google Search Ads
```

### **Métricas de Comparación**

```dart
// Trackear performance por plataforma
Mobile Revenue (AdMob): $X.XX per user
Web Revenue (AdSense): $Y.YY per user
Desktop Revenue (AdSense): $Z.ZZ per user

// Optimizar basado en datos reales
```

## 🎯 Próximos Pasos

### **Inmediatos (Configuración)**

1. ✅ Obtener AdSense Publisher ID
2. ✅ Actualizar `_defaultPublisherId` en AdSenseService
3. ✅ Agregar script AdSense a `web/index.html`
4. ✅ Verificar que AdMob siga funcionando en móvil

### **Mediano Plazo (Optimización)**

1. 📊 Configurar analytics comparativos AdMob vs AdSense
2. 🔄 Implementar A/B testing de formatos de anuncios
3. 📈 Optimizar placement basado en métricas UX + Revenue
4. 🎯 Configurar targeting específico por plataforma

### **Largo Plazo (Escalamiento)**

1. 🤖 Implementar ML para optimización automática
2. 💰 Agregar Header Bidding para maximizar revenue
3. 🔗 Integrar con redes adicionales (Unity Ads, etc.)
4. 📊 Dashboard unificado con métricas cross-platform

---

**¿Necesitas ayuda configurando alguno de estos aspectos específicos?** Puedo ayudarte con la implementación práctica de cualquier parte de esta configuración.
