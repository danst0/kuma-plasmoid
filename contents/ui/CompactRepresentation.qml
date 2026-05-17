import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: compact

    required property PlasmoidItem plasmoidItem
    property var summary: ({ up: 0, down: 0, degraded: 0, unknown: 0, total: 0, status: "unknown" })

    readonly property bool inVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool inHorizontalPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal

    // Vertical panels: a square, label is hidden regardless of showText.
    // Horizontal panels: width grows with the optional label.
    Layout.preferredWidth: inVerticalPanel
        ? Kirigami.Units.iconSizes.smallMedium
        : contentRow.implicitWidth + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: inVerticalPanel
        ? Kirigami.Units.iconSizes.smallMedium
        : Kirigami.Units.iconSizes.smallMedium

    hoverEnabled: true
    onClicked: plasmoidItem.expanded = !plasmoidItem.expanded

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        StatusDot {
            status: compact.summary.status
            diameter: Kirigami.Units.iconSizes.small
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        PlasmaComponents.Label {
            id: summaryLabel
            // appearance: 0 = Normal (dot + text per showText), 1 = Compact (dot only).
            // Vertical panels never show the text — no horizontal room for it.
            visible: !compact.inVerticalPanel
                     && Plasmoid.configuration.appearance === 0
                     && Plasmoid.configuration.showText
                     && compact.summary.total > 0
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
