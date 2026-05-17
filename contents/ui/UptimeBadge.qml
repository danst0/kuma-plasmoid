import QtQuick
import org.kde.kirigami as Kirigami

// Small pill rendering 24h uptime percentage. `percentage` null = loading.
Rectangle {
    id: badge

    property var percentage: null

    implicitWidth: label.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: label.implicitHeight + Kirigami.Units.smallSpacing
    radius: height / 2
    color: badge._tone(percentage)
    opacity: percentage === null ? 0.4 : 0.9

    function _tone(p) {
        if (p === null || p === undefined) return Kirigami.Theme.disabledTextColor;
        if (p >= 99.5) return Kirigami.Theme.positiveTextColor;
        if (p >= 95)   return Kirigami.Theme.neutralTextColor;
        return Kirigami.Theme.negativeTextColor;
    }

    Text {
        id: label
        anchors.centerIn: parent
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.bold: true
        color: Kirigami.Theme.backgroundColor
        text: badge.percentage === null
              ? "…"
              : (badge.percentage >= 99.95 ? "100%" : badge.percentage.toFixed(1) + "%")
    }
}
