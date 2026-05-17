.pragma library

// =============================================================================
//  API key read/write through the org.freedesktop.secrets DBus interface,
//  via the `secret-tool` CLI. Works against both KWallet and GNOME Keyring,
//  whichever is registered as the active Secret Service provider.
//
//  Attribute scheme:
//      service = me.dumke.kuma
//      key     = apikey
//
//  This file stays QML-free: callers inject an `executor` object with an
//  `exec(cmd, callback)` method. `callback(exitCode, stdout, stderr)`.
// =============================================================================

const SERVICE = "me.dumke.kuma";
const KEY = "apikey";
const LABEL = "Uptime Kuma API key";

function _shEscape(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function lookup(executor, callback) {
    const cmd = "secret-tool lookup service " + _shEscape(SERVICE) + " key " + _shEscape(KEY);
    executor.exec(cmd, function (exitCode, stdout, stderr) {
        if (exitCode === 0) {
            // secret-tool prints the secret without a trailing newline, but be lenient.
            callback(null, stdout.replace(/\r?\n$/, ""));
        } else if (exitCode === 1) {
            // Not found is not an error.
            callback(null, null);
        } else {
            callback(new Error(stderr || ("secret-tool exited with " + exitCode)), null);
        }
    });
}

function store(executor, value, callback) {
    if (value === null || value === undefined || value === "") {
        clear(executor, callback);
        return;
    }
    // Pipe via printf to keep the secret off the secret-tool argv. The printf
    // argv is still visible in /proc during the brief subprocess lifetime, but
    // anyone with /proc/$UID access already owns the keyring session.
    const cmd =
        "printf %s " + _shEscape(value) +
        " | secret-tool store --label=" + _shEscape(LABEL) +
        " service " + _shEscape(SERVICE) +
        " key " + _shEscape(KEY);
    executor.exec(cmd, function (exitCode, stdout, stderr) {
        if (exitCode === 0)
            callback(null);
        else
            callback(new Error(stderr || ("secret-tool exited with " + exitCode)));
    });
}

function clear(executor, callback) {
    const cmd = "secret-tool clear service " + _shEscape(SERVICE) + " key " + _shEscape(KEY);
    executor.exec(cmd, function (exitCode, stdout, stderr) {
        // secret-tool clear is idempotent — exit 0 even if nothing matched.
        if (exitCode === 0)
            callback(null);
        else
            callback(new Error(stderr || ("secret-tool exited with " + exitCode)));
    });
}
