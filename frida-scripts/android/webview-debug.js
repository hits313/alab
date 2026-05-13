/*
 * alab · android/webview-debug.js
 *
 * Force-enable WebView remote debugging on production builds.
 * After loading, open chrome://inspect on the host to see the WebView.
 *
 * Usage:   frida -U -f com.target.app -l webview-debug.js --no-pause
 *
 * Pattern from iddoeldor/frida-snippets · WithSecureLabs cheatsheets.
 */

Java.perform(function () {
    var C = '[webview-debug]';
    try {
        var WV = Java.use('android.webkit.WebView');
        WV.setWebContentsDebuggingEnabled.implementation = function (e) {
            console.log(C, 'WebView.setWebContentsDebuggingEnabled(true) forced');
            return this.setWebContentsDebuggingEnabled.call(this, true);
        };
        // Also flip after construction
        WV.$init.overloads.forEach(function (o) {
            o.implementation = function () {
                var ret = o.apply(this, arguments);
                this.getSettings().setJavaScriptEnabled(true);
                this.getSettings().setAllowFileAccess(true);
                this.getSettings().setAllowFileAccessFromFileURLs(true);
                this.getSettings().setAllowUniversalAccessFromFileURLs(true);
                WV.setWebContentsDebuggingEnabled(true);
                return ret;
            };
        });
        console.log(C, 'open chrome://inspect on the host to see WebViews.');
    } catch (e) { console.log(C, e); }
});
