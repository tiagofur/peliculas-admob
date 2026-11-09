# Desplegar en un VPS

Guía para poner la API en producción: un VPS con Ubuntu 24.04, Docker Compose (API + Postgres + Caddy con HTTPS + backups diarios) y deploy automático desde GitHub Actions.

Tiempo estimado: 30–45 min la primera vez.

## 0. Qué necesitas

- Un VPS con Ubuntu 24.04. Por ejemplo, Hetzner CX22 (2 vCPU, 4 GB, ~4 €/mes). Al crearlo, añade tu clave SSH pública.
- Un dominio o subdominio para la API, p. ej. `api.tudominio.com`.
- Las claves de `.env` (ver [.env.example](../.env.example)).

## 1. DNS

Crea un registro **A** (y **AAAA** si el VPS tiene IPv6) de `api.tudominio.com` a la IP del VPS. Caddy necesita que resuelva antes de arrancar para sacar el certificado HTTPS.

## 2. Preparar el servidor (una vez)

Desde la carpeta `backend/` en tu Mac:

```bash
ssh root@IP_DEL_VPS 'bash -s' < deploy/bootstrap.sh
```

Instala Docker, firewall (solo 22, 80 y 443), actualizaciones de seguridad automáticas, fail2ban y 2 GB de swap. Crea el usuario `deploy` con tu clave SSH y **desactiva el login de root y por contraseña**. A partir de aquí:

```bash
ssh deploy@IP_DEL_VPS
```

## 3. Configuración en el servidor

```bash
scp docker-compose.yml Caddyfile deploy@IP_DEL_VPS:/opt/peliculas/
scp -r deploy deploy@IP_DEL_VPS:/opt/peliculas/
scp .env.example deploy@IP_DEL_VPS:/opt/peliculas/.env
ssh deploy@IP_DEL_VPS
cd /opt/peliculas && nano .env
```

En `.env` de producción:

| Variable | Valor |
|---|---|
| `DOMAIN` | `api.tudominio.com` |
| `TRUST_PROXY` | `true` |
| `POSTGRES_PASSWORD` | `openssl rand -base64 32` |
| `JWT_SECRET` | `openssl rand -base64 48` |
| `TMDB_API_KEY` | tu key |
| `APPLE_CLIENT_IDS`, `STOREKIT_BUNDLE_ID` | `mx.creapolis.peliculas.native` |
| `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | clave `.p8` de Sign in with Apple |
| `APNS_KEY_ID`, `APNS_PRIVATE_KEY` | clave `.p8` de APNs (puede ser la misma) |
| `PRO_PRODUCT_IDS` | IDs de App Store Connect (y de Play: son los mismos) |
| `PLAY_CREDENTIALS_JSON` | clave JSON de la service account de Play en una línea, entre comillas simples: `'{"type":"service_account",...}'` (`jq -c . clave.json`) |
| `PLAY_RTDN_TOKEN` | `openssl rand -hex 24` (va en la URL de push de Pub/Sub) |
| `FCM_CREDENTIALS_JSON` | clave JSON de la service account de Firebase, igual que la de Play |

Después: `chmod 600 .env`.

## 4. Imagen de la API

GitHub Actions construye la imagen en cada push a `main` y la sube a `ghcr.io/tiagofur/peliculas-api`. El repo es privado, así que el servidor necesita permiso para descargarla:

1. GitHub → Settings → Developer settings → Personal access tokens → **Fine-grained** o **classic** con solo `read:packages`.
2. En el servidor:
   ```bash
   echo TOKEN | docker login ghcr.io -u tiagofur --password-stdin
   ```

## 5. Primer arranque

```bash
cd /opt/peliculas
deploy/deploy.sh ghcr.io/tiagofur/peliculas-api:latest
curl https://api.tudominio.com/healthz   # → ok
curl https://api.tudominio.com/version
```

`deploy.sh` descarga la imagen, arranca todo y espera a que la API esté sana. Si no lo está en 60 s, enseña los logs y sale con error.

## 6. Deploy automático desde GitHub

En GitHub → Settings del repo:

1. **Environments** → crea `production` (puedes exigir aprobación manual).
2. **Secrets** (del environment `production`):
   - `VPS_HOST`: IP o dominio del VPS.
   - `VPS_SSH_KEY`: clave privada **nueva y solo para deploy** (`ssh-keygen -t ed25519 -f deploy_key -N ""`). Añade `deploy_key.pub` a `/home/deploy/.ssh/authorized_keys` en el servidor.
   - `VPS_KNOWN_HOSTS`: salida de `ssh-keyscan IP_DEL_VPS`.
3. **Variables**: `DEPLOY_ENABLED` = `true`.

Desde entonces, cada push a `main` que toque `backend/`: tests → imagen → deploy.

## 7. Apple

- **App Store Connect** → tu app → Información de la app → Notificaciones del servidor de App Store → versión 2 → `https://api.tudominio.com/v1/storekit/notifications` (producción y sandbox). Pulsa "Enviar notificación de prueba": en los logs debe salir `storekit notification type=TEST`.
- La app nativa apunta a `https://api.tudominio.com`.

## Backups

- Cada día a las 03:00 UTC se guarda un `pg_dump` en `/opt/peliculas/backups/`, se comprueba que se puede leer y se guardan los últimos 14 días.
- **Copia fuera del servidor (recomendado)**: si el disco del VPS muere, los backups locales también. Con rclone a un Hetzner Storage Box (~3 €/mes) o cualquier S3, añade a `.env`:
  ```env
  RCLONE_REMOTE=box:peliculas-backups
  RCLONE_CONFIG_BOX_TYPE=sftp
  RCLONE_CONFIG_BOX_HOST=uXXXXX.your-storagebox.de
  RCLONE_CONFIG_BOX_USER=uXXXXX
  RCLONE_CONFIG_BOX_PORT=23
  RCLONE_CONFIG_BOX_PASS=<rclone obscure TU_PASSWORD>
  ```
- Backup manual: `docker compose run --rm backup now`.
- **Restaurar** (para la API mientras tanto y pide confirmación):
  ```bash
  deploy/restore.sh backups/peliculas-YYYYmmdd-HHMMSS.dump
  ```

## Día a día

| Qué | Comando (en `/opt/peliculas`) |
|---|---|
| Estado | `docker compose --profile prod ps` |
| Logs de la API | `docker compose logs -f api` |
| Volver a una versión anterior | `deploy/deploy.sh ghcr.io/tiagofur/peliculas-api:<sha>` |
| Entrar a Postgres | `docker compose exec db psql -U peliculas` |

**Monitorización**: crea un monitor gratuito (UptimeRobot, Better Stack…) contra `https://api.tudominio.com/healthz` que te avise si falla.
