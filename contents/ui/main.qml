import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "../code/parsers.js" as Parsers
import "../code/logger.js" as Logger

PlasmoidItem {
    id: root

    property var monitors: []
    property var summary: ({ up: 0, down: 0, degraded: 0, unknown: 0, total: 0, status: "unknown" })

    // ----- Lifecycle -----
    Component.onCompleted: {
        Logger.setLevel(_logLevelName());
        Logger.info("plasmoid initialized, version", "0.1.0");
        refresh();
    }

    function _logLevelName() {
        // KConfigXT Enum exposes integer; map to logger names.
        const lvl = Plasmoid.configuration.logLevel;
        if (lvl === 0) return "Error";
        if (lvl === 2) return "Debug";
        return "Info";
    }

    // ----- Refresh loop -----
    Timer {
        id: pollTimer
        interval: Math.max(10, Plasmoid.configuration.refreshSeconds) * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Plasmoid.configuration
        function onRefreshSecondsChanged() {
            pollTimer.interval = Math.max(10, Plasmoid.configuration.refreshSeconds) * 1000;
        }
        function onLogLevelChanged() {
            Logger.setLevel(root._logLevelName());
        }
        function onDemoModeChanged() {
            root.refresh();
        }
    }

    function refresh() {
        if (Plasmoid.configuration.demoMode) {
            Logger.debug("refresh: demo mode → mockMonitors()");
            root.monitors = Parsers.mockMonitors();
        } else {
            // M2+ wires real network fetch here. For M1 the plasmoid only
            // renders when demoMode is on.
            Logger.debug("refresh: demo mode off and no network impl yet (M1)");
            root.monitors = [];
        }
        root.summary = Parsers.aggregateMonitors(root.monitors);
    }

    // ----- Representations -----
    compactRepresentation: CompactRepresentation {
        summary: root.summary
    }

    fullRepresentation: FullRepresentation {
        monitors: root.monitors
        summary: root.summary
    }

    // Top-level icon used by Plasma if no compactRepresentation paints itself.
    Plasmoid.icon: "network-server"
}
