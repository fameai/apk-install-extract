#!/bin/bash
# Smart APK installer - handles both single and split APKs
# Usage: ./adb-install-smart.sh <device> <arch> <apk_path>

set -e

DEVICE="$1"
ARCH="$2"
APK_PATH="$3"

if [ -z "$DEVICE" ] || [ -z "$ARCH" ] || [ -z "$APK_PATH" ]; then
    echo "Usage: $0 <device> <arch> <apk_path>"
    exit 1
fi

# Get directory and basename
APK_DIR="$(dirname "$APK_PATH")"
APK_BASENAME="$(basename "$APK_PATH")"

# Check if this is a split APK setup by looking for config.*.apk files
echo "Checking for split APKs in $APK_DIR..."
CONFIG_APKS=$(find "$APK_DIR" -maxdepth 1 -name "config.*.apk" -o -name "split*.apk" | sort)

if [ -n "$CONFIG_APKS" ]; then
    echo "Found split APKs configuration:"
    echo "  Base: $APK_PATH"
    echo "  Config APKs:"
    echo "$CONFIG_APKS" | sed 's/^/    /'

    # Build install-multiple command
    echo ""
    echo "Installing split APKs with install-multiple..."
    APK_LIST="$APK_PATH"
    for config_apk in $CONFIG_APKS; do
        APK_LIST="$APK_LIST $config_apk"
    done

    # Execute install-multiple
    echo "Command: adb -s $DEVICE install-multiple --abi $ARCH $APK_LIST"
    adb -s "$DEVICE" install-multiple --abi "$ARCH" $APK_LIST

    echo "✓ Split APKs installed successfully"
else
    echo "No config APKs found, installing as single APK..."
    echo "Command: adb -s $DEVICE install --abi $ARCH $APK_PATH"
    adb -s "$DEVICE" install --abi "$ARCH" "$APK_PATH"

    echo "✓ Single APK installed successfully"
fi

# Verify installation
PKG=$(aapt dump badging "$APK_PATH" | awk -F" " '/package/ {print $2}' | awk -F"'" '/name=/ {print $2}')
echo ""
echo "Verifying installation of package: $PKG"
if adb -s "$DEVICE" shell pm list packages | grep -q "^package:$PKG$"; then
    echo "✓ Package $PKG is installed"

    # List installed APK paths
    echo ""
    echo "Installed APK paths:"
    adb -s "$DEVICE" shell pm path "$PKG"
else
    echo "✗ ERROR: Package $PKG not found after installation"
    exit 1
fi
