# Frida Scripts

Curated, production-quality Frida scripts bundled with **alab**. Each file is annotated with the upstream techniques it draws from. All credit to the original researchers and projects below.

## Inventory

### Android — `frida-scripts/android/`

| Script | Purpose |
|---|---|
| `root-bypass.js` | Defeat root-detection: RootBeer, su binary, Magisk, build tags, SafetyNet basic |
| `rasp-bypass.js` | Anti-debug, anti-emulator, anti-Frida, anti-Xposed, integrity, ptrace, self-kill |
| `ssl-multi-unpin.js` | Multi-stack SSL unpin: OkHttp3/4, Conscrypt, TrustKit, NSC, RN, Cordova, Cronet |
| `biometric-bypass.js` | BiometricPrompt + FingerprintManager forced-success |
| `webview-debug.js` | Force `setWebContentsDebuggingEnabled(true)` for chrome://inspect |
| `universal-ssl-unpin.js` | Original alab SSL unpin (kept for backward-compat with `alab unpin-frida`) |

### iOS — `frida-scripts/ios/`

| Script | Purpose |
|---|---|
| `jailbreak-bypass.js` | File/URL-scheme/fork/dyld/IOSSecuritySuite JB-detection bypass |
| `ssl-bypass.js` | BoringSSL · SecTrustEvaluate · AFNetworking · TrustKit |
| `anti-frida-bypass.js` | sysctl P_TRACED, frida port 27042, dyld frida-* cloaking |

## Run

```bash
# Android — boot AVD, then spawn target with one or more scripts:
frida -U -f com.target.app \
  -l frida-scripts/android/root-bypass.js \
  -l frida-scripts/android/rasp-bypass.js \
  -l frida-scripts/android/ssl-multi-unpin.js \
  --no-pause

# iOS — assumes frida-server on jailbroken device or Frida.framework injected:
frida -U -f com.target.app \
  -l frida-scripts/ios/jailbreak-bypass.js \
  -l frida-scripts/ios/ssl-bypass.js \
  -l frida-scripts/ios/anti-frida-bypass.js \
  --no-pause
```

You can also load them through `objection`:

```bash
objection -g com.target.app explore \
  --startup-script frida-scripts/android/rasp-bypass.js
```

Or via the alab wrapper (auto-selects script bundles per platform):

```bash
alab unpin-frida com.target.app          # SSL only
alab unpin-frida com.target.app full     # SSL + root + RASP (one-liner)
```

---

## Credits & Upstream Sources

These scripts adapt techniques and patterns documented in the following public projects. If you use **alab**, please **star** the original repos — that's where the research lives.

| Project | URL | What we use |
|---|---|---|
| **iddoeldor / frida-snippets** | https://github.com/iddoeldor/frida-snippets | Snippet patterns for hooking, anti-debug, prop spoofing |
| **httptoolkit / frida-interception-and-unpinning** | https://github.com/httptoolkit/frida-interception-and-unpinning | Modern multi-stack SSL unpin (Conscrypt / RN / Cronet coverage) |
| **sensepost / objection** | https://github.com/sensepost/objection | Root-disable, SSL-disable, biometric-bypass agent patterns |
| **WithSecureLabs / android-keystore-audit** | https://github.com/WithSecureLabs/android-keystore-audit | Multi-bypass class techniques (was FSecureLABS) |
| **dki / ios10-ssl-bypass** | https://codeshare.frida.re/@dki/ios10-ssl-bypass/ | SecTrustEvaluate hook baseline for iOS |
| **nabla-c0d3 / ssl-kill-switch2** | https://github.com/nabla-c0d3/ssl-kill-switch2 | BoringSSL SSL_VERIFY_NONE pattern |
| **Areizen / iOS-Jailbreak-Detection-Bypass** | https://github.com/Areizen/iOS-Jailbreak-Detection-Bypass | iOS JB path lists, fork/dyld checks |
| **r0ysue / AndroidSecurityStudy** | https://github.com/r0ysue/AndroidSecurityStudy | RASP bypass research, native ptrace |
| **Ch0pin / medusa** | https://github.com/Ch0pin/medusa | Modular Android instrumentation patterns |
| **Areizen / Android-Application-Pentest-Roadmap** | https://github.com/Areizen/Android-Application-Pentest-Roadmap | Root-bypass coverage matrix |
| **Frida Codeshare community** | https://codeshare.frida.re | Community scripts for iOS/Android |

> If your work is reflected here and you'd like attribution adjusted, open an issue at https://github.com/hits313/alab/issues — credit will be updated immediately.

## License

Scripts authored for **alab** are MIT-licensed. Patterns drawn from the projects above retain their original licenses (predominantly MIT / Apache-2.0 / public-domain Frida-codeshare terms).
