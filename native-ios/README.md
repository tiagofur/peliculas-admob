# Películas — App nativa iOS

SwiftUI, mínimo iOS 15. Liquid Glass real en iOS 26+ y materiales clásicos en iOS 15–25.
Habla solo con el **backend Go** (`backend/`): TMDB por su caché, cuentas, sync, Pro y avisos. Ya no usa Supabase ni lleva la key de TMDB dentro.

> Qué falta configurar fuera del código (Apple, App Store Connect, servidor). Sin anuncios y con Pro apagado: ver [`docs/PRO.md`](../docs/PRO.md): [`docs/ios/configuracion-produccion.html`](../docs/ios/configuracion-produccion.html).

## Correr en el simulador

```bash
# 1. Backend local (otra terminal). Usa el puerto 8787 porque 8080 suele estar ocupado.
cd backend && API_PORT=8787 docker compose up -d --build

# 2. App
cd native-ios
./scripts/sync-env.sh      # lee el .env de la raíz → Config/Secrets.generated.xcconfig (gitignored)
xcodegen generate
open PeliculasNative.xcodeproj   # ⌘R con el esquema PeliculasNative
```

Debug apunta a `http://127.0.0.1:8787`. En un iPhone físico pon `IOS_API_BASE_URL_DEV` en el `.env` (la IP de tu Mac o tu servidor).

## Tests

```bash
xcodebuild test -scheme PeliculasNative -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

- Unitarios: modelos, sync (last-write-wins, formato de ops), "Siguiente", proveedores, niveles.
- `ProStoreTests`: compras con `Products.storekit` (sin App Store).
- `BackendIntegrationTests`: registro → sync entre dos "dispositivos" → borrar cuenta, contra el backend local. Se saltan solos si el backend no responde.

## Configuración

| Archivo | Qué hay |
|---|---|
| `Config/Shared.xcconfig` | Bundle ID, versión, URLs por defecto, páginas legales |
| `Config/Debug.xcconfig` / `Release.xcconfig` | URL del backend por entorno, APNs sandbox/producción |
| `Config/Secrets.generated.xcconfig` | Lo tuyo, generado desde el `.env` (no se commitea) |
| `project.yml` | Proyecto XcodeGen: targets, entitlements, Info.plist. Ojo: el `.pbxproj` ya tiene ajustes a mano; no lo regeneres sin revisar el diff |
| `Products.storekit` | Productos Pro para probar compras en el simulador |
| `PeliculasNative/PrivacyInfo.xcprivacy` | Privacy Manifest |

Variables del `.env` que lee `sync-env.sh`: `IOS_API_BASE_URL`, `IOS_API_BASE_URL_DEV`, `APPLE_TEAM_ID`, `IOS_BUNDLE_ID`, `IOS_PRIVACY_URL`, `IOS_TERMS_URL`, `IOS_SUPPORT_URL`.

## Arquitectura

```
App/          entrada, pestañas, deep links (peliculas://…), hojas globales
Core/         APIClient (Bearer + refresh), TMDBClient (vía /v1/tmdb), Keychain,
              PushManager (APNs), ReminderManager, diseño (Liquid Glass + respaldo)
Models/       MediaItem + MediaKey (tipo + id: película 1399 ≠ serie 1399)
Features/
  Auth/       SessionStore (email + Sign in with Apple), SignInView, AccountView
  Library/    LibraryStore local-first + cola de sync, SyncModels, LibraryView
  UpNext/     "Siguiente": próximo episodio por serie y estrenos
  Pro/        ProStore (StoreKit 2) y paywall
  Home/ Detail/ Search/ Actors/ Gamification/ Onboarding/
PeliculasWidget/  widget "Tendencias" con pósters
```

**Sync**: cada cambio guarda su hora y deja una op en la cola. La cola sube 3 s después, al abrir y al volver a primer plano; luego se baja todo desde el cursor. Al iniciar sesión se sube la biblioteca local entera (fusión). Al cerrar sesión se vacía lo local (los datos quedan en la cuenta).

**Pro**: el estado sale de `Transaction.currentEntitlements` (funciona sin cuenta y sin red). Con sesión, cada compra se reclama en `POST /v1/storekit/transactions` con `appAccountToken` = ID del usuario.

## Diseño

- Contenido primero: héroe a sangre completa, pósters grandes; el vidrio solo en controles flotantes.
- iOS 18+: API `Tab` con pestaña de búsqueda (`role: .search`). iOS 26+: barra que se encoge al bajar, botones `.glass` / `.glassProminent`, `GlassEffectContainer`.
- Menú contextual en cada póster (Watchlist, favorito, vista, listas, compartir).
- Hápticos, Dynamic Type, VoiceOver (etiquetas y encabezados), Reduce Motion (el carrusel no avanza solo).
