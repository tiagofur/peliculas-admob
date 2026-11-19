# Apelación 4.3(a)/4.3(b)/4.2.6 — Películas iOS

Rechazo recibido el **2026-11-13** (guidelines 4.3 Spam y 4.2.6 App Generation Services).
Estrategia elegida: **responder las 9 preguntas en el Resolution Center sin resubir build**.

> ⚠️ El campo de respuesta de ASC tiene límite de **4000 caracteres**: el texto de abajo
> mide **3950** (50 de margen). Si quieres añadir alguna línea extra, quita otra antes.

## Dónde responder

App Store Connect → Películas → la versión rechazada → **Resolution Center → Reply**
(o responde al correo del rechazo). Pega el texto en inglés de abajo tal cual.

## Antes de enviar la apelación

1. **Verifica en ASC (Apps) que la cuenta no tenga ninguna otra app**, aunque sea en estado
   distinto a «A la venta». Si la Flutter llegó a tener ficha en iOS, retírala también.
   El usuario confirmó que la Flutter solo estuvo en Google Play y se eliminará por completo;
   esta apelación afirma que es nuestra única app en el App Store, así que debe ser cierto.
2. **Actualiza la ficha**: capturas nuevas (sin Pro, ya generadas) y descripción centrada en
   Siguiente/Biblioteca/Estadísticas/avisos de episodios, no en «cartelera». Con la versión
   rechazada se puede editar metadata y el revisor la verá al releer.
3. **Notas del revisor** con cuenta demo (crear usuario por correo contra producción) y la
   nota «no ads, no in-app purchases» del CHECKLIST-ASC.md.
4. **Nombre**: el nombre genérico «Películas» es el candidato más probable del 4.3(b); un
   nombre distintivo ayudaría mucho si Apple insiste. La línea ofreciendo renombrar NO cabe
   en el límite de 4000 — si la quieres, quita antes la frase de cierre de las capturas y
   añade: `If the concern is the generic name, we are willing to adopt a distinctive one.`
5. Elimina la Flutter de Google Play (coherencia del producto; no afecta a Apple).

## Punto débil honesto

La pregunta 4 (beta testing) es la más floja: sin TestFlight externo; se responde con
dogfooding + 62 tests + feedback de la versión Android en Play. Si haces una ronda de
TestFlight antes de responder, cambia la frase «No external TestFlight beta yet; planned
for the next update» por `Películas ran a TestFlight beta with N testers; their feedback
led to X.` (cuenta los caracteres de nuevo).

## Lectura de la ficha vía API (pendiente)

Existe la clave `~/.appstoreconnect/private_keys/AuthKey_22YZT9D55J.p8` y un lector
compilado en `/tmp/asc-read/asc-read`. Falta el **Issuer ID** (ASC → Users y acceso →
Integraciones → App Store Connect API) para ejecutar:

```bash
ASC_ISSUER=<uuid> /tmp/asc-read/asc-read
```

Lista las apps de la cuenta (punto 1 del checklist), y nombre/subtítulo, descripción,
keywords, «qué hay de nuevo», promo y capturas por locale de la ficha rechazada.

---

## Texto para pegar (3950/4000 caracteres)

We believe Películas complies with 4.3(a), 4.3(b) and 4.2.6; we answer all nine questions below without resubmitting. Películas is a hand-built, fully native iPhone app (SwiftUI, zero third-party frameworks, no code-generation service) — a private place to organize the movies and series you watch, track TV episode by episode and see where to stream them. Free: no ads, no in-app purchases.

1. What the app does and the problem it solves
A personal companion for movies and TV series: discovery (trending, Top 10, theaters, upcoming, recommendations from the user's own favorites, curated collections); a personal library (watchlist, favorites, watched history, personal ratings and reviews, custom lists, statistics — on device, works offline; sign-in optional, only for sync); a series tracker ("Up Next": per-episode watched marking, season progress, push notifications from our backend when a followed series airs a new episode). Viewers across streaming services have no single private place to remember what they watched, rate it, track series and get notified of new episodes. Every title links to the streaming apps themselves ("Where to watch"; JustWatch attribution).

2. Intended user
Spanish- and Portuguese-speaking viewers in Latin America, Spain and Brazil who want a private tracker, not a social network. Full es/en/pt-BR localizations; content in the device language. Designed for iPhone (widget, haptics, native charts).

3. Need or gap in the market
JustWatch is an availability catalog: no library, no episode tracking, no notifications. Letterboxd: social film diary, weak in TV, English-first. TV Time: series tracking but ad-heavy — what our users reject. Serializd: little presence in LatAm/Brazil. Películas combines in one ad-free native app: per-episode tracking, new-episode push notifications from our own backend, a private library with ratings, reviews, lists, history and statistics, curated editorial collections, and Spanish/Portuguese as first-class languages.

4. Beta testing
Daily use by the developer against our production backend; 62 automated unit and integration tests (data models, sync engine, deep links, tracker); manual testing on the iOS Simulator (device sizes, languages). The Android version is live on Google Play; its users' feedback informed the iOS feature set. No external TestFlight beta yet; planned for the next update.

5. Standalone or suite?
Standalone — our only app on the App Store. The Android version is on Google Play as a separate native codebase (Kotlin/Compose): two implementations of one product, not a suite.

6. Could this functionality live in another app on your account?
No. There is no other app on our App Store developer account — this is our first and only iOS app.

7. Shared code with other apps on your account?
There are no other apps on our App Store account. The iOS binary uses only Apple SDKs — no third-party frameworks. The Android sibling shares no code with it: independent, hand-written native codebases over the same backend API.

8. Shared codebase with any third-party app?
No. All code written from scratch — no template, no app-generation service, no licensed codebase. Metadata comes from The Movie Database (TMDB) official public API — a data source, not a codebase — accessed only via our own backend (API key stays server-side) and credited in-app; availability credited to JustWatch. Beyond that data we add everything personal: library, tracking, ratings, reviews, lists, statistics, notifications, sync.

9. Created for a client or third party?
No. Developed and operated by Tiago Furtado (creapolis), an independent self-funded developer — own brand, backend and domain (peliculas.creapolis.dev). We are the content provider of the editorial and personal features; TMDB metadata is used with attribution under their API terms.

We also refreshed our screenshots and description to foreground these differences.

Tiago Furtado — creapolis
