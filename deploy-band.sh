#!/usr/bin/env bash
#
# deploy-band.sh - un solo comando para llevar tu app a la Band 9 física.
# Va en la raíz del proyecto (donde están package.json y src/).
#
# Uso:  ./deploy-band.sh
#
# Variables opcionales:
#   PHONE_SERIAL     serial ADB del teléfono
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PHONE_SERIAL="${PHONE_SERIAL:-}"
MANIFEST="$PROJECT_DIR/src/manifest.json"
ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

# --- 1. Chequeos rápidos ---
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

# --- 4. Compilar e instalar ---
PKG_NAME="$(node -e "console.log(JSON.parse(require('fs').readFileSync('$MANIFEST')).package)")"
RPK_FILENAME="$(echo "$PKG_NAME" | tr '.' '_').rpk"
PLATFORM="$(ls -d "$ANDROID_HOME"/platforms/android-* 2>/dev/null | sort -V | tail -1)/android.jar"
BUILD_TOOLS="$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1)"
LAUNCH_DEX="/data/local/tmp/launch.dex"
LAUNCH_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$LAUNCH_TMP_DIR"; adb -s "$PHONE_SERIAL" shell rm -f "$LAUNCH_DEX" 2>/dev/null || true' EXIT

if [ ! -f "$PLATFORM" ] || [ ! -d "$BUILD_TOOLS" ]; then
    echo "ERROR: no encuentro Android SDK, platform o build-tools en $ANDROID_HOME"
    exit 1
fi

echo "==> Compilando..."
(cd "$PROJECT_DIR" && npm run build 2>&1 | tail -15)
RPK_FILE="$(find "$PROJECT_DIR/dist" -name '*.rpk' -type f | sort -r | head -1)"
if [ -z "$RPK_FILE" ]; then
    echo "ERROR: no encuentro un .rpk en $PROJECT_DIR/dist/"
    exit 1
fi

echo "==> Compilando launcher..."
mkdir -p "$LAUNCH_TMP_DIR/classes" "$LAUNCH_TMP_DIR/dex"
javac -source 8 -target 8 -bootclasspath "$PLATFORM" \
    "$PROJECT_DIR/tools/LaunchFragment.java" -d "$LAUNCH_TMP_DIR/classes"
"$BUILD_TOOLS/d8" "$LAUNCH_TMP_DIR/classes/LaunchFragment.class" \
    --output "$LAUNCH_TMP_DIR/dex"
adb -s "$PHONE_SERIAL" push "$LAUNCH_TMP_DIR/dex/classes.dex" "$LAUNCH_DEX"

adb -s "$PHONE_SERIAL" shell mkdir -p /sdcard/Xiaomi-band 2>/dev/null || true
adb -s "$PHONE_SERIAL" push "$RPK_FILE" "/sdcard/Xiaomi-band/$RPK_FILENAME"
APK_PATH="$(adb -s "$PHONE_SERIAL" shell pm path com.xiaomi.wearable | head -1 | sed 's/package://' | tr -d '\r' || true)"
if [ -z "$APK_PATH" ]; then
    echo "ERROR: Mi Fitness (com.xiaomi.wearable) no está instalado"
    exit 1
fi

echo "==> Abriendo la pantalla de instalación..."
RESULT="$(adb -s "$PHONE_SERIAL" shell "CLASSPATH=$LAUNCH_DEX app_process / LaunchFragment $APK_PATH" 2>&1 || true)"
if ! echo "$RESULT" | grep -q 'SUCCESS'; then
    echo "ERROR: no pude abrir la pantalla de instalación: $RESULT"
    exit 1
fi

echo "==> Pasos manuales en el teléfono:"
echo "1. Tocá \"click to input package name\", escribí $PKG_NAME y aceptá."
echo "2. Tocá \"install third app\"."
echo "3. Elegí $RPK_FILENAME en la carpeta Xiaomi-band."