# Guía de Configuración AdSense - Monetización Adaptativa

## 🚀 Configuración Rápida

### Paso 1: Registro en Google AdSense

1. **Registrarse en Google AdSense**

   - Ir a [https://www.google.com/adsense/](https://www.google.com/adsense/)
   - Crear cuenta o usar cuenta Google existente
   - Verificar dominio web donde se mostrará la app

2. **Obtener Publisher ID**
   ```
   Formato: ca-pub-XXXXXXXXXXXXXXXXX
   Ejemplo: ca-pub-1234567890123456
   ```

### Paso 2: Configurar en el Código

**Actualizar AdSenseService:**

```dart
// En lib/services/monetization/adsense_service.dart
static const String _defaultPublisherId = 'ca-pub-TU_PUBLISHER_ID_AQUÍ';
```

**Ejemplo:**

```dart
static const String _defaultPublisherId = 'ca-pub-1234567890123456';
```

### Paso 3: Configuración Web (index.html)

**Agregar a `web/index.html`:**

```html
<head>
  <!-- Google AdSense -->
  <script
    async
    src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-TU_PUBLISHER_ID"
    crossorigin="anonymous"
  ></script>

  <!-- Meta tags para AdSense -->
  <meta name="google-adsense-account" content="ca-pub-TU_PUBLISHER_ID" />
</head>
```

### Paso 4: Verificar Configuración

**Test de inicialización:**

```dart
final monetization = AdaptiveMonetizationManager.instance;
await monetization.initialize();

if (monetization.isMonetizationAvailable) {
  print('✅ AdSense configurado correctamente');
} else {
  print('❌ Error en configuración AdSense');
}
```

## 📋 Checklist de Configuración

### ✅ Configuración Básica

- [ ] Cuenta Google AdSense creada
- [ ] Publisher ID obtenido
- [ ] Publisher ID configurado en AdSenseService
- [ ] Script AdSense agregado a index.html
- [ ] Dominio verificado en AdSense Console

### ✅ Configuración Avanzada

- [ ] Políticas de contenido verificadas
- [ ] Configuración GDPR/CCPA implementada
- [ ] Analytics de monetización configurados
- [ ] Tests de integración funcionando
- [ ] Métricas UX configuradas

### ✅ Validación

- [ ] App web funciona correctamente
- [ ] Anuncios se cargan en web/desktop
- [ ] Móvil sigue usando AdMob
- [ ] Preferencias de usuario funcionan
- [ ] No hay errores en consola

## 🔧 Configuración por Entorno

### Desarrollo

```dart
// Para testing
static const String _defaultPublisherId = 'ca-pub-test-development';

// Habilitar debug
static const bool _debugMode = true;
```

### Producción

```dart
// Publisher ID real
static const String _defaultPublisherId = 'ca-pub-1234567890123456';

// Deshabilitar debug
static const bool _debugMode = false;
```

## 🌐 Configuración Específica de Plataforma

### Web

```html
<!-- web/index.html -->
<script
  async
  src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-TU_ID"
  crossorigin="anonymous"
></script>
```

### Desktop (Electron/PWA)

```html
<!-- Misma configuración que web -->
<meta name="google-adsense-account" content="ca-pub-TU_ID" />
```

### Móvil (AdMob)

```yaml
# android/app/src/main/AndroidManifest.xml
<meta-data
android:name="com.google.android.gms.ads.APPLICATION_ID"
android:value="ca-app-pub-XXXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

## 📊 Configuración de Analytics

### Eventos de Monetización

```dart
// Inicialización
AnalyticsManager.instance.logAdInteraction(
  adType: 'system',
  action: 'adsense_initialized',
  platform: 'web',
);

// Anuncio mostrado
AnalyticsManager.instance.logAdInteraction(
  adType: 'banner',
  action: 'shown',
  platform: 'web',
  revenue: estimatedRevenue,
);
```

### Métricas Clave

```dart
// Configurar tracking de:
- Impresiones por plataforma
- CTR por tipo de anuncio
- Revenue por usuario
- Tiempo de carga de anuncios
- Errores de carga
```

## 🛡️ Configuración de Privacidad

### GDPR/CCPA Compliance

```dart
// En UserMonetizationPreferencesService
await updateAdPreference(
  AdPreferenceType.personalizedAds,
  userConsentToPersonalizedAds,
);
```

### Configuración DNT (Do Not Track)

```dart
// Respetar configuración del navegador
final respectDNT = getUserPreferences().respectDoNotTrack;
if (respectDNT && browserHasDNT()) {
  // No mostrar anuncios personalizados
}
```

## 🚨 Solución de Problemas

### Error: "AdSense no carga"

```dart
// Verificar:
1. Publisher ID correcto en código
2. Dominio aprobado en AdSense Console
3. No hay adblockers activos
4. Script cargado correctamente
```

### Error: "Anuncios no se muestran"

```dart
// Debug:
final metrics = monetization.getMetrics();
print('AdSense inicializado: ${metrics.isInitialized}');
print('Anuncios activos: ${metrics.hasActiveBanner}');
```

### Error: "Violación de políticas"

```dart
// Verificar:
1. Contenido cumple políticas AdSense
2. Frecuencia de anuncios apropiada
3. Etiquetado correcto de anuncios
4. No clicks artificiales
```

## 🎯 Optimización de Performance

### Carga Lazy de AdSense

```dart
// Solo cargar cuando sea necesario
if (Platform.isWeb && shouldShowAds()) {
  await AdSenseService.instance.initialize();
}
```

### Cache de Configuración

```dart
// Cachear preferencias de usuario
final prefs = await SharedPreferences.getInstance();
final cachedConfig = prefs.getString('adsense_config');
```

### Timeout Configuration

```dart
// Configurar timeouts apropiados
static const Duration _adLoadTimeout = Duration(seconds: 3);
static const Duration _adDisplayTimeout = Duration(seconds: 1);
```

## 📈 Métricas de Éxito

### KPIs a Monitorear

```dart
✅ Revenue per User (RPU)
✅ Ad Load Time < 3 segundos
✅ CTR > 1% (industry average)
✅ User Retention sin degradación
✅ App Store Rating mantenido
✅ Complaints about ads < 1%
```

### Dashboard de Métricas

```dart
// Implementar dashboard con:
- Revenue por plataforma (AdMob vs AdSense)
- Performance comparativo
- Métricas UX (retención, sesión)
- Errores y problemas técnicos
```

## 🔄 Flujo de Testing

### Tests Automatizados

```bash
# Test de integración AdSense
flutter test integration_test/adsense_integration_test.dart

# Test de monetización cross-platform
flutter test test/monetization/adaptive_monetization_test.dart

# Test de preferencias usuario
flutter test test/monetization/user_preferences_test.dart
```

### Tests Manuales

```dart
1. ✅ Web: Verificar anuncios AdSense cargan
2. ✅ Mobile: Verificar AdMob sigue funcionando
3. ✅ Desktop: Verificar AdSense en desktop
4. ✅ Preferencias: Verificar control de usuario
5. ✅ UX: Verificar frecuencia apropiada
```

## 🎨 Personalización de Anuncios

### Estilos de Banner

```dart
AdaptiveBannerWidget(
  size: AdaptiveBannerSize.mediumRectangle,
  backgroundColor: Theme.of(context).cardColor,
  borderRadius: 8.0,
  showLabel: true,
  labelStyle: TextStyle(
    fontSize: 12,
    color: Colors.grey[600],
  ),
)
```

### Anuncios Nativos

```dart
// Configuración para anuncios que se integran naturalmente
AdaptiveNativeAdWidget(
  height: 120,
  blendWithContent: true,
  respectContentTheme: true,
)
```

---

## 📞 Soporte y Recursos

### Documentación Oficial

- [Google AdSense Help](https://support.google.com/adsense)
- [AdSense Policies](https://support.google.com/adsense/answer/48182)
- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)

### Comunidad

- [Flutter Community](https://flutter.dev/community)
- [AdSense Community](https://support.google.com/adsense/community)

---

_Con esta configuración tendrás un sistema de monetización adaptativo completamente funcional que maximiza ingresos mientras mantiene una experiencia de usuario excepcional._
