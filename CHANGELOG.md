# Changelog

## v2.1.0 — 2026-05-14

### New commands

- **`alab hunt <pkg>`** — full-auto recon. Pulls APK(s) including splits, decompiles with jadx, dumps the manifest, runs apkleaks, enumerates exported components, and writes a structured `REPORT.md` to `$HUNT_DIR/<pkg>/` (default `~/hunt/<pkg>/`). One command, complete first pass on any installed app.
- **`alab doctor`** — environment health check. Verifies KVM, Java 17, Python 3.10+, adb, emulator, frida-tools, objection, jadx, apktool, apkleaks, scrcpy, AVD existence, frida-server binary, host↔server version sync, Burp listener on `127.0.0.1:8080`, disk space. Green ✔ / red ✘ with the exact remediation command per check.
- **`alab frida-sync`** — auto-detects host `frida-tools` version and device ABI, downloads the matching `frida-server` from GitHub Releases, extracts, makes executable, and updates the version pin in `start-lab.sh` so they never drift again.
- **`alab certs`** — lists system CA store count, confirms the Burp cert hash is installed, lists user-store CAs. Replaces a hardcoded hash check with one driven by the real cert that was installed.
- **`alab grep <pkg> <regex>`** — colorized grep across `/tmp/jadx-<pkg>/sources/`. Useful for `(api[_-]?key|secret|jwt|token|http[s]?://...)`.
- **`alab snapshot {save|load|list}`** — quick AVD state snapshot via `adb emu avd snapshot`. Saves you a 90-second reboot when you brick the device mid-test.
- **`alab unpin-full <pkg>`** — chains `root-bypass.js` + `rasp-bypass.js` + `ssl-multi-unpin.js` in one Frida invocation. The "if any single hook fails, try this" command.
- **`alab version`** — prints alab + frida + magisk + AVD names in one line.

### Bug fixes

- **Burp cert hash** — `cmd_status` used to hardcode `9a5ba575.0` which was only valid for one user's Burp install. Now persists the real hash to `~/tools/android-lab/burp/.cert-hash` at install time and reads from it.
- **`alab logcat <pkg>`** — when `pidof <pkg>` returned empty (app not running), the grep regex collapsed to `pkg|` and matched the entire logcat. Now warns + tag-filters when no PID, uses `--pid=` when running.
- **`alab pull-apk`** — modern apps ship as split APKs. `pm path` returns multiple lines; the old script silently grabbed only the first. Now detects splits and pulls all of them into `/tmp/<pkg>/`.
- **`alab install`** — now supports `install-multiple` for split APKs.
- **Tool availability checks** — `jadx`, `apkleaks`, `apktool`, `frida-server` binary, and `objection` are checked with `command -v` before invocation, with the exact pip/apt fix in the error message.
- **AVD lock file** — removed before every boot, not just sometimes.

### Quality of life

- **No-color auto-detect** — `NO_COLOR=1` env var or non-TTY output now drops ANSI codes. Makes `alab ... | grep` and CI usage sane.
- **Configurable via env** — `ANDROID_SDK_ROOT`, `ALAB_AVD`, `ALAB_BURP_HOST`, `ALAB_BURP_PORT`, `ALAB_FRIDA_VERSION`, `ALAB_HUNT_DIR` all override defaults.
- **`alab help`** / `alab` with no args prints the full menu.
- **bash + zsh completion** — `completions/alab.bash`. Tab-completes subcommands; for `hunt`/`pull-apk`/`logcat`/etc. tab-completes **live installed packages** off the device.
- **Unknown command** now errors clearly + prints usage instead of silently showing the banner.

### Docs

- **`frida-scripts/`** — full Android + iOS bypass bundle landed in v2.0; this release wires `hunt` and `unpin-full` to those scripts.
- **README** — `Frida Scripts` and `Credits` sections added.

---

## v2.0.0 — 2026-05-13

Initial public release.

- `start-lab.sh` dispatcher (boot · root · frida · burp · unpin · APK · device commands)
- Frida-scripts bundle:
  - Android: `root-bypass.js`, `rasp-bypass.js`, `ssl-multi-unpin.js`, `biometric-bypass.js`, `webview-debug.js`, `universal-ssl-unpin.js`
  - iOS: `jailbreak-bypass.js`, `ssl-bypass.js`, `anti-frida-bypass.js`
- Cross-platform install guide (Linux · macOS · Windows): `docs/ALAB-INSTALL.md`
- Aesthetic PDF: `docs/ALAB-Framework-Guide.pdf`
- README with badges, command table, credits to upstream Frida research
