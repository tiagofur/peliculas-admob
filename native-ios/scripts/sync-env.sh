#!/bin/bash
# Pasa tus valores del `.env` de la raíz del repo al build iOS.
# Genera Config/Secrets.generated.xcconfig (gitignored: nunca se commitea).
# Uso: ./scripts/sync-env.sh   (repite cada vez que cambies el .env)
#
# Variables que lee (todas opcionales; si faltan se usan las de Shared.xcconfig):
#   IOS_API_BASE_URL       URL pública del backend Go, p. ej. https://api.tudominio.com
#   IOS_API_BASE_URL_DEV   URL del backend para Debug (por defecto http://127.0.0.1:8787)
#   APPLE_TEAM_ID          Team ID de developer.apple.com (10 caracteres)
#   IOS_BUNDLE_ID          Bundle ID si no usas mx.creapolis.peliculas.native
#   IOS_PRIVACY_URL / IOS_TERMS_URL / IOS_SUPPORT_URL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NATIVE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$NATIVE_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
OUT_FILE="$NATIVE_DIR/Config/Secrets.generated.xcconfig"

echo '// Generado por scripts/sync-env.sh desde el .env — NO commitear.' > "$OUT_FILE"

if [ ! -f "$ENV_FILE" ]; then
  echo "No hay .env en $REPO_ROOT — se usan los valores de Config/Shared.xcconfig." >&2
  exit 0
fi

get() { grep -E "^$1=" "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '"' | tr -d "'" || true; }
# xcconfig trata "//" como comentario: https://x → https:/$()/x
url() { printf '%s' "$1" | sed 's#://#:/$()/#'; }
put() { [ -n "$2" ] && echo "$1 = $2" >> "$OUT_FILE" || true; }

put API_BASE_URL_PROD "$(url "$(get IOS_API_BASE_URL)")"
put API_BASE_URL_DEV "$(url "$(get IOS_API_BASE_URL_DEV)")"
put DEVELOPMENT_TEAM "$(get APPLE_TEAM_ID)"
put APP_BUNDLE_ID "$(get IOS_BUNDLE_ID)"
put PRIVACY_URL "$(url "$(get IOS_PRIVACY_URL)")"
put TERMS_URL "$(url "$(get IOS_TERMS_URL)")"
put SUPPORT_URL "$(url "$(get IOS_SUPPORT_URL)")"

COUNT=$(($(grep -c '=' "$OUT_FILE" || true)))
echo "OK: $OUT_FILE con $COUNT valores (no se muestran)."
