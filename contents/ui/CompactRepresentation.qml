import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: compact

    property var summary: ({ up: 0, down: 0, degraded: 0, unknown: 0, total: 0, status: "unknown" })

    Layout.preferredWidth: contentRow.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

    onClicked: Plasmoid.expanded = !Plasmoid.expanded

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        StatusDot {
            status: compact.summary.status
            diameter: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignVCenter
        }

        PlasmaComponents.Label {
            id: summaryLabel
            visible: Plasmoid.configuration.showText && compact.summary.total > 0
            Layout.alignment: Qt.AlignVCenter
            text: {
                const s = compact.summary;
                if (s.down > 0)
                    return s.down + "↓ " + s.up + "↑";
                if (s.degraded > 0)
                    return s.degraded + "! " + s.up + "↑";
                return s.up + "/" + s.total;
            }
        }
    }
}
