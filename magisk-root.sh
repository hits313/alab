#!/usr/bin/env bash
# Magisk root installer for google_apis emulator
# Run ONCE after first emulator boot. Patches ramdisk + installs Magisk app.
# Requires: emulator running, adb root working

set -e

ANDROID_SDK_ROOT="$HOME/Android/Sdk"
ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
MAGISK_APK="$HOME/tools/android-lab/magisk/Magisk-v28.1.apk"
AVD_PATH="$HOME/.android/avd/Pixel6_API33_root.avd"

export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

echo "[*] Step 1: Install Magisk APK"
"$ADB" root && sleep 2
"$ADB" install -r "$MAGISK_APK"
echo "[+] Magisk APK installed."

echo "[*] Step 2: Patch ramdisk for Magisk daemon"
# Pull current ramdisk
"$ADB" pull /data/local/tmp/ /tmp/magisk-work/ 2>/dev/null || true

# The Magisk app on google_apis will patch itself on first launch
# Just need to grant it root and trigger setup
"$ADB" shell am start -n com.topjohnwu.magisk/.ui.MainActivity
echo "[*] Magisk app launched. Complete setup inside the app."
echo "    → In Magisk: tap 'Install' → 'Direct Install' → Reboot"
echo "    → After reboot Magisk daemon will be running."

echo ""
echo "[+] Post-setup: verify with:"
echo "    adb shell su -c 'id'"
echo "    adb shell /data/local/tmp/frida-server &"
