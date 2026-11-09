#!/usr/bin/env bash
# Despliega el backend en el servidor Plesk desde tu Mac (usa tu clave SSH).
# Uso (desde backend/):  deploy/plesk/deploy-plesk.sh usuario@servidor
# Variables opcionales: REMOTE_DIR (por defecto /opt/peliculas), SSH_PORT (22), API_PORT (8787)
# Construye la imagen en el servidor: no hace falta GHCR ni token de GitHub.
set -euo pipefail

target="${1:?uso: deploy-plesk.sh usuario@servidor}"
dir="${REMOTE_DIR:-/opt/peliculas}"
port="${SSH_PORT:-22}"
api_port="${API_PORT:-8787}"
version="$(git rev-parse --short HEAD 2>/dev/null || echo manual)"

cd "$(dirname "$0")/../.."   # backend/

# aasa/ (AASA de iOS + assetlinks.json de Android) vive solo en el servidor: --delete no debe tocarla.
echo "→ Subiendo código a $target:$dir"
ssh -p "$port" "$target" "mkdir -p '$dir/backups'"
rsync -az --delete -e "ssh -p $port" \
  --exclude '.env*' --exclude 'backups/' --exclude 'aasa/' --exclude '.git' --exclude '*.test' \
  ./ "$target:$dir/"

echo "→ Construyendo y arrancando (api + db + backup; sin Caddy: Plesk hace de proxy)"
ssh -p "$port" "$target" bash -s -- "$dir" "$version" "$api_port" <<'REMOTE'
set -euo pipefail
dir="$1"; version="$2"; api_port="$3"
cd "$dir"
if [[ ! -f .env ]]; then
  echo "Falta $dir/.env — copia deploy/plesk/env.production.example a .env y rellénalo." >&2
  exit 1
fi
chmod 600 .env
grep -q '^API_PORT=' .env || echo "API_PORT=$api_port" >> .env
export API_VERSION="$version"
docker compose up -d --build --remove-orphans api db backup
for _ in $(seq 1 45); do
  status=$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q api)" 2>/dev/null || echo starting)
  if [[ "$status" == healthy ]]; then
    echo "OK: API sana ($version) en 127.0.0.1:$(grep '^API_PORT=' .env | cut -d= -f2)"
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 2
done
echo "La API no quedó sana. Logs:" >&2
docker compose logs --tail 60 api >&2
exit 1
REMOTE

echo "→ Prueba pública: curl https://api-peliculas.creapolis.dev/healthz"
