# Backend propio en Go — Plan

> Objetivo: dejar Supabase por completo. Un solo backend para iOS, Apple TV y, más adelante, Android/Flutter.
> Roadmap de producto: [`docs/ios/ROADMAP.md`](../../docs/ios/ROADMAP.md)

## Decisiones

| Tema | Decisión |
|---|---|
| Lenguaje | Go (stdlib `net/http` con rutas de Go 1.22+) |
| Base de datos | PostgreSQL 17 (`pgx`), migraciones SQL versionadas |
| Login | Sign in with Apple + Google + email/contraseña |
| Sesiones | JWT de acceso corto (15 min) + refresh token rotativo en BD |
| Sync | Delta sync por cursor (sin realtime al principio) |
| Pro | StoreKit 2: App Store Server Notifications V2 + App Store Server API |
| Push | APNs directo (sin Firebase) |
| Hosting | VPS (Hetzner o similar) + Docker Compose: API + Postgres + Caddy (HTTPS) |
| Código | `backend/` en este repo |

## Caché de TMDB

La app ya no llama a TMDB directamente: llama a `GET /v1/tmdb/{ruta}` del backend, que responde el mismo JSON de TMDB.

Ventajas:
- **La key de TMDB sale de la app.** Hoy va dentro del binario y cualquiera puede extraerla.
- **Menos llamadas a TMDB.** Si 1.000 personas abren "Tendencias" en una hora, TMDB recibe 1 llamada, no 1.000.
- **La app funciona aunque TMDB falle**: se sirve la última copia guardada.
- **Más rápido**: la mayoría de respuestas salen de memoria.

### Cómo funciona

```
App ──▶ /v1/tmdb/movie/550?language=es-MX
          │
          ├─ 1. Memoria (LRU)        → HIT
          ├─ 2. Postgres (tmdb_cache) → HIT, se sube a memoria
          └─ 3. TMDB                  → se guarda en ambos
```

- **Fresco** (dentro del TTL): se sirve tal cual. Cabecera `X-Cache: HIT`.
- **Caducado pero guardado** (hasta 30 días): se sirve al instante y se refresca en segundo plano. `X-Cache: STALE`.
- **Sin copia**: se pide a TMDB. `X-Cache: MISS`.
- **TMDB caído**: se sirve la copia caducada si existe.
- **Peticiones iguales a la vez**: solo una va a TMDB (`singleflight`).
- **404 de TMDB**: se guarda 1 hora para no repetir.
- Límite propio hacia TMDB (~35 peticiones/s) para no pasar su límite.

### Cuánto dura cada cosa (TTL)

| Qué | TTL |
|---|---|
| Tendencias, en cines, en emisión hoy | 1 h |
| Populares, mejor valoradas, próximos estrenos | 6 h |
| Discover | 3 h |
| Búsqueda | 6 h |
| Detalle de película estrenada hace más de 1 año | 7 días |
| Detalle de película reciente o próxima | 12 h |
| Detalle de serie terminada o cancelada | 30 días |
| Detalle de serie en emisión | 6 h (cambia el próximo episodio) |
| Temporada | 24 h |
| Vídeos, reparto, keywords, similares | 7 días |
| Dónde verla (`watch/providers`) | 24 h |
| Géneros, configuración | 30 días |

- La clave de caché es la ruta + parámetros ordenados (`language`, `region`, `page`…), sin la API key.
- Solo se aceptan rutas de una lista permitida (no somos un proxy abierto).
- **Las imágenes no pasan por el backend**: siguen saliendo del CDN de TMDB (`image.tmdb.org`), que es gratis y rápido.
- Pendiente: confirmar en los términos de TMDB el tiempo máximo que se permite guardar datos (ver issue de licencia #127).

### Biblioteca sin llamar a TMDB

Cada elemento de la biblioteca guarda una **foto mínima** del título (nombre, póster, año, tipo). Así "Mis favoritos" o "Watchlist" se pintan sin ninguna llamada a TMDB.

## Modelo de datos

Unifica las ~20 tablas de Supabase en menos tablas y más claras:

| Tabla | Para qué |
|---|---|
| `users` | Cuenta: email, nombre, avatar, idioma, país |
| `identities` | Un usuario puede entrar con Apple, Google o email (`provider`, `subject`, `password_hash`) |
| `refresh_tokens` | Sesiones activas por dispositivo (hash, caducidad, revocado) |
| `library_items` | Favoritos, watchlist y vistos en una sola tabla (`kind`) + foto mínima |
| `lists`, `list_items` | Listas propias |
| `ratings` | Notas y reseñas |
| `watched_episodes` | Episodios vistos |
| `achievements` | Logros desbloqueados |
| `devices` | Tokens APNs, país, versión de app |
| `entitlements` | Estado Pro (StoreKit): producto, caducidad, `original_transaction_id` |
| `tmdb_cache` | Caché de TMDB (`key`, `body bytea`, `status`, `fetched_at`, `expires_at`) |

Todas las tablas de usuario llevan `updated_at` y `deleted_at` (borrado lógico) para el sync.

## Sync

En vez del realtime de Supabase:

- `GET /v1/sync?since=<cursor>` → todo lo que cambió desde el cursor (incluye borrados) + cursor nuevo.
- `POST /v1/sync` → lote de cambios del dispositivo con su hora local. Gana el último que escribe (como hoy).
- La app sincroniza al abrir, al volver a primer plano y tras cada cambio.
- Si más adelante hace falta tiempo real: Server-Sent Events, sin cambiar el modelo.

## API (v1)

| Método | Ruta | Fase |
|---|---|---|
| GET | `/healthz` | 0 |
| GET | `/v1/tmdb/{ruta}` | 0 |
| POST | `/v1/auth/email/signup` · `/login` | 1 |
| POST | `/v1/auth/apple` · `/google` (ID token) | 1 |
| POST | `/v1/auth/refresh` · `/logout` | 1 |
| GET/PATCH/DELETE | `/v1/me` (DELETE = borrar cuenta) | 1 |
| GET/POST | `/v1/sync` | 2 |
| POST | `/v1/storekit/notifications` (webhook de Apple) | 3 |
| GET | `/v1/me/entitlements` | 3 |
| POST | `/v1/devices` (token APNs) | 4 |

## Fases

| Fase | Qué | Hecho cuando |
|---|---|---|
| **0** | Esqueleto + caché TMDB | La app nativa usa `/v1/tmdb/*` y la key sale del binario |
| **1** | Auth: email, Apple, Google, JWT, borrar cuenta | Login en la app nativa contra el backend |
| **2** | Biblioteca, listas, ratings, episodios + sync | La app guarda y sincroniza sin Supabase |
| **3** | Pro con StoreKit 2 | El servidor sabe quién es Pro (widgets, avisos, IA) |
| **4** | Push APNs: episodios nuevos | Tarea diaria que avisa de estrenos de series seguidas |
| **5** | Deploy VPS: Compose, Caddy, backups diarios `pg_dump` | API en producción con HTTPS |
| **6** | Migración desde Supabase | Usuarios (las contraseñas bcrypt de Supabase se copian tal cual) y datos migrados; Flutter apunta al backend; Supabase apagado |

## Seguridad

- Contraseñas con bcrypt (compatibles con las de Supabase para migrarlas).
- ID tokens de Apple y Google verificados con sus claves públicas (JWKS).
- Límite de peticiones por IP y por usuario.
- Webhook de StoreKit verificado con la firma JWS de Apple.
- Secretos solo por variables de entorno (`.env` fuera de git).
