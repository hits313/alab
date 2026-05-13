// Universal Android SSL Unpinning — covers OkHttp3, TrustManager, HttpsURLConnection, WebViewClient
// Usage: frida -U -f com.target.app -l universal-ssl-unpin.js --no-pause

setTimeout(function() {
  Java.perform(function() {
    console.log("[*] SSL Unpinning starting...");

    // 1. TrustManager: trust all certs
    var TrustManager = Java.registerClass({
      name: "com.sslunpin.TrustAll",
      implements: [Java.use("javax.net.ssl.X509TrustManager")],
      methods: {
        checkClientTrusted: function(chain, authType) {},
        checkServerTrusted: function(chain, authType) {},
        getAcceptedIssuers: function() { return []; }
      }
    });

    var SSLContext = Java.use("javax.net.ssl.SSLContext");
    var TrustManagers = [TrustManager.$new()];
    var sslContext = SSLContext.getInstance("TLS");
    sslContext.init(null, TrustManagers, null);
    SSLContext.getDefault.overload().implementation = function() { return sslContext; };
    console.log("[+] TrustManager bypassed");

    // 2. OkHttp3 CertificatePinner
    try {
      var CertPinner = Java.use("okhttp3.CertificatePinner");
      CertPinner.check.overload("java.lang.String", "java.util.List").implementation = function(h, c) {
        console.log("[+] OkHttp3 pin check bypassed: " + h);
      };
      CertPinner.check.overload("java.lang.String", "[Ljava.security.cert.Certificate;").implementation = function(h, c) {};
    } catch(e) {}

    // 3. HttpsURLConnection HostnameVerifier
    try {
      var HV = Java.use("javax.net.ssl.HttpsURLConnection");
      HV.setDefaultHostnameVerifier.implementation = function(v) {};
      HV.setHostnameVerifier.implementation = function(v) {};
    } catch(e) {}

    // 4. WebViewClient SSL errors
    try {
      var WVC = Java.use("android.webkit.WebViewClient");
      WVC.onReceivedSslError.overload("android.webkit.WebView","android.webkit.SslErrorHandler","android.net.http.SslError").implementation = function(view, handler, error) {
        handler.proceed();
        console.log("[+] WebView SSL error bypassed");
      };
    } catch(e) {}

    // 5. NetworkSecurityTrustManager (Android 7+)
    try {
      var NSTM = Java.use("android.security.net.config.NetworkSecurityTrustManager");
      NSTM.checkPins.implementation = function(chain) { console.log("[+] NetworkSecurity checkPins bypassed"); };
    } catch(e) {}

    // 6. TrustKit
    try {
      var TK = Java.use("com.datatheorem.android.trustkit.pinning.OkHostnameVerifier");
      TK.verify.overload("java.lang.String","javax.net.ssl.SSLSession").implementation = function(h, s) { return true; };
    } catch(e) {}

    console.log("[+] SSL Unpinning complete.");
  });
}, 0);
