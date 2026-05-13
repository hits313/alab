# alab — Android Pentest Lab

**v2.0** · Pixel 6 · API 33 · Magisk 25.2 + Zygisk · Frida 17.2.14 · KVM-accelerated · zero-Studio

```
  ██████╗ ██╗      █████╗ ██████╗
  ██╔══██╗██║     ██╔══██╗██╔══██╗
  ███████║██║     ███████║██████╔╝
  ██╔══██║██║     ██╔══██║██╔══██╗
  ██║  ██║███████╗██║  ██║██████╔╝
  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝
```

A no-bullshit Android pentesting framework. One command boots a rooted Pixel 6 emulator with Magisk + Zygisk + DenyList, pushes Frida, installs the Burp CA as a system cert, routes traffic through Burp, and exposes a clean CLI for unpinning, decompiling, and intercepting any APK.

> *Developed by hits · built by human + AI (Opus 4.6)*

---

## 1 · Requirements

| Component   | Minimum                                  | Notes                                          |
|-------------|------------------------------------------|------------------------------------------------|
| OS          | Linux / macOS / Windows (WSL2 or native) | All three covered below                        |
| CPU         | x86_64 with VT-x/AMD-V (or Apple Silicon)| Hardware virtualization mandatory              |
| RAM         | 8 GB system                              | AVD uses 3 GB, Burp + Frida add ~1 GB          |
| Disk        | 25 GB free                               | SDK ~6 GB · system image ~5 GB · AVD ~10 GB    |
| Python      | 3.10+                                    | for Frida tools, objection, apkleaks           |
| Java        | OpenJDK 17                               | for jadx, apktool                              |
| Burp Suite  | Community or Pro                         | needed for proxy + cert export                 |
| Node.js     | 20+ (only for CLI agents)                | Claude Code / Gemini CLI                       |

---

## 2 · Install — Linux

Tested on Ubuntu 22.04 / Pop!_OS / Debian 12. Other distros adjust `apt` → `dnf`/`pacman`.

### 2.1 · Pre-flight

```bash
ls /dev/kvm                          # must exist
egrep -c '(vmx|svm)' /proc/cpuinfo   # > 0
free -g                              # ≥ 8
df -h ~                              # ≥ 25 G
```

If `/dev/kvm` is missing:

```bash
sudo apt install qemu-kvm libvirt-daemon-system
sudo usermod -aG kvm,libvirt $USER
# log out / log in
```

### 2.2 · System packages

```bash
sudo apt update
sudo apt install -y \
  openjdk-17-jdk python3-pip python3-venv \
  qemu-kvm adb scrcpy unzip wget curl git \
  apktool sqlite3 openssl
```

### 2.3 · Android SDK (cmdline-tools only — no Studio)

```bash
mkdir -p ~/Android/Sdk/cmdline-tools && cd /tmp
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip
mv cmdline-tools ~/Android/Sdk/cmdline-tools/latest

export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH

yes | sdkmanager --licenses
sdkmanager "platform-tools" "emulator" "platforms;android-33" \
           "system-images;android-33;google_apis;x86_64"
```

> **Critical:** use `google_apis`, **not** `google_apis_playstore`. PlayStore images block `adb root`.

### 2.4 · Create AVD

```bash
echo "no" | avdmanager create avd \
  -n Pixel6_API33_root \
  -k "system-images;android-33;google_apis;x86_64" \
  -d "pixel_6"

AVD=~/.android/avd/Pixel6_API33_root.avd/config.ini
sed -i 's/^hw.ramSize=.*/hw.ramSize=3072/' $AVD
sed -i 's/^hw.cpu.ncore=.*/hw.cpu.ncore=6/' $AVD
echo "disk.dataPartition.size=4096M" >> $AVD
```

### 2.5 · Frida + tooling

```bash
pip install --user frida-tools==17.2.14 objection apkleaks androguard

mkdir -p ~/tools/android-lab/frida && cd ~/tools/android-lab/frida
wget https://github.com/frida/frida/releases/download/17.2.14/frida-server-17.2.14-android-x86_64.xz
xz -d frida-server-*.xz && mv frida-server-* frida-server && chmod +x frida-server
```

### 2.6 · jadx + dex2jar + Magisk

```bash
cd ~/tools/android-lab
wget https://github.com/skylot/jadx/releases/download/v1.5.0/jadx-1.5.0.zip
unzip jadx-1.5.0.zip -d jadx

wget https://github.com/pxb1988/dex2jar/releases/download/v2.4/dex-tools-v2.4.zip
unzip dex-tools-v2.4.zip -d dex2jar

mkdir -p magisk && cd magisk
wget -O Magisk-v28.1.apk https://github.com/topjohnwu/Magisk/releases/download/v28.1/Magisk-v28.1.apk
```

### 2.7 · Clone alab + shell aliases

```bash
git clone https://github.com/hits313/alab.git ~/tools/android-lab/alab
cp ~/tools/android-lab/alab/start-lab.sh ~/tools/android-lab/
chmod +x ~/tools/android-lab/start-lab.sh
```

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export PATH=$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$HOME/.local/bin:$HOME/tools/android-lab/jadx/bin:$PATH

alias alab='bash ~/tools/android-lab/start-lab.sh'
```

Reload: `source ~/.zshrc`

---

## 3 · Install — macOS

Tested on macOS 14 Sonoma (Apple Silicon + Intel). HVF replaces KVM — works out of the box.

### 3.1 · Homebrew base

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install openjdk@17 python@3.11 wget unzip git \
             android-platform-tools scrcpy sqlite openssl@3
brew install --cask android-commandlinetools

sudo ln -sfn $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk \
             /Library/Java/JavaVirtualMachines/openjdk-17.jdk
```

### 3.2 · Android SDK

```bash
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
mkdir -p $ANDROID_SDK_ROOT
export PATH=$(brew --prefix android-commandlinetools)/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH

yes | sdkmanager --licenses
# Apple Silicon → arm64-v8a · Intel → x86_64
ARCH=$(uname -m); [[ "$ARCH" == "arm64" ]] && IMG="arm64-v8a" || IMG="x86_64"
sdkmanager "platform-tools" "emulator" "platforms;android-33" \
           "system-images;android-33;google_apis;$IMG"
```

### 3.3 · Create AVD

```bash
echo "no" | avdmanager create avd \
  -n Pixel6_API33_root \
  -k "system-images;android-33;google_apis;$IMG" \
  -d "pixel_6"
```

### 3.4 · Frida + tooling

```bash
pip3 install --user frida-tools==17.2.14 objection apkleaks androguard

# frida-server — match device arch (emulator is host arch)
mkdir -p ~/tools/android-lab/frida && cd ~/tools/android-lab/frida
ARCH=$(uname -m); [[ "$ARCH" == "arm64" ]] && FA="arm64" || FA="x86_64"
wget https://github.com/frida/frida/releases/download/17.2.14/frida-server-17.2.14-android-$FA.xz
xz -d frida-server-*.xz && mv frida-server-* frida-server && chmod +x frida-server
```

### 3.5 · Clone alab + zshrc aliases

```bash
mkdir -p ~/tools && git clone https://github.com/hits313/alab.git ~/tools/android-lab
chmod +x ~/tools/android-lab/start-lab.sh

cat >> ~/.zshrc <<'EOF'
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$HOME/.local/bin:$HOME/tools/android-lab/jadx/bin:$PATH
alias alab='bash ~/tools/android-lab/start-lab.sh'
EOF
source ~/.zshrc
```

### macOS gotchas

- **Apple Silicon**: use the `arm64-v8a` system image — `x86_64` runs at 5% speed under Rosetta.
- **HVF**: hardware acceleration is automatic, no `/dev/kvm` setup needed.
- **adb auth dialog**: first launch shows "Allow USB debugging" — accept once.

---

## 4 · Install — Windows

Two paths. WSL2 is **strongly recommended** — it's just the Linux flow with one extra step. Native is supported but bumpier.

### 4.1 · Option A — WSL2 (recommended)

```powershell
# in elevated PowerShell
wsl --install -d Ubuntu-22.04
wsl --update
```

Then **inside WSL2**, follow the Linux flow (§2). One extra detail:

```bash
# WSL2 needs explicit KVM passthrough for the emulator
# Enable Hyper-V on the Windows side then in WSL2:
sudo apt install -y qemu-kvm
ls /dev/kvm   # should exist on WSL2 kernel 5.10+
```

`adb` from WSL2 talks to the AVD running inside WSL2 — no Windows bridge needed. To use Burp on Windows + AVD in WSL2:

```bash
# WSL2 IP from inside WSL
ip route show | grep default | awk '{print $3}'   # → 172.x.x.1 = Windows host
# point AVD proxy at this IP, listen Burp on 0.0.0.0:8080
```

### 4.2 · Option B — Native Windows

```powershell
# Install prerequisites with winget
winget install -e --id EclipseAdoptium.Temurin.17.JDK
winget install -e --id Python.Python.3.11
winget install -e --id Git.Git
winget install -e --id 7zip.7zip
```

Download cmdline-tools and unzip to `C:\Android\Sdk\cmdline-tools\latest\`:

```
https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip
```

Set env vars (System Properties → Environment Variables):

```
ANDROID_SDK_ROOT  =  C:\Android\Sdk
PATH              +=  C:\Android\Sdk\cmdline-tools\latest\bin
PATH              +=  C:\Android\Sdk\platform-tools
PATH              +=  C:\Android\Sdk\emulator
```

In a **new** PowerShell:

```powershell
sdkmanager --licenses
sdkmanager "platform-tools" "emulator" "platforms;android-33" `
           "system-images;android-33;google_apis;x86_64"

echo no | avdmanager create avd -n Pixel6_API33_root `
  -k "system-images;android-33;google_apis;x86_64" -d "pixel_6"
```

Python tools:

```powershell
py -m pip install --user frida-tools==17.2.14 objection apkleaks androguard
```

Download frida-server, jadx, Magisk into `C:\tools\android-lab\` (mirror the Linux layout). Clone alab repo:

```powershell
git clone https://github.com/hits313/alab.git C:\tools\android-lab
```

`start-lab.sh` is bash — on native Windows use **Git Bash** to run it:

```bash
# in Git Bash
alias alab='bash /c/tools/android-lab/start-lab.sh'
alab start
```

### Windows gotchas

- **Hyper-V vs HAXM**: Windows 11 → Hyper-V (built-in). Older Windows 10 → install Intel HAXM via SDK manager.
- **`adb root` fails**: same rule — `google_apis`, never `playstore`.
- **Path separators**: Git Bash translates `~` and `/c/` correctly; cmd.exe does not.
- **antivirus**: Windows Defender may flag `frida-server.exe` and Magisk APK. Allow-list `C:\tools\android-lab\`.

---

## 5 · Quick Start (all platforms)

```bash
alab start          # boot AVD · auto-root · proxy · zygisk
alab setup          # full chain: root + frida + burp-cert + proxy
alab status         # device · root · magisk · frida · proxy
alab stop           # kill emulator
```

### Burp wiring (one-time)

1. Burp → Proxy → Proxy settings → Import/Export CA → **DER format**
2. Save to `~/tools/android-lab/burp/cacert.der`
3. `alab burp-cert` (converts → pushes as system cert → reboots)
4. `alab proxy-on`

All HTTP/S now flows through Burp. No app-level proxy. No user-store cert dance.

---

## 6 · Command Reference

### Boot
| Command          | Action                                                    |
|------------------|-----------------------------------------------------------|
| `alab start`     | Boot AVD, auto root, proxy on, zygisk on, denylist on     |
| `alab stop`      | Kill emulator                                             |
| `alab screen`    | scrcpy mirror (1080p, screen-off on host)                 |

### Root / Magisk
| Command                       | Action                                          |
|-------------------------------|-------------------------------------------------|
| `alab root`                   | `adb root` + remount /system                    |
| `alab setup`                  | Root + frida + proxy + magisk in one shot       |
| `alab magisk`                 | Show daemon version + denylist status           |
| `alab denylist`               | Enable Zygisk + DenyList via sqlite3            |
| `alab denylist-add com.x.y`   | Add package to DenyList                         |
| `alab denylist-ls`            | List all DenyList entries                       |

### Intercept
| Command          | Action                                                    |
|------------------|-----------------------------------------------------------|
| `alab frida`     | Push + start frida-server on device                       |
| `alab frida-stop`| Kill frida-server                                         |
| `alab burp-cert` | Install Burp CA as system cert + reboot                   |
| `alab proxy-on`  | Route all device traffic → Burp 10.0.2.2:8080             |
| `alab proxy-off` | Clear proxy                                               |

### SSL Unpin
| Command                          | Action                                       |
|----------------------------------|----------------------------------------------|
| `alab unpin com.bank.app`        | objection spawn + `android sslpinning disable` |
| `alab unpin-frida com.bank.app`  | Frida universal unpin (OkHttp3, TrustKit, TM) |

### APK
| Command                       | Action                                          |
|-------------------------------|-------------------------------------------------|
| `alab install app.apk`        | adb install -r                                  |
| `alab pull-apk com.x.y`       | Pull installed APK from device                  |
| `alab decompile app.apk`      | jadx → `/tmp/jadx-<name>/`                      |
| `alab strings app.apk`        | apkleaks — secrets + endpoints                  |
| `alab manifest app.apk`       | Dump decoded AndroidManifest.xml                |

### Device
| Command                        | Action                                         |
|--------------------------------|------------------------------------------------|
| `alab screenshot`              | Save → `/tmp/screen.png` + open viewer          |
| `alab logcat com.x.y`          | Live logcat filtered by package                |
| `alab pull-data com.x.y`       | Pull `/data/data/<pkg>` → `/tmp/appdata-<pkg>` |
| `alab activities com.x.y`      | List activities + exported flag                |
| `alab launch com.pkg/.Main`    | `am start -n <component>`                      |
| `alab status`                  | Full status panel                              |

---

## 7 · Attaching a CLI Agent — Claude Code / Gemini

The lab is fully scriptable. Both Claude Code and Gemini CLI can drive `alab` end-to-end — recon, root, unpin, decompile, intercept, report.

### 7.1 · Claude Code

```bash
npm i -g @anthropic-ai/claude-code
claude --version
cd ~/tools/android-lab && claude
```

Pre-grant alab permissions — drop this into `~/tools/android-lab/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(alab *)",
      "Bash(adb *)",
      "Bash(frida *)",
      "Bash(frida-ps *)",
      "Bash(objection *)",
      "Bash(jadx *)",
      "Bash(apktool *)",
      "Bash(apkleaks *)"
    ]
  }
}
```

Sample prompts:

```
> Boot the lab, install /tmp/target.apk, decompile it, list all exported activities, and start frida-server.
> Pull SharedPreferences from com.target.app and look for hardcoded API keys or JWTs.
> Hook all java.net.URL constructors in com.target.app via Frida and dump them live.
> Run apkleaks on /tmp/target.apk and triage every hit into a P1/P2/P3 bucket.
```

### 7.2 · Gemini CLI

```bash
npm i -g @google/gemini-cli
gemini auth login
cd ~/tools/android-lab && gemini

> Use the alab framework at start-lab.sh — read it, understand the commands,
  then boot the emulator, install /tmp/target.apk, and decompile it with jadx.
```

YOLO / auto-approve (only on trusted alab targets): `gemini --yolo`

### 7.3 · Pro tip — feed the agent the doc

```bash
claude < ~/tools/android-lab/docs/ALAB-INSTALL.md
# or
gemini -p "$(cat ~/tools/android-lab/docs/ALAB-INSTALL.md) Now boot the lab and decompile /tmp/x.apk."
```

---

## 8 · Troubleshooting

| Issue                          | Fix                                                                    |
|--------------------------------|------------------------------------------------------------------------|
| Emulator slow / black screen   | KVM/HVF check · user in `kvm` group · `-gpu swangle` software fallback |
| `adb root` fails               | Image must be `google_apis`, not `google_apis_playstore`               |
| Frida version mismatch         | `frida --version` must == `frida-server` binary version                |
| Burp cert not trusted          | Re-run `alab burp-cert`; system cert install requires `-writable-system` |
| Proxy not intercepting         | Burp listener bound to `0.0.0.0:8080` (AVD uses `10.0.2.2`)            |
| App detects root → exits       | `alab denylist-add com.target.app` + objection root-disable hook       |
| `frida-ps -U` empty            | `alab frida` again — frida-server dies if device reboots               |
| TLS still blocked              | `alab unpin-frida <pkg>` — covers OkHttp3, TrustKit, TM, WebView, NSC  |
| Emulator won't start: lock file| `rm ~/.android/avd/Pixel6_API33_root.avd/hardware-qemu.ini.lock`       |
| WSL2 `/dev/kvm` missing        | Enable Hyper-V on Windows + `sudo apt install qemu-kvm` in WSL          |
| macOS Apple Silicon slow       | Use `arm64-v8a` system image, never x86_64                              |

---

## 9 · Layout

```
~/tools/android-lab/
├── start-lab.sh                # alab dispatcher
├── unpin.sh                    # SSL unpin wrapper
├── magisk-root.sh              # Magisk install helper
├── frida/
│   └── frida-server            # arch-matched binary
├── frida-scripts/
│   └── universal-ssl-unpin.js  # OkHttp3 + TrustKit + TM + WebView + NSC
├── jadx/bin/jadx
├── dex2jar/dex2jar/d2j-dex2jar.sh
├── magisk/Magisk-v28.1.apk
├── burp/
│   ├── cacert.der              # exported from Burp
│   └── cacert.pem              # converted, auto-generated
├── apks/                       # drop targets here
└── docs/
    ├── ALAB-INSTALL.md         # this file
    └── ALAB-INSTALL.pdf
```

---

*alab v2.0 · developed by hits · built by human + AI (Opus 4.6) · zero-Studio Android pentest framework*
