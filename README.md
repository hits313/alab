<div align="center">

```
  ██████╗ ██╗      █████╗ ██████╗
  ██╔══██╗██║     ██╔══██╗██╔══██╗
  ███████║██║     ███████║██████╔╝
  ██╔══██║██║     ██╔══██║██╔══██╗
  ██║  ██║███████╗██║  ██║██████╔╝
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝
```

# alab — Android Pentest Framework

**Zero-Studio Android pentest lab. One command. Rooted. Pinned-cert-bypassed. Burp-piped.**

[![Linux](https://img.shields.io/badge/Linux-supported-success?logo=linux&logoColor=white)](#linux)
[![macOS](https://img.shields.io/badge/macOS-supported-success?logo=apple&logoColor=white)](#macos)
[![Windows](https://img.shields.io/badge/Windows-WSL2%20%2F%20native-success?logo=windows&logoColor=white)](#windows)
[![Frida](https://img.shields.io/badge/Frida-17.2.14-ff3366)](https://frida.re)
[![Magisk](https://img.shields.io/badge/Magisk-25.2%20%2B%20Zygisk-00ff88)](https://github.com/topjohnwu/Magisk)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

*developed by hits · built by human + AI (Opus 4.6)*

</div>

---

## What it does

`alab` boots a rooted Pixel 6 emulator (Android 13, API 33), pushes `frida-server`, installs the Burp CA as a **system cert**, routes all device traffic through Burp, and gives you a clean CLI to install/decompile/intercept any APK — **without Android Studio, without Genymotion, without VMware**.

```bash
$ alab start
[*] Starting Pixel6_API33_root...
[+] Emulator PID: 88421
[*] Waiting for device to boot...
[+] Device booted.
[*] Enabling root...
[+] Root: uid=0
[+] Proxy → Burp 10.0.2.2:8080
[+] Zygisk ON  ·  DenyList ON
[+] Ready. Run alab screen to mirror display.
```

---

## Features

- **One-command bring-up** — `alab start` → boots, roots, proxies, zygisks
- **System-cert Burp install** — TLS intercept with no app-level proxy
- **Magisk + Zygisk + DenyList** — pre-wired for root-detection-bypass
- **Universal SSL unpinning** — OkHttp3, TrustKit, TrustManager, WebView, NSC
- **APK toolchain** — jadx, apktool, dex2jar, apkleaks, androguard
- **Frida 17.2.14** — host tools + server binary pinned to matching version
- **CLI agent ready** — drop-in configs for Claude Code & Gemini CLI
- **Cross-platform** — Linux, macOS (Apple Silicon + Intel), Windows (WSL2 + native)

---

## Quick install

### Linux

```bash
git clone https://github.com/hits313/alab.git ~/tools/android-lab
cd ~/tools/android-lab && chmod +x start-lab.sh
# Follow §2 in docs/ALAB-INSTALL.md for SDK + AVD setup
echo "alias alab='bash ~/tools/android-lab/start-lab.sh'" >> ~/.zshrc && source ~/.zshrc
```

### macOS (Apple Silicon or Intel)

```bash
brew install openjdk@17 python@3.11 wget android-platform-tools scrcpy
git clone https://github.com/hits313/alab.git ~/tools/android-lab
# Follow §3 in docs/ALAB-INSTALL.md (note: arm64-v8a sysimg on Apple Silicon)
```

### Windows

**WSL2 (recommended):** `wsl --install -d Ubuntu-22.04`, then follow the Linux flow inside WSL.

**Native:** see §4 in [docs/ALAB-INSTALL.md](docs/ALAB-INSTALL.md) — winget + Git Bash.

📄 **Full install guide:** [docs/ALAB-INSTALL.md](docs/ALAB-INSTALL.md) · [docs/ALAB-Framework-Guide.pdf](docs/ALAB-Framework-Guide.pdf)

---

## Commands

| Phase     | Command                                | What it does                                |
|-----------|----------------------------------------|---------------------------------------------|
| Boot      | `alab start`                           | Boot AVD, auto-root, proxy on, zygisk on    |
| Boot      | `alab setup`                           | Full chain: root + frida + burp-cert + proxy|
| Boot      | `alab status`                          | Device · root · magisk · frida · proxy      |
| Intercept | `alab frida`                           | Push + start frida-server                   |
| Intercept | `alab burp-cert`                       | Install Burp CA as system cert + reboot     |
| Intercept | `alab proxy-on` / `proxy-off`          | Toggle Burp proxy                           |
| Unpin     | `alab unpin com.bank.app`              | objection SSL unpin                         |
| Unpin     | `alab unpin-frida com.bank.app`        | Frida universal SSL unpin                   |
| APK       | `alab install app.apk`                 | adb install -r                              |
| APK       | `alab decompile app.apk`               | jadx → `/tmp/jadx-<name>/`                  |
| APK       | `alab strings app.apk`                 | apkleaks — secrets + endpoints              |
| APK       | `alab manifest app.apk`                | Dump AndroidManifest.xml                    |
| Device    | `alab logcat com.x.y`                  | Filtered live logcat                        |
| Device    | `alab pull-data com.x.y`               | Pull `/data/data/<pkg>`                     |
| Magisk    | `alab denylist-add com.x.y`            | Hide root from package                      |

Run `alab` with no args for the full menu.

---

## Driving alab with a CLI agent

Both **Claude Code** and **Gemini CLI** can drive alab end-to-end. Sample workflow:

> *Boot the lab, install /tmp/target.apk, decompile it with jadx, list all exported activities, start frida-server, hook all `java.net.URL` constructors, and capture traffic through Burp.*

The agent sequences `alab` commands, parses decompiled output, writes Frida hooks, and drops findings into `~/hunt/<target>/`. Pre-grant permissions via `.claude/settings.json` — see §7 in the install guide.

---

## Stack

| Component       | Version        |
|-----------------|----------------|
| AVD             | Pixel 6 · Android 13 · API 33 · `google_apis` |
| Emulator accel  | KVM (Linux) · HVF (macOS) · Hyper-V (Windows) |
| Frida           | 17.2.14 host + server                          |
| objection       | latest                                         |
| jadx            | 1.5.0                                          |
| dex2jar         | v2.4                                           |
| apktool         | 2.5.0                                          |
| Magisk          | v28.1 + Zygisk + DenyList                      |
| Burp            | Community / Pro (system-cert install)          |

---

## Repo layout

```
alab/
├── start-lab.sh                # main dispatcher (the `alab` command)
├── unpin.sh                    # SSL unpin wrapper
├── magisk-root.sh              # Magisk install helper
├── frida-scripts/
│   └── universal-ssl-unpin.js  # OkHttp3 + TrustKit + TM + WebView + NSC
├── docs/
│   ├── ALAB-INSTALL.md         # full install + ops guide
│   └── ALAB-INSTALL.pdf        # dark-mode PDF
├── LICENSE
└── README.md
```

---

## Disclaimer

`alab` is for **authorized security testing only** — bug bounty programs (BBP) you are in-scope on, your own apps, CTF challenges, or penetration tests with written permission. Do not use this framework against systems you do not have authorization to test. The author is not responsible for misuse.

---

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center">

**developed by hits** · *built by human + AI (Opus 4.6)*

[install guide](docs/ALAB-INSTALL.md) · [PDF](docs/ALAB-Framework-Guide.pdf) · [issues](https://github.com/hits313/alab/issues)

</div>
