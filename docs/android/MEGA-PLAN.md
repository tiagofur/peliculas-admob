# MEGA PLAN — App Android nativa «Películas» (Material 3 Expressive)

> Plan de implementación de la app Android nativa con **paridad funcional completa** con la
> app iOS (`native-ios/`, fases 1-4 + universal links, todo en `main` a nov 2026).
> Código nuevo en `native-android/`. Producto: [`PRODUCT.md`](../../PRODUCT.md) ·
> Plan iOS que cierra: [audits/2026-11-ios-app-review.md](../audits/2026-11-ios-app-review.md)
>
> Redactado: 2026-11-08 · Estado: 📝 plan (pendiente de aprobación)

---

## 1. Objetivo y principios

**Llevar a Android la misma app que ya vive en iOS**, no una versión reducida:

1. **Paridad 1:1 de features** con iOS (inventario en §2). Mismo backend Go (`api-peliculas.creapolis.dev`), misma cuenta, misma biblioteca sincronizada.
2. **Nativo de verdad**: Kotlin + Jetpack Compose + **Material 3 Expressive** (estable en `material3 1.9.x`), dynamic color, widgets, App Links.
3. **Mismos modelos de sync**: portar `LibraryStore` tal cual (JSON + outbox + cursor) para que iOS y Android sean clientes intercambiables del mismo protocolo `/v1/sync`.
4. **ES/PT primero**: mismos strings del catálogo (es base, en, pt-BR) — portar `Localizable.xcstrings` a `strings.xml`/`resources`.
5. **Monetización espejo**: Pro (mensual/anual/lifetime) con los mismos product IDs (`peliculas_pro_*`) vía Play Billing; AdMob banner solo en gratis.

**No competitivo con la app Flutter**: la Flutter sigue en `flutter/` (web + existentes); esta es la nativa para Play Store, como `native-ios` lo es para App Store.

---

## 2. Inventario de paridad (qué debe tener Android)

### 2.1 Features de la app iOS hoy (todo esto se replica)

| Área | Features iOS | Referencia iOS |
|---|---|---|
| Home | Héroe carrusel auto-avance, rails (series tendencia, cines, estrenos, aclamadas), Top 10, Continuar viendo, Visto recientemente, "Porque te gustó X", pull-to-refresh | `HomeView/HomeLoader` |
| Listas | **Infinite scroll** en Ver todo/búsqueda/géneros/moods (PagedListLoader: seed, dedupe, tope 10 págs, retry), estados vacío/error | `PagedListLoader`, `SeeAllView` |
| Descubrimiento | Explorar por género con **orden (populares/valoradas/recientes) + filtro año**, 8 **moods curados** (discover con géneros+piso de votos+nota mínima) | `GenreResultsView`, `Moods.swift` |
| Búsqueda | Debounce, scopes Todo/Películas/Series, historial 8, **personas** (fila → ficha actor), paginación infinita | `SearchLoader/SearchView` |
| Detalle | Stretchy header, actionBar (watchlist/fav/visto/listas/share), estrellas + **reseña personal**, **Dirección/Creado por**, temporadas+episodios con marcado y "marcar todo", tráiler embebido, "Dónde verla" (providers + deep links a apps), reparto → actor, similares, TMDB attribution, refreshable | `DetailView/DetailLoader` |
| Biblioteca | Watchlist/Favoritos/Vistas/Calificadas/Listas propias (límite 3 gratis), recientes, **Estadísticas** (tiles + actividad 12 meses + épocas), **Historial por mes** | `LibraryView`, `StatsView`, `HistoryView` |
| Siguiente | Próximo episodio por serie, marcar visto desde tarjeta, próximos episodios al aire, paywall gate de avisos | `UpNextView/UpNextStore` |
| Cuenta/Sync | Email+password, Sign in with Apple, tokens rotativos en llavero, sync biblioteca (outbox/pull/lww), merge al entrar, logout/borrar cuenta | `SessionStore`, `LibraryStore.sync` |
| Gamificación | Logros + niveles + toast desbloqueo | `Achievements*` |
| Monetización | Paywall Pro (StoreKit 2), restore, gate de listas y avisos, AdMob banner | `ProStore/PaywallView` |
| Notificaciones | Recordatorios semanales locales (viernes tendencias / domingo watchlist), push de episodios nuevos (Pro, APNs) | `ReminderManager`, `PushManager` |
| Widget | Tendencias del día (small/medium) con pósters, estado "Sin conexión" honesto | `TrendingWidget` |
| Deep links | Esquema propio + **universal links** `peliculas.creapolis.dev/movie|serie/{id}` (AASA en VPS), share con enlaces propios | `DeepLinkRouter` |
| Bugs ya resueltos que Android debe evitar desde el diseño | 401 limpia biblioteca (no mezcla cuentas), retry en detalle, episodios no obsoletos, widget sin datos falsos, héroe con error | PRs #163/#164 |

### 2.2 Gaps conocidos de iOS (no bloquean; Android puede adelantar los baratos)

Del audit: **Wrapped anual compartible** (render imagen + share), widget de lock screen,
modo offline/biblioteca sin red, películas en "Siguiente", varios tráilers, filtro "mis
plataformas" en explorar, Live Activities (equivalente Android: no aplica; sí rich/ongoing
notifications). **Decisión propuesta**: Android nace sin estos; el Wrapped se diseña a la par
en ambas plataformas en su momento (F9 opcional).

---

## 3. Stack tecnológico

| Capa | Elección | Notas |
|---|---|---|
| Lenguaje | **Kotlin 2.2+** | Coroutines + Flow |
| UI | **Jetpack Compose** (BOM nov 2026) + **Material 3 Expressive** (`material3 1.9.x`) | `MaterialExpressiveTheme`, dynamic color (Android 12+), Styles API, componentes expressive (§7) |
| SDK | **minSdk 26** (Android 8, ≈97% dispositivos) · **targetSdk 36** (obligatorio Play hasta ago 2027) · compileSdk 36/37 | Edge-to-edge, splash API, adaptive icons |
| Navegación | Navigation Compose type-safe + bottom bar M3 | Espejo de `AppTab` (home/siguiente/biblioteca/buscar) |
| Arquitectura | **Single-module** espejo de iOS: `features/<area>/` con `ViewModel + StateFlow`; **DI manual** (`AppContainer` en Application, como los `@EnvironmentObject`) | Sin Hilt a propósito: paridad estructural 1:1 con iOS y menos artefactos. Reevaluable si el módulo crece |
| Red | **Retrofit + OkHttp + kotlinx.serialization** | `ApiClient.kt` (auth, refresh rotativo, errores) y `TmdbClient.kt` port de `APIClient/TMDBClient` (mismo proxy `/v1/tmdb`, `page`/`total_pages`, allowlist ya soportada) |
| Sesión | Tokens en **Keystore** (EncryptedSharedPreferences/DataStore cifrado); refresh rotativo con cola single-flight (port `validAccessToken`) | Mismo `StoredSession` |
| Biblioteca | **JSON file + kotlinx.serialization** (port exacto de `LibraryStore`: marks/ratings/lists/episodes, outbox, cursor, last-write-wins) | Clave para que ambos clientes hablen el mismo `/v1/sync` sin cambios |
| Imágenes | **Coil 3** (caché memoria/disco, dedupe, cancelación, prefetch en rails) | Resuelve de serie lo que iOS sufre con `AsyncImage` |
| Gráficas | Compose `Canvas` custom (barras actividad + épocas) | Mismo diseño que Swift Charts, sin dependencia |
| Vídeo | Tráiler: WebView con **YouTube IFrame Player** (igual que iOS) | Fullscreen bottom-sheet M3 |
| Notificaciones locales | **WorkManager** (periódico) + AlarmManager exacto para viernes/domingo | Port `ReminderManager` |
| Push | **FCM** (episodios nuevos, Pro) | ⚠️ requiere workstream backend (§6.1) |
| Compras | **Play Billing Library 7+**: `peliculas_pro_monthly/yearly/lifetime` (mismos IDs), restore, entitlements vía backend | ⚠️ requiere backend verify (§6.2) |
| Ads | Google Mobile Ads (AdMob) banner adaptativo solo en gratis | Ad units nuevos de Android |
| Widget | **Glance** (Compose) — tendencias small/medium | Mismo fetch + estado offline honesto |
| Links | **App Links** `peliculas.creapolis.dev` → `assetlinks.json` | Reusa subdominio y patrón nginx del AASA (§6.3) |
| Rendimiento | R8 + **Baseline Profiles** + startup profile | |
| CI | GitHub Actions: `build + test + detekt/ktlint` en PR | Igual que valida GitGuardian hoy |

---

## 4. Mapa de pantallas iOS → Android

| iOS | Android (Compose) |
|---|---|
| `RootView` (tabs + modal host + toast logros) | `RootScaffold` (NavigationBar M3 + Snackbar/Toast logros) |
| `HomeView` (héroe + rails) | `HomeScreen` (HorizontalPager héroe + LazyRows) |
| `SeeAllView` + `PosterGrid` | `SeeAllScreen` (LazyVerticalGrid 3 col + footer load-more) |
| `SearchView` (+géneros/moods/personas) | `SearchScreen` (SearchBar M3 + chips scopes + grids) |
| `GenreResultsView`/`PagedResultsView` | `ResultsScreen` (toolbar filtros: orden/año) |
| `DetailView` | `DetailScreen` (collapsing header + secciones) |
| `ActorView` | `ActorScreen` (filmografía LazyRow/grid) |
| `LibraryView`/`StatsView`/`HistoryView` | `LibraryScreen`/`StatsScreen`/`HistoryScreen` |
| `UpNextView` | `UpNextScreen` |
| `SignInView`/`AccountView` | `SignInScreen` (email + **Google Sign-In**)/`AccountScreen` |
| `PaywallView` | `PaywallScreen` (Play Billing) |
| `OnboardingView` | `OnboardingScreen` |
| `TrendingWidget` | `TrendingWidget` (Glance) |

**Traducción de estilo** (Liquid Glass iOS → M3 Expressive): botones glass → `FilledTonalButton`/expressive shapes; `SectionHeader` con "Ver todo" → headers con `TextButton`; badges SERIE/PELÍCULA → `AssistChip`; filtros toolbar → `FilterChip` + `DropdownMenu`; estrellas → `RatingBar` custom (mismos 5 pasos 0.5).

---

## 5. Fases de implementación

Cada fase = rama `feat/android-<fase>` + PR + tests verdes. Las estimaciones son de esfuerzo relativo (S ≤2d, M ≤1 sem, L 1-2 sem).

### F0 — Fundaciones (M)
- Proyecto Gradle/Kotlin en `native-android/`, package `mx.creapolis.peliculas.android`.
- Tema M3 Expressive: `MaterialExpressiveTheme` + paleta custom + dynamic color + dark; tipografía y shapes.
- `AppContainer` (DI manual), Navigation Compose con 4 tabs, CI GitHub Actions.
- **Puertos núcleo**: `ApiClient.kt` (perform/authed/refresh rotativo/APIError), `TmdbClient.kt` (get/list/pagedList + `MediaListSource` + `DiscoverSort` + modelos kotlinx.serialization), `MediaItem`/`MediaKey`.
- *Tests*: ports de `ModelTests` + decode paginado (snake_case igual que iOS).

### F1 — Home e infinite scroll (M)
- `PagedListLoader` → `PagedListViewModel` (seed, dedupe, done, loadMoreFailed, retry).
- Héroe carrusel (auto-avance respetando `reduce motion`), rails + **load-more horizontal** (paridad Flutter, iOS aún no lo tiene), Top 10, Ver todo infinito, pull-to-refresh M3, estados vacío/error/retry, attribution TMDB.
- *Tests*: port de `PaginationTests` (8 casos) — la lógica es la misma y ya está diseñada testeable.

### F2 — Descubrimiento y búsqueda (M)
- Explorar por género (grid tiles color) con **orden + año**; moods curados (port de `Moods`).
- Búsqueda: debounce 350ms, scopes, historial, **personas**, paginación infinita.
- `ActorScreen` (persona + filmografía).
- *Tests*: moods/sources, score de mezcla.

### F3 — Detalle (L)
- Stretchy header, actionBar completo, rating estrellas + **reseña** (misma interacción nota/reseña), dirección/creado por, temporadas + episodios (marcar, "todo", progreso), tráiler WebView, providers + `ProviderLinks` Android (intents a Netflix/Prime/Disney+/HBO Max apps), reparto, similares, refresh.
- *Tests*: `creditHeadline`, `bestTrailer`, providers decode (ports).

### F4 — Biblioteca + Sync + Auth (L) ← *corazón del producto*
- Port exacto de `LibraryStore` (marks/ratings+review/lists/episodes, JSON, outbox, cursor, apply/lww, merge tras login, reset en logout/**401**).
- Pantallas biblioteca (categorías, grids con filtro peli/serie, listas CRUD + límite 3 gratis), recientes.
- Auth: email signup/login, **Google Sign-In** (`POST /v1/auth/google` ya existe), refresh rotativo, cuenta (perfil, borrar cuenta, sign out con hooks).
- *Tests*: port de `SyncTests` (8) contra backend local docker + BackendIntegration e2e (dos "dispositivos").

### F5 — Siguiente (M)
- Port `UpNextStore` (siguiente episodio, progreso, enriquecimiento de temporadas), tarjetas con marcar, próximos al aire, gate de avisos → paywall.

### F6 — Gamificación + Stats + Historial (M)
- Port `AchievementStore` (logros, niveles, toast) sobre `LibraryCounts`.
- `StatsScreen` (tiles + Canvas: actividad 12m + épocas), `HistoryScreen` por mes.
- *Tests*: port de `PhaseFourTests` (stats puras) + niveles.

### F7 — Monetización (M)
- Play Billing 7: compra/restore/entitlements vía backend (§6.2), `PaywallScreen`, gates (listas, avisos), AdMob banner adaptativo (solo gratis, mismas ubicaciones que iOS).

### F8 — Notificaciones + Widget + App Links (M)
- Recordatorios semanales locales (WorkManager), canales de notificación.
- **FCM** push de episodios (Pro) — depende de §6.1.
- Widget Glance de tendencias (small/medium, estado offline honesto, click → ficha).
- **App Links**: intent-filters + `assetlinks.json` en el subdominio (§6.3), share con enlaces propios (mismo `shareURL` que iOS).
- *Tests*: router de links (port `DeepLinkTests`).

### F9 — Pulido y release (M)
- Baseline profiles, adaptive icon + splash, revisión de permisos (INTERNET/POST_NOTIFICATIONS/BIOMETRIC opcional), accesibilidad (content descriptions, dynamic type → font scale).
- Localización completa es/en/pt-BR desde el catálogo iOS.
- **Play Console**: ficha (título/descrípción/screenshots phone 6.9" y tablet), Data Safety, contenido, testing interno → cerrado → producción por fases.
- Opcional: Wrapped compartible a la par con iOS.

**Orden**: F0→F9 secuencial; F4 puede empezar en paralelo con F3 (store puro sin UI). Backend (§6) arranca con F0 para no bloquear F7/F8.

---

## 6. Workstreams del backend Go

Necesarios para paridad completa (ninguno bloquea F0-F6):

### 6.1 Push FCM (bloquea avisos de episodios en F8)
- `internal/push`: ya existe `Sender` interface + tabla devices con `platform` (`ios|tvos`).
  Añadir `platform: "android"`, sender FCM (google.golang.org/api/fcm) con service account
  en config (`FCM_CREDENTIALS_JSON`), y elegir alert → data message según plataforma.

### 6.2 Play Billing (bloquea F7)
- Hoy solo StoreKit: `POST /v1/storekit/transactions` + RTDN.
  Añadir `POST /v1/play/transactions` (verifica purchase token vía Google Play Developer API,
  mapea a los mismos `peliculas_pro_*` → entitlements) y endpoint RTDN de Play (`Pub/Sub`).

### 6.3 App Links (trivial, 30 min)
- Servir `/.well-known/assetlinks.json` desde `peliculas.creapolis.dev` con el SHA-256 del
  keystore de firma — misma location nginx exacta que ya sirve el AASA (patrón verificado en
  el VPS: `/opt/peliculas/aasa/` + `vhost_nginx.conf`).

### 6.4 Nada más
- `/v1/sync`, `/v1/tmdb/{path...}` (ya pagina), `/v1/auth/google` y `/v1/me` se reusan tal cual.

---

## 7. Diseño: qué usamos de Material 3 Expressive

- `MaterialExpressiveTheme` + `motionScheme()` (spring physics del sistema expresive).
- **Dynamic color** (Android 12+) con fallback a paleta de marca; dark theme completo.
- Componentes: `LoadingIndicator` (expressive) para carga, `FlexibleBottomSheet` para
  tráiler y filtros, `SplitToggleButton` para scopes de búsqueda, `FilterChip`/`DropdownMenu`
  para orden/año, `SegmentedButton` donde aplique, `HorizontalFloatingToolbar` potencial.
- Formas: `MaterialShapes` con esquinas asimétricas en tarjetas de héroe/Top 10 para el
  "sello expresive" sin romper la identidad compartida con iOS.
- Edge-to-edge + `predictive back` (targetSdk 36 lo pide de facto).

---

## 8. Riesgos y decisiones abiertas

| # | Decisión | Recomendación |
|---|---|---|
| 1 | DI manual vs Hilt | Manual (`AppContainer`) por paridad con iOS; migrar a Hilt solo si duele |
| 2 | ¿Google Sign-In en v1? | Sí: el endpoint ya existe y en Android es el "SIWA local" |
| 3 | ¿targetSdk 36 o 37? | 36 (obligatorio Play); 37 cuando Play lo exija (ago 2027) |
| 4 | minSdk | 26 (notificaciones modernas, ~97% cobertura) |
| 5 | Charts lib vs Canvas | Canvas custom (misma estética iOS, cero dependencias) |
| 6 | Single module vs multi | Single espejo de iOS; extraer `:core:network`/`:core:sync` si el build se vuelve lento |
| 7 | Billing server-side desde día 1 | Sí (RTDN + verify); el modelo entitlements del backend ya lo espera |

Riesgos: (a) FCM/Play Billing dependen del backend — arrancar §6 en F0; (b) sync compartido
exige **port exacto** de la semántica lww/outbox (por eso F4 se testea contra el backend real
como en iOS); (c) M3 Expressive evoluciona rápido — fijar BOM en F0 y actualizar una vez por
fase.

---

## 9. Resumen de esfuerzo

| Fase | Contenido | Tamaño |
|---|---|---|
| F0 | Fundaciones + puertos red/modelos + CI | M |
| F1 | Home + infinite scroll | M |
| F2 | Géneros/moods/búsqueda/personas | M |
| F3 | Detalle completo | L |
| F4 | Biblioteca + sync + auth | L |
| F5 | Siguiente | M |
| F6 | Logros + stats + historial | M |
| F7 | Play Billing + AdMob | M |
| F8 | Notifs + widget + app links | M |
| F9 | Pulido + release Play | M |
| §6 | Backend: FCM + Play verify + assetlinks | M |

Total ≈ 9-10 bloques M/L — ejecutable fase a fase con PRs independientes, igual que se hizo
en iOS (4 fases + UL en una sesión de trabajo con 60 tests).

---

## Referencias

- Material 3 Expressive en Compose (estable, nov 2026): [m3.material.io](https://m3.material.io/develop/android/jetpack-compose) · [releases material3](https://developer.android.com/jetpack/androidx/releases/compose-material3)
- Play target API: [requisitos](https://support.google.com/googleplay/android-developer/answer/11926878) (36 obligatorio; 37 ≈ ago 2027) · [Android 17 behavior changes](https://developer.android.com/about/versions/17/behavior-changes-17)
