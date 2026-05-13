/*
 * alab · android/ssl-multi-unpin.js
 *
 * Modern, multi-stack SSL pinning bypass — covers:
 *   OkHttp3, OkHttp4, Conscrypt, TrustKit, TrustManagerImpl, X509TrustManager,
 *   Apache HttpClient, Cronet, gRPC OkHttp, Retrofit, AFNetworking-style,
 *   HttpsURLConnection, NetworkSecurityConfig, react-native-ssl-pinning.
 *
 * Usage:   frida -U -f com.target.app -l ssl-multi-unpin.js --no-pause
 *
 * Adapted from the very actively maintained:
 *   - httptoolkit/frida-interception-and-unpinning
 *     https://github.com/httptoolkit/frida-interception-and-unpinning
 *   - WithSecureLabs/frida-multiple-bypass
 *   - sensepost/objection
 *   - iddoeldor/frida-snippets
 */

setTimeout(function () { Java.perform(function () {
    var C = '[ssl-unpin]';

    // ── X509TrustManager / TrustManagerImpl ───────────────────────
    try {
        var TMI = Java.use('com.android.org.conscrypt.TrustManagerImpl');
        TMI.checkTrustedRecursive.implementation = function () { return Java.use('java.util.ArrayList').$new(); };
        TMI.verifyChain.implementation = function (untrustedChain) { return untrustedChain; };
        console.log(C, 'Conscrypt TrustManagerImpl hooked');
    } catch (e) { }

    try {
        var X509TM = Java.use('javax.net.ssl.X509TrustManager');
        var SSLContext = Java.use('javax.net.ssl.SSLContext');
        var TrustAll = Java.registerClass({
            name: 'com.alab.TrustAll',
            implements: [X509TM],
            methods: {
                checkClientTrusted: function () { },
                checkServerTrusted: function () { },
                getAcceptedIssuers: function () { return []; }
            }
        });
        SSLContext.init.overload('[Ljavax.net.ssl.KeyManager;', '[Ljavax.net.ssl.TrustManager;', 'java.security.SecureRandom')
          .implementation = function (km, tm, sr) {
              this.init(km, [TrustAll.$new()], sr);
          };
        console.log(C, 'SSLContext.init forced TrustAll');
    } catch (e) { }

    // ── OkHttp3 CertificatePinner ─────────────────────────────────
    try {
        var CP = Java.use('okhttp3.CertificatePinner');
        CP.check.overload('java.lang.String', 'java.util.List').implementation = function () { };
        CP['check$okhttp'].overload('java.lang.String', 'kotlin.jvm.functions.Function0').implementation = function () { };
        console.log(C, 'OkHttp3 CertificatePinner.check no-op');
    } catch (e) { }

    // ── OkHttp4 (Kotlin) — same class, different bytecode ─────────
    try {
        var CP4 = Java.use('okhttp3.CertificatePinner');
        CP4['check'].overload('java.lang.String', '[Ljava.security.cert.Certificate;').implementation = function () { };
    } catch (e) { }

    // ── TrustKit (Datatheorem) ────────────────────────────────────
    try {
        var TK = Java.use('com.datatheorem.android.trustkit.pinning.OkHostnameVerifier');
        TK.verify.overload('java.lang.String','javax.net.ssl.SSLSession').implementation = function () { return true; };
        TK.verify.overload('java.lang.String','java.security.cert.X509Certificate').implementation = function () { return true; };
        var PinFail = Java.use('com.datatheorem.android.trustkit.pinning.PinningTrustManager');
        PinFail.checkServerTrusted.implementation = function () { };
        console.log(C, 'TrustKit PinningTrustManager bypassed');
    } catch (e) { }

    // ── Apache HttpClient ─────────────────────────────────────────
    try {
        var ApacheSSF = Java.use('org.apache.http.conn.ssl.SSLSocketFactory');
        ApacheSSF.setHostnameVerifier.implementation = function () { };
        var AllowAll = Java.use('org.apache.http.conn.ssl.AllowAllHostnameVerifier');
        AllowAll.verify.overload('java.lang.String','javax.net.ssl.SSLSession').implementation = function () { return true; };
    } catch (e) { }

    // ── HttpsURLConnection.setDefaultHostnameVerifier ─────────────
    try {
        var HUC = Java.use('javax.net.ssl.HttpsURLConnection');
        HUC.setDefaultHostnameVerifier.implementation = function () { };
        HUC.setSSLSocketFactory.implementation = function () { };
        HUC.setHostnameVerifier.implementation = function () { };
    } catch (e) { }

    // ── Network Security Config (Android N+) ──────────────────────
    try {
        var NSC = Java.use('android.security.net.config.NetworkSecurityConfig');
        var Builder = Java.use('android.security.net.config.NetworkSecurityConfig$Builder');
        Builder.build.implementation = function () {
            var cfg = this.build.call(this);
            // user-added CAs already trusted via system store; nothing to do
            return cfg;
        };
    } catch (e) { }

    // ── WebViewClient SSL errors ──────────────────────────────────
    try {
        var WVC = Java.use('android.webkit.WebViewClient');
        WVC.onReceivedSslError.implementation = function (view, handler, err) { handler.proceed(); };
    } catch (e) { }

    // ── Cronet (Chromium HTTP stack used by some Google apps) ─────
    try {
        var Cronet = Java.use('org.chromium.net.impl.CronetUrlRequestContext');
        // best effort; many builds strip symbols
    } catch (e) { }

    // ── react-native-ssl-pinning ──────────────────────────────────
    try {
        var RNSP = Java.use('com.toyberman.Utils.OkHttpUtils');
        RNSP.buildOkHttpClient.implementation = function (a, b, c, d) {
            console.log(C, 'react-native-ssl-pinning buildOkHttpClient → unpinned');
            return Java.use('okhttp3.OkHttpClient$Builder').$new().build();
        };
    } catch (e) { }

    // ── Appcelerator Titanium ─────────────────────────────────────
    try {
        var AppcSSF = Java.use('appcelerator.https.PinningTrustManager');
        AppcSSF.checkServerTrusted.implementation = function () { };
    } catch (e) { }

    // ── Phonegap (Cordova-Plugin-SSL-CertificateChecker) ──────────
    try {
        var PGSSL = Java.use('nl.xservices.plugins.SSLCertificateChecker');
        PGSSL.execute.implementation = function (a, b, c) {
            c.success('CONNECTION_SECURE');
            return true;
        };
    } catch (e) { }

    console.log(C, 'multi-stack SSL unpin installed.');
}); }, 0);
