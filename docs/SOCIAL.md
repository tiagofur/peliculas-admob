# Social: especificación de la fase mínima

Estado: **propuesta** (9 nov 2026). Nada de esto está implementado.

## Objetivo

Que la gente vuelva a la app para ver qué ven sus amigos y que invite a otros. Es la palanca
de crecimiento para llegar a los usuarios que hacen falta para pagar la licencia de TMDB
(ver `docs/PRO.md`).

Reglas:

- **Lo social es gratis.** Una red social vale por cuánta gente hay en ella. Pro solo suma
  extras encima (ver "Pro sobre lo social").
- **Sin texto libre en la primera versión.** El feed muestra acciones (vio, está viendo,
  calificó), no reseñas. Así casi no hay nada que moderar.
- **Privado por defecto hasta que el usuario elige.** Nadie aparece en el feed de otros sin
  haber activado su perfil público.

## Alcance de la fase mínima

| Incluye | Se deja para después |
|---|---|
| Perfil público con @usuario, nombre y avatar | Reseñas con texto y comentarios |
| Seguir / dejar de seguir (sin aprobación) | Perfiles privados con solicitudes de seguimiento |
| Feed: "está viendo", "vio", "calificó con ★" | Feed de listas creadas o actualizadas |
| 4 reacciones: ❤️ 😂 😮 🤔 | Mensajes directos |
| Aviso push "Fulano reaccionó / te sigue" | Agrupar avisos ("Fulano y 3 más") |
| Buscar por @usuario y enlace de invitación | Importar contactos |
| Denunciar y bloquear | Moderación con IA (ver `docs/IA-LOCAL.md`) |
| Feed "Comunidad" para quien no sigue a nadie | Algoritmo de feed (el de la fase mínima es cronológico) |

Sobre la reacción de "enojado": en calificaciones tiende a volverse agresiva. 🤔 ("no estoy de
acuerdo") deja el desacuerdo sin hostilidad. Si se quiere 😡 igual, se añade al catálogo sin
cambiar el modelo.

## Lo que ya existe y se reutiliza

- `users` (`display_name`, `avatar_url`), autenticación con Apple, Google y correo.
- `library_items` (`favorite`, `watchlist`, `watched`), `ratings` (`score` 0–10, `review`),
  `watched_episodes`, todo vía `/v1/sync`.
- Push: APNs (iOS) listo; FCM (Android) listo en el backend, falta la app (`docs/PRO.md` §4).

**Falta el estado "estoy viendo".** Hoy solo hay favorito, watchlist y visto. Opciones:
1. Nuevo `kind = 'watching'` en `library_items` (cambio de sync en **las dos apps a la vez**,
   como dice `CLAUDE.md`).
2. Derivarlo para series: marcar un episodio = "está viendo la serie". Para películas hace falta la opción 1.

Recomendado: la opción 1, con un botón "Estoy viendo" en el detalle.

## Backend

### Tablas nuevas (migración `0009_social.sql`)

```sql
-- Perfil público. Una fila = el usuario activó lo social.
CREATE TABLE profiles (
    user_id    uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    handle     text NOT NULL UNIQUE CHECK (handle ~ '^[a-z0-9_]{3,20}$'),
    bio        text NOT NULL DEFAULT '' CHECK (length(bio) <= 160),
    is_public  boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE follows (
    follower_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    followee_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id),
    CHECK (follower_id <> followee_id)
);
CREATE INDEX follows_followee ON follows (followee_id);

-- Eventos del feed. Se escriben al aplicar ops de /v1/sync (no desde la app aparte).
CREATE TABLE activities (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    verb       text NOT NULL CHECK (verb IN ('watching', 'watched', 'rated')),
    media_type text NOT NULL CHECK (media_type IN ('movie', 'tv')),
    tmdb_id    integer NOT NULL,
    title      text NOT NULL DEFAULT '',
    poster_path text NOT NULL DEFAULT '',
    score      smallint,                -- solo 'rated'
    created_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz              -- si se desmarca, desaparece del feed
);
CREATE INDEX activities_user_time ON activities (user_id, created_at DESC);

CREATE TABLE reactions (
    activity_id uuid NOT NULL REFERENCES activities (id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind        text NOT NULL CHECK (kind IN ('heart', 'laugh', 'wow', 'disagree')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (activity_id, user_id)   -- una reacción por persona; cambiarla = UPDATE
);

CREATE TABLE blocks (
    blocker_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE reports (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    target_user uuid REFERENCES users (id) ON DELETE CASCADE,
    activity_id uuid REFERENCES activities (id) ON DELETE CASCADE,
    reason      text NOT NULL CHECK (reason IN ('spam', 'offensive', 'impersonation', 'other')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz
);
```

Reglas del servidor:
- **Sin spam de eventos:** el mismo `(user, verb, título)` dentro de 24 h actualiza el evento
  existente en vez de crear otro. Marcar 10 episodios seguidos = un solo "está viendo".
- **Desmarcar borra:** quitar "visto" o la calificación pone `deleted_at` en su actividad.
- **Bloquear** borra el follow en los dos sentidos y oculta a esa persona en el feed, la
  búsqueda y los avisos.
- **Sin perfil = sin actividades.** Solo se generan eventos si existe la fila en `profiles`.
- Borrar la cuenta (`DELETE /v1/me`) ya borra en cascada.

### Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| PUT | `/v1/profile` | Crear o editar el perfil: `{handle, bio, is_public}` (409 si el @ está tomado) |
| GET | `/v1/profiles/{handle}` | Perfil, contadores, si lo sigo, últimas actividades |
| GET | `/v1/profiles?query=` | Buscar por @ o nombre (máx. 20) |
| POST / DELETE | `/v1/follows/{handle}` | Seguir / dejar de seguir |
| GET | `/v1/profiles/{handle}/followers` y `/following` | Listas paginadas |
| GET | `/v1/feed?before=<cursor>` | Actividades de quien sigo, 30 por página, más recientes primero |
| GET | `/v1/feed/community?before=` | Actividades públicas recientes (el feed para quien no sigue a nadie) |
| PUT / DELETE | `/v1/activities/{id}/reaction` | `{kind}` reaccionar o quitar la reacción |
| POST / DELETE | `/v1/blocks/{handle}` | Bloquear / desbloquear |
| POST | `/v1/reports` | `{handle?, activity_id?, reason}` |

Paginación por cursor (`created_at` + `id`), no por número de página.

### Avisos push

Tipos nuevos en `internal/push`: `new_follower` y `reaction`. Como mucho un aviso de
reacciones por actividad cada hora. Se pueden desactivar en Cuenta.

## Apps (iOS y Android a la vez)

1. **Cuenta → "Perfil público":** elegir @usuario (comprobando disponibilidad), bio,
   interruptor público. Texto claro: "Tus seguidores verán lo que ves, terminas y calificas".
2. **Nueva pestaña "Amigos"** (o sección en Inicio): feed con póster, "Fulano vio X", estrellas
   si calificó, hora relativa y barra de reacciones. Tocar el póster abre el detalle de siempre.
3. **Feed vacío:** "Comunidad" + usuarios sugeridos + botón "Invitar amigos".
4. **Perfil de otro usuario:** avatar, @, bio, contadores, seguir, actividades recientes,
   menú ⋯ con Denunciar y Bloquear.
5. **Invitación:** enlace universal `https://peliculas.creapolis.dev/u/<handle>` (ya hay
   universal links en iOS); sin la app, lleva a la tienda.
6. **Detalle:** botón "Estoy viendo" (si se elige la opción 1 de arriba).

## Requisitos de las tiendas

- **Apple, guía 1.2 (contenido generado por usuarios):** filtro de contenido inaceptable,
  denunciar, bloquear, y responder a las denuncias en 24 h. El @, la bio y el avatar ya cuentan
  como contenido de usuario. Hace falta un correo o un panel para revisar `reports`.
- **Términos de uso:** añadir reglas de la comunidad (las tiendas las piden con contenido de usuarios).
- **Privacidad:** actualizar la etiqueta de App Store y el formulario de seguridad de datos de
  Play (la actividad se vuelve visible a otros) y la política de privacidad.
- **Edad:** con interacción entre usuarios, la clasificación por edad puede subir; revisarla.
- **TMDB:** solo se guardan IDs, título y póster, igual que la biblioteca; sin cambios.

## Pro sobre lo social (cuando Pro se reactive)

- "% de compatibilidad" con otro usuario (según las calificaciones en común).
- Ver quién reaccionó a cada actividad (gratis: solo el número).
- Personalizar el perfil (portada, título favorito destacado) y distintivo Pro.
- Modo incógnito: marcar algo sin que salga en el feed.

## Estimación (una persona)

| Parte | Tiempo |
|---|---|
| Backend: migración, endpoints, eventos desde sync, push, tests | 1–1,5 semanas |
| iOS: perfil, feed, reacciones, perfil ajeno, invitación | 1–1,5 semanas |
| Android: lo mismo | 1–1,5 semanas |
| Moderación mínima, textos legales, privacidad en tiendas | 2–3 días |
| **Total** | **~3–5 semanas** |

## Métricas para saber si funciona

- % de usuarios activos con perfil público.
- Seguidos por usuario (meta: 3 o más en la primera semana).
- % de usuarios que abren el feed al menos 3 días por semana.
- Invitaciones enviadas → cuentas creadas.
- Retención a 7 y 30 días de quien sigue a alguien frente a quien no.
