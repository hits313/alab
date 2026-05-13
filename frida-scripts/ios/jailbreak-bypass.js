/*
 * alab · ios/jailbreak-bypass.js
 *
 * Comprehensive iOS jailbreak-detection bypass.
 * Covers: file existence (/Applications/Cydia.app, /private/var/lib/apt/, ...),
 *         URL scheme (cydia://), fork()/system() probes, dyld inserts,
 *         common JB SDKs (IOSSecuritySuite, Trustkit's JB checks).
 *
 * Usage:   frida -U -f com.target.app -l jailbreak-bypass.js --no-pause
 *
 * Adapted from these well-known scripts:
 *   - dki/ios-fridantiroot                 https://codeshare.frida.re/@dki/ios10-ssl-bypass/
 *   - Areizen/iOS-Jailbreak-Detection      https://github.com/Areizen/iOS-Jailbreak-Detection-Bypass
 *   - sensepost/objection (ios jailbreak_bypass)
 */

if (ObjC.available) {
    var C = '[jb-bypass]';

    var jbPaths = [
        '/Applications/Cydia.app','/Applications/blackra1n.app','/Applications/FakeCarrier.app',
        '/Applications/Icy.app','/Applications/IntelliScreen.app','/Applications/MxTube.app',
        '/Applications/RockApp.app','/Applications/SBSettings.app','/Applications/WinterBoard.app',
        '/private/var/lib/apt/','/private/var/lib/cydia','/private/var/mobile/Library/SBSettings/Themes',
        '/private/var/stash','/private/var/tmp/cydia.log','/System/Library/LaunchDaemons/com.ikey.bbot.plist',
        '/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist','/usr/bin/sshd',
        '/usr/libexec/sftp-server','/usr/sbin/sshd','/etc/apt','/bin/bash','/bin/sh','/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/usr/libexec/cydia/firmware.sh','/var/cache/apt','/var/lib/apt','/var/lib/cydia',
        '/var/log/syslog','/var/tmp/cydia.log','/var/jb', '/jb'
    ];

    // ── 1 · NSFileManager.fileExistsAtPath: ───────────────────────
    var FM = ObjC.classes.NSFileManager;
    var origFEAP = FM['- fileExistsAtPath:'];
    Interceptor.attach(origFEAP.implementation, {
        onEnter: function (args) {
            this.path = new ObjC.Object(args[2]).toString();
            this.fake = jbPaths.indexOf(this.path) !== -1;
        },
        onLeave: function (retval) {
            if (this.fake) {
                console.log(C, 'hide ' + this.path);
                retval.replace(0);
            }
        }
    });

    // ── 2 · stat(), lstat(), access(), fopen() ────────────────────
    ['stat','lstat','access'].forEach(function (fn) {
        var ptr = Module.findExportByName(null, fn);
        if (ptr) {
            Interceptor.attach(ptr, {
                onEnter: function (args) {
                    this.p = Memory.readCString(args[0]);
                    this.fake = jbPaths.some(function (j) { return this.p && this.p.indexOf(j) === 0; }, this);
                },
                onLeave: function (rv) {
                    if (this.fake) {
                        console.log(C, fn + '(' + this.p + ') → -1');
                        rv.replace(-1);
                    }
                }
            });
        }
    });

    var fopenPtr = Module.findExportByName(null, 'fopen');
    if (fopenPtr) {
        Interceptor.attach(fopenPtr, {
            onEnter: function (args) {
                this.p = Memory.readCString(args[0]);
                this.fake = this.p && jbPaths.some(function (j) { return this.p.indexOf(j) === 0; }, this);
            },
            onLeave: function (rv) {
                if (this.fake) {
                    console.log(C, 'fopen(' + this.p + ') → NULL');
                    rv.replace(NULL);
                }
            }
        });
    }

    // ── 3 · UIApplication canOpenURL: cydia:// ────────────────────
    try {
        var UIApp = ObjC.classes.UIApplication;
        var orig = UIApp['- canOpenURL:'];
        Interceptor.attach(orig.implementation, {
            onEnter: function (args) {
                var url = new ObjC.Object(args[2]).absoluteString().toString();
                this.fake = /^cydia:|^sileo:|^zbra:|^undecimus:|^filza:|^activator:/i.test(url);
                if (this.fake) console.log(C, 'hide canOpenURL(' + url + ')');
            },
            onLeave: function (rv) { if (this.fake) rv.replace(0); }
        });
    } catch (e) { }

    // ── 4 · fork() / vfork() — JB detectors call to ensure failure ─
    ['fork','vfork'].forEach(function (fn) {
        var p = Module.findExportByName(null, fn);
        if (p) {
            Interceptor.replace(p, new NativeCallback(function () {
                console.log(C, fn + '() called → returning -1');
                return -1;
            }, 'int', []));
        }
    });

    // ── 5 · dyld inserted-library check (DYLD_INSERT_LIBRARIES) ───
    var getenv = Module.findExportByName(null, 'getenv');
    if (getenv) {
        Interceptor.attach(getenv, {
            onEnter: function (args) {
                this.k = Memory.readCString(args[0]);
                this.fake = this.k === 'DYLD_INSERT_LIBRARIES';
            },
            onLeave: function (rv) {
                if (this.fake) {
                    console.log(C, 'getenv(DYLD_INSERT_LIBRARIES) → NULL');
                    rv.replace(NULL);
                }
            }
        });
    }

    // ── 6 · _dyld_image_count + _dyld_get_image_name (MobileSubstrate scan) ─
    var dyldGetName = Module.findExportByName(null, '_dyld_get_image_name');
    if (dyldGetName) {
        Interceptor.attach(dyldGetName, {
            onLeave: function (rv) {
                try {
                    var name = Memory.readCString(rv);
                    if (name && /MobileSubstrate|substitute|libhooker|cycript|frida/i.test(name)) {
                        console.log(C, 'cloak dyld img: ' + name);
                        Memory.writeUtf8String(rv, '/usr/lib/libSystem.B.dylib');
                    }
                } catch (e) { }
            }
        });
    }

    // ── 7 · IOSSecuritySuite (popular JB-detect SDK) ──────────────
    try {
        var ISS = ObjC.classes.IOSSecuritySuite;
        if (ISS) {
            var sels = ['amIJailbroken','amIJailbrokenWithFailedChecks','amIDebugged','amIRunInEmulator'];
            sels.forEach(function (s) {
                if (ISS[s]) {
                    Interceptor.attach(ISS[s].implementation, {
                        onLeave: function (rv) { rv.replace(0); console.log(C, 'IOSSecuritySuite.' + s + ' → false'); }
                    });
                }
            });
        }
    } catch (e) { }

    console.log(C, 'iOS jailbreak-detection bypass installed.');
} else {
    console.log('[jb-bypass] not an ObjC runtime — abort.');
}
