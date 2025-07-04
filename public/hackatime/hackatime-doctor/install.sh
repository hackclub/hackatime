#!/usr/bin/env bash
set -e

TARGET="hackatime-doctor"
PLATFORM="$(uname -s)"

if [[ "$PLATFORM" == *"MINGW"* || "$PLATFORM" == *"MSYS"* || "$PLATFORM" == *"CYGWIN"* ]]; then
    BIN_EXT=".exe"
else
    BIN_EXT=""
fi

BIN_PATH=""
if [ -f "$TARGET$BIN_EXT" ]; then
    BIN_PATH="./$TARGET$BIN_EXT"
elif [ -f "bin/$TARGET$BIN_EXT" ]; then
    BIN_PATH="bin/$TARGET$BIN_EXT"
else
    echo "Error: Could not find $TARGET binary in current directory or bin/"
    echo "Run this script from your extracted release package directory"
    exit 1
fi

case "$PLATFORM" in
    Linux*)
        PREFIX="${1:-/usr/local}"
        INSTALL_DIR="$PREFIX/bin"
        DEST_PATH="$INSTALL_DIR/$TARGET$BIN_EXT"
        INSTALL_CMD="install -m 755 \"$BIN_PATH\" \"$DEST_PATH\""
        ;;
    Darwin*)
        PREFIX="${1:-/usr/local}"
        INSTALL_DIR="$PREFIX/bin"
        DEST_PATH="$INSTALL_DIR/$TARGET$BIN_EXT"
        INSTALL_CMD="install -m 755 \"$BIN_PATH\" \"$DEST_PATH\""
        ;;
    MINGW*|MSYS*|CYGWIN*)
        INSTALL_DIR="${1:-/c/Program Files/hackatime-doctor}"
        DEST_PATH="$INSTALL_DIR/$TARGET$BIN_EXT"
        INSTALL_CMD="mkdir -p \"$INSTALL_DIR\" && cp \"$BIN_PATH\" \"$DEST_PATH\""
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

echo "Installing hackatime-doctor to: $DEST_PATH"
eval "$INSTALL_CMD"

case "$PLATFORM" in
    Linux*|Darwin*)
        echo "✅ Successfully installed to $DEST_PATH"
        
        if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
            echo "ℹ️  Note: $INSTALL_DIR is not in your PATH"
            echo "Add this to your shell config:"
            echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echo "✅ Successfully installed to $DEST_PATH"
        
        if [[ "$PATH" != *"$INSTALL_DIR"* ]]; then
            echo "ℹ️  Note: $INSTALL_DIR is not in your PATH"
            echo "Consider adding it to your system environment variables"
        fi
        ;;
esac

if "$DEST_PATH" --help >/dev/null 2>&1; then
    echo "✔️  Verification:"
    "$DEST_PATH" --help
else
    echo "⚠️  Warning: Could not verify installation"
fi
