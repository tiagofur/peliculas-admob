# Checklist de publicación en App Store — Películas (nativa iOS)

Estado al **2026-11-09**. Todo lo de la sección «Ya listo» está verificado funcionando;
lo demás requiere tu Apple ID.

> **Versión gratis, sin anuncios ni compras.** Por la licencia comercial de TMDB, AdMob se
> eliminó y Pro está apagado (`AppConfig.Pro.salesEnabled = false`): no hay paywall ni
> "Restaurar compras", y el límite de 3 listas avisa sin mencionar Pro. Este checklist es
> para enviar **así**. Para reactivar Pro, ver `docs/PRO.md` (incluye lo de las suscripciones).

## ✅ Ya listo (verificado)

| Pieza | Estado |
|---|---|
| Backend producción | `https://api-peliculas.creapolis.dev` vivo (healthz 200, caché TMDB, migraciones 6/6) |
| App → API | Release compilada y probada en simulador contra producción (29 peticiones verificadas en logs del VPS) |
| Tests | 32/32 verdes (3 de integración contra backend local) |
| Signing | `DEVELOPMENT_TEAM` (T5SKULSP2M) inyectado vía `sync-env.sh` |
| Bundle ID | `mx.creapolis.peliculas.native` (+ `.widget` y `.tests`) — **ficha nueva**, la Flutter sigue publicada aparte |
| Legales | `https://creapolis.dev/privacidad/` (Aviso), `https://creapolis.dev/terminos/` (Términos) y `https://creapolis.dev/es/contacto/` (Soporte) — 200 OK. Configuradas en `Info.plist` vía `IOS_*_URL` del `.env` |
| Compras | Ninguna a la vista: `salesEnabled = false` (el código de StoreKit sigue, apagado) |
| APNs push | Clave `U73X59U2VH` ya configurada en el backend de producción |
| Privacy | `PrivacyInfo.xcprivacy` presente; **sin ATT ni SDK de anuncios**; `ITSAppUsesNonExemptEncryption=false` |
| Capturas 6.9" | `appstore/capture-screenshots.sh` toma 6 (inicio, detalle, siguiente, biblioteca, buscar, cuenta). **Retómalas con este build**: las anteriores pueden mostrar el banner, la sección Pro o el paywall |

## 📋 1. Apple Developer (developer.apple.com)

- [ ] Al primer Archive con signing automático, Xcode registra el App ID
      `mx.creapolis.peliculas.native` con Push Notifications + Sign in with Apple.
      Verifica en *Certificates, Identifiers & Profiles → Identifiers*.

## 📋 2. App Store Connect (appstoreconnect.apple.com)

- [ ] **Acuerdos**: *Paid Applications* **no hace falta** mientras no se venda nada
      (solo al reactivar Pro).
- [ ] **Nueva app**: Mi Apps → «+» → iOS. Nombre: `Películas` · Idioma: Español ·
      Bundle ID: `mx.creapolis.peliculas.native` · SKU: `peliculas-native-ios`.
- [ ] **Suscripciones y compras in-app**: si ya creaste `peliculas_pro_*`, **no los adjuntes
      a la versión** y déjalos sin enviar o quítalos de la venta. Si van adjuntos, el revisor
      los busca en la app, no los encuentra y la rechaza.
- [ ] **Versión 1.0.0**: subir las 6 capturas (6.9"), icono 1024, descripción,
      keywords (español), soporte `https://creapolis.dev/es/contacto/`,
      privacidad `https://creapolis.dev/privacidad/`,
      términos `https://creapolis.dev/terminos/`, clasificación 4+/12+
      (usa las mismas respuestas que la app Flutter ya publicada), Copyright © 2026 Tiago Furtado.
- [ ] **Textos sin monetización**: descripción, texto promocional, keywords y capturas sin
      «Pro», «suscripción», «premium» ni anuncios.
- [ ] **Privacidad de la app** (App Privacy): sin «Publicidad de terceros», sin «Rastreo» y
      sin «Identificador de publicidad». Quedan: correo e ID de usuario (cuenta), contenido del
      usuario (biblioteca), ID de dispositivo (avisos), todo para la funcionalidad de la app.
- [ ] **Notas del revisor**: cuenta demo (crea un usuario por correo en la propia app
      contra producción y pon las credenciales) + nota de que Sign in with Apple también funciona.
      Añade:
      > This version has no ads and no in-app purchases; the app is completely free.
      > Free accounts can create up to 3 custom lists. Signing in is optional and only used to sync.

## 📋 3. AdMob

Ya no aplica: la app no tiene anuncios. En apps.admob.com puedes desactivar los bloques de
iOS. El `app-ads.txt` de `peliculas.creapolis.dev` no hace falta para esta app.

## 📋 4. Archive y subida (Xcode, en tu Mac)

0. Build desde `main` con el PR #185 fusionado. **No regeneres con `xcodegen`**: el
   `project.pbxproj` tiene ajustes a mano que `project.yml` no recoge y la compilación se rompe.
   Sube `CURRENT_PROJECT_VERSION` en `native-ios/Config/Shared.xcconfig` si ya subiste un build antes.
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
