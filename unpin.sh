#!/usr/bin/env bash
# SSL Unpinning via objection/frida
# Usage: ./unpin.sh com.target.app [method]
# Methods: objection (default), frida-universal, frida-custom

PKG="${1:-}"
METHOD="${2:-objection}"

if [[ -z "$PKG" ]]; then
  echo "Usage: $0 <package.name> [objection|frida-universal|frida-custom]"
  exit 1
fi

export PATH="$HOME/.local/bin:$HOME/Android/Sdk/platform-tools:$PATH"

case "$METHOD" in
  objection)
    echo "[*] Launching objection SSL unpin for: $PKG"
    objection --gadget "$PKG" explore --startup-command "android sslpinning disable"
    ;;

  frida-universal)
    echo "[*] Frida universal SSL unpin for: $PKG"
    # Uses frida-scripts universal ssl unpinning script
    SCRIPT="$HOME/tools/android-lab/frida-scripts/universal-ssl-unpin.js"
    if [[ ! -f "$SCRIPT" ]]; then
      echo "[!] Script not found. Downloading..."
      mkdir -p ~/tools/android-lab/frida-scripts
      curl -L "https://raw.githubusercontent.com/httptoolkit/frida-android-unpinning/main/frida-script.js" \
        -o "$SCRIPT" 2>/dev/null
    fi
    frida -U -f "$PKG" -l "$SCRIPT" --no-pause
    ;;

  frida-custom)
    echo "[*] Custom frida script. Edit: ~/tools/android-lab/frida-scripts/custom.js"
    frida -U -f "$PKG" -l ~/tools/android-lab/frida-scripts/custom.js --no-pause
    ;;
esac
