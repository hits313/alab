#!/usr/bin/env bash
# alab — SSL / RASP / root unpin wrapper (Android + iOS)
# Usage:
#   unpin.sh <pkg>                                   # objection sslpinning disable
#   unpin.sh <pkg> ssl                               # multi-stack SSL unpin
#   unpin.sh <pkg> root                              # root-detection bypass only
#   unpin.sh <pkg> rasp                              # RASP bundle (debug/emu/frida/xposed)
#   unpin.sh <pkg> full                              # SSL + root + RASP combined
#   unpin.sh <pkg> ios-jb                            # iOS jailbreak-detection bypass
#   unpin.sh <pkg> ios-ssl                           # iOS SSL pinning bypass
#   unpin.sh <pkg> ios-full                          # iOS jb + ssl + anti-frida

PKG="${1:-}"
MODE="${2:-objection}"
DIR="$HOME/tools/android-lab/frida-scripts"

if [[ -z "$PKG" ]]; then
  cat <<EOF
Usage: $0 <package> [objection|ssl|root|rasp|full|ios-jb|ios-ssl|ios-full]

Examples:
  $0 com.target.app                # objection 'android sslpinning disable'
  $0 com.target.app ssl            # multi-stack SSL unpin
  $0 com.target.app full           # SSL + root + RASP (Android)
  $0 com.bank.ios ios-full         # JB + SSL + anti-Frida (iOS)
EOF
  exit 1
fi

export PATH="$HOME/.local/bin:$HOME/Android/Sdk/platform-tools:$PATH"

run() { echo "[*] frida -U -f $PKG  ::  $@"; frida -U -f "$PKG" "$@" --no-pause; }

case "$MODE" in
  objection)  objection --gadget "$PKG" explore --startup-command "android sslpinning disable" ;;
  ssl)        run -l "$DIR/android/ssl-multi-unpin.js" ;;
  root)       run -l "$DIR/android/root-bypass.js" ;;
  rasp)       run -l "$DIR/android/rasp-bypass.js" ;;
  full)       run -l "$DIR/android/root-bypass.js" \
                  -l "$DIR/android/rasp-bypass.js" \
                  -l "$DIR/android/ssl-multi-unpin.js" ;;
  ios-jb)     run -l "$DIR/ios/jailbreak-bypass.js" ;;
  ios-ssl)    run -l "$DIR/ios/ssl-bypass.js" ;;
  ios-full)   run -l "$DIR/ios/jailbreak-bypass.js" \
                  -l "$DIR/ios/ssl-bypass.js" \
                  -l "$DIR/ios/anti-frida-bypass.js" ;;
  *)          echo "[-] unknown mode: $MODE"; exit 1 ;;
esac
