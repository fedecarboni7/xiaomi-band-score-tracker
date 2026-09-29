#!/usr/bin/env bash
#
# deploy-band.sh - un solo comando para llevar tu app a la Band 9 física.
# Va en la raíz del proyecto (donde están package.json y src/).
#
# Uso:  ./deploy-band.sh
#
# Variables opcionales:
#   BAND_TOOLS_DIR   carpeta del repo xiaomi-band-development
#   PHONE_SERIAL     serial ADB del teléfono
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="${BAND_TOOLS_DIR:-$HOME/repos/xiaomi-band-development}"
PHONE_SERIAL="${PHONE_SERIAL:-}"
MANIFEST="$PROJECT_DIR/src/manifest.json"

# --- 1. Chequeos rápidos ---
if [ ! -x "$TOOLS_DIR/scripts/deploy.sh" ]; then
    echo "ERROR: no encuentro $TOOLS_DIR/scripts/deploy.sh"
    exit 1
fi

if ! grep -q '"build"' "$PROJECT_DIR/package.json"; then
    echo "ERROR: package.json no tiene un script \"build\"."
    exit 1
fi

# Autodetectar el teléfono (ignora emuladores)
if [ -z "$PHONE_SERIAL" ]; then
    PHONE_SERIAL="$(adb devices | grep -v emulator | grep -E 'device$' | head -1 | awk '{print $1}' || true)"
fi
if [ -z "$PHONE_SERIAL" ]; then
    echo "ERROR: no encuentro un teléfono por ADB."
    echo "Conectalo por USB, desbloquealo y aceptá la depuración."
    exit 1
fi

if ! adb -s "$PHONE_SERIAL" get-state >/dev/null 2>&1; then
    echo "ERROR: el teléfono $PHONE_SERIAL no responde por ADB."
    echo "Conectalo por USB, desbloquealo y aceptá la depuración."
    exit 1
fi

# --- 2. Subir versionCode (la banda cachea versiones viejas) ---
node -e '
const fs = require("fs");
const p = process.argv[1];
const m = JSON.parse(fs.readFileSync(p, "utf8"));
m.versionCode += 1;
fs.writeFileSync(p, JSON.stringify(m, null, 2) + "\n");
console.log("==> versionCode ->", m.versionCode);
' "$MANIFEST"

# --- 3. Borrar .rpk viejos para que se use siempre el recién compilado ---
rm -f "$PROJECT_DIR"/dist/*.rpk

# --- 4. Compilar e instalar (delegado al script revisado) ---
"$TOOLS_DIR/scripts/deploy.sh" --project "$PROJECT_DIR" --serial "$PHONE_SERIAL" || {
    echo "El deploy falló. Limpio y salgo."
    STATUS=1
}

# --- 5. Limpieza (incluye el volcado de pantalla del teléfono) ---
adb -s "$PHONE_SERIAL" shell rm -f /data/local/tmp/launch.dex /sdcard/ui_tmp.xml 2>/dev/null || true
rm -f /tmp/ui_tmp.xml /tmp/LaunchFragment.java

exit "${STATUS:-0}"