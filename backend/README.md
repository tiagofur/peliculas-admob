# Películas API (Go)

Backend propio que reemplaza a Supabase. Plan completo: [docs/PLAN.md](docs/PLAN.md).

**Estado: fase 0** — caché de TMDB lista. Auth, sync, Pro y push vienen en las siguientes fases.

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

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/healthz` | `ok` si la API y Postgres responden |
| GET | `/v1/tmdb/{ruta}` | Mismo JSON que `https://api.themoviedb.org/3/{ruta}`, con caché |

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
internal/httpapi/   rutas, logs, límite por IP
```
