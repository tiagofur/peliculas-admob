# Revisión app iOS nativa — noviembre 2026

> Revisión completa de [`native-ios/`](../../native-ios/) (SwiftUI) comparada con la app Flutter
> y el backend Go. Objetivo: catálogo de bugs + mejoras acordadas con plan de trabajo.
> **Estado**: 🚧 en progreso. Orden de trabajo acordado (se hará todo):
> 1. Fix paginación → 2. Bugs críticos → 3. Quick wins → 4. Features nuevas.
>
> Fecha: 2026-11-08 · Rama de trabajo: se creará por fase (PRs separados).

---

## 1. El bug reportado: "las listas se terminan" (sin infinite scroll)

**Síntoma**: en Flutter las listas crecen al hacer scroll; en iOS la lista termina y no
aparecen más películas.

**Diagnóstico**: en iOS **solo "Explorar por género" tiene infinite scroll**. Todo lo demás
carga únicamente la página 1.

| Lista | Estado | Evidencia |
|---|---|---|
| "Ver todo" (SeeAll) | ❌ Solo página 1 | `SeeAllView.swift:4-17` recibe un array estático (`items`) y lo pinta. Sin `onAppear`, sin load-more, sin refreshable |
| Búsqueda | ❌ Solo página 1 | `SearchLoader.run` (`SearchLoader.swift:67-91`): una llamada por tipo, ~20 resultados y fin |
| Filas del Home | ❌ Página 1 | `HomeLoader.load` (`HomeLoader.swift:20-46`): nunca pasa `page` |
| Explorar por género | ✅ Paginado | `GenreLoader` (`SearchLoader.swift:124-136`): el único bien hecho (page, done, dedupe, tope 10 páginas) |

**Causa raíz (2 capas)**:

1. `TMDBClient` no soporta paginación: `trending/topRated/popular/nowPlaying/upcoming/search`
   (`TMDBClient.swift:48-59`) no aceptan `page`, y `TMDBResponse` (`TMDBClient.swift:135`) solo
   decodifica `results`, descartando `total_pages`. La app ni siquiera sabe que hay más páginas.
2. `SeeAllView` no tiene loader propio: recibe el snapshot de la fila del Home (~20 ítems) y ahí muere.

**Referencia Flutter** (por eso ahí sí funciona): `MoviesNotifier` con `currentPage` /
`loadNextPage()` / `hasReachedMax` (`flutter/lib/presentation/providers/movies/movies_providers.dart:61-127`)
y listener de scroll en `movie_masonry.dart:27-34` (umbral `pixels + 100`) y
`movie_horizontal_listview.dart:38-46` (umbral `pixels + 200`).

**Buenas noticias**: el backend ya lo soporta. El proxy TMDB tiene `page` en la allowlist de
query params (`backend/internal/tmdb/policy.go:49`) y `TMDBClient.discover` ya acepta `page`.
**La corrección es 100% app**.

**Plan del fix** (acordado):

1. Extender `TMDBClient`: parámetro `page` en listas + devolver `total_pages`
   (tipo paginado nuevo).
2. Generalizar `GenreLoader` → `PagedListLoader` reutilizable (page, done, dedupe, loading).
3. `SeeAllView` deja de recibir `items: [MediaItem]` y pasa a recibir un *source*
   (trending / topRated / nowPlaying / upcoming / género) que construye el loader.
   "Ver todo" y búsqueda paginan infinito, igual que Flutter.
4. Opcional: disparar `loadMore` al final del scroll horizontal de las filas del Home.

---

## 2. Bugs encontrados (por gravedad)

1. **🔴 Mezcla de datos entre cuentas** — ante 401 en refresh, `SessionStore.clearLocal()`
   (`SessionStore.swift:115-119`) borra solo tokens; la biblioteca local queda. Si luego entra
   otra cuenta, `mergeAfterSignIn()` (`LibraryStore.swift:249-254`) sube el snapshot completo de
   la cuenta anterior → **mezcla las bibliotecas de dos usuarios**. Integridad de datos, no solo UX.
   *Fix*: al 401 definitivo, correr hook de sign-out que limpie/archive el snapshot local.
2. **🔴 Detalle sin retry real** — el error dice "Desliza para reintentar" (`DetailView.swift:37`)
   pero el ScrollView **no tiene `.refreshable`** ni botón Reintentar. Única salida: salir y reentrar.
3. **🟠 Widget muestra datos falsos** — si el fetch falla muestra "Dune: Parte Dos" etc. como
   tendencias reales (`TrendingWidget.swift:30`), y `fetch()` es síncrono sin timeout.
   *Fix*: estado de error honesto + timeout.
4. **🟠 Deep link `peliculas://trending` roto** — lo usan el widget (`TrendingWidget.swift:91,105`)
   y los recordatorios (`ReminderManager.swift:49`), pero el `switch` de `DeepLinkRouter.swift:19-34`
   no tiene ese case → cae a `default` (Home). No existe pantalla de tendencias.
5. **🟠 Héroe fantasma** — si `/trending/day` falla pero el resto va bien, `featured` queda vacío,
   `failed = isEmpty` es `false` (`HomeLoader.swift:45`) y el héroe renderiza un gradiente vacío
   sin spinner/error/retry (`HomeView.swift:193-215`).
6. **🟡 Episodios de temporada obsoletos** — al cambiar temporada no se limpia `episodes` antes del
   fetch (`DetailLoader.swift:47-54`); si falla (`try?`) quedan los episodios de la temporada
   anterior bajo el selector nuevo. Sin estado de error.
7. **🟡 UpNext re-fetch masivo** — `onChange(of: watchedEpisodeCount)` → `load()` completo
   (`UpNextView.swift:30`): refetchea hasta 60 series + `enrich()` con hasta 30 peticiones de
   temporada (`UpNextStore.swift:86-91,127-137`) al marcar UN episodio visto. Sin cancelación de
   tareas al salir de la pantalla.
8. **🟡 Menores**:
   - `UIScreen.main.bounds` deprecated y erróneo en Split View (`UpNextView.swift:84`).
   - Banner AdMob no se recarga al cambiar ancho (`AdBannerView.swift:94`, `updateUIView` vacío).
   - Títulos con tamaño fijo que ignoran Dynamic Type (`HomeView.swift:146` size 36,
     `DetailView.swift:94` size 34, `HomeView.swift:320` size 96, `AchievementsView.swift:14` size 44).
   - Toggle push rebota a off sin mensaje si falla el registro (`PushManager.swift:57,62` con `try?`).
   - Force unwraps: `APIClient.url` con `URLComponents(...)!` (`APIClient.swift:66,71`),
     `AppConfig.apiBaseURL` con `URL(...)!` (`AppConfig.swift:13`); fallback silencioso a
     `http://127.0.0.1:8787` en Release sin diagnóstico.
   - Error parcial silencioso en Detail: `catch { failed = detail == nil }` (`DetailLoader.swift:41-44`).
   - `GenreResultsView` sin estado error/vacío si falla la página 1 (`SearchView.swift:135-149`).
   - `saveNow` codifica el snapshot JSON completo en MainActor (`LibraryStore.swift:410-419`).
   - `AsyncImage` básico sin dedupe/prefetch/downsampling (`PosterImage.swift:19`, `ActorView.swift:142`).
   - Búsqueda "Todo" ordenada por heurística local, no relevancia TMDB (`SearchLoader.swift:93-99`).
   - Logros solo en UserDefaults local, sin sync entre dispositivos (`Achievements.swift:43,75-79`).
   - Recordatorio semanal: el conteo del body queda congelado al programar; solo se refresca al
     volver a foreground (`ReminderManager.swift:59`, `PeliculasNativeApp.swift:53`).

---

## 3. Features a medias (baratas de completar, alto retorno)

| Feature | Estado actual | Fix propuesto |
|---|---|---|
| **Reseñas personales** | El campo `review` viaja por todo el sync (`SyncModels.swift:59-69`, `LibraryStore.swift:152-156`) pero **no existe UI** para escribirlo ni verlo | Text field + listado en Detail. Casi gratis: el sync ya funciona |
| **Filtro por año** | `discover(kind:genreId:year:)` acepta `year` pero siempre se llama con `nil` (`SearchLoader.swift:129`) | Picker de año en Explorar |
| **Orden en explorar** | `sort_by` fijado a `popularity.desc` (`TMDBClient.swift:62`) | Menú popularidad/nota/fecha |
| **"Porque te gustó X"** | Solo el primer favorito (`HomeLoader.swift:49-57`); sin favoritos, nada | Rotar seed o basar en top géneros vistos |
| **Director / crew** | Solo `credits.cast` primeros 15 (`DetailLoader.swift:28`) | Mostrar director y crew principal |
| **Pull-to-refresh en Detail** | El texto de error lo promete pero no existe | `.refreshable` |
| **`description` de listas** | Siempre `""` al crear/renombrar/sync (`LibraryStore.swift:167,177,369`) | UI opcional o eliminar del modelo |
| **"Avísame cuando se estrenen"** | Botón que solo abre paywall (`UpNextView.swift:49-56`) | Flujo real de avisos por serie |
| **Widget** | Solo small/medium home screen, sin configuración (`TrendingWidget.swift:150`) | Lock screen + intents de configuración |

---

## 4. Features nuevas recomendadas (priorizadas por valor/esfuerzo)

**Primera línea (impacto en retención):**

1. **Estadísticas / "Tu año en cine" (Wrapped)** — Flutter ya lo tiene
   (`flutter/lib/presentation/views/movies/statistics_view.dart`, `enhanced_user_profile_service.dart:778`).
   En iOS: Swift Charts + datos locales de `LibraryStore`, imagen compartible (marketing orgánico).
   Ya está en el ROADMAP (§2.6).
2. **Descubrimiento por estado de ánimo / categorías curadas** — Flutter tiene 12 categorías
   ("Joyas Ocultas", "Noche Romántica"…, `discovery_provider.dart:7-196`) que son solo `discover`
   con distintos filtros. Se apoya sobre el `PagedListLoader` del fix de paginación.
3. **Búsqueda de personas** — hoy los actores solo son alcanzables desde el reparto.
   Multi-search de TMDB ya existe en el proxy; decodificar `media_type: "person"` y reusar `ActorView`.

**Segunda línea (completan el producto):**

4. **Historial completo de visualización** — hoy solo "recientes" (15 ítems locales,
   `LibraryStore.swift:223-229`). Pestaña en Biblioteca agrupada por mes.
5. **Universal links** (`https://…/movie/:id`) — el share hoy comparte URLs de themoviedb
   (`PosterImage.swift:199-201`) que no abren la app. Compartir debe traer gente a la app
   (o al App Store).
6. **Widget lock screen + configurable**.
7. **Estado offline + caché de detalle** — hoy sin red Home/Detail mueren en bloque; la biblioteca
   ya persiste metadatos, un modo "solo biblioteca" cubriría metro/avión.

**Tercera línea (nice to have):**

8. Películas en "Siguiente" (continuar viendo no solo series), varios tráilers en Detail,
   prefetch de imágenes en rails, filtro por proveedor de streaming ("qué hay en Netflix"),
   reseñas de TMDB, crew completo, Live Activities (ya en ROADMAP §2.3).

---

## 5. Qué tiene Flutter que iOS no tiene (referencia rápida)

Verificado en código Flutter (rutas bajo `flutter/lib/`):

- **Paginación real** en grids y filas (ver §1).
- **Filtros avanzados** completos (género, año, duración, rating, sort, idioma, certificación,
  watch providers): `movie_filters_provider.dart:7-89`, UI en 4 tabs `filters_view.dart:9`.
- **Reviews con votos de utilidad** y reporte: `movie_rating_service.dart:25-384`.
- **Notificaciones inteligentes** (hora óptima, límite diario, topics, categorías):
  `notification_manager.dart:217`.
- **Gamificación con retos y leaderboard**: `challenge_system.dart:68`, `leaderboard_service.dart:7-28`.
- **Sync Supabase con colas offline y resolución de conflictos**: `persistent_sync_queue.dart`,
  `conflict_resolver.dart`.
- **Descubrimiento curado por categorías y mood**: `discovery_provider.dart:7-196`,
  `movie_filters_provider.dart:175-242`.
- **Estadísticas y Year in Review**: `statistics_view.dart`, `enhanced_user_profile_service.dart`.
- **Listas por defecto autogeneradas**: `default_lists_manager.dart:32`.
- **Trakt trending** y **ML de recomendaciones**: `trakt_api_service.dart:49`,
  `recommendation_engine.dart`.

Nota: la búsqueda Flutter tampoco pagina (una página); iOS puede superarla con el fix de §1.
El "Pro" de Flutter es un purchases service local (sin IAP real); el de iOS ya usa StoreKit 2 real.

---

## 6. Estado de ejecución

| Fase | Alcance | Estado |
|---|---|---|
| 1. Paginación | `TMDBClient` pages → `PagedListLoader` → SeeAll + búsqueda infinitos | ✅ **hecha** (PR [#163](https://github.com/tiagofur/peliculas-admob/pull/163)) |
| 2. Bugs críticos | Mezcla de cuentas 401, `.refreshable` en Detail, widget datos falsos, deep link trending, héroe fantasma | ✅ **hecha** (PR #163) |
| 3. Quick wins | UI de reseñas, filtro año, orden, director en Detail | ✅ **hecha** (PR #163) |
| 4. Features nuevas | Estadísticas ✓ · Moods ✓ · Personas ✓ · Historial ✓ · Universal links ✅ | ✅ **completa** (PR #163) |

### Notas de la fase 4 (2026-11-08)

- **Estadísticas** (`Features/Stats/StatsView.swift`): `LibraryStats.build` puro y testeable
  (vistos película/serie, nota media sin borradas, ventana fija de 12 meses de actividad con
  ceros, décadas por año de estreno). UI con Swift Charts (barras actividad + épocas) y tiles.
  Entrada: fila "Estadísticas" en Biblioteca. El Wrapped compartible (imagen) queda como
  follow-up — requiere render a UIImage + ShareLink.
- **Descubrimiento por mood** (`Moods.swift`): 8 moods curados ("Joyas ocultas", "Noche
  romántica"…) → `MediaListSource.discover` con géneros + piso de votos + nota mínima
  (paridad con las categorías de Flutter). Grid "Descubrir" en Buscar → `PagedResultsView`
  (grid paginado genérico que ahora también usan los géneros).
- **Búsqueda de personas**: `searchPeople` (`/search/person`) en paralelo con los títulos
  solo en el scope "Todo"; hasta 3 personas con foto → fila "Personas" → `ActorView`.
  Un fallo de personas no tumba la búsqueda.
- **Historial completo** (`HistoryView`): `LibraryStore.watchedLog()` (visto ordenado por
  fecha real de marca), agrupado por mes con `List` insetGrouped. Entrada: botón reloj en la
  toolbar de Biblioteca.
- **Universal links**: NO empezado aquí a propósito — requiere entitlement + rutas https y
  el archivo `apple-app-site-association` servido en `creapolis.dev` (Plesk), además de
  decidir el dominio/rutas. Se propone como fase aparte con paso de servidor.
- i18n: 30 claves nuevas (en + pt-BR), incluidas interpoladas (`%lld películas · %lld series`).
- Batería completa: **57/57 tests** (+4 PhaseFourTests). Captura verificada: fila Estadísticas
  y botón Historial visibles en Biblioteca.

### Universal links (2026-11-08, cierre de la fase 4)

- **Dominio elegido: `peliculas.creapolis.dev`** (no el apex) — ya era subdominio Plesk y
  hospeda la web Flutter: con la app instalada el enlace abre la app nativa (AASA) y sin ella
  el usuario cae en la web que ya existía. Cero redirects; el share de la app ahora emite
  enlaces propios en vez de themoviedb.org.
- **App**: entitlement `applinks:peliculas.creapolis.dev` (junto a SIWA/APS),
  `MediaItem.shareURL` → `https://peliculas.creapolis.dev/movie|serie/{id}`,
  `DeepLinkRouter.open` maneja https del dominio (`/movie|pelicula|serie|tv/{id}`, `/trending`),
  `DeepLinkRouter.webDomain` como fuente única. +3 tests (router https + shareURL).
- **Servidor** (deployado y verificado): AASA versionada en
  `native-ios/appserver/apple-app-site-association` (`appIDs: T5SKULSP2M.mx.creapolis.peliculas.native`,
  componentes `/movie|pelicula|serie|tv/*` y `/trending`), copiada a
  `ordo-vps:/opt/peliculas/aasa/` y servida vía location exacta en
  `/var/www/vhosts/system/peliculas.creapolis.dev/conf/vhost_nginx.conf`
  (`default_type application/json` + `alias`), aplicada con
  `plesk sbin httpdmng --reconfigure-domain`. Verificado: `HTTP/2 200`,
  `content-type: application/json`, JSON válido, web Flutter intacta (`/movie/550` sigue en HTML).
- **Verificación end-to-end en simulador**: abrir el enlace https con la app instalada
  abre la ficha nativa (El club de la pelea) — AASA + entitlement match OK.
- **Nota para build a device**: el entitlement nuevo requiere regenerar el provisioning
  profile con la capability Associated Domains — con firma automática Xcode lo hace solo;
  si un build de device falla, abrir Xcode → Signing & Capabilities una vez.
- Batería final: **60/60 tests**.

### Notas de la fase 3 (2026-11-08)

- **Reseñas personales**: `LibraryStore.setReview` + `review(for:)` — el campo `review` del
  sync por fin tiene UI. En el Detalle: sección "Tu reseña" con editor y bloque de lectura.
  Interplay nota/reseña cuidado: quitar la nota conserva la reseña; borrar reseña sin nota
  sí marca la fila borrada. `rating(for:)` ahora devuelve `nil` con score 0.
- **Dirección / creador**: `TMDBCredits.crew` + `TMDBFullDetail.createdBy` + `TMDBPerson.job`.
  Películas: directores dedup del crew; series: `created_by`. Fila "Dirección/Creado por"
  bajo la barra de acciones. Función pura estática testeable.
- **Orden + año en Explorar por género**: `DiscoverSort` (populares / mejor valoradas /
  más recientes) con piso de votos por orden y tope de fecha de estreno para "recientes";
  `MediaListSource.genre` ahora lleva `year` (parámetro que estaba muerto) y `sort`.
  Menú de filtros en la toolbar; cambiar filtro recrea la lista por identidad (`.id(source)`).
- **i18n**: 14 claves nuevas en `Localizable.xcstrings` (es base + en + pt-BR), incluidas 2
  que faltaban de la fase 1 ("No hay títulos en esta lista/el género…").
- **Trampa documentada**: con `JSONDecoder.convertFromSnakeCase`, las CodingKeys explícitas
  deben ir en forma *convertida* (`case createdBy`, no `= "created_by"` — el decoder convierte
  la clave del JSON y luego compara). `watch/providers` sí necesita raw value porque contiene `/`.
- Verificado en simulador vía deep link `peliculas://movie/550`: fila "Dirección David
  Fincher" y sección "Tu reseña" visibles en el detalle real.
- Batería completa: **53/53 tests** (8 nuevos de QuickWins).

### Notas de la fase 2 (2026-11-08)

### Notas de la fase 2 (2026-11-08)

- **401 mezcla de cuentas**: `SessionStore.forceSignOut()` corre los hooks `willSignOut`
  (incluido `library.resetForSignOut()`) antes de limpiar tokens. El login siguiente parte
  de biblioteca vacía; la del usuario se recupera del servidor al volver a entrar.
- **Detalle con retry real**: `.refreshable` en el ScrollView + botón "Reintentar" en el
  bloque de error (el texto ya no promete un gesto que no existía).
- **Episodios obsoletos** (bonus, bug menor §2.6): `loadEpisodes` limpia `episodes` si el
  fetch de la temporada falla — ya no se muestran episodios de la temporada anterior.
- **Widget honesto**: sin datos muestra "Sin conexión" (nada de sample data que parezca
  real; `sample` queda solo para placeholder/galería). Fetch con timeout 10 s (API) y 8 s
  (pósters) vía semáforo; reintento en 1 h. Además elimina el force-unwrap de URLs del
  medium widget.
- **Deep link `peliculas://trending`**: ahora selecciona la pestaña Inicio
  (el widget y la notificación semanal lo usan). Tests: `DeepLinkTests` (4).
- **Héroe fantasma**: `HomeLoader.featuredFailed` distingue el fallo del carrusel aunque
  el resto de filas cargue; `HeroPlaceholder` muestra error + Reintentar.
- No automatizable en este entorno (sin mocks de red estáticos en el proyecto): el camino
  del 401 comparte el mismo código que `signOut()` (testado vía integración); el widget se
  verifica añadiéndolo a la pantalla de inicio en un device/simulador con la app instalada.
- Batería completa: **45/45 tests** (41 previos + 4 de deep links).

### Notas de la fase 1 (2026-11-08)

- **Descubrimiento importante**: el HEAD de `main` **no compilaba** — el proyecto declara
  deployment target iOS 15.0 pero el código usa APIs de iOS 17 sin gates
  (`onChange` de 2 parámetros en RootView/PeliculasNativeApp/SignInView/UpNextView,
  `ContentUnavailableView` en `GlassIfAvailable.swift:190`). El target de tests ya estaba en
  17.0. Como la app de facto requiere iOS 17 desde hace tiempo, se subió el target del
  proyecto (app + widget) a **17.0** en vez de degradar el código. Si algún día se quiere
  soportar iOS 15/16 habrá que hacer un trabajo de gates explícito.
- Implementación: `TMDBClient.pagedList(_:page:)` + `MediaListSource` + `TMDBPagedMovies`
  (`total_pages`), `PagedListLoader` genérico con seed/dedupe/estados, `SeeAllView` y
  búsqueda e "Explorar por género" con infinite scroll y pie con "Reintentar".
  Se eliminaron `TMDBClient.search` y `TMDBClient.discover` (absorbidos por `pagedList`/`searchPage`).
- Verificación: 41/41 tests (8 nuevos de paginación + 1 de integración nueva contra el
  backend local `127.0.0.1:8787` que prueba páginas distintas vía proxy). La app compiló,
  instaló y arrancó en simulador con datos reales. Sin idb en este entorno no se pudo
  automatizar el gesto de scroll; revisar a mano al abrir un "Ver todo".
