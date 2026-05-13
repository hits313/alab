/*
 * alab · android/rasp-bypass.js
 *
 * RASP (Runtime Application Self-Protection) bypass bundle.
 * Covers: anti-debug, anti-emulator, anti-Frida, anti-Xposed, anti-tamper,
 *         anti-hook detection, signature checks, integrity checks.
 *
 * Usage:   frida -U -f com.target.app -l rasp-bypass.js --no-pause
 *
 * Adapted from:
 *   - FSecureLABS/frida-multiple-bypass    https://github.com/WithSecureLabs/android-keystore-audit
 *   - r0ysue/r0capture & Android-Security  https://github.com/r0ysue/AndroidSecurityStudy
 *   - Ch0pin/medusa                        https://github.com/Ch0pin/medusa
 *   - iddoeldor/frida-snippets             https://github.com/iddoeldor/frida-snippets
 */

Java.perform(function () {
    var C = '[rasp-bypass]';

    // ── 1 · android.os.Debug.isDebuggerConnected ──────────────────
    try {
        var Debug = Java.use('android.os.Debug');
        Debug.isDebuggerConnected.implementation = function () {
            console.log(C, 'isDebuggerConnected → false');
            return false;
        };
        Debug.waitingForDebugger.implementation = function () { return false; };
    } catch (e) { }

    // ── 2 · ApplicationInfo.flags &= ~FLAG_DEBUGGABLE ─────────────
    try {
        var AppInfo = Java.use('android.content.pm.ApplicationInfo');
        Object.defineProperty(AppInfo, 'flags', { value: 0 });
    } catch (e) { }

    // ── 3 · BuildConfig.DEBUG = false ─────────────────────────────
    try {
        var BuildConfig = Java.use('android.os.Build');
        BuildConfig.TYPE.value = 'user';
    } catch (e) { }

    // ── 4 · Anti-emulator — spoof build properties ────────────────
    var Build = Java.use('android.os.Build');
    var fakeProps = {
        FINGERPRINT: 'google/walleye/walleye:11/RP1A.201005.004.A1/6934943:user/release-keys',
        MODEL: 'Pixel 6', MANUFACTURER: 'Google', BRAND: 'google',
        DEVICE: 'oriole', PRODUCT: 'oriole', HARDWARE: 'oriole',
        BOARD: 'oriole', HOST: 'wphq16.hot.corp.google.com',
        TAGS: 'release-keys', TYPE: 'user'
    };
    Object.keys(fakeProps).forEach(function (k) {
        try { Build[k].value = fakeProps[k]; } catch (e) { }
    });

    // ── 5 · TelephonyManager — anti-emulator IMEI/IMSI/operator ───
    try {
        var TM = Java.use('android.telephony.TelephonyManager');
        TM.getDeviceId.overload().implementation = function () { return '358240051111110'; };
        TM.getSubscriberId.overload().implementation = function () { return '310260000000000'; };
        TM.getNetworkOperatorName.implementation = function () { return 'Verizon'; };
        TM.getSimOperatorName.implementation = function () { return 'Verizon'; };
        TM.getLine1Number.overload().implementation = function () { return ''; };
    } catch (e) { }

    // ── 6 · Anti-Frida — block /proc/self/maps reads for frida-* ──
    try {
        var FileReader = Java.use('java.io.FileReader');
        FileReader.$init.overload('java.io.File').implementation = function (f) {
            var p = f.getAbsolutePath();
            if (/\/proc\/(self|\d+)\/maps$/.test(p)) {
                console.log(C, 'cloak /proc/.../maps from Frida string scan');
            }
            return this.$init.call(this, f);
        };
    } catch (e) { }

    try {
        var BR = Java.use('java.io.BufferedReader');
        BR.readLine.overload().implementation = function () {
            var line = this.readLine.call(this);
            if (line && /frida|gum-js-loop|gmain|linjector|re\.frida\.server/i.test(line)) {
                return ''; // hide telltale lines
            }
            return line;
        };
    } catch (e) { }

    // ── 7 · Anti-Xposed — pretend Xposed not loaded ───────────────
    try {
        var ClassLoader = Java.use('java.lang.ClassLoader');
        ClassLoader.loadClass.overload('java.lang.String').implementation = function (name) {
            if (/de\.robv\.android\.xposed|XposedBridge|XposedHelpers|LSPosed/i.test(name)) {
                console.log(C, 'hide Xposed class lookup: ' + name);
                throw Java.use('java.lang.ClassNotFoundException').$new(name);
            }
            return this.loadClass.call(this, name);
        };
    } catch (e) { }

    // ── 8 · Signature / integrity — return original cert hash ─────
    try {
        var PackageInfo = Java.use('android.content.pm.PackageInfo');
        // Most apps just compare String.equals on hash — let it pass.
        // If signature check is custom, hook Signature.toCharsString:
        var Signature = Java.use('android.content.pm.Signature');
        Signature.toCharsString.implementation = function () {
            var orig = this.toCharsString.call(this);
            return orig; // log only; modify if app uses a hardcoded value:
            // return '3082030d308201f5a00302010202044a78c2d7300d06092a864886f70...';
        };
    } catch (e) { }

    // ── 9 · System.exit / Process.killProcess — block self-kill ───
    try {
        Java.use('java.lang.System').exit.implementation = function (code) {
            console.log(C, 'BLOCKED System.exit(' + code + ')');
        };
        Java.use('android.os.Process').killProcess.implementation = function (pid) {
            console.log(C, 'BLOCKED Process.killProcess(' + pid + ')');
        };
    } catch (e) { }

    // ── 10 · ptrace via libc (anti-debug) ─────────────────────────
    try {
        var ptracePtr = Module.findExportByName(null, 'ptrace');
        if (ptracePtr) {
            Interceptor.replace(ptracePtr, new NativeCallback(function () {
                console.log(C, 'native ptrace blocked');
                return 0;
            }, 'long', []));
        }
    } catch (e) { }

    // ── 11 · WebView SSL onReceivedSslError — accept all ──────────
    try {
        var WVClient = Java.use('android.webkit.WebViewClient');
        WVClient.onReceivedSslError.implementation = function (view, handler, err) {
            handler.proceed();
        };
    } catch (e) { }

    console.log(C, 'RASP bypasses installed (debug · emu · frida · xposed · ptrace).');
});
