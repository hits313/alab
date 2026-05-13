# Android Pentest Lab — Setup & Usage

## Stack
| Component | Version | Location |
|-----------|---------|----------|
| Android SDK | cmdline-tools 12.0 | `~/Android/Sdk/` |
| Emulator | Latest | `~/Android/Sdk/emulator/` |
| AVD | Pixel 6, Android 13 (API 33) | `~/.android/avd/Pixel6_API33_root.avd/` |
| System Image | google_apis x86_64 | `~/Android/Sdk/system-images/android-33/` |
| Frida | 17.2.14 | `~/tools/android-lab/frida/frida-server` |
| Frida Tools | 17.2.14 | `~/.local/bin/frida*` |
| objection | latest | `~/.local/bin/objection` |
| Magisk | v28.1 APK | `~/tools/android-lab/magisk/` |
| jadx | 1.5.0 | `~/tools/android-lab/jadx/` |
| dex2jar | v2.4 | `~/tools/android-lab/dex2jar/` |
| apktool | system | `/usr/bin/apktool` |
| apkleaks | latest | `~/.local/bin/apkleaks` |
| androguard | 4.1.3 | pip |

## AVD Config
- **CPU**: 6 cores (12th Gen i5-12450H, KVM accelerated)
- **RAM**: 3072 MB
- **Data partition**: 4096 MB
- **GPU**: host mode (hardware acceleration)
- **Root**: `adb root` works natively (google_apis image, non-PlayStore)

---

## Quick Start

```bash
# Launch emulator
alab start

# Full pentest setup (root + frida + burp-cert + proxy)
alab setup

# Individual commands
alab root        # enable root shell
alab frida       # push + start frida-server on device
alab proxy-on    # route all device traffic through Burp (127.0.0.1:8080)
alab proxy-off   # clear proxy
alab status      # show device + frida status
alab stop        # kill emulator
```

---

## Burp Suite Setup (one-time)

1. Open Burp → Proxy → Proxy settings → Import/Export CA Certificate
2. Export → **Certificate in DER format** → save to `~/tools/android-lab/burp/cacert.der`
3. Run: `alab burp-cert` — converts to PEM, pushes as system cert, reboots device
4. Run: `alab proxy-on`

After setup, all HTTP/S from the device goes through Burp. No app-level proxy needed.

---

## Magisk Full Root (optional, beyond adb root)

`adb root` is sufficient for Frida + Burp. Magisk adds:
- Root manager UI + app grants
- Module support (MagiskHide, LSPosed)

```bash
# With emulator running:
bash ~/tools/android-lab/magisk-root.sh

# In Magisk app on device:
# → Install → Direct Install → Reboot
```

---

## SSL Unpinning

### Method 1 — objection (easiest)
```bash
# Spawns app with SSL pinning disabled
objection --gadget com.target.app explore --startup-command "android sslpinning disable"
```

### Method 2 — universal Frida script
```bash
frida -U -f com.target.app -l ~/tools/android-lab/frida-scripts/universal-ssl-unpin.js --no-pause
```

### Method 3 — unpin.sh wrapper
```bash
~/tools/android-lab/unpin.sh com.target.app               # uses objection
~/tools/android-lab/unpin.sh com.target.app frida-universal  # uses frida script
```

Covers: OkHttp3 CertificatePinner, TrustManager, HttpsURLConnection, WebViewClient, NetworkSecurityPolicy, TrustKit.

---

## APK Analysis

```bash
# Decompile APK
jadx -d /tmp/jadx-out target.apk

# Extract + decode resources
apktool d target.apk -o /tmp/apktool-out

# Find secrets/endpoints
apkleaks -f target.apk

# DEX → JAR
~/tools/android-lab/dex2jar/dex2jar/d2j-dex2jar.sh classes.dex -o out.jar

# Androguard interactive
python3 -c "from androguard.misc import AnalyzeAPK; a,d,dx = AnalyzeAPK('target.apk'); print(a.get_activities())"
```

---

## Frida Recipes

```bash
# List running processes
frida-ps -U

# Attach to running app
frida -U com.target.app

# Spawn with script
frida -U -f com.target.app -l script.js --no-pause

# objection shell
objection --gadget com.target.app explore

# objection commands inside shell
android sslpinning disable
android root disable
android intent launch_activity com.target.app.MainActivity
memory list modules
android hooking list classes
android hooking watch class com.target.SomeClass
```

---

## ADB Cheatsheet

```bash
adb devices                           # list devices
adb root                              # restart as root
adb shell                             # root shell
adb install -r app.apk                # install APK
adb pull /data/data/com.target/       # pull app data
adb logcat | grep "com.target"        # filter logs
adb shell am start -n com.pkg/.Activity  # launch activity
adb shell dumpsys package com.target  # package info
adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png
```

---

## PATH (auto-loaded via ~/.zshrc)
```
~/Android/Sdk/platform-tools   → adb, fastboot
~/Android/Sdk/emulator         → emulator
~/Android/Sdk/cmdline-tools    → avdmanager, sdkmanager
~/.local/bin                   → frida, frida-ps, frida-trace, objection, apkleaks
~/tools/android-lab/jadx/bin   → jadx, jadx-gui
~/tools/android-lab/dex2jar    → d2j-dex2jar.sh
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Emulator slow | KVM must be enabled: `ls /dev/kvm` |
| `adb root` fails | Only works on `google_apis`, not `google_apis_playstore` |
| Frida version mismatch | `frida --version` on host must match `frida-server` on device |
| Burp cert not trusted | Run `alab burp-cert` then reboot |
| Proxy not intercepting | Confirm `alab proxy-on` + Burp listener on 0.0.0.0:8080 |
| App not interceptable | Need SSL unpin — run `alab frida` first, then use objection |
