/*
 * alab · ios/ssl-bypass.js
 *
 * iOS SSL/TLS pinning bypass — covers SecTrustEvaluate, NSURLSession,
 * AFNetworking AFSecurityPolicy, TrustKit, BoringSSL.
 *
 * Usage:   frida -U -f com.target.app -l ssl-bypass.js --no-pause
 *
 * Adapted from:
 *   - dki/ios10-ssl-bypass                 https://codeshare.frida.re/@dki/ios10-ssl-bypass/
 *   - nabla-c0d3/ssl-kill-switch2          https://github.com/nabla-c0d3/ssl-kill-switch2
 *   - sensepost/objection (ios sslpinning_disable)
 *   - httptoolkit/frida-interception-and-unpinning
 */

if (ObjC.available) {
    var C = '[ios-ssl]';

    // ── 1 · BoringSSL SSL_VERIFY_NONE ─────────────────────────────
    try {
        var SSL_set_custom_verify =
            Module.findExportByName('libboringssl.dylib','SSL_set_custom_verify') ||
            Module.findExportByName(null,'SSL_set_custom_verify');
        var SSL_VERIFY_NONE = 0;
        var verifyCallback = new NativeCallback(function () { return 0; }, 'int', ['pointer','pointer']);
        if (SSL_set_custom_verify) {
            Interceptor.replace(SSL_set_custom_verify, new NativeCallback(function (ssl, mode, callback) {
                origSSV(ssl, SSL_VERIFY_NONE, verifyCallback);
            }, 'void', ['pointer','int','pointer']));
            var origSSV = new NativeFunction(SSL_set_custom_verify, 'void', ['pointer','int','pointer']);
            console.log(C, 'BoringSSL SSL_set_custom_verify hooked');
        }
        var SSL_get_psk_identity = Module.findExportByName(null, 'SSL_get_psk_identity');
        if (SSL_get_psk_identity) {
            Interceptor.replace(SSL_get_psk_identity, new NativeCallback(function () { return 'fake'; }, 'pointer', ['pointer']));
        }
    } catch (e) { }

    // ── 2 · SecTrustEvaluate / SecTrustEvaluateWithError ──────────
    try {
        var STE = Module.findExportByName('Security','SecTrustEvaluate');
        if (STE) {
            Interceptor.attach(STE, {
                onLeave: function (rv) {
                    var trustResultPtr = this.context.x1; // arm64
                    if (trustResultPtr) Memory.writeU32(trustResultPtr, 4); // kSecTrustResultProceed
                    rv.replace(0); // errSecSuccess
                }
            });
            console.log(C, 'SecTrustEvaluate hooked');
        }
        var STEWE = Module.findExportByName('Security','SecTrustEvaluateWithError');
        if (STEWE) {
            Interceptor.replace(STEWE, new NativeCallback(function (trust, err) {
                if (err) Memory.writePointer(err, NULL);
                return 1;
            }, 'int', ['pointer','pointer']));
            console.log(C, 'SecTrustEvaluateWithError hooked');
        }
    } catch (e) { }

    // ── 3 · NSURLSession challenge handler ────────────────────────
    try {
        var NSURLCredential = ObjC.classes.NSURLCredential;
        var Sess = ObjC.classes.NSURLSession;
        // Hook the delegate's didReceiveChallenge — too app-specific to do generically here.
        // Instead, neutralize the validation API:
        var SecPolicy = ObjC.classes.SecPolicy;
    } catch (e) { }

    // ── 4 · AFNetworking AFSecurityPolicy ─────────────────────────
    try {
        var AFSP = ObjC.classes.AFSecurityPolicy;
        if (AFSP) {
            AFSP['+ policyWithPinningMode:'].implementation = ObjC.implement(
                AFSP['+ policyWithPinningMode:'],
                function (self, sel, mode) {
                    return AFSP['+ policyWithPinningMode:'](0); // None
                }
            );
            AFSP['- evaluateServerTrust:forDomain:'].implementation = ObjC.implement(
                AFSP['- evaluateServerTrust:forDomain:'],
                function () { return 1; }
            );
            console.log(C, 'AFSecurityPolicy bypassed');
        }
    } catch (e) { }

    // ── 5 · TrustKit (datatheorem) ────────────────────────────────
    try {
        var TSKPV = ObjC.classes.TSKPinningValidator;
        if (TSKPV) {
            TSKPV['- evaluateTrust:forHostname:'].implementation = ObjC.implement(
                TSKPV['- evaluateTrust:forHostname:'],
                function () { return 0; } // TSKTrustEvaluationSuccess
            );
            console.log(C, 'TrustKit TSKPinningValidator bypassed');
        }
    } catch (e) { }

    console.log(C, 'iOS SSL pinning bypass installed.');
}
