## App nativa iOS hermosa estilo Apple TV con Liquid Glass, mínimo iOS 15

Branch: `feat/native-ios-liquid-glass` (desde `feat/series-support`). Estrategia: `ask-on-risk`. Runner: Xcode 27.2 + Swift 6.4.2.

## Specs

- S1: "quiero hacer la app NATIVA de IOS con liquid Glass y todo lo hermosos que se puede hacer en una app ios nativa"
- S2: "con version minima ios 15"
- S3: "revisa TODO que puedas de la documentacion sobre ios 15 y 26 y 27 que ya usan el liquid glass y como resolver para versiones anterior a 26 que no tenian liquid glass"
- S4: "para crear la app nativa ios hermosa al estilo Apple TV"
- S5: "existe algun tipo de Admob pero de Apple? si no existe usamos el mismo de google"
- S6: "empezamos a desarrollar, va a quedar hermosa"

## Tasks

- T1 (S1,S2,S3): scaffold `native-ios/` SwiftUI + Deployment Target 15.0 + SDK 27 — route: inline — status: done — commit: pending (BUILD SUCCEEDED generic/platform=iOS, CODE_SIGNING_ALLOWED=NO)
- T2 (S1,S3,S4): design system `GlassIfAvailable` + Regular/Clear + fallback blur iOS 15 — route: inline — status: done — commit: pending
- T3 (S4): Home estilo Apple TV (hero edge-to-edge + rails) + Detalle — route: inline — status: done (corte Home+detalle elegido) — commit: pending
- T4 (S4): Detalle + Biblioteca (Favoritos/Watchlist/Vistas/Calificadas/Listas, ratings, store local UserDefaults v1-compatible) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; @State evitado: macro no expande en este toolchain, estado en LibraryStore)
- T4b: TMDB real (popular/trending/top_rated + pósters, fallback muestra sin key) — route: inline — status: done — commit: pending
- T5 (S5): AdMob Google-Mobile-Ads-SDK vía SPM — route: inline — status: parcial (stub `#canImport` + `GAD_AD_UNIT_ID` cableado; resolución SPM bloqueada por sandbox `~/Library/Caches` incluso con `-packageCachePath`; snippet exacto en `native-ios/README.md` para tu Mac) — commit: pending
- T7: Buscar (TMDB `/search/movie` + debounce, tab Buscar) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T8: Sync Supabase (`user_lists`/`user_list_items`, local-first, push con token) — route: inline — status: done (código; NO verificado contra backend: sin red a Supabase desde este equipo) — commit: pending
- T9: Login nativo (GoTrue REST login/registro/logout, tab Cuenta, token → sync) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; auth real sin verificar: sin red a Supabase desde este equipo)
- T10: Series + tráilers (endpoints `/tv`, rail Series en tendencia, búsqueda Películas/Series, player YouTube embebido WebKit, chip SERIE/PELÍCULA + año, metadatos duración/temporadas/episodios/géneros vía `/movie|tv/{id}`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; datos reales sin verificar: sin red a TMDB desde este equipo)
- T11: Temporadas/episodios (`/tv/{id}/season/{n}`, selector de temporada, stills) + player a pantalla completa (`fullScreenCover` + botón Listo) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; episodios/player real sin verificar: sin red a TMDB desde este equipo)
- T12: Reparto (`/movie|tv/{id}/credits`, fotos circulares + personaje) + Similares (`/similar`, rail con navegación) en el detalle — route: inline — status: done — commit: pending (BUILD SUCCEEDED; datos reales sin verificar: sin red a TMDB desde este equipo)
- T13: Logros (umbrales de `achievement_categories.dart`, tab Logros con puntos/progreso, toast al desbloquear, persistidos) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; desbloqueo real se verifica en device con uso)
- T14: Widget Tendencias (WidgetKit small/medium, timeline 6h, TMDB o muestra; target app-extension vía xcodegen) — route: inline — status: done — commit: pending (BUILD SUCCEEDED app+extensión; contenido real sin verificar: sin red a TMDB desde este equipo)
- T15: Calificaciones (estrellas 1–10 en detalle, sección Calificadas, persistidas v1-compatible) + compartir real (UIActivityViewController con link TMDB) + pull-to-refresh + caché de pósters (URLCache 50/200MB) + háptica al guardar — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T16: Recordatorios locales (UserNotifications: tendencias viernes 19h + nudge watchlist domingo, toggle en Cuenta, espejo de `notification_preferences.dart`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; disparo real solo en device con permiso)
- T17: Estado sin conexión en Home (banner + reintentar) + encabezados de accesibilidad en secciones — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T18: Historial de búsqueda (últimas 8 con resultado, re-ejecutar, borrar) + tap del widget abre la app (`widgetURL peliculas://trending`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; trampa `Published.prepend` corregida a `insert(at:)`)
- T19: Diagnóstico "no carga películas" (key ausente vs sin red): `keyOrigin` + banner honesto + campo para pegar TMDB_API_KEY en Cuenta sin recompilar + tests `KeyConfigTests` — route: inline — status: done (BUILD SUCCEEDED app; tests en repo SIN correr ni compilar aquí: sandbox bloquea caché de módulos y no hay simuladores; correr en tu Mac con `xcodebuild test -scheme PeliculasNativeTests`) — commit: pending
- T20: Claves del `.env` al build (`scripts/sync-env.sh` → `Secrets.generated.xcconfig` gitignored → xcconfig del proyecto; verificado: el .app trae TMDB_API_KEY de 33 chars sin exponerla) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T21: Deep links `peliculas://` (esquema registrado en plist + `onOpenURL` por tab: trending→Inicio, search→Buscar, library→Biblioteca) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; esquema verificado en Info.plist generado)
- T22: Resumen de actividad en Cuenta (Favs/Watchlist/Vistas/Puntos) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T23: Compartir con link incluido en el texto (antes solo el título; Copiar pegaba sin URL) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; verificado en compilación, pendiente prueba de Copiar en device)
- T24: Filtros de búsqueda (géneros `/genre/movie|tv/list` + año vía `/discover`, espejo de `advanced_search` de Flutter) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; resultados reales sin verificar: sin red a TMDB)
- T25: "Porque viste X" (recomendaciones del primer favorito vía `/recommendations`, espejo de `personalized_recommendations` de Flutter) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; rail real sin verificar: sin red a TMDB)
- T26: "Visto recientemente" (últimos 12 detalles abiertos, rail en Home, persistido v1-compatible) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T27: Onboarding de primer uso (bienvenida + qué hace la app + aviso de key si falta, una sola vez) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; `.foregroundStyle(.accentColor)` no existe en ShapeStyle: se usa `.tint`)
- T28: Botones Favorito/Vista conmutan de verdad (`toggleWatched` nuevo; `markWatched` solo insertaba) + estado visible (cápsula llena vs tenue) + VoiceOver anuncia activado/desactivado — route: inline — status: done — commit: pending (BUILD SUCCEEDED; verificado en compilación, pendiente toque real en device)
- T29: Home más ancho que la pantalla (backdrop con `.frame(height:)` imponía proporción 747pt; ahora caja fija + `maxWidth`) + rails `LazyHStack`→`HStack` + mismo fix en detalle — route: inline — status: done — commit: pending (BUILD SUCCEEDED; verificado en compilación, pendiente confirmación visual en device: hero encuadrado y primeras películas visibles)
- T30: "Ver todo" en cada rail (cuadrícula completa con navegación al detalle) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T31: Episodios vistos (ojo por episodio en Temporadas, persistido v1-compatible) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T32: Auditoría iOS 15 (grep: cero APIs 16+; el compilador ya lo garantiza con deployment 15.0) + checklist de publicación en README — route: inline — status: done — commit: pending
- T33: Año+rating en celdas de búsqueda + "Ver bienvenida de nuevo" en Cuenta — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T34: Badge con conteo en tab Biblioteca (solo si >0; `.badge` no acepta nil) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T35: Voto visible en pósters de Calificadas (cápsula con tu 1–10) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T36: "Tú: X" junto al rating TMDB en el encabezado del detalle — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T37: Progreso por temporada ("3/10") + botón Toda/Ninguno para marcarla entera — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T38: Episodios vistos en Tu actividad (quinto stat) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; se revirtió un gancho muerto antes de compilar)
- T39: Perfil de actor (foto, biografía, datos, filmografía navegable con `/person/{id}` y `/movie_credits`; tapping una tarjeta de reparto abre su perfil, espejo de `ActorScreen`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; rails similares también a HStack)
- T40: "Dónde verla" (logos MX de `/watch/providers` + link JustWatch, sección en el detalle) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; logos reales sin verificar: sin red a TMDB)
- T41: "Dónde verla" incluye renta y compra además de plana (en MX muchos títulos no tienen `flatrate`; la sección no salía) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T42: Región del teléfono para "Dónde verla" (`Locale`, fallback US; sin atar a MX) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T43: Bug real "Dónde verla" no salía nunca (faltaba `convertFromSnakeCase` en ese decode; `try?` lo tragaba en silencio) + `decodeWatchProviders` puro + tests `WatchProvidersTests` — route: inline — status: done — commit: pending (BUILD SUCCEEDED app; tests en repo sin correr aquí)
- T44: Tap abre LA APP del proveedor vía `ProviderLinks` (cascade espejo de Flutter `DeepLinkService`: esquema app → web propia; Apple TV directo a tv.apple.com; desconocido→JustWatch regional; el `link` de TMDB nunca es destino) + test `ProviderLinksTests` (no corrido aquí) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T45: Auditoría Flutter→nativa (639 dart): streaming ya portado (`tmdb_provider_mapper` + `deep_link_service` → cascade app→web en `ProviderLinks`); IDs extra (Prime 119/2100/10, Max 1825/425, Paramount 582/2303) — route: inline — status: done — commit: pending (BUILD SUCCEEDED)
- T46: Fallback a App Store si la app del proveedor no está instalada (a pedido: antes caía a Safari; cascade app→store→web, espejo Flutter) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; tests actualizados, sin correr aquí)
- T47: Detección real de app instalada (`canOpenURL` + `LSApplicationQueriesSchemes` en plist vía project.yml; corrige "Safari no puede abrir, dirección inválida": ya no se intenta un esquema sin app que lo maneje) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; plist verificado con los 6 esquemas)
- T48: Niveles de usuario por puntos (espejo `Level.defaultLevels`: 7 umbrales 0/150/400/800/1500/2500/4000, nivel + progreso en Logros, `LevelTests`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; tests sin correr aquí)
- T49: Fix tests en device real (`GENERATE_INFOPLIST_FILE: YES` en `PeliculasNativeTests`; el error "target does not have an Info.plist" bloqueaba `xcodebuild test`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED app; test corre en tu Mac)
- T50: Fix `KeyConfigTests` en Swift 6 (`@MainActor` en el test que lee `HomeLoader.offline/keyMissing`; eran los únicos 2 errores del run en tu Mac) + 3 warnings heredados intactos (shareURL `URL?`, `glassProminent`, háptica) — route: inline — status: done — commit: pending (BUILD SUCCEEDED app; TEST pendiente en tu Mac)
- T51: Tests rojos en tu Mac corregidos (eran culpa de los tests, no de la app): `KeyConfigTests` ya no asume "sin key" (tu Mac la tiene por sync-env.sh; acepta ambos entornos) + helper de `ProviderLinksTests` con keys camelCase (el `try!` con `snake_case` y decoder plano crasheaba) — route: inline — status: done — commit: pending (TEST SUCCEEDED verificado en tu Mac: `success`)
- T52: Detalle con portada siempre arriba y tráiler debajo (antes el tráiler reemplazaba la portada y no se veía; sección "Tráiler" con header como el resto) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; QA visual en tu Mac)
- T53: Transiciones (momento protagonista: la portada "aterriza" con fade+scale al abrir el detalle; tráiler entra con fundido; tabs con crossfade) iOS 15-safe, flag en `DetailLoader` (patrón del proyecto: `@State` no expande en este toolchain) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; QA visual en tu Mac)
- T54: Portada estilo Flutter (`SliverAppBar`: full-bleed `w1280`/póster, fondo negro, degradado inferior al fondo + superior para la navegación) + hero-transition póster→detalle (`matchedGeometryEffect`, 8 orígenes: hero, rails, ver-todo, buscar, biblioteca, lista, similares, filmografía) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; QA visual de la morph en tu Mac)
- T55: Fixes de tu captura ("Animales"): portada mitad blanca = el fade de entrada peleaba con la morph (ahora la morph la lleva sin fade); tráiler con Error 153 = embed restringido (botón "Abrir en YouTube" como salida + `playsinline=1`) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; QA visual en tu Mac)
- T56: Morph retirada (tu captura "Materia oscura" la mostró desplazando la portada fuera de su marco: `matchedGeometryEffect` + push + cambio de aspecto póster→héroe no se llevan; portada full-bleed fija + fade de entrada, que sí es determinista) — route: inline — status: done — commit: pending (BUILD SUCCEEDED; QA visual en tu Mac)
- T6 (S1,S3): QA iOS 15/26/27 + accesibilidad (slider Glass, Reduce Transparency/Contrast/Motion) — route: inline — status: in_progress (simuladores de este equipo caídos; corre en tu Mac) — commit: pending

## Log

- L1 (2026-11-07): "sabes que... quiero hacer la app NATIVA de IOS con liquid Glass y todo lo hermosos que se puede hacer en una app ios nativa... con version minima ios 15. revisa TODO que puedas de la documentacion sobre ios 15 y 26 y 27 que ya usan el liquid glass y como resolver para versiones anterior a 26 que no tenian liquid glass y planeamos todo para crear la app nativa ios hermosa al estilo Apple TV"
- L2: "existe algun tipo de Admob pero de Apple? si no existe usamos el mismo de google" → decisión: no existe equivalente (iAd cerrado 30-jun-2016); se usa Google AdMob también en nativa.
- L3: "empezamos a desarrollar, va a quedar hermosa" → autorización para implementar. Base verificada: Flutter con `IPHONEOS_DEPLOYMENT_TARGET = 15.0`, Xcode 27.2 disponible.
- L4 (2026-11-07): `xcodebuild test -scheme PeliculasNativeTests` intentado aquí → NO corre: CoreSimulatorService caído ("Connection invalid", sin runtimes) y el destino genérico rechaza tests ("must be run on a concrete device", exit=70). `ProviderLinksTests` queda para tu Mac.
