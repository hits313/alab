#!/usr/bin/env bash
# alab — Android Pentest Framework
# AVD: Pixel6_API33_root | Android 13 | google_apis x86_64 | KVM + Magisk + Zygisk
# developed by hits · built by human + AI (Opus 4.6)

ALAB_VERSION="2.1.0"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
EMULATOR="$ANDROID_SDK_ROOT/emulator/emulator"
ADB="$ANDROID_SDK_ROOT/platform-tools/adb"
AVD_NAME="${ALAB_AVD:-Pixel6_API33_root}"
BURP_HOST="${ALAB_BURP_HOST:-10.0.2.2}"
BURP_PORT="${ALAB_BURP_PORT:-8080}"
LAB_DIR="$HOME/tools/android-lab"
FRIDA_SERVER="$LAB_DIR/frida/frida-server"
FRIDA_VERSION="${ALAB_FRIDA_VERSION:-17.2.14}"
MAGISK_VERSION="25.2"
SCRCPY="$(command -v scrcpy 2>/dev/null || echo "$HOME/.local/bin/scrcpy")"
HUNT_DIR="${ALAB_HUNT_DIR:-$HOME/hunt}"

export ANDROID_SDK_ROOT
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$HOME/.local/bin:$LAB_DIR/jadx/bin:$PATH"

# ── colors (auto-disable when not TTY or NO_COLOR set) ────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  R='\033[0;31m';  BR='\033[1;31m'
  G='\033[0;32m';  BG='\033[1;32m'
  Y='\033[1;33m'
  C='\033[0;36m';  BC='\033[1;36m'
  B='\033[0;34m';  BB='\033[1;34m'
  W='\033[1;37m';  DIM='\033[2m'
  RESET='\033[0m'
else
  R= BR= G= BG= Y= C= BC= B= BB= W= DIM= RESET=
fi

info()  { echo -e "${BC}[*]${RESET} $*"; }
ok()    { echo -e "${BG}[+]${RESET} $*"; }
warn()  { echo -e "${Y}[!]${RESET} $*"; }
err()   { echo -e "${BR}[-]${RESET} $*" >&2; }
hdr()   { echo -e "\n${BB}  ──  ${W}${*}${RESET}"; }

# ── banner ────────────────────────────────────────────────────────────────────
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
  echo -e "  ${DIM}       =[ ${W}alab v${ALAB_VERSION}  ::  Android Pentest Framework${RESET}${DIM}        ]${RESET}"
  echo -e "  ${DIM}+ -- --=[ ${C}Pixel 6  ·  API 33  ·  Magisk ${MAGISK_VERSION}  ·  Zygisk${RESET}${DIM}      ]${RESET}"
  echo -e "  ${DIM}+ -- --=[ ${C}Frida ${FRIDA_VERSION}  ·  objection  ·  jadx  ·  Burp${RESET}${DIM}   ]${RESET}"
  echo -e "  ${DIM}+ -- --=[ ${C}KVM  ·  scrcpy mirror  ·  hunt mode${RESET}${DIM}                  ]${RESET}"
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
  echo -e "    ${W}snapshot${RESET}    ${DIM}<n>${RESET}  save AVD snapshot ${DIM}(snapshot save mybase / snapshot load mybase)${RESET}"
  echo ""
  echo -e "${BB}  ──  ${W}HEALTH / META${RESET}"
  echo -e "    ${W}doctor${RESET}             full environment health check ${DIM}(KVM · SDK · frida sync · burp · tools)${RESET}"
  echo -e "    ${W}frida-sync${RESET}         pull frida-server matching the host frida-tools version"
  echo -e "    ${W}version${RESET}            print alab + frida + magisk + AVD versions"
  echo ""
  echo -e "${BB}  ──  ${W}ROOT / MAGISK${RESET}"
  echo -e "    ${W}root${RESET}               adb root + remount"
  echo -e "    ${W}setup${RESET}              full setup: root + frida + proxy + magisk"
  echo -e "    ${W}magisk${RESET}             show Magisk daemon version + DenyList status"
  echo -e "    ${W}denylist${RESET}           enable Zygisk + DenyList via sqlite3"
  echo -e "    ${W}denylist-add${RESET} ${DIM}<pkg>${RESET} add pkg to DenyList"
  echo -e "    ${W}denylist-ls${RESET}        list all DenyList entries"
  echo ""
  echo -e "${BB}  ──  ${W}INTERCEPT${RESET}"
  echo -e "    ${W}frida${RESET}              push + start frida-server ${FRIDA_VERSION} on device"
  echo -e "    ${W}frida-stop${RESET}         kill frida-server"
  echo -e "    ${W}burp-cert${RESET}          install Burp CA as system cert"
  echo -e "    ${W}proxy-on${RESET}           route all traffic → Burp ${BURP_HOST}:${BURP_PORT}"
  echo -e "    ${W}proxy-off${RESET}          clear proxy"
  echo -e "    ${W}certs${RESET}              list trusted CA certs on device (system + user + Burp status)"
  echo ""
  echo -e "${BB}  ──  ${W}SSL / RASP UNPIN${RESET}"
  echo -e "    ${W}unpin${RESET}      ${DIM}<pkg>${RESET}  objection SSL unpin spawn"
  echo -e "    ${W}unpin-frida${RESET} ${DIM}<pkg>${RESET} Frida SSL unpin (multi-stack)"
  echo -e "    ${W}unpin-full${RESET}  ${DIM}<pkg>${RESET} SSL + root + RASP combined ${DIM}(loads 3 scripts)${RESET}"
  echo ""
  echo -e "${BB}  ──  ${W}APK${RESET}"
  echo -e "    ${W}install${RESET}    ${DIM}<apk>${RESET}  install APK ${DIM}(handles split APKs)${RESET}"
  echo -e "    ${W}pull-apk${RESET}   ${DIM}<pkg>${RESET}  pull installed APK from device ${DIM}(merges splits)${RESET}"
  echo -e "    ${W}decompile${RESET}  ${DIM}<apk>${RESET}  jadx decompile → /tmp/jadx-<name>/"
  echo -e "    ${W}strings${RESET}    ${DIM}<apk>${RESET}  apkleaks — secrets + endpoints"
  echo -e "    ${W}manifest${RESET}   ${DIM}<apk>${RESET}  dump decoded AndroidManifest.xml"
  echo -e "    ${W}grep${RESET}       ${DIM}<pkg> <re>${RESET}  grep decompiled sources for a pattern"
  echo ""
  echo -e "${BB}  ──  ${W}HUNT MODE${RESET}"
  echo -e "    ${W}hunt${RESET}       ${DIM}<pkg>${RESET}  auto recon: pull APK · decompile · apkleaks · manifest"
  echo -e "    ${DIM}                       → REPORT.md at \$HUNT_DIR/<pkg>/${RESET}"
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

# ── core helpers ──────────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

wait_for_boot() {
  info "Waiting for device to boot..."
  "$ADB" wait-for-device
  until "$ADB" shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do
    sleep 2
  done
  ok "Device booted."
}

require_device() {
  if ! "$ADB" devices 2>/dev/null | grep -q "device$"; then
    err "No device connected. Run: alab start"
    return 1
  fi
}

# ── boot ──────────────────────────────────────────────────────────────────────
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

cmd_stop()    { "$ADB" emu kill 2>/dev/null && ok "Emulator stopped." || warn "No emulator running."; }
cmd_screen()  { info "Launching scrcpy mirror..."; "$SCRCPY" --max-size 1080 --stay-awake --no-audio --turn-screen-off & ok "scrcpy PID: $!"; }

cmd_snapshot() {
  local op="${2:-}" name="${3:-base}"
  case "$op" in
    save)  "$ADB" emu avd snapshot save "$name" && ok "Snapshot saved: $name" ;;
    load)  "$ADB" emu avd snapshot load "$name" && ok "Snapshot loaded: $name" ;;
    list)  "$ADB" emu avd snapshot list ;;
    *)     err "Usage: alab snapshot {save|load|list} [name]" ;;
  esac
}

# ── root / magisk ─────────────────────────────────────────────────────────────
cmd_root() {
  info "Enabling root..."
  "$ADB" root && sleep 2
  "$ADB" remount 2>/dev/null || true
  ok "Root: uid=0"
}

cmd_magisk_perms() {
  info "Configuring Magisk..."
  "$ADB" shell "sqlite3 /data/adb/magisk.db 'CREATE TABLE IF NOT EXISTS settings (key TEXT, value INT, PRIMARY KEY(key)); REPLACE INTO settings VALUES(\"zygisk\",1); REPLACE INTO settings VALUES(\"denylist\",1);' 2>/dev/null" || true
  "$ADB" shell "magisk --denylist enable 2>/dev/null" || true
  ok "Zygisk ${BG}ON${RESET}  ·  DenyList ${BG}ON${RESET}"
}

cmd_magisk() {
  hdr "Magisk"
  "$ADB" shell "magisk -v 2>/dev/null && magisk -V 2>/dev/null" || warn "Daemon not running"
  "$ADB" shell "magisk --denylist status 2>/dev/null" || true
}

cmd_denylist()     { cmd_magisk_perms; }
cmd_denylist_add() { local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab denylist-add com.x.y" && return 1
                     "$ADB" shell "magisk --denylist add $pkg" && ok "DenyList ← ${W}${pkg}${RESET}"; }
cmd_denylist_ls()  { hdr "DenyList"; "$ADB" shell "magisk --denylist ls 2>/dev/null" || warn "Empty or daemon not running"; }

# ── frida ─────────────────────────────────────────────────────────────────────
cmd_frida() {
  [[ -f "$FRIDA_SERVER" ]] || { err "frida-server missing — run: alab frida-sync"; return 1; }
  info "Pushing frida-server ${FRIDA_VERSION}..."
  "$ADB" root && sleep 1
  "$ADB" push "$FRIDA_SERVER" /data/local/tmp/frida-server >/dev/null
  "$ADB" shell chmod 755 /data/local/tmp/frida-server
  "$ADB" shell "pkill -f frida-server 2>/dev/null; true"
  sleep 1
  "$ADB" shell "/data/local/tmp/frida-server &"
  sleep 2
  ok "frida-server running.  ${DIM}verify:${RESET} frida-ps -U"
}

cmd_frida_stop() { "$ADB" shell "pkill -f frida-server" && ok "frida-server stopped." || warn "Not running."; }

cmd_frida_sync() {
  have frida || { err "frida not installed: pip install --user frida-tools"; return 1; }
  local host_ver arch_d arch_h url
  host_ver=$(frida --version 2>/dev/null | tr -d '[:space:]')
  [[ -z "$host_ver" ]] && { err "Could not detect frida host version"; return 1; }
  if require_device 2>/dev/null; then
    arch_d=$("$ADB" shell getprop ro.product.cpu.abi | tr -d '\r')
  else
    arch_d="x86_64"
  fi
  case "$arch_d" in
    arm64-v8a)  arch_h="arm64" ;;
    armeabi*)   arch_h="arm" ;;
    x86_64)     arch_h="x86_64" ;;
    x86)        arch_h="x86" ;;
    *)          err "Unknown device arch: $arch_d"; return 1 ;;
  esac
  url="https://github.com/frida/frida/releases/download/${host_ver}/frida-server-${host_ver}-android-${arch_h}.xz"
  info "Host frida: ${W}${host_ver}${RESET}  ·  device arch: ${W}${arch_d}${RESET}  →  ${arch_h}"
  info "URL: $url"
  mkdir -p "$LAB_DIR/frida"
  if curl -fSL --progress-bar "$url" -o "$LAB_DIR/frida/frida-server.xz"; then
    ( cd "$LAB_DIR/frida" && xz -df frida-server.xz && chmod +x frida-server )
    ok "frida-server ${host_ver} ready at $FRIDA_SERVER"
    sed -i.bak "s/^FRIDA_VERSION=.*/FRIDA_VERSION=\"\${ALAB_FRIDA_VERSION:-${host_ver}}\"/" "$LAB_DIR/start-lab.sh" 2>/dev/null && rm -f "$LAB_DIR/start-lab.sh.bak"
  else
    err "Download failed — check version exists at github.com/frida/frida/releases"
  fi
}

# ── burp / proxy ──────────────────────────────────────────────────────────────
cmd_burp_cert() {
  local CERT_DER="$LAB_DIR/burp/cacert.der"
  local CERT_PEM="$LAB_DIR/burp/cacert.pem"
  [[ -f "$CERT_DER" ]] || { err "Missing: $CERT_DER"; err "Export from Burp > Proxy > Settings > CA Certificate (DER format)"; return 1; }
  info "Installing Burp CA as system cert..."
  openssl x509 -inform DER -in "$CERT_DER" -out "$CERT_PEM"
  local HASH
  HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$CERT_PEM" | head -1)
  [[ -z "$HASH" ]] && { err "Could not compute cert hash"; return 1; }
  echo "$HASH" > "$LAB_DIR/burp/.cert-hash"
  "$ADB" root && sleep 1 && "$ADB" remount
  if ! "$ADB" push "$CERT_PEM" "/system/etc/security/cacerts/${HASH}.0" >/dev/null; then
    err "Push failed — emulator may not be -writable-system"; return 1
  fi
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

cmd_proxy_off() { "$ADB" shell settings put global http_proxy :0; ok "Proxy cleared."; }

cmd_certs() {
  hdr "System CA store (count)"
  "$ADB" shell "ls /system/etc/security/cacerts/ 2>/dev/null | wc -l"
  hdr "Burp cert installed?"
  if [[ -f "$LAB_DIR/burp/.cert-hash" ]]; then
    local h; h=$(cat "$LAB_DIR/burp/.cert-hash")
    "$ADB" shell "ls -l /system/etc/security/cacerts/${h}.0 2>/dev/null" | grep -q "$h" \
      && ok "Burp cert ${W}${h}.0${RESET} present" || warn "Burp cert ${h}.0 NOT present"
  else
    warn "No record of installed Burp cert (run: alab burp-cert)"
  fi
  hdr "User-store CAs"
  "$ADB" shell "ls /data/misc/user/0/cacerts-added/ 2>/dev/null | head -10" || warn "none"
}

# ── unpin ─────────────────────────────────────────────────────────────────────
cmd_unpin() {
  local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab unpin com.x.y" && return 1
  info "objection SSL unpin → ${W}${pkg}${RESET}"
  objection --gadget "$pkg" explore --startup-command "android sslpinning disable"
}

cmd_unpin_frida() {
  local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab unpin-frida com.x.y" && return 1
  local script="$LAB_DIR/frida-scripts/android/ssl-multi-unpin.js"
  [[ -f "$script" ]] || script="$LAB_DIR/frida-scripts/universal-ssl-unpin.js"
  info "Frida SSL unpin → ${W}${pkg}${RESET}"
  frida -U -f "$pkg" -l "$script" --no-pause
}

cmd_unpin_full() {
  local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab unpin-full com.x.y" && return 1
  local D="$LAB_DIR/frida-scripts/android"
  info "Frida full bypass (SSL + root + RASP) → ${W}${pkg}${RESET}"
  frida -U -f "$pkg" \
    -l "$D/root-bypass.js" \
    -l "$D/rasp-bypass.js" \
    -l "$D/ssl-multi-unpin.js" --no-pause
}

# ── apk ───────────────────────────────────────────────────────────────────────
cmd_install() {
  local apk="${2:-}"; [[ -z "$apk" ]] && err "Usage: alab install app.apk [split1.apk split2.apk ...]" && return 1
  shift
  if [[ $# -gt 1 ]]; then
    "$ADB" install-multiple -r "$@" && ok "Installed split APKs: $*"
  else
    "$ADB" install -r "$apk" && ok "Installed: ${W}${apk}${RESET}"
  fi
}

cmd_pull_apk() {
  local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab pull-apk com.x.y" && return 1
  require_device || return 1
  local paths; paths=$("$ADB" shell pm path "$pkg" | sed 's/package://g' | tr -d '\r')
  [[ -z "$paths" ]] && { err "Package $pkg not installed"; return 1; }
  local count; count=$(echo "$paths" | wc -l)
  if [[ "$count" -eq 1 ]]; then
    "$ADB" pull "$paths" "/tmp/${pkg}.apk" >/dev/null && ok "Saved: ${W}/tmp/${pkg}.apk${RESET}"
  else
    info "Split APK detected ($count parts) — pulling all → /tmp/${pkg}/"
    mkdir -p "/tmp/${pkg}"
    while IFS= read -r p; do
      [[ -n "$p" ]] && "$ADB" pull "$p" "/tmp/${pkg}/$(basename "$p")" >/dev/null
    done <<< "$paths"
    ok "Saved $count APKs → ${W}/tmp/${pkg}/${RESET}"
    ls -lh "/tmp/${pkg}/"
  fi
}

cmd_decompile() {
  local apk="${2:-}"; [[ -z "$apk" ]] && err "Usage: alab decompile app.apk" && return 1
  have jadx || { err "jadx not in PATH — see install guide §2.6"; return 1; }
  local out="/tmp/jadx-$(basename "$apk" .apk)"
  jadx -d "$out" "$apk" && ok "Output: ${W}${out}${RESET}"
}

cmd_strings() {
  local apk="${2:-}"; [[ -z "$apk" ]] && err "Usage: alab strings app.apk" && return 1
  have apkleaks || { err "apkleaks missing: pip install --user apkleaks"; return 1; }
  apkleaks -f "$apk"
}

cmd_manifest() {
  local apk="${2:-}"; [[ -z "$apk" ]] && err "Usage: alab manifest app.apk" && return 1
  have apktool || { err "apktool missing: sudo apt install apktool"; return 1; }
  apktool d -s "$apk" -o /tmp/manifest-decode -f >/dev/null 2>&1
  cat /tmp/manifest-decode/AndroidManifest.xml
}

cmd_grep() {
  local pkg="${2:-}" pat="${3:-}"
  [[ -z "$pkg" || -z "$pat" ]] && err "Usage: alab grep <pkg> <regex>" && return 1
  local src="/tmp/jadx-${pkg}/sources"
  [[ -d "$src" ]] || src="/tmp/jadx-base/sources"
  [[ -d "$src" ]] || { err "No decompiled sources for $pkg — run: alab decompile <apk> first"; return 1; }
  info "grep -rn '$pat' $src"
  grep -rn --color=always -E "$pat" "$src" | head -100
}

# ── device ────────────────────────────────────────────────────────────────────
cmd_screenshot() { "$ADB" exec-out screencap -p > /tmp/screen.png && ok "Saved: ${W}/tmp/screen.png${RESET}" && (command -v xdg-open >/dev/null && xdg-open /tmp/screen.png &) ; }

cmd_logcat() {
  local pkg="${2:-}"
  if [[ -z "$pkg" ]]; then
    "$ADB" logcat
  else
    local pid; pid=$("$ADB" shell "pidof $pkg 2>/dev/null" | tr -d '\r')
    if [[ -z "$pid" ]]; then
      warn "$pkg not running — filtering by tag only"
      "$ADB" logcat | grep --line-buffered -i "$pkg"
    else
      info "PID=$pid"
      "$ADB" logcat --pid="$pid"
    fi
  fi
}

cmd_pull_data() {
  local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab pull-data com.x.y" && return 1
  "$ADB" pull "/data/data/$pkg" "/tmp/appdata-$pkg" && ok "Saved: ${W}/tmp/appdata-${pkg}${RESET}"
}

cmd_activities() {
  local pkg="${2:-}"; [[ -z "$pkg" ]] && err "Usage: alab activities com.x.y" && return 1
  "$ADB" shell "dumpsys package $pkg" | grep -E "Activity|exported" | grep -i "activity"
}

cmd_launch() {
  local comp="${2:-}"; [[ -z "$comp" ]] && err "Usage: alab launch com.pkg/.Activity" && return 1
  "$ADB" shell "am start -n $comp" && ok "Launched: ${W}${comp}${RESET}"
}

cmd_status() {
  banner
  hdr "Device";   "$ADB" devices
  hdr "Root";     "$ADB" shell id 2>/dev/null || warn "Not connected"
  hdr "Magisk";   "$ADB" shell "magisk -v 2>/dev/null && magisk --denylist status 2>/dev/null" || warn "Daemon not running"
  hdr "Frida";    frida-ps -U 2>/dev/null | head -5 || warn "frida-server not running"
  hdr "Proxy";    "$ADB" shell settings get global http_proxy 2>/dev/null
  hdr "Burp Cert"
  if [[ -f "$LAB_DIR/burp/.cert-hash" ]]; then
    local h; h=$(cat "$LAB_DIR/burp/.cert-hash")
    "$ADB" shell "ls /system/etc/security/cacerts/${h}.0 2>/dev/null && echo Installed || echo Missing"
  else
    echo "No cert hash on file — run: alab burp-cert"
  fi
  echo ""
}

# ── doctor ────────────────────────────────────────────────────────────────────
cmd_doctor() {
  banner
  hdr "Host environment"
  local checks=()
  _chk() { local name="$1" cmd="$2" hint="$3"
    if eval "$cmd" >/dev/null 2>&1; then echo -e "  ${BG}✔${RESET}  $name"
    else echo -e "  ${BR}✘${RESET}  $name   ${DIM}→ $hint${RESET}"; fi
  }
  _chk "KVM device"         "test -e /dev/kvm"               "sudo apt install qemu-kvm; usermod -aG kvm \$USER"
  _chk "Java 17"            "java -version 2>&1 | grep -q '17\\.'"  "sudo apt install openjdk-17-jdk"
  _chk "Python 3.10+"       "python3 -c 'import sys;exit(0 if sys.version_info>=(3,10) else 1)'" "use python3.10+"
  _chk "adb"                "command -v adb"                 "ANDROID_SDK_ROOT/platform-tools missing in PATH"
  _chk "emulator"           "command -v emulator"            "ANDROID_SDK_ROOT/emulator missing in PATH"
  _chk "frida-tools"        "command -v frida"               "pip install --user frida-tools"
  _chk "objection"          "command -v objection"           "pip install --user objection"
  _chk "jadx"               "command -v jadx"                "extract jadx → ~/tools/android-lab/jadx/"
  _chk "apktool"            "command -v apktool"             "sudo apt install apktool"
  _chk "apkleaks"           "command -v apkleaks"            "pip install --user apkleaks"
  _chk "scrcpy"             "command -v scrcpy"              "sudo apt install scrcpy   (optional, for mirror)"
  _chk "AVD '$AVD_NAME'"    "test -d $HOME/.android/avd/${AVD_NAME}.avd" "see install guide §2.4"
  _chk "frida-server bin"   "test -f $FRIDA_SERVER"          "alab frida-sync"

  hdr "Frida version sync"
  if have frida; then
    local host_v="$(frida --version 2>/dev/null)"
    echo "  host frida-tools : ${W}${host_v}${RESET}   (server expected: $FRIDA_VERSION)"
    [[ "$host_v" != "$FRIDA_VERSION" ]] && warn "version mismatch — run: alab frida-sync"
  fi

  hdr "Burp listener (host:$BURP_HOST:$BURP_PORT)"
  if (echo > "/dev/tcp/127.0.0.1/$BURP_PORT") 2>/dev/null; then
    ok "Something listening on 127.0.0.1:$BURP_PORT"
  else
    warn "Nothing listening on 127.0.0.1:$BURP_PORT — start Burp + listen on 0.0.0.0:$BURP_PORT"
  fi

  hdr "Disk"
  df -h "$HOME" | tail -1 | awk '{printf "  %s used / %s total — %s free\n",$3,$2,$4}'
  echo ""
}

cmd_version() {
  echo -e "${W}alab${RESET}      ${ALAB_VERSION}"
  echo -e "${W}frida${RESET}     $(frida --version 2>/dev/null || echo '—')"
  echo -e "${W}magisk${RESET}    ${MAGISK_VERSION}"
  echo -e "${W}AVD${RESET}       ${AVD_NAME}"
  echo -e "${W}sdk${RESET}       ${ANDROID_SDK_ROOT}"
}

# ── HUNT MODE ─────────────────────────────────────────────────────────────────
cmd_hunt() {
  local pkg="${2:-}"
  [[ -z "$pkg" ]] && err "Usage: alab hunt com.x.y" && return 1
  require_device || return 1
  have jadx || { err "jadx required"; return 1; }
  local out="$HUNT_DIR/$pkg"
  mkdir -p "$out"
  hdr "Hunt: ${W}$pkg${RESET}  →  $out"

  info "[1/6] Pulling APK(s)..."
  local paths; paths=$("$ADB" shell pm path "$pkg" | sed 's/package://g' | tr -d '\r')
  [[ -z "$paths" ]] && { err "Package $pkg not installed"; return 1; }
  local apks=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && { local fn="$out/$(basename "$p")"; "$ADB" pull "$p" "$fn" >/dev/null && apks+=("$fn"); }
  done <<< "$paths"
  ok "Pulled ${#apks[@]} APK(s)"
  local base="${apks[0]}"

  info "[2/6] Decompiling base APK with jadx..."
  jadx -d "$out/jadx" "$base" >/dev/null 2>&1
  ok "jadx output: $out/jadx/sources"

  info "[3/6] Dumping manifest..."
  apktool d -s "$base" -o "$out/apktool" -f >/dev/null 2>&1
  cp "$out/apktool/AndroidManifest.xml" "$out/AndroidManifest.xml" 2>/dev/null

  info "[4/6] apkleaks scan..."
  apkleaks -f "$base" -o "$out/apkleaks.json" --json >/dev/null 2>&1 || true

  info "[5/6] Enumerating exported components..."
  "$ADB" shell "dumpsys package $pkg" > "$out/dumpsys.txt" 2>&1
  grep -E "Activity|Receiver|Service|Provider" "$out/dumpsys.txt" | grep -i "exported" > "$out/exported.txt" 2>/dev/null || true

  info "[6/6] Generating REPORT.md..."
  local ver pkg_path size_total perm_count act_count exp_count native_libs
  ver=$("$ADB" shell "dumpsys package $pkg | grep versionName" | head -1 | tr -d '\r')
  size_total=$(du -sh "$out" 2>/dev/null | awk '{print $1}')
  perm_count=$(grep -c "uses-permission" "$out/AndroidManifest.xml" 2>/dev/null || echo 0)
  act_count=$(grep -c "<activity" "$out/AndroidManifest.xml" 2>/dev/null || echo 0)
  exp_count=$(grep -c 'android:exported="true"' "$out/AndroidManifest.xml" 2>/dev/null || echo 0)
  native_libs=$(unzip -l "$base" 2>/dev/null | grep -E '\.so$' | awk '{print $4}' | head -10)

  cat > "$out/REPORT.md" <<EOF
# alab hunt — \`$pkg\`

> Generated $(date -u +"%Y-%m-%d %H:%M UTC") · alab v${ALAB_VERSION}

## Summary
| | |
|---|---|
| Package | \`$pkg\` |
| ${ver:-Version not found} | |
| APKs pulled | ${#apks[@]} |
| Total size | $size_total |
| Permissions | $perm_count |
| Activities (total) | $act_count |
| Exported components | $exp_count |

## Files
- \`$base\`
- \`$out/jadx/sources/\` — decompiled Java
- \`$out/AndroidManifest.xml\` — decoded manifest
- \`$out/apkleaks.json\` — secrets / endpoints scan
- \`$out/dumpsys.txt\` — full pm dumpsys output
- \`$out/exported.txt\` — exported components

## Native libraries
\`\`\`
${native_libs:-none}
\`\`\`

## Exported components (review for IDOR / unauth access)
\`\`\`
$(head -30 "$out/exported.txt" 2>/dev/null || echo "none extracted")
\`\`\`

## apkleaks (top hits)
\`\`\`
$(head -50 "$out/apkleaks.json" 2>/dev/null || echo "no output")
\`\`\`

## Next steps
\`\`\`bash
# Intercept TLS:
alab proxy-on
alab unpin-full $pkg

# Or just SSL:
alab unpin-frida $pkg

# Hook URLs at runtime:
frida -U -n $pkg -e 'Java.perform(()=>{var URL=Java.use("java.net.URL");URL.\$init.overload("java.lang.String").implementation=function(u){console.log("[URL]",u);return this.\$init(u);}})'

# Pull app data after exercise:
alab pull-data $pkg

# Search decompiled sources:
alab grep $pkg "(api[_-]?key|secret|jwt|token)"
\`\`\`

---
*Generated by alab hunt mode · developed by hits · built by human + AI (Opus 4.6)*
EOF
  ok "Report: ${W}$out/REPORT.md${RESET}"
  echo ""
  command -v less >/dev/null && less -F -X "$out/REPORT.md" || cat "$out/REPORT.md"
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
  snapshot)      cmd_snapshot "$@" ;;
  doctor)        cmd_doctor ;;
  version|-v|--version)  cmd_version ;;
  frida-sync)    cmd_frida_sync ;;
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
  certs)         cmd_certs ;;
  unpin)         cmd_unpin "$@" ;;
  unpin-frida)   cmd_unpin_frida "$@" ;;
  unpin-full)    cmd_unpin_full "$@" ;;
  install)       cmd_install "$@" ;;
  pull-apk)      cmd_pull_apk "$@" ;;
  decompile)     cmd_decompile "$@" ;;
  strings)       cmd_strings "$@" ;;
  manifest)      cmd_manifest "$@" ;;
  grep)          cmd_grep "$@" ;;
  hunt)          cmd_hunt "$@" ;;
  screenshot)    cmd_screenshot ;;
  logcat)        cmd_logcat "$@" ;;
  pull-data)     cmd_pull_data "$@" ;;
  activities)    cmd_activities "$@" ;;
  launch)        cmd_launch "$@" ;;
  status)        cmd_status ;;
  ""|help|-h|--help) usage ;;
  *)             err "Unknown command: $1"; usage; exit 1 ;;
esac
