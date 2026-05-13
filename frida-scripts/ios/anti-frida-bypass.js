/*
 * alab · ios/anti-frida-bypass.js
 *
 * Counter common Frida-detection probes on iOS:
 *   - port 27042 scan (default frida-server port)
 *   - /usr/lib/frida-* dyld scan
 *   - sysctl PROC_TRACED check (anti-debug)
 *   - task_get_exception_ports check
 *
 * Usage:   frida -U -f com.target.app -l anti-frida-bypass.js --no-pause
 *
 * Adapted from:
 *   - jailbreak detection bypass research by Areizen, sensepost
 *   - Frida codeshare community scripts
 */

if (ObjC.available) {
    var C = '[anti-frida]';

    // ── 1 · sysctl P_TRACED clear ─────────────────────────────────
    var sysctl = Module.findExportByName(null, 'sysctl');
    if (sysctl) {
        var orig = new NativeFunction(sysctl, 'int', ['pointer','uint','pointer','pointer','pointer','int']);
        Interceptor.replace(sysctl, new NativeCallback(function (name, namelen, oldp, oldlenp, newp, newlen) {
            var ret = orig(name, namelen, oldp, oldlenp, newp, newlen);
            if (ret === 0 && oldp.isNull() === false) {
                // kinfo_proc.kp_proc.p_flag offset 32 typically
                try {
                    var flag = Memory.readU32(oldp.add(32));
                    if (flag & 0x800) { // P_TRACED
                        Memory.writeU32(oldp.add(32), flag & ~0x800);
                        console.log(C, 'cleared P_TRACED in sysctl');
                    }
                } catch (e) { }
            }
            return ret;
        }, 'int', ['pointer','uint','pointer','pointer','pointer','int']));
    }

    // ── 2 · connect() to 127.0.0.1:27042 → fail ──────────────────
    var connect = Module.findExportByName(null, 'connect');
    if (connect) {
        Interceptor.attach(connect, {
            onEnter: function (args) {
                var sa = args[1];
                try {
                    // sa_family on offset 1, port at offset 2-3 (network order)
                    var family = Memory.readU8(sa.add(1));
                    if (family === 2) { // AF_INET
                        var port = (Memory.readU8(sa.add(2)) << 8) | Memory.readU8(sa.add(3));
                        if (port === 27042 || port === 27043) {
                            console.log(C, 'block connect to frida port ' + port);
                            this.block = true;
                        }
                    }
                } catch (e) { }
            },
            onLeave: function (rv) { if (this.block) rv.replace(-1); }
        });
    }

    // ── 3 · dyld scan for frida modules ───────────────────────────
    var dyldGetName = Module.findExportByName(null, '_dyld_get_image_name');
    if (dyldGetName) {
        Interceptor.attach(dyldGetName, {
            onLeave: function (rv) {
                try {
                    var name = Memory.readCString(rv);
                    if (name && /frida|gum|gadget|substrate/i.test(name)) {
                        console.log(C, 'cloak dyld module ' + name);
                        Memory.writeUtf8String(rv, '/usr/lib/libSystem.B.dylib');
                    }
                } catch (e) { }
            }
        });
    }

    // ── 4 · task_get_exception_ports ──────────────────────────────
    var tgep = Module.findExportByName(null, 'task_get_exception_ports');
    if (tgep) {
        Interceptor.replace(tgep, new NativeCallback(function () { return 5; }, 'int', []));
        console.log(C, 'task_get_exception_ports → KERN_FAILURE');
    }

    console.log(C, 'iOS anti-Frida bypass installed.');
}
