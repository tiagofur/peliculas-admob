#!/usr/bin/env bash
# Capturas 6.9" para App Store con datos reales (cuenta demo) y hora 9:41.
#
#   1) appstore/capture-screenshots.sh setup   → compila Release (API de producción), abre el
#      simulador e instala la app. Ahí: pasa el onboarding y entra con la cuenta demo
#      (Cuenta → correo y contraseña). Comprueba que Biblioteca y Siguiente tengan series.
#   2) appstore/capture-screenshots.sh shoot   → toma las 6 capturas en appstore/screenshots/
#
# Variables opcionales: SIM_NAME (por defecto el "Pro Max" más nuevo), DETAIL_URL.
set -euo pipefail
cd "$(dirname "$0")/.."                      # native-ios/
OUT="appstore/screenshots"
DERIVED="build/screenshots"
APP="$DERIVED/Build/Products/Release-iphonesimulator/PeliculasNative.app"
DETAIL_URL="${DETAIL_URL:-peliculas://serie/95396}"   # Severance

udid() {
  xcrun simctl list devices available -j | python3 -c '
import json, os, sys
want = os.environ.get("SIM_NAME", "Pro Max")
best = None
for runtime, devs in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime: continue
    ver = tuple(int(x) for x in runtime.rsplit("iOS-", 1)[-1].split("-") if x.isdigit())
    for d in devs:
        if want in d["name"] and (best is None or ver > best[0]):
            best = (ver, d["udid"], d["name"])
if not best: sys.exit("No hay simulador que contenga: " + want)
print(best[1]); print(best[2], file=sys.stderr)'
}

UDID="$(udid)"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist" 2>/dev/null || true)"

launch() { xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
           xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshots >/dev/null; sleep 4; }

case "${1:-}" in
setup)
  ./scripts/sync-env.sh
  xcodegen generate
  xcrun simctl boot "$UDID" 2>/dev/null || true
  open -a Simulator
  xcodebuild -project PeliculasNative.xcodeproj -scheme PeliculasNative -configuration Release \
    -destination "id=$UDID" -derivedDataPath "$DERIVED" -quiet build
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
  xcrun simctl install "$UDID" "$APP"
  launch
  echo "Listo. En el simulador: pasa el onboarding, entra con la cuenta demo y luego corre: $0 shoot"
  ;;
shoot)
  [[ -n "$BUNDLE_ID" ]] || { echo "Primero: $0 setup" >&2; exit 1; }
  mkdir -p "$OUT"
  xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  shots=(
    "01-inicio|peliculas://trending|6"
    "02-detalle|$DETAIL_URL|7"
    "03-siguiente|peliculas://upnext|6"
    "04-biblioteca|peliculas://library|5"
    "05-buscar|peliculas://search|5"
    "06-cuenta|peliculas://account|5"
  )
  for s in "${shots[@]}"; do
    IFS='|' read -r name url wait <<<"$s"
    launch
    xcrun simctl openurl "$UDID" "$url"
    sleep "$wait"
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name-6.9.png" >/dev/null
    echo "✓ $OUT/$name-6.9.png"
  done
  xcrun simctl status_bar "$UDID" clear
  echo "Listo: revisa las capturas antes de subirlas."
  ;;
*) echo "Uso: $0 setup | shoot" >&2; exit 1 ;;
esac
