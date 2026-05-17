import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Lightweight wrapper around the legacy `executable` data engine so callers can
// run a shell command and receive (exitCode, stdout, stderr) in a callback.
// Plasma 6 still ships this engine via plasma5support; if it ever goes away we
// re-implement against QtProcess or a DBus call.
Item {
    id: shell

    property var _pending: ({})

    function exec(cmd, callback) {
        if (!cmd) {
            callback(-1, "", "empty command");
            return;
        }
        shell._pending[cmd] = callback;
        source.connectSource(cmd);
    }

    P5Support.DataSource {
        id: source
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            const cb = shell._pending[sourceName];
            delete shell._pending[sourceName];
            source.disconnectSource(sourceName);
            if (typeof cb === "function") {
                cb(data["exit code"] || 0,
                   data["stdout"] || "",
                   data["stderr"] || "");
            }
        }
    }
}
