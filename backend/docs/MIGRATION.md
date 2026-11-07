# Dejar Supabase: migración de datos y cambio

Cómo pasar los usuarios y sus bibliotecas de Supabase al backend propio sin que nadie pierda nada, y cuándo se puede apagar Supabase.

## Qué se copia

| De Supabase | Al backend | Notas |
|---|---|---|
| `auth.users` | `users` | **Mismo ID**. Sin anónimos ni borrados. Nombre y avatar de `raw_user_meta_data` |
| Contraseña (`encrypted_password`) | `identities` (email) | El hash bcrypt se copia tal cual: **la misma contraseña sigue funcionando** |
| `auth.identities` (apple, google) | `identities` | Mismo `sub`: la misma cuenta de Apple/Google entra en el mismo usuario |
| `user_profiles` / `profiles` | `users` | Rellena nombre y avatar solo si estaban vacíos |
| `user_favorites`, `user_watchlist`, `user_watched` | `library_items` | Con título, póster y año. Lo borrado pasa como borrado |
| `user_lists`, `user_list_items` | `lists`, `list_items` | Mismo ID de lista. El orden de las listas sigue su fecha de creación |
| `user_movie_ratings` | `ratings` | Escala 1.0–10.0 en pasos de 0.5 (se redondea al 0.5 más cercano si hiciera falta) |

**No se copia** (y por qué):
- **Sesiones**: todos tienen que volver a iniciar sesión una vez.
- **Episodios vistos**: en Flutter viven solo en el dispositivo (Hive), no en Supabase. La app los subirá en su primer sync con el backend nuevo.
- **Logros, estadísticas, reseñas útiles**: pendientes de la fase 2b.
- **Avatares subidos a Supabase Storage**: la URL se copia y sigue funcionando mientras Supabase exista. Antes de apagarlo hay que moverlos (ver el final).

## La herramienta

`migrate-supabase` va dentro de la imagen de la API. Solo **lee** de Supabase.

- **Se puede ejecutar las veces que quieras.** Nunca duplica nada y nunca pisa un cambio más nuevo hecho en el backend nuevo: gana el `updated_at` más reciente.
- **`-dry-run`** hace todo dentro de una transacción, enseña el informe y no guarda nada.
- Lee las columnas reales de cada tabla antes de consultarla. Las tablas de Supabase cambiaron con los años (`is_deleted` en unas, `deleted_at` en otras, `user_watched_movies` → `user_watched`).
- Si un email ya se registró en el backend nuevo con otra cuenta, ese usuario no se copia y sale en el informe para resolverlo a mano.

### Conexión a Supabase

Supabase → Project Settings → Database → Connection string → **Session pooler** (puerto 5432). Añádela al `.env` del servidor:

```env
SUPABASE_DB_URL=postgres://postgres.xxxxxxxx:PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres
```

### Ejecutarla en el servidor

```bash
cd /opt/peliculas
# 1. Ver qué haría
docker compose run --rm --entrypoint /migrate-supabase api -dry-run
# 2. Hacerlo
docker compose run --rm --entrypoint /migrate-supabase api
```

Informe de ejemplo:

```
step                 read  written  skipped
users                 812      812        0
identities            845      845        0
favorites            9120     9120        3
...
```

`skipped` son filas de usuarios que no se copiaron (anónimos, borrados o con conflicto de email).

## Plan del cambio

### Fase A: el backend ya funciona y Flutter sigue en Supabase

1. Desplegar el backend ([DEPLOY.md](DEPLOY.md)).
2. Ejecutar la migración (primero `-dry-run`).
3. Publicar la app nativa de iOS apuntando al backend. Quien ya tenía cuenta entra con la misma contraseña, Apple o Google, y encuentra su biblioteca.
4. Mientras la app Flutter siga usando Supabase, **repetir la copia cada noche** para traer cuentas y cambios nuevos. En el `crontab` del usuario `deploy`:
   ```cron
   30 4 * * * cd /opt/peliculas && docker compose run --rm --entrypoint /migrate-supabase api >> backups/migrate.log 2>&1
   ```

> ⚠️ La copia es **en un solo sentido** (Supabase → backend). Lo que alguien cambie en la app nativa no vuelve a Flutter. Por eso la fase A debe ser corta.

### Fase B: Flutter usa el backend nuevo

1. Cambiar la capa de datos de Flutter a la API (`/v1/auth/*`, `/v1/sync`, `/v1/tmdb/*`). Es una tarea aparte.
2. Añadir los IDs de la app Flutter al `.env` del backend para que sus logins valgan:
   - `APPLE_CLIENT_IDS=mx.creapolis.peliculas.native,mx.creapolis.peliculas`
   - `GOOGLE_CLIENT_IDS=` los client IDs de Android, iOS y web de Flutter.
3. Publicar la versión de Flutter con **actualización obligatoria**.
4. El día del cambio: última copia, quitar el cron y poner Supabase en solo lectura (revocar `INSERT/UPDATE/DELETE` a `authenticated` o pausar el proyecto).

### Fase C: apagar Supabase

1. Esperar 2–4 semanas a que casi todos tengan la versión nueva.
2. Mover los avatares de Supabase Storage (bucket `avatars`) a otro almacenamiento y actualizar `avatar_url`.
3. Hacer un `pg_dump` completo de Supabase y guardarlo fuera del servidor.
4. Borrar el proyecto de Supabase.
