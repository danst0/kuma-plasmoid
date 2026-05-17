import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

ColumnLayout {
    spacing: Kirigami.Units.largeSpacing
    anchors.centerIn: parent

    property string title: ""
    property string subtitle: ""

    Kirigami.Icon {
        source: "network-server-symbolic"
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
        opacity: 0.5
    }

    PlasmaComponents.Label {
        text: title
        Layout.alignment: Qt.AlignHCenter
        font.bold: true
    }

    PlasmaComponents.Label {
        text: subtitle
        Layout.alignment: Qt.AlignHCenter
        opacity: 0.7
        wrapMode: Text.WordWrap
        Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        horizontalAlignment: Text.AlignHCenter
    }
}
