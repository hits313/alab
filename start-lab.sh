#!/usr/bin/env bash
# alab — Android Pentest Framework
# AVD: Pixel6_API33_root | Android 13 | google_apis x86_64 | KVM + Magisk 25.2 + Zygisk

ANDROID_SDK_ROOT="$HOME/Android/Sdk"
EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"
ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
AVD_NAME="Pixel6_API33_root"
BURP_HOST="10.0.2.2"
BURP_PORT="8080"
FRIDA_SERVER="$HOME/tools/android-lab/frida/frida-server"
FRIDA_VERSION="17.2.14"
MAGISK_VERSION="25.2"
SCRCPY="$HOME/.local/bin/scrcpy"

export ANDROID_SDK_ROOT
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$HOME/.local/bin:$HOME/tools/android-lab/jadx/bin:$PATH"

# ── colors ───────────────────────────────────────────────────────────────────
R='\033[0;31m'   BR='\033[1;31m'
G='\033[0;32m'   BG='\033[1;32m'
Y='\033[1;33m'
C='\033[0;36m'   BC='\033[1;36m'
B='\033[0;34m'   BB='\033[1;34m'
W='\033[1;37m'   DIM='\033[2m'
RESET='\033[0m'

info()  { echo -e "${BC}[*]${RESET} $*"; }
ok()    { echo -e "${BG}[+]${RESET} $*"; }
warn()  { echo -e "${Y}[!]${RESET} $*"; }
err()   { echo -e "${BR}[-]${RESET} $*"; }
hdr()   { echo -e "\n${BB}  ──  ${W}${*}${RESET}"; }

# ── banner ───────────────────────────────────────────────────────────────────
banner() {
  local DEVICE STATUS ROOT_ST FRIDA_ST PROXY_ST ZYGISK_ST
  DEVICE=$("$ADB" devices 2>/dev/null | grep -v "List" | grep "device$" | awk '{print $1}' | head -1)
  if [[ -n "$DEVICE" ]]; then
    STATUS="${BG}online${RESET}"
    ROOT_ST=$("$ADB" shell id 2>/dev/null | grep -o "uid=0" && echo "" || echo "no-root")
    [[ "$ROOT_ST" == *"uid=0"* ]] && ROOT_ST="${BG}uid=0${RESET}" || ROOT_ST="${Y}adb-user${RESET}"
    FRIDA_RUNNING=$("$ADB" shell "pgrep -f frida-server" 2>/dev/null)
    [[ -n "$FRIDA_RUNNING" ]] && FRIDA_ST="${BG}running${RESET}" || FRIDA_ST="${DIM}stopped${RESET}"
    PROXY_VAL=$("$ADB" shell settings get global http_proxy 2>/dev/null | tr -d '\r')
    [[ "$PROXY_VAL" == *"$BURP_HOST"* ]] && PROXY_ST="${BG}${PROXY_VAL}${RESET}" || PROXY_ST="${DIM}off${RESET}"
    ZYGISK_VAL=$("$ADB" shell "sqlite3 /data/adb/magisk.db 'SELECT value FROM settings WHERE key=\"zygisk\";' 2>/dev/null" | tr -d '\r')
    [[ "$ZYGISK_VAL" == "1" ]] && ZYGISK_ST="${BG}ON${RESET}" || ZYGISK_ST="${Y}OFF${RESET}"
  else
    STATUS="${DIM}offline${RESET}"
    ROOT_ST="${DIM}—${RESET}"; FRIDA_ST="${DIM}—${RESET}"
    PROXY_ST="${DIM}—${RESET}"; ZYGISK_ST="${DIM}—${RESET}"
  fi

  echo -e "${BR}"
  echo -e '  ██████╗ ██╗      █████╗ ██████╗ '
  echo -e '  ██╔══██╗██║     ██╔══██╗██╔══██╗'
  echo -e '  ███████║██║     ███████║██████╔╝'
  echo -e '  ██╔══██║██║     ██╔══██║██╔══██╗'
  echo -e '  ██║  ██║███████╗██║  ██║██████╔╝'
  echo -e '  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ '
  echo -e "${RESET}"
  echo -e "  ${DIM}       =[ ${W}alab v2.0  ::  Android Pentest Framework${RESET}${DIM}           ]${RESET}"
  echo -e "  ${DIM}+ -- --=[ ${C}Pixel 6  ·  API 33  ·  Magisk ${MAGISK_VERSION}  ·  Zygisk${RESET}${DIM}      ]${RESET}"
  echo -e "  ${DIM}+ -- --=[ ${C}Frida ${FRIDA_VERSION}  ·  objection  ·  jadx  ·  Burp${RESET}${DIM}   ]${RESET}"
  echo -e "  ${DIM}+ -- --=[ ${C}KVM  ·  angle_indirect  ·  scrcpy mirror${RESET}${DIM}           ]${RESET}"
  echo ""
  echo -e "  ${DIM}device  ${RESET}  ${STATUS}  ${DIM}│${RESET}  ${DIM}root   ${RESET} ${ROOT_ST}  ${DIM}│${RESET}  ${DIM}frida  ${RESET} ${FRIDA_ST}"
  echo -e "  ${DIM}proxy   ${RESET}  ${PROXY_ST}  ${DIM}│${RESET}  ${DIM}zygisk ${RESET} ${ZYGISK_ST}"
  echo ""
}

usage() {
  banner
  echo -e "${BB}  ──  ${W}BOOT${RESET}"
  echo -e "    ${W}start${RESET}              boot AVD · auto root · proxy · Zygisk · DenyList"
  echo -e "    ${W}stop${RESET}               kill emulator"
  echo -e "    ${W}screen${RESET}             mirror device via scrcpy"
  echo ""
  echo -e "${BB}  ──  ${W}ROOT / MAGISK${RESET}"
  echo -e "    ${W}root${RESET}               adb root + remount"
  echo -e "    ${W}setup${RESET}              full setup: root + frida + proxy + magisk"
  echo -e "    ${W}magisk${RESET}             show Magisk daemon version + DenyList status"
  echo -e "    ${W}denylist${RESET}           enable Zygisk + DenyList via sqlite3"
  echo -e "    ${W}denylist-add${RESET}       add pkg to DenyList  →  alab denylist-add com.bank.app"
  echo -e "    ${W}denylist-ls${RESET}        list all DenyList entries"
  echo ""
  echo -e "${BB}  ──  ${W}INTERCEPT${RESET}"
  echo -e "    ${W}frida${RESET}              push + start frida-server ${FRIDA_VERSION} on device"
  echo -e "    ${W}frida-stop${RESET}         kill frida-server"
  echo -e "    ${W}burp-cert${RESET}          install Burp CA as system cert"
  echo -e "    ${W}proxy-on${RESET}           route all traffic → Burp ${BURP_HOST}:${BURP_PORT}"
  echo -e "    ${W}proxy-off${RESET}          clear proxy"
  echo ""
  echo -e "${BB}  ──  ${W}SSL UNPIN${RESET}"
  echo -e "    ${W}unpin${RESET}      ${DIM}<pkg>${RESET}  objection SSL unpin spawn"
  echo -e "    ${W}unpin-frida${RESET} ${DIM}<pkg>${RESET} Frida universal unpin  (OkHttp3 · TrustKit · TrustManager)"
  echo ""
  echo -e "${BB}  ──  ${W}APK${RESET}"
  echo -e "    ${W}install${RESET}    ${DIM}<apk>${RESET}  install APK"
  echo -e "    ${W}pull-apk${RESET}   ${DIM}<pkg>${RESET}  pull installed APK from device"
  echo -e "    ${W}decompile${RESET}  ${DIM}<apk>${RESET}  jadx decompile → /tmp/jadx-<name>/"
  echo -e "    ${W}strings${RESET}    ${DIM}<apk>${RESET}  apkleaks — secrets + endpoints"
  echo -e "    ${W}manifest${RESET}   ${DIM}<apk>${RESET}  dump decoded AndroidManifest.xml"
  echo ""
  echo -e "${BB}  ──  ${W}DEVICE${RESET}"
  echo -e "    ${W}screenshot${RESET}         save → /tmp/screen.png"
  echo -e "    ${W}logcat${RESET}     ${DIM}<pkg>${RESET}  live logcat filtered by package"
  echo -e "    ${W}pull-data${RESET}  ${DIM}<pkg>${RESET}  pull /data/data/<pkg> to /tmp/"
  echo -e "    ${W}activities${RESET} ${DIM}<pkg>${RESET}  list all activities + exported flag"
  echo -e "    ${W}launch${RESET}     ${DIM}<comp>${RESET} launch activity: com.pkg/.Activity"
  echo -e "    ${W}status${RESET}             full status: device · root · Magisk · frida · proxy"
  echo ""
}

# ── core helpers ─────────────────────────────────────────────────────────────
wait_for_boot() {
  info "Waiting for device to boot..."
  "$ADB" wait-for-device
  until "$ADB" shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do
    sleep 2
  done
  ok "Device booted."
}

cmd_start() {
  if pgrep -f "emulator.*$AVD_NAME" > /dev/null 2>&1; then
    warn "Emulator already running."
    return 0
  fi
  rm -f "$HOME/.android/avd/${AVD_NAME}.avd/hardware-qemu.ini.lock" 2>/dev/null
  info "Starting ${W}${AVD_NAME}${RESET}..."
  "$EMULATOR" \
    -avd "$AVD_NAME" \
    -accel on \
    -gpu swangle \
    -memory 2048 \
    -cores 6 \
    -no-snapshot-save \
    -no-snapshot \
    -writable-system \
    -dns-server 8.8.8.8 \
    -no-boot-anim \
    > /tmp/emulator.log 2>&1 &
  ok "Emulator PID: $!"
  wait_for_boot
  info "Auto-configuring..."
  cmd_root
  cmd_proxy_on
  cmd_magisk_perms
  echo ""
  ok "Ready. ${DIM}Run${RESET} ${W}alab screen${RESET} ${DIM}to mirror display.${RESET}"
}

cmd_stop() {
  "$ADB" emu kill 2>/dev/null && ok "Emulator stopped." || warn "No emulator running."
}

cmd_screen() {
  info "Launching scrcpy mirror..."
  "$SCRCPY" --max-size 1080 --stay-awake --no-audio --turn-screen-off &
  ok "scrcpy PID: $!"
}

cmd_root() {
  info "Enabling root..."
  "$ADB" root && sleep 2
  "$ADB" remount 2>/dev/null || true
  ok "Root: uid=0"
}

cmd_frida() {
  info "Pushing frida-server ${FRIDA_VERSION}..."
  "$ADB" root && sleep 1
  "$ADB" push "$FRIDA_SERVER" /data/local/tmp/frida-server
  "$ADB" shell chmod 755 /data/local/tmp/frida-server
  "$ADB" shell "pkill -f frida-server 2>/dev/null; true"
  sleep 1
  "$ADB" shell "/data/local/tmp/frida-server &"
  sleep 2
  ok "frida-server running.  ${DIM}verify:${RESET} frida-ps -U"
}

cmd_frida_stop() {
  "$ADB" shell "pkill -f frida-server" && ok "frida-server stopped." || warn "Not running."
}

cmd_burp_cert() {
  CERT_DER="$HOME/tools/android-lab/burp/cacert.der"
  CERT_PEM="$HOME/tools/android-lab/burp/cacert.pem"
  if [[ ! -f "$CERT_DER" ]]; then
    err "Missing: $CERT_DER"
    err "Export from Burp > Proxy > Settings > CA Certificate (DER format)"
    return 1
  fi
  info "Installing Burp CA as system cert..."
  openssl x509 -inform DER -in "$CERT_DER" -out "$CERT_PEM"
  HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$CERT_PEM" | head -1)
  "$ADB" root && sleep 1 && "$ADB" remount
  "$ADB" push "$CERT_PEM" "/system/etc/security/cacerts/${HASH}.0"
  "$ADB" shell "chmod 644 /system/etc/security/cacerts/${HASH}.0"
  ok "Cert installed: ${W}${HASH}.0${RESET}"
  info "Rebooting..."
  "$ADB" reboot && wait_for_boot
}

cmd_proxy_on() {
  "$ADB" shell settings put global http_proxy "$BURP_HOST:$BURP_PORT"
  "$ADB" shell settings put global captive_portal_mode 0
  "$ADB" shell settings put global captive_portal_detection_enabled 0
  "$ADB" shell settings put global captive_portal_http_url  "http://connectivitycheck.gstatic.com/generate_204"
  "$ADB" shell settings put global captive_portal_https_url "http://connectivitycheck.gstatic.com/generate_204"
  ok "Proxy → Burp ${W}${BURP_HOST}:${BURP_PORT}${RESET}"
}

cmd_proxy_off() {
  "$ADB" shell settings put global http_proxy :0
  ok "Proxy cleared."
}

cmd_magisk() {
  hdr "Magisk"
  "$ADB" shell "magisk -v 2>/dev/null && magisk -V 2>/dev/null" || warn "Daemon not running"
  "$ADB" shell "magisk --denylist status 2>/dev/null" || true
  echo -e "\n${DIM}  Zygisk DB:${RESET}"
  "$ADB" shell "sqlite3 /data/adb/magisk.db 'SELECT key,value FROM settings;' 2>/dev/null" | \
    while IFS='|' read -r k v; do
      [[ "$v" == "1" ]] && echo -e "    ${BG}●${RESET} ${k}" || echo -e "    ${Y}○${RESET} ${k}"
    done
}

cmd_magisk_perms() {
  info "Configuring Magisk..."
  "$ADB" shell "sqlite3 /data/adb/magisk.db 'CREATE TABLE IF NOT EXISTS settings (key TEXT, value INT, PRIMARY KEY(key)); REPLACE INTO settings VALUES(\"zygisk\",1); REPLACE INTO settings VALUES(\"denylist\",1);' 2>/dev/null" || true
  "$ADB" shell "magisk --denylist enable 2>/dev/null" || true
  ok "Zygisk ${BG}ON${RESET}  ·  DenyList ${BG}ON${RESET}"
}

cmd_denylist() {
  cmd_magisk_perms
}

cmd_denylist_add() {
  PKG="${2:-}"
  [[ -z "$PKG" ]] && err "Usage: alab denylist-add com.package.name" && return 1
  "$ADB" shell "magisk --denylist add $PKG" && ok "DenyList ← ${W}${PKG}${RESET}" || err "Failed — is Magisk daemon running?"
}

cmd_denylist_ls() {
  hdr "DenyList"
  "$ADB" shell "magisk --denylist ls 2>/dev/null" || warn "Empty or daemon not running"
}

cmd_unpin() {
  PKG="${2:-}"
  [[ -z "$PKG" ]] && err "Usage: alab unpin com.package.name" && return 1
  info "objection SSL unpin → ${W}${PKG}${RESET}"
  objection --gadget "$PKG" explore --startup-command "android sslpinning disable"
}

cmd_unpin_frida() {
  PKG="${2:-}"
  [[ -z "$PKG" ]] && err "Usage: alab unpin-frida com.package.name" && return 1
  SCRIPT="$HOME/tools/android-lab/frida-scripts/universal-ssl-unpin.js"
  info "Frida universal SSL unpin → ${W}${PKG}${RESET}"
  frida -U -f "$PKG" -l "$SCRIPT" --no-pause
}

cmd_install() {
  APK="${2:-}"
  [[ -z "$APK" ]] && err "Usage: alab install app.apk" && return 1
  "$ADB" install -r "$APK" && ok "Installed: ${W}${APK}${RESET}"
}

cmd_pull_apk() {
  PKG="${2:-}"
  [[ -z "$PKG" ]] && err "Usage: alab pull-apk com.package.name" && return 1
  PATH_APK=$("$ADB" shell pm path "$PKG" | cut -d: -f2 | tr -d '\r')
  "$ADB" pull "$PATH_APK" "/tmp/${PKG}.apk" && ok "Saved: ${W}/tmp/${PKG}.apk${RESET}"
}

cmd_decompile() {
  APK="${2:-}"
  [[ -z "$APK" ]] && err "Usage: alab decompile app.apk" && return 1
  OUT="/tmp/jadx-$(basename "$APK" .apk)"
  jadx -d "$OUT" "$APK" && ok "Output: ${W}${OUT}${RESET}"
}

cmd_strings() {
  APK="${2:-}"
  [[ -z "$APK" ]] && err "Usage: alab strings app.apk" && return 1
  apkleaks -f "$APK"
}

cmd_manifest() {
  APK="${2:-}"
  [[ -z "$APK" ]] && err "Usage: alab manifest app.apk" && return 1
  apktool d -s "$APK" -o /tmp/manifest-decode -f 2>/dev/null
  cat /tmp/manifest-decode/AndroidManifest.xml
}

cmd_screenshot() {
  "$ADB" exec-out screencap -p > /tmp/screen.png && ok "Saved: ${W}/tmp/screen.png${RESET}" && xdg-open /tmp/screen.png &
}

cmd_logcat() {
  PKG="${2:-}"
  if [[ -z "$PKG" ]]; then
    "$ADB" logcat
  else
    PID=$("$ADB" shell "pidof $PKG 2>/dev/null")
    "$ADB" logcat | grep -E "$PKG|$PID"
  fi
}

cmd_pull_data() {
  PKG="${2:-}"
  [[ -z "$PKG" ]] && err "Usage: alab pull-data com.package.name" && return 1
  "$ADB" pull "/data/data/$PKG" "/tmp/appdata-$PKG" && ok "Saved: ${W}/tmp/appdata-${PKG}${RESET}"
}

cmd_activities() {
  PKG="${2:-}"
  [[ -z "$PKG" ]] && err "Usage: alab activities com.package.name" && return 1
  "$ADB" shell "dumpsys package $PKG" | grep -E "Activity|exported" | grep -i "activity"
}

cmd_launch() {
  COMPONENT="${2:-}"
  [[ -z "$COMPONENT" ]] && err "Usage: alab launch com.pkg/.Activity" && return 1
  "$ADB" shell "am start -n $COMPONENT" && ok "Launched: ${W}${COMPONENT}${RESET}"
}

cmd_status() {
  banner
  hdr "Device"
  "$ADB" devices
  hdr "Root"
  "$ADB" shell id 2>/dev/null || warn "Not connected"
  hdr "Magisk"
  "$ADB" shell "magisk -v 2>/dev/null && magisk --denylist status 2>/dev/null" || warn "Daemon not running"
  hdr "Frida"
  frida-ps -U 2>/dev/null | head -5 || warn "frida-server not running"
  hdr "Proxy"
  "$ADB" shell settings get global http_proxy 2>/dev/null
  hdr "Burp Cert"
  "$ADB" shell "ls /system/etc/security/cacerts/9a5ba575.0 2>/dev/null && echo 'Installed' || echo 'Missing'"
  echo ""
}

cmd_setup() {
  wait_for_boot
  cmd_root
  cmd_magisk_perms
  cmd_frida
  cmd_burp_cert || true
  cmd_proxy_on
  echo ""
  ok "Full setup complete."
  cmd_status
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "${1:-}" in
  start)         cmd_start ;;
  stop)          cmd_stop ;;
  screen)        cmd_screen ;;
  root)          cmd_root ;;
  setup)         cmd_setup ;;
  magisk)        cmd_magisk ;;
  denylist)      cmd_denylist ;;
  denylist-add)  cmd_denylist_add "$@" ;;
  denylist-ls)   cmd_denylist_ls ;;
  frida)         cmd_frida ;;
  frida-stop)    cmd_frida_stop ;;
  burp-cert)     cmd_burp_cert ;;
  proxy-on)      cmd_proxy_on ;;
  proxy-off)     cmd_proxy_off ;;
  unpin)         cmd_unpin "$@" ;;
  unpin-frida)   cmd_unpin_frida "$@" ;;
  install)       cmd_install "$@" ;;
  pull-apk)      cmd_pull_apk "$@" ;;
  decompile)     cmd_decompile "$@" ;;
  strings)       cmd_strings "$@" ;;
  manifest)      cmd_manifest "$@" ;;
  screenshot)    cmd_screenshot ;;
  logcat)        cmd_logcat "$@" ;;
  pull-data)     cmd_pull_data "$@" ;;
  activities)    cmd_activities "$@" ;;
  launch)        cmd_launch "$@" ;;
  status)        cmd_status ;;
  *)             usage ;;
esac
