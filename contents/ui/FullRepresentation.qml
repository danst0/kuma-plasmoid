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
    property string lastError: ""
    property bool isLoading: false

    signal refreshRequested()

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 18
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12

    // Bumped every minute so "Xs ago" / "Xm ago" labels in MonitorRow refresh
    // without needing a full Kuma refetch.
    property int relativeTimeTick: 0
    Timer {
        interval: 60 * 1000
        running: full.visible
        repeat: true
        onTriggered: full.relativeTimeTick++
    }

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
                text: i18n("Uptime Kuma")
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: full.summary.total > 0
                text: i18n("%1 up · %2 down · %3 total",
                           full.summary.up, full.summary.down, full.summary.total)
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !full.isLoading
                onClicked: full.refreshRequested()
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // Body: list or empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            EmptyState {
                visible: full.monitors.length === 0
                title: full.lastError.length > 0
                    ? i18n("Couldn’t fetch monitors")
                    : i18n("No monitors")
                subtitle: {
                    if (full.lastError.length > 0)
                        return full.lastError;
                    if (Plasmoid.configuration.demoMode)
                        return i18n("Demo mode is on but no mock data is loaded.");
                    if (!Plasmoid.configuration.baseUrl)
                        return i18n("Set your Uptime Kuma base URL in widget settings, or enable Demo Mode.");
                    return full.isLoading
                        ? i18n("Loading…")
                        : i18n("No monitors returned from the configured endpoint.");
                }
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
                            showBadge: Plasmoid.configuration.showBadges
                            badgePercentage: modelData.badgePercentage
                            relativeTimeTick: full.relativeTimeTick
                        }
                    }
                }
            }
        }
    }
}
