import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

Item {
    id: full

    property var monitors: []
    property var summary: ({ up: 0, down: 0, degraded: 0, unknown: 0, total: 0, status: "unknown" })

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 18
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            StatusDot {
                status: full.summary.status
                diameter: Kirigami.Units.iconSizes.smallMedium
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaExtras.Heading {
                level: 3
                text: "Uptime Kuma"
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: full.summary.total > 0
                text: full.summary.up + " up · " + full.summary.down + " down · " + full.summary.total + " total"
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // Body: list or empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            EmptyState {
                visible: full.monitors.length === 0
                title: "No monitors"
                subtitle: Plasmoid.configuration.demoMode
                    ? "Demo mode is on but no mock data is loaded."
                    : "Configure your Uptime Kuma base URL in widget settings, or enable Demo Mode."
            }

            PlasmaComponents.ScrollView {
                anchors.fill: parent
                visible: full.monitors.length > 0

                ListView {
                    id: list
                    model: full.monitors
                    spacing: Kirigami.Units.smallSpacing
                    clip: true

                    delegate: Item {
                        width: list.width
                        height: rowLayout.implicitHeight + Kirigami.Units.smallSpacing

                        MonitorRow {
                            id: rowLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing

                            monitorName: modelData.name || ""
                            status: modelData.status || "unknown"
                            latencyMs: modelData.latencyMs
                            lastCheckUnix: modelData.lastCheck && typeof modelData.lastCheck.to_unix === "function"
                                ? modelData.lastCheck.to_unix()
                                : 0
                            message: modelData.message || ""
                            showLatency: Plasmoid.configuration.showLatency
                        }
                    }
                }
            }
        }
    }
}
