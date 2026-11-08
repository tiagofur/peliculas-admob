# Checklist de publicación en App Store — Películas (nativa iOS)

Estado al **2026-11-08**. Todo lo de la sección «Ya listo» está verificado funcionando;
lo demás requiere tu Apple ID / consolas de AdMob.

## ✅ Ya listo (verificado)

| Pieza | Estado |
|---|---|
| Backend producción | `https://api-peliculas.creapolis.dev` vivo (healthz 200, caché TMDB, migraciones 6/6) |
| App → API | Release compilada y probada en simulador contra producción (29 peticiones verificadas en logs del VPS) |
| Tests | 32/32 verdes (3 de integración contra backend local) |
| Signing | `DEVELOPMENT_TEAM` (T5SKULSP2M) inyectado vía `sync-env.sh`; proyecto regenerado con `xcodegen` |
| Bundle ID | `mx.creapolis.peliculas.native` (+ `.widget` y `.tests`) — **ficha nueva**, la Flutter sigue publicada aparte |
| Legales | `https://peliculas.creapolis.dev/{privacidad,terminos,soporte}` (200 OK). Configuradas en `Info.plist` vía `IOS_*_URL` del `.env` |
| StoreKit | `Products.storekit`: `peliculas_pro_monthly` $1.99 · `peliculas_pro_yearly` $12.99 (1 sem gratis) · `peliculas_pro_lifetime` $29.99. El paywall de la app coincide |
| APNs push | Clave `U73X59U2VH` ya configurada en el backend de producción |
| Privacy | `PrivacyInfo.xcprivacy` presente; ATT con texto en español; `ITSAppUsesNonExemptEncryption=false` |
| Capturas 6.9" | `native-ios/appstore/screenshots/*.png` — 7 pantallas a 1320×2868 (onboarding, home, detalle, buscar, biblioteca, cuenta, Pro) |
| Banner AdMob | Banner de **prueba** de Google (decisión tomada; ver «Pendiente» para el real) |

## 📋 1. Apple Developer (developer.apple.com)

- [ ] Al primer Archive con signing automático, Xcode registra el App ID
      `mx.creapolis.peliculas.native` con Push Notifications + Sign in with Apple.
      Verifica en *Certificates, Identifiers & Profiles → Identifiers*.

## 📋 2. App Store Connect (appstoreconnect.apple.com)

- [ ] **Acuerdos**: *Agreements, Tax, and Banking* → activar **Paid Applications**
      (banco + impuestos). Sin esto no se pueden vender suscripciones.
- [ ] **Nueva app**: Mi Apps → «+» → iOS. Nombre: `Películas` · Idioma: Español ·
      Bundle ID: `mx.creapolis.peliculas.native` · SKU: `peliculas-native-ios`.
- [ ] **Suscripciones** (Monetización → Suscripciones):
      - Grupo: `Películas Pro`
      - `peliculas_pro_monthly` — $1.99 USD/mes (MX $35 aprox), 1 semana de prueba
      - `peliculas_pro_yearly` — $12.99 USD/año, 1 semana de prueba, nivel del grupo
      - Pantalla de pago: puedes usar `07-pro-6.9.png`
      - Revisión de suscripción: descripciones cortas (sin anuncios, avisos, listas ilimitadas)
- [ ] **Compra no consumible** (Monetización → Compras in-app):
      `peliculas_pro_lifetime` — $29.99 USD, pago único
- [ ] **App Store Server Notifications V2** (Información de la app → URL de servidor):
      `https://api-peliculas.creapolis.dev/v1/storekit/notifications`
      (producción **y** sandbox). El backend ya la valida.
- [ ] **Versión 1.0.0**: subir las 7 capturas (6.9"), icono 1024, descripción,
      keywords (español), soporte `https://peliculas.creapolis.dev/soporte`,
      privacidad `/privacidad`, términos `/terminos`, clasificación 4+/12+
      (usa las mismas respuestas que la app Flutter ya publicada), Copyright © 2026 Tiago Furtado.
- [ ] **Adjuntar los 3 IAP** a la versión 1.0.0 antes de enviar a revisión.
- [ ] **Notas del revisor**: cuenta demo (crea un usuario por correo en la propia app
      contra producción y pon las credenciales) + nota de que Sign in with Apple también funciona.

## 📋 3. AdMob (apps.admob.com)

- [ ] Crear bloque **banner** para iOS → actualizar `ADMOB_IOS_BANNER` en el `.env`
      raíz → `cd native-ios && ./scripts/sync-env.sh && xcodegen generate`.
      (Hoy usa el banner de prueba de Google a propósito.)
- [ ] Publicar **mensajes de privacidad UMP** (Consentimiento → GDPR para EEA/UK;
      la app ya integra UMP).
- [ ] `app-ads.txt`: ya hay uno servido en `peliculas.creapolis.dev` (heredado del
      Flutter) — actualízalo con el publisher ID si hace falta y declara
      `https://peliculas.creapolis.dev` como web del desarrollador en ASC.

## 📋 4. Archive y subida (Xcode, en tu Mac)

1. `open native-ios/PeliculasNative.xcodeproj`
2. Scheme **PeliculasNative**, destino *Any iOS Device (arm64)*.
3. *Product → Archive* (usa config Release → API de producción).
4. *Distribute App → App Store Connect → Upload*. Signing automático con tu team.
5. En ASC: seleccionar el build 1.0.0 (1) en la versión y **enviar a revisión**.

## 📋 5. Pendientes externos conocidos

- `peliculas.creapolis.mx` **no tiene DNS delegado** (parece expirado). Las URLs de la
  app ya apuntan a `.dev`; decide si renuevas el `.mx` o lo dejas morir (el `app-ads.txt`
  antiguo del Flutter vivía ahí).
- Rotar secrets del historial de git (Supabase service role, Trakt) — pendiente de otra sesión.

## Redespliegue / day-2

- Backend: `cd backend && API_PORT=8790 ./deploy/plesk/deploy-plesk.sh ordo-vps`
- Nueva versión de la app: subir `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` en
  `native-ios/Config/Shared.xcconfig` → Archive de nuevo.
