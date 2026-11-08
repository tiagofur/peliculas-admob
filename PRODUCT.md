# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

SwiftUI (respuesta del usuario a la pregunta de stack; Deployment Target iOS 15.0, SDK 27, Xcode 27.2)

## Users

Fans de cine y series que exploran qué ver y gestionan su biblioteca (Favoritos, Watchlist, Vistas, Listas propias). Uso personal, en iPhone, en español/inglés/portugués según `lib/l10n` (`app_es`, `app_en`, `app_pt`, `app_pt_BR`).

## Product Purpose

App nativa iOS hermosa al estilo Apple TV para explorar y gestionar películas y series. Datos de TMDB, trailers de YouTube, cuentas y sincronización con el backend Go propio, gamificación y modo offline heredados del Flutter actual. Éxito: se ve espectacular, carga rápido y el chrome (tab bar, toolbars) usa Liquid Glass en iOS 26/27 sin romperse en iOS 15.

## Positioning

La misma Películas que ya existe en Flutter/Android, pero reescrita nativa: contenido manda (hero edge-to-edge, rails de pósters), chrome mínimo flotante en vidrio. No es un port visual 1:1 del Material de Flutter.

## Operating Context

Uso en sofá/sesión de descubrimiento: Home con destacados, detalle con trailer, guardar en Watchlist/Listas, compartir. Rutas actuales en `lib/config/router/app_router.dart` (Home, Mi Biblioteca, Watchlist, Listas, Perfil, Logros, Settings). Deep links `peliculas://` según `Info.plist`.

## Capabilities and Constraints

- Mínimo iOS 15.0 (`ios/Podfile`, `IPHONEOS_DEPLOYMENT_TARGET = 15.0`); se conserva.
- Liquid Glass solo existe desde iOS 26 (WWDC25) y se refina en 27; en 15–25 fallback con blur clásico (`.thinMaterial` / `UIVisualEffectView`).
- Backend propio en Go (`backend/`): caché TMDB, cuentas (email + Apple), sync, Pro (StoreKit 2) y avisos APNs. Supabase queda solo para la app Flutter hasta migrarla.
- Monetización: Google AdMob (no existe equivalente de Apple; iAd cerró 30-jun-2016). Mismo `GADApplicationIdentifier` actual.
- Decisión abierta: nombre del nuevo target/proyecto `native-ios/` vs reemplazo de `ios/Runner`; se asume carpeta paralela hasta decidir publicación.

## Brand Commitments

Nombre Películas. Estilo Apple TV, oscuro, pósters grandes. Sin compromisos nuevos de logo o voz.

## Evidence on Hand

- `README.md`: app Flutter Supabase + gamificación + offline; TMDB + YouTube.
- `lib/presentation/screens/movies/`, `lib/presentation/screens/series/serie_screen.dart`, `lib/config/router/app_router.dart`.
- `ios/Runner/Info.plist` con `GADApplicationIdentifier`; `ios/Podfile` platform 15.0.
- Guías Liquid Glass inspeccionadas (mirrors que citan WWDC25 219/356/220 y HIG).

## Product Principles

- Contenido primero, chrome deferente.
- Nativo de verdad: componentes del sistema antes que imitaciones.
- Legible en todo el rango del slider Glass de iOS 27.
- Rendimiento: vidrio solo en chrome, nunca en celdas.
- Paridad de datos con Flutter/Android, no divergencia de backend.

## Accessibility & Inclusion

Soportar Reduce Transparency, Increase Contrast, Reduce Motion y el slider de Liquid Glass de iOS 27; contraste verificado sobre pósters brillantes.
