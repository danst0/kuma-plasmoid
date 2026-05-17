import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: dot

    property string status: "unknown"
    property real diameter: Kirigami.Units.iconSizes.small

    implicitWidth: diameter
    implicitHeight: diameter
    radius: diameter / 2
    antialiasing: true

    color: {
        switch (status) {
        case "up":          return Kirigami.Theme.positiveTextColor;
        case "degraded":
        case "maintenance": return Kirigami.Theme.neutralTextColor;
        case "down":        return Kirigami.Theme.negativeTextColor;
        default:            return Kirigami.Theme.disabledTextColor;
        }
    }

    border.width: 1
    border.color: Qt.darker(color, 1.25)
}
