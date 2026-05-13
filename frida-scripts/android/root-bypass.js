/*
 * alab · android/root-bypass.js
 *
 * Comprehensive Android root-detection bypass.
 * Covers: RootBeer, su binary check, busybox, Magisk path, build tags,
 *         test-keys, Superuser.apk, dangerous props, SafetyNet basic.
 *
 * Usage:   frida -U -f com.target.app -l root-bypass.js --no-pause
 *
 * Adapted from public-domain patterns documented in:
 *   - iddoeldor/frida-snippets             https://github.com/iddoeldor/frida-snippets
 *   - sensepost/objection (root-disable)   https://github.com/sensepost/objection
 *   - WithSecureLabs / android-keystore    https://github.com/WithSecureLabs/android-keystore-audit
 *   - Areizen/Android-Application-Pentest  https://github.com/Areizen/Android-Application-Pentest-Roadmap
 */

Java.perform(function () {
    var C = '[root-bypass]';

    // ── 1 · java.io.File.exists()  on known root paths ────────────
    var rootPaths = [
        '/system/app/Superuser.apk', '/sbin/su', '/system/bin/su',
        '/system/xbin/su', '/data/local/xbin/su', '/data/local/bin/su',
        '/system/sd/xbin/su', '/system/bin/failsafe/su', '/data/local/su',
        '/su/bin/su', '/system/etc/init.d/99SuperSUDaemon',
        '/dev/com.koushikdutta.superuser.daemon/',
        '/system/xbin/busybox', '/system/xbin/daemonsu',
        '/sbin/.magisk', '/cache/.disable_magisk', '/dev/.magisk.unblock',
        '/cache/magisk.log', '/data/adb/magisk', '/data/adb/modules',
        '/data/adb/magisk.db', '/init.magisk.rc'
    ];

    var File = Java.use('java.io.File');
    File.exists.implementation = function () {
        var name = this.getAbsolutePath();
        if (rootPaths.indexOf(name) !== -1) {
            console.log(C, 'hide ' + name);
            return false;
        }
        return this.exists.call(this);
    };

    // ── 2 · Runtime.exec("su" / "which su" / "mount") ─────────────
    var Runtime = Java.use('java.lang.Runtime');
    var execOverloads = ['java.lang.String', '[Ljava.lang.String;'];
    execOverloads.forEach(function (sig) {
        Runtime.exec.overload(sig).implementation = function (cmd) {
            var s = (typeof cmd === 'string') ? cmd : cmd.join(' ');
            if (/\b(su|which|mount|magisk|busybox)\b/.test(s)) {
                console.log(C, 'block exec → ' + s);
                return this.exec.overload(sig).call(this, 'echo');
            }
            return this.exec.overload(sig).call(this, cmd);
        };
    });

    // ── 3 · ProcessBuilder ─────────────────────────────────────────
    try {
        var PB = Java.use('java.lang.ProcessBuilder');
        PB.start.implementation = function () {
            var cmd = this.command.call(this).toString();
            if (/\b(su|which|mount|magisk|busybox)\b/.test(cmd)) {
                console.log(C, 'block ProcessBuilder → ' + cmd);
                this.command.overload('java.util.List').call(this,
                    Java.use('java.util.Arrays').asList(['echo']));
            }
            return this.start.call(this);
        };
    } catch (e) { }

    // ── 4 · System.getProperty("ro.build.tags") ───────────────────
    var SystemProp = Java.use('java.lang.System');
    SystemProp.getProperty.overload('java.lang.String').implementation = function (k) {
        if (k === 'ro.build.tags' || k === 'ro.debuggable' || k === 'ro.secure') {
            console.log(C, 'spoof getProperty(' + k + ')');
            if (k === 'ro.build.tags') return 'release-keys';
            if (k === 'ro.secure') return '1';
            if (k === 'ro.debuggable') return '0';
        }
        return this.getProperty.call(this, k);
    };

    // ── 5 · android.os.Build constants ─────────────────────────────
    try {
        var Build = Java.use('android.os.Build');
        Build.TAGS.value = 'release-keys';
        Build.FINGERPRINT.value = 'google/sdk_gphone_x86/generic_x86:13/TQ3A.230805.001/10316531:user/release-keys';
    } catch (e) { }

    // ── 6 · RootBeer (popular root-check lib) ─────────────────────
    try {
        var RB = Java.use('com.scottyab.rootbeer.RootBeer');
        ['isRooted','isRootedWithoutBusyBoxCheck','detectRootManagementApps',
         'detectPotentiallyDangerousApps','detectTestKeys','checkForBusyBoxBinary',
         'checkForSuBinary','checkSuExists','checkForRWPaths','checkForDangerousProps',
         'checkForRootNative','detectRootCloakingApps'].forEach(function (m) {
            try {
                RB[m].implementation = function () {
                    console.log(C, 'RootBeer.' + m + ' → false');
                    return false;
                };
            } catch (e) { }
        });
    } catch (e) { /* lib not present */ }

    // ── 7 · PackageManager.getInstalledPackages / getPackageInfo ──
    var rootPkgs = [
        'com.noshufou.android.su','com.thirdparty.superuser','eu.chainfire.supersu',
        'com.koushikdutta.superuser','com.zachspong.temprootremovejb','com.ramdroid.appquarantine',
        'com.topjohnwu.magisk','com.kingroot.kinguser','com.kingo.root','com.smedialink.oneclickroot',
        'com.zhiqupk.root.global','com.alephzain.framaroot'
    ];
    var ApplicationPackageManager;
    try {
        ApplicationPackageManager = Java.use('android.app.ApplicationPackageManager');
        ApplicationPackageManager.getPackageInfo.overload('java.lang.String', 'int')
          .implementation = function (pkg, flags) {
            if (rootPkgs.indexOf(pkg) !== -1) {
                console.log(C, 'hide pkg ' + pkg);
                throw Java.use('android.content.pm.PackageManager$NameNotFoundException').$new(pkg);
            }
            return this.getPackageInfo.call(this, pkg, flags);
        };
    } catch (e) { }

    // ── 8 · SafetyNet basic — return ctsProfileMatch=true ─────────
    try {
        var SNApi = Java.use('com.google.android.gms.safetynet.SafetyNetApi$AttestationResult');
        SNApi.getJwsResult.implementation = function () {
            console.log(C, 'SafetyNet getJwsResult — returning forged token (basic)');
            // header.payload.sig — payload claims ctsProfileMatch:true
            return 'eyJhbGciOiJSUzI1NiJ9.eyJjdHNQcm9maWxlTWF0Y2giOnRydWUsImJhc2ljSW50ZWdyaXR5Ijp0cnVlfQ.';
        };
    } catch (e) { }

    console.log(C, 'root-detection hooks installed.');
});
