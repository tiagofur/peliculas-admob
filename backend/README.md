# Películas API (Go)

Backend propio que reemplaza a Supabase. Plan completo: [docs/PLAN.md](docs/PLAN.md).

**Estado: fase 1** — caché de TMDB y login (email, Apple, Google) listos. Sync, Pro y push vienen en las siguientes fases.

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
| GET | `/v1/tmdb/{ruta}` | Mismo JSON que `https://api.themoviedb.org/3/{ruta}`, con caché |

| POST | `/v1/auth/email/signup` | `{email, password, name?, device?}` → sesión (201) |
| POST | `/v1/auth/email/login` | `{email, password, device?}` → sesión |
| POST | `/v1/auth/apple` | `{id_token, nonce?, authorization_code?, name?, device?}` → sesión |
| POST | `/v1/auth/google` | `{id_token, nonce?, device?}` → sesión |
| POST | `/v1/auth/refresh` | `{refresh_token}` → sesión nueva (el refresh token cambia cada vez) |
| POST | `/v1/auth/logout` | `{refresh_token}` → cierra la sesión de ese dispositivo (204) |
| GET | `/v1/me` | Perfil (requiere `Authorization: Bearer <access_token>`) |
| PATCH | `/v1/me` | `{display_name?, avatar_url?, locale?, country?}` |
| DELETE | `/v1/me` | Borra la cuenta y todos sus datos (204). Revoca el token de Apple si hay clave `.p8` |

**Sesión** = `{access_token, token_type, expires_in, refresh_token, user}`. El access token dura 15 min; el refresh token 60 días y se renueva en cada uso. Si alguien reutiliza un refresh token viejo (más de 30 s después), se cierran todas las sesiones de ese inicio de sesión.

**Errores**: `{"error": "<código>"}` — `invalid_email`, `weak_password`, `email_taken` (409), `invalid_credentials`, `invalid_token`, `invalid_nonce` (401), `provider_not_configured` (503), `rate_limited` (429).

**Cuentas que se juntan**: si alguien entra con Apple o Google y su email verificado ya existe, se usa esa cuenta. Si esa cuenta se registró con email y contraseña sin verificar, se borra la contraseña y se cierran sus sesiones (evita que alguien registre tu email antes que tú para quedarse con tu cuenta).

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

## Desplegar en el VPS

```bash
# en el servidor, con el DNS de DOMAIN apuntando a él
cp .env.example .env   # TMDB, POSTGRES_PASSWORD, DOMAIN, TRUST_PROXY=true
docker compose --profile prod up -d --build
```

Caddy saca el certificado HTTPS solo. Los backups diarios de Postgres van en la fase 5.

## Estructura

```
cmd/api/            arranque, apagado limpio, limpieza horaria de la caché
internal/config/    variables de entorno
internal/db/        conexión y migraciones SQL embebidas
internal/cache/     LRU en memoria + tabla tmdb_cache en Postgres
internal/tmdb/      lista de rutas, TTL, cliente TMDB y proxy con caché
internal/auth/      email + bcrypt, Apple/Google (JWKS), JWT, refresh rotativo, cuenta
internal/httpapi/   rutas, logs, límite por IP
```
