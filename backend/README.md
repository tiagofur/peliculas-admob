# Películas API (Go)

Backend propio que reemplaza a Supabase. Plan completo: [docs/PLAN.md](docs/PLAN.md).

**Estado: fases 0–6 listas** — caché de TMDB, login (email, Apple, Google), biblioteca con sync, Pro (StoreKit 2), avisos de episodios nuevos (APNs), deploy (VPS + CI) y migración desde Supabase ([docs/MIGRATION.md](docs/MIGRATION.md)). Falta que la app Flutter use esta API para poder apagar Supabase.

## Correr en local

```bash
cd backend
cp .env.example .env   # pon TMDB_API_KEY o TMDB_READ_TOKEN
docker compose up -d --build
curl http://127.0.0.1:8080/healthz
curl -i "http://127.0.0.1:8080/v1/tmdb/movie/550?language=es-MX"
```

Si el puerto 8080 está ocupado: `API_PORT=8787 docker compose up -d`.

Sin Docker (caché solo en memoria):

```bash
TMDB_API_KEY=... go run ./cmd/api
```

## Tests

```bash
go vet ./... && go test -race ./...
```

Los tests de login necesitan un Postgres; sin él se saltan:

```bash
docker run -d --name peliculas-testdb -e POSTGRES_PASSWORD=test -e POSTGRES_DB=test -p 127.0.0.1:55432:5432 postgres:17-alpine
TEST_DATABASE_URL="postgres://postgres:test@127.0.0.1:55432/test?sslmode=disable" go test -race -p 1 ./...
```

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/healthz` | `ok` si la API y Postgres responden |
| GET | `/version` | Commit que está corriendo |
| GET | `/v1/tmdb/{ruta}` | Mismo JSON que `https://api.themoviedb.org/3/{ruta}`, con caché |

| POST | `/v1/auth/email/signup` | `{email, password, name?, device?}` → sesión (201) |
| POST | `/v1/auth/email/login` | `{email, password, device?}` → sesión |
| POST | `/v1/auth/apple` | `{id_token, nonce?, authorization_code?, name?, device?}` → sesión |
| POST | `/v1/auth/google` | `{id_token, nonce?, device?}` → sesión |
| POST | `/v1/auth/password/forgot` | `{email, lang?}` → `204` siempre (exista o no la cuenta); envía un código de 6 dígitos válido 15 min |
| POST | `/v1/auth/password/reset` | `{email, code, password, device?}` → sesión; cierra las demás sesiones. Error `invalid_reset_code` (5 intentos máx.) |
| POST | `/v1/auth/refresh` | `{refresh_token}` → sesión nueva (el refresh token cambia cada vez) |
| POST | `/v1/auth/logout` | `{refresh_token}` → cierra la sesión de ese dispositivo (204) |
| GET | `/v1/me` | Perfil (requiere `Authorization: Bearer <access_token>`) |
| PATCH | `/v1/me` | `{display_name?, avatar_url?, locale?, country?}` |
| DELETE | `/v1/me` | Borra la cuenta y todos sus datos (204). Revoca el token de Apple si hay clave `.p8` |

| GET | `/v1/sync?cursor=<c>` | Cambios de la biblioteca desde el cursor (vacío = todo) |
| POST | `/v1/sync` | `{ops: [...]}` sube hasta 500 cambios → `{results: [...]}` |
| POST | `/v1/storekit/transactions` | `{signed_transaction}` tras comprar o restaurar → estado Pro |
| POST | `/v1/storekit/notifications` | Webhook de Apple (App Store Server Notifications V2) |
| POST | `/v1/play/transactions` | `{purchase_token, product_id, package_name?}` tras comprar o restaurar en Android → estado Pro |
| POST | `/v1/play/notifications` | Push de Pub/Sub con las notificaciones de Google Play (RTDN) |
| GET | `/v1/me/entitlements` | `{pro, product_id, expires_at, auto_renew, in_grace_period, store}` (App Store y Play) |
| POST | `/v1/devices` | `{token, platform?, environment?, locale?, timezone?, app_version?}` registra el token APNs o FCM (204) |
| DELETE | `/v1/devices/{token}` | Quita el dispositivo (al cerrar sesión o desactivar avisos) |
| POST | `/v1/devices/test` | Envía un aviso de prueba a tus dispositivos → `{sent}` |

**Sesión** = `{access_token, token_type, expires_in, refresh_token, user}`. El access token dura 15 min; el refresh token 60 días y se renueva en cada uso. Si alguien reutiliza un refresh token viejo (más de 30 s después), se cierran todas las sesiones de ese inicio de sesión.

**Errores**: `{"error": "<código>"}` — `invalid_email`, `weak_password`, `email_taken` (409), `invalid_credentials`, `invalid_token`, `invalid_nonce` (401), `provider_not_configured` (503), `rate_limited` (429).

**Cuentas que se juntan**: si alguien entra con Apple o Google y su email verificado ya existe, se usa esa cuenta. Si esa cuenta se registró con email y contraseña sin verificar, se borra la contraseña y se cierran sus sesiones (evita que alguien registre tu email antes que tú para quedarse con tu cuenta).

### Sync de la biblioteca

Cinco tipos de dato (`entity`):

| entity | Clave | Campos |
|---|---|---|
| `library` | `kind` + `media_type` + `tmdb_id` | `kind`: `favorite` · `watchlist` · `watched`; foto mínima `title`, `poster_path`, `year` |
| `list` | `id` (UUID que genera el dispositivo) | `name`, `description`, `position` |
| `list_item` | `list_id` + `media_type` + `tmdb_id` | foto mínima + `position` |
| `rating` | `media_type` + `tmdb_id` | `score` 1.0–10.0 en pasos de 0.5, `review` |
| `episode` | `tv_id` + `season` + `episode` | `watched_at` |

Todos llevan `updated_at` (hora del dispositivo) y `deleted` (borrado).

**Subir** (`POST /v1/sync`):

```json
{"ops": [
  {"entity": "library", "data": {"kind": "watchlist", "media_type": "movie", "tmdb_id": 550,
   "title": "El club de la pelea", "poster_path": "/p.jpg", "year": "1999", "updated_at": "2026-11-07T12:00:00Z"}},
  {"entity": "episode", "data": {"tv_id": 1399, "season": 1, "episode": 1, "updated_at": "2026-11-07T12:00:00Z"}}
]}
```

Cada op responde `applied`, `stale` (ya había un cambio más nuevo: gana el último) o `invalid` (con `error`; el resto del lote sigue). Una hora del dispositivo en el futuro (más de 5 min) se cambia por la del servidor.

**Bajar** (`GET /v1/sync?cursor=...`): devuelve `{cursor, has_more, library, lists, list_items, ratings, episodes}`. Guarda el `cursor` y envíalo la próxima vez. Si `has_more` es `true`, vuelve a pedir enseguida. Una fila puede llegar repetida: aplicarla dos veces da el mismo resultado.

**Cuándo sincronizar**: al abrir la app, al volver a primer plano y unos segundos después de cada cambio (subir primero, luego bajar).

### Pro (StoreKit 2)

**En la app:**
1. Al comprar, pasa el ID del usuario como `appAccountToken`: `product.purchase(options: [.appAccountToken(userID)])`.
2. Tras comprar o restaurar, envía `transaction.jwsRepresentation` a `POST /v1/storekit/transactions`.
3. Para saber si es Pro, usa `GET /v1/me/entitlements`. `pro: true` con `expires_at: null` es de por vida.

**En App Store Connect** (Mi app → Información de la app → Notificaciones del servidor de App Store): versión 2, URL `https://<tu-dominio>/v1/storekit/notifications` para producción y sandbox.

Cómo funciona:
- Todo lo que llega de Apple se verifica: firma ES256 con una cadena de certificados que termina en la Apple Root CA G3 (huella fijada en el código) y las marcas de Apple en el certificado intermedio y en el final.
- Solo cuentan los productos de `PRO_PRODUCT_IDS` y el bundle de `STOREKIT_BUNDLE_ID`.
- Renovaciones, reembolsos, vencimientos y periodo de gracia llegan por el webhook. Si Apple manda los avisos desordenados, uno viejo nunca pisa a uno nuevo.
- Una compra pertenece a la primera cuenta que la reclama. Si otra cuenta intenta usar la misma compra: `409 purchase_owned_by_other_account`.
- Si el aviso de Apple llega antes que la app, la compra se guarda sin dueño (o con el del `appAccountToken`) y se asigna cuando la app la reclama.

### Pro en Android (Google Play Billing)

**En la app:** tras comprar o restaurar, envía `{purchase_token, product_id}` a `POST /v1/play/transactions` (`package_name` es opcional; si va, tiene que ser `PLAY_PACKAGE_NAME`). El estado Pro sale del mismo `GET /v1/me/entitlements` que en iOS, con `store: "play"`. No hace falta reconocer (acknowledge) la compra en la app: lo hace el backend.

Respuestas de error: `400 invalid_purchase` (Google no conoce el token), `400 unknown_product`, `400 wrong_app`, `409 purchase_pending` (pago pendiente, se activa cuando llegue el aviso de Play) y `409 purchase_owned_by_other_account`.

**En Google Cloud y Play Console:**
1. Crea una service account en el proyecto de Google Cloud vinculado a Play Console y activa la *Google Play Android Developer API*. Descarga su clave JSON y ponla en `PLAY_CREDENTIALS_JSON` (el JSON entero o la ruta al archivo).
2. En Play Console → Usuarios y permisos, invita el email de la service account con permiso para *ver datos financieros* y *gestionar pedidos y suscripciones*.
3. Crea un tema de Pub/Sub, da a `google-play-developer-notifications@system.gserviceaccount.com` el rol *Publicador* y ponlo en Play Console → Monetización → Configuración de monetización → Notificaciones en tiempo real.
4. Crea una suscripción **push** a ese tema con URL `https://<tu-dominio>/v1/play/notifications?token=<PLAY_RTDN_TOKEN>`. Mejor aún, activa también la autenticación OIDC de la suscripción y pon su audiencia y service account en `PLAY_RTDN_AUDIENCE` / `PLAY_RTDN_EMAIL`.

Cómo funciona:
- El backend nunca se fía del cliente ni del aviso: siempre vuelve a leer la compra de la Google Play Developer API (`purchases.subscriptionsv2` para suscripciones, `purchases.products` para el de por vida) y guarda lo que dice Google.
- Mismos productos y misma tabla que StoreKit (`entitlements`, con `store = 'play'`): `PLAY_PRODUCT_IDS` (por defecto `PRO_PRODUCT_IDS`). Los que contienen `lifetime` son compras únicas, salvo que digas otros en `PLAY_ONE_TIME_PRODUCT_IDS`.
- Estados: activa o cancelada (sin renovación) → Pro hasta `expiryTime`; periodo de gracia → Pro con `in_grace_period: true`; en espera, pausada o vencida → sin Pro; reembolso → revocada.
- Las compras nuevas se reconocen en el servidor (Google reembolsa las que no se reconocen en 3 días). Si falla, se reintenta en el siguiente claim o aviso.
- Una compra pertenece a la primera cuenta que la reclama. Si llega el aviso de Play antes que la app, se guarda sin dueño y se asigna al reclamarla. Un cambio de plan (`linkedPurchaseToken`) hereda el dueño de la compra anterior.

### Avisos de episodios nuevos (APNs y FCM)

**En iOS:** al tener permiso de notificaciones, envía el token a `POST /v1/devices` con `environment: "sandbox"` en builds de Xcode y `"production"` en TestFlight/App Store, más `locale` y `timezone` (`TimeZone.current.identifier`). Al cerrar sesión, `DELETE /v1/devices/{token}`. El aviso trae `tv_id`, `season`, `episode` y `url: peliculas://serie/{id}` para abrir la serie.

**En Android:** lo mismo con `platform: "android"` y el token de FCM tal cual (distingue mayúsculas). `environment` no hace falta. El aviso va como notificación (título y texto) al canal `peliculas_episodes`, con los mismos datos (`tv_id`, `season`, `episode`, `url`) como strings. Para enviarlos, pon la clave JSON de una service account con el rol *Firebase Cloud Messaging API Admin* en `FCM_CREDENTIALS_JSON`.

Cómo funciona:
- Cada hora, el backend mira las series que sigue cada usuario: las que tiene en su biblioteca o de las que ha visto algún episodio.
- Para cada serie lee `last_episode_to_air` de TMDB a través de la caché, así que no hay llamadas extra.
- Avisa una sola vez por episodio y usuario: el día del estreno a partir de las 18:00 en su zona horaria, o al día siguiente si se pasó. No avisa si ya lo marcó como visto.
- Título y texto en el idioma de cada dispositivo (es / en / pt), con los nombres de TMDB en ese idioma.
- Si APNs o FCM dicen que un token ya no vale, se desactiva. Si ningún dispositivo recibió el aviso, se reintenta en la siguiente pasada.
- Con varias instancias de la API, solo una ejecuta la tarea (lock en Postgres).
- Por defecto es una función Pro (`PUSH_PRO_ONLY=true`).

`/v1/tmdb` solo acepta las rutas de la lista en `internal/tmdb/policy.go`. La cabecera `X-Cache` dice de dónde salió la respuesta: `HIT` (caché), `STALE` (caché caducada, refrescando detrás) o `MISS` (TMDB).

### Cambiar la app a la caché

En la app solo cambia la URL base y desaparece la key:

```
antes:  https://api.themoviedb.org/3/movie/550?api_key=XXX&language=es-MX
ahora:  https://<tu-api>/v1/tmdb/movie/550?language=es-MX
```

Las imágenes siguen saliendo de `https://image.tmdb.org`.

## Variables de entorno

| Variable | Por defecto | Para qué |
|---|---|---|
| `TMDB_API_KEY` / `TMDB_READ_TOKEN` | — | Credencial de TMDB (una de las dos) |
| `DATABASE_URL` | vacío | Postgres. Vacío = caché solo en memoria |
| `ADDR` | `:8080` | Dirección de escucha |
| `MEM_CACHE_ENTRIES` | `5000` | Tamaño de la caché en memoria |
| `CACHE_STALE_MAX` | `720h` | Cuánto se puede servir una respuesta caducada |
| `TRUST_PROXY` | `false` | `true` detrás de Caddy (IP real del cliente) |
| `JWT_SECRET` | — | Obligatorio con base de datos, mínimo 32 caracteres |
| `APPLE_CLIENT_IDS` | vacío | Bundle ID de iOS primero. Vacío = Apple desactivado |
| `APPLE_TEAM_ID` / `APPLE_KEY_ID` / `APPLE_PRIVATE_KEY` | vacío | Clave `.p8` para revocar tokens de Apple al borrar cuenta |
| `GOOGLE_CLIENT_IDS` | vacío | Client IDs de Google. Vacío = Google desactivado |
| `RESEND_API_KEY` | vacío | Correos de "olvidé mi contraseña" vía Resend. Vacío = `/v1/auth/password/forgot` responde `503 mail_not_configured` |
| `MAIL_FROM` | `Películas <no-reply@creapolis.dev>` | Remitente; su dominio debe estar verificado en Resend |
| `STOREKIT_BUNDLE_ID` | primer `APPLE_CLIENT_IDS` | Bundle de la app que vende Pro |
| `PRO_PRODUCT_IDS` | vacío | Productos que dan Pro. Vacío = Pro desactivado |
| `APNS_KEY_ID` / `APNS_PRIVATE_KEY` | vacío | Clave `.p8` de APNs. Vacío = se guardan dispositivos pero no se envía nada |
| `APNS_TEAM_ID` / `APNS_TOPIC` | `APPLE_TEAM_ID` / `STOREKIT_BUNDLE_ID` | Equipo y bundle de la app |
| `FCM_CREDENTIALS_JSON` | vacío | Service account de Firebase (JSON o ruta). Vacío = se guardan dispositivos Android pero no se envía nada |
| `FCM_PROJECT_ID` | `project_id` de la clave | Proyecto de Firebase |
| `PLAY_CREDENTIALS_JSON` | vacío | Service account con acceso a la Play Developer API (JSON o ruta). Vacío = Pro en Android desactivado |
| `PLAY_PACKAGE_NAME` | `mx.creapolis.peliculas` | `applicationId` de la app Android |
| `PLAY_PRODUCT_IDS` | `PRO_PRODUCT_IDS` | Productos de Play que dan Pro |
| `PLAY_ONE_TIME_PRODUCT_IDS` | los que contienen `lifetime` | Productos de compra única (el resto son suscripciones) |
| `PLAY_RTDN_TOKEN` | vacío | Secreto en la URL de push (`?token=`) |
| `PLAY_RTDN_AUDIENCE` / `PLAY_RTDN_EMAIL` | vacío | Audiencia y service account del token OIDC de la suscripción push |
| `PUSH_PRO_ONLY` | `true` | Avisos de episodios solo para Pro |
| `PUSH_ALERT_HOUR` | `18` | Hora local desde la que se avisa de lo que se estrena hoy |
| `PUSH_INTERVAL` | `1h` | Cada cuánto corre la tarea |

## Desplegar en el VPS

Guía paso a paso: [docs/DEPLOY.md](docs/DEPLOY.md). Resumen:

- `deploy/bootstrap.sh` prepara un Ubuntu 24.04 nuevo (Docker, firewall, usuario `deploy`, SSH solo con clave).
- `docker compose --profile prod` añade Caddy (HTTPS automático, HTTP/3, cabeceras de seguridad) y backups diarios de Postgres con copia opcional fuera del servidor.
- GitHub Actions (`.github/workflows/backend.yml`): tests con Postgres en cada PR; en `main`, imagen a `ghcr.io` y deploy por SSH si `DEPLOY_ENABLED=true`.
- `GET /version` dice qué commit está corriendo.

## Estructura

```
cmd/api/            arranque, apagado limpio, limpieza horaria de la caché, `api healthcheck`
deploy/             preparar el VPS, desplegar, restaurar y la imagen de backups
cmd/migrate-supabase/ copia usuarios y bibliotecas desde Supabase
internal/migrate/   lógica de la migración
internal/config/    variables de entorno
internal/db/        conexión y migraciones SQL embebidas
internal/cache/     LRU en memoria + tabla tmdb_cache en Postgres
internal/tmdb/      lista de rutas, TTL, cliente TMDB y proxy con caché
internal/auth/      email + bcrypt, Apple/Google (JWKS), JWT, refresh rotativo, cuenta
internal/library/   biblioteca, listas, notas, episodios y sync por cursor
internal/storekit/  verificación JWS de Apple, compras y webhook, estado Pro
internal/play/      Google Play: verificación de compras, acknowledge y RTDN
internal/google/    tokens OAuth de service accounts (Play, FCM) sin SDKs
internal/push/      clientes APNs y FCM, dispositivos y tarea horaria de episodios nuevos
internal/httpapi/   rutas, logs, límite por IP
```
