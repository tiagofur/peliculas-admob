# Pro: desactivado por ahora y cómo reactivarlo

Estado a **9 nov 2026**: la app es gratis, **sin anuncios y sin Pro visible**, en iOS y Android.
Todo el código de Pro (compras, backend, paywall) sigue en el repo, apagado con un interruptor.

## Por qué

TMDB cobra **149 USD/mes** de licencia comercial en cuanto la app gana dinero de cualquier forma
(anuncios **o** suscripción). Sin usuarios, eso sale del bolsillo. Mientras la app no tenga
ingresos entra en el uso **no comercial** gratuito de TMDB.

- Se escribió a TMDB pidiendo un periodo de gracia o una tarifa para indies.
  - **Si dan luz verde:** se reactiva Pro (checklist abajo) dentro del plazo que den, por escrito.
  - **Si no:** Pro sigue apagado hasta que haya usuarios suficientes para cubrir la licencia.
- Cuentas: con 2,99 USD/mes quedan ~2,54 USD tras la comisión de 15% de las tiendas, así que hacen
  falta **~60 suscriptores** para cubrir TMDB. Con una conversión típica del 2–5%, eso son
  **~1.200–3.000 usuarios activos**.
- **No activar ninguna compra sin la licencia comercial firmada:** cobrar sin ella incumple los
  términos de TMDB y pueden revocar la clave de la API.

## Qué se quitó para siempre: anuncios

AdMob se eliminó por completo (no está detrás del interruptor). Si algún día vuelven los anuncios,
también cuentan como uso comercial para TMDB.

- Android: dependencias `play-services-ads` y `user-messaging-platform`, el `APPLICATION_ID` del
  manifiesto, `AdsManager`/`AdBannerView`, los banners de Inicio y Detalle, y "Privacidad de anuncios"
  en Cuenta. Ya no se usan `ADMOB_APP_ID` ni `ADMOB_BANNER_ID`.
- iOS: el paquete `GoogleMobileAds` (en `project.yml` y en el `project.pbxproj`), `Ads/AdBannerView.swift`,
  `GADApplicationIdentifier`, `GADAdUnitID`, `SKAdNetworkItems`, `NSUserTrackingUsageDescription`
  (permiso ATT), las variables `GAD_*` de los xcconfig y de `scripts/sync-env.sh`.
- "Sin anuncios" ya **no es una ventaja de Pro**: se quitó del paywall y de los textos en todos los idiomas.

## El interruptor

| App | Dónde | Valor actual |
|---|---|---|
| Android | `AppConfig.Pro.SALES_ENABLED` en `native-android/.../core/network/ApiClient.kt` | `false` |
| iOS | `AppConfig.Pro.salesEnabled` en `native-ios/PeliculasNative/Core/AppConfig.swift` | `false` |

Con `false`:

- `ProStore.presentPaywall()` no hace nada (en las dos apps). El enlace `peliculas://pro` tampoco abre nada.
- La sección **Pro de Cuenta** se oculta (salvo para quien ya tenga Pro comprado).
- **Avisos de episodios nuevos** (función Pro): en iOS se ocultan el interruptor "Episodios nuevos"
  de Cuenta y el botón "Avísame cuando se estrenen" de Siguiente. En Android ya estaban ocultos
  porque falta FCM (ver abajo).
- **Límite de listas** (3 en la versión gratis, `FREE_LIST_LIMIT` / `freeListLimit`): sigue activo,
  pero en vez del paywall sale un aviso que **no menciona Pro**: "Llegaste al máximo de 3 listas.
  Borra una para crear otra." Lo hace `ProStore.presentListLimit(...)`.
- Las compras de las tiendas siguen escuchándose (por si alguien ya era Pro); no se cargan productos
  ni precios porque el paywall nunca se abre.
- No hay textos de "próximamente": Apple rechaza funciones anunciadas que no están disponibles (guía 2.1).

## Checklist para reactivar Pro

### 1. Antes de tocar código
- [ ] Licencia comercial de TMDB firmada (o acuerdo de gracia por escrito, con fechas).
- [ ] Decidir qué incluye Pro y qué se queda gratis (ver "¿Pro vale la pena?" abajo).
      Regla: **no quitar a los usuarios gratis nada que ya tengan.**
- [ ] Decidir el regalo para los primeros usuarios (p. ej., meses de Pro gratis a las cuentas
      creadas antes del lanzamiento: se puede dar desde el backend con `users.created_at` y una
      fila en `entitlements`, sin cambiar las apps).

### 2. Código
- [ ] `SALES_ENABLED = true` (Android) y `salesEnabled = true` (iOS), en el mismo release.
- [ ] Revisar el paywall (`PaywallScreen.kt` / `PaywallView.swift`) con la lista final de ventajas.
      En Android el distintivo "Ahorra 40%" está fijo en `PlanCard`: calcularlo como en iOS o quitarlo.
- [ ] Tests: `F7ProTests` (Android) tiene pruebas que dependen del interruptor; con `true` corren
      las del paywall y se saltan las de "Pro oculto".
- [ ] Si se quiere avisar del límite con el paywall otra vez, ya lo hace `presentListLimit` solo.

### 3. Backend (VPS Plesk, `.env`)
- [ ] `PRO_PRODUCT_IDS=peliculas_pro_monthly,peliculas_pro_yearly,peliculas_pro_lifetime`
- [ ] `STOREKIT_BUNDLE_ID` (iOS) y `PLAY_PACKAGE_NAME` + `PLAY_CREDENTIALS_JSON` (Android).
- [ ] Notificaciones de Play (RTDN): tema de Pub/Sub + suscripción push a
      `/v1/play/notifications?token=<PLAY_RTDN_TOKEN>` (pasos en `backend/README.md`).
- [ ] `PUSH_PRO_ONLY=true` (avisos de episodios solo para Pro; es el valor por defecto).

### 4. Avisos de episodios en Android (Firebase / FCM): **pendiente**
El backend ya envía por FCM; lo que falta es la app y la configuración:
- [ ] Crear el proyecto en la consola de Firebase con el paquete `mx.creapolis.peliculas`
      (y `mx.creapolis.peliculas.debug` para pruebas).
- [ ] Añadir `google-services.json` (no subirlo si se decide tratarlo como secreto), el plugin
      `com.google.gms.google-services` y la dependencia `firebase-messaging`.
- [ ] Un `FirebaseMessagingService` que registre el token con `POST /v1/devices`
      (`platform: "android"`) y el canal de notificaciones `peliculas_episodes`.
- [ ] En el servidor: `FCM_CREDENTIALS_JSON` con una service account con el rol
      *Firebase Cloud Messaging API Admin*.
- [ ] `AppConfig.EPISODE_PUSH_AVAILABLE = true` en Android (muestra los avisos en Cuenta, Siguiente y el paywall).

### 5. Tiendas
- [ ] App Store Connect: productos `peliculas_pro_*` a la venta, con captura del paywall para revisión.
      Etiqueta de privacidad: añadir "Historial de compras" (ya está en `PrivacyInfo.xcprivacy`).
- [ ] Play Console: productos y suscripciones activos; formulario de seguridad de datos con compras.
- [ ] Texto de la ficha: añadir la sección Pro (`docs/android/PLAYSTORE.md`).

## ¿Pro vale la pena hoy?

Lo que hay hoy como Pro: **listas ilimitadas** (más de 3) y **avisos de episodios** (solo iOS hasta
tener FCM). "Sin anuncios" ya no cuenta. Es poco para que alguien pague:

- Las listas ilimitadas solo importan a usuarios muy activos.
- Los avisos de episodios son lo más valioso, pero apps gratuitas de seguimiento de series los dan gratis.

Ideas para un Pro más fuerte (sin quitar nada de lo gratis):
- Estadísticas avanzadas (tiempo visto por año, géneros, actores, "resumen del año" compartible).
- Widgets extra (próximos episodios, tamaños grandes) y iconos o temas de la app.
- Avisos más ricos: estrenos de películas de la watchlist en cines o en streaming, y cuando un
  título llega a tus plataformas.
- Exportar la biblioteca (CSV) e importar desde otras apps.
- Notas privadas por título y listas compartidas con amigos.
