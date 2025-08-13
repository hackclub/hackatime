#!/usr/bin/env bash

set -e

TARGET="hackatime-doctor"
PLATFORM="$(uname -s)"

case "$PLATFORM" in
    Linux*|Darwin*)
        PREFIX="${1:-/usr/local}"
        BIN_PATH="$PREFIX/bin/$TARGET"
        CMD="rm -f \"$BIN_PATH\""
        ;;
    MINGW*|MSYS*|CYGWIN*)
        INSTALL_DIR="${1:-/c/Program Files/hackatime-doctor}"
        BIN_PATH="$INSTALL_DIR/$TARGET.exe"
        CMD="rm -f \"$BIN_PATH\" && rmdir \"$INSTALL_DIR\" 2>/dev/null || true"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

echo "Removing hackatime-doctor from: $BIN_PATH"
eval "$CMD"
echo "Uninstallation complete"
