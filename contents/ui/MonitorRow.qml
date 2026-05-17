import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: row

    property string monitorName: ""
    property string status: "unknown"
    property var latencyMs: null
    property var lastCheckUnix: 0
    property string message: ""
    property bool showLatency: true

    spacing: Kirigami.Units.smallSpacing * 2

    StatusDot {
        status: row.status
        diameter: Kirigami.Units.iconSizes.small
        Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        PlasmaComponents.Label {
            text: row.monitorName
            elide: Text.ElideRight
            Layout.fillWidth: true
            font.bold: true
        }

        PlasmaComponents.Label {
            text: row.message
            visible: row.message && row.message.length > 0
            elide: Text.ElideRight
            Layout.fillWidth: true
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
        }
    }

    PlasmaComponents.Label {
        text: row.showLatency && row.latencyMs !== null && row.latencyMs !== undefined
              ? row.latencyMs + " ms"
              : ""
        visible: text.length > 0
        opacity: 0.8
        Layout.alignment: Qt.AlignVCenter
    }

    PlasmaComponents.Label {
        text: row.lastCheckUnix > 0 ? relativeTime(row.lastCheckUnix) : ""
        visible: text.length > 0
        opacity: 0.6
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        Layout.alignment: Qt.AlignVCenter

        function relativeTime(unix) {
            const deltaSec = Math.floor(Date.now() / 1000) - unix;
            if (deltaSec < 60)   return deltaSec + "s ago";
            if (deltaSec < 3600) return Math.floor(deltaSec / 60) + "m ago";
            if (deltaSec < 86400) return Math.floor(deltaSec / 3600) + "h ago";
            return Math.floor(deltaSec / 86400) + "d ago";
        }
    }
}
