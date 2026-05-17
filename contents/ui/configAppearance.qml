import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigBase {
    id: root

    function _servicesToText(list) {
        if (!list || !list.length) return "";
        return list.join(", ");
    }

    function _textToServices(text) {
        if (!text) return [];
        const parts = text.split(",").map(function (s) { return s.trim(); }).filter(function (s) { return s.length > 0; });
        // Schema says max 10 — enforced here so the model never carries more.
        return parts.slice(0, 10);
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        // ----- Layout -----
        ComboBox {
            Kirigami.FormData.label: i18n("Panel appearance:")
            model: [
                i18n("Normal — status dot with summary text"),
                i18n("Compact — status dot only")
            ]
            currentIndex: root.cfg_appearance
            onActivated: root.cfg_appearance = currentIndex
        }

        CheckBox {
            text: i18n("Show summary text next to the panel dot")
            enabled: root.cfg_appearance === 0
            checked: root.cfg_showText
            onToggled: root.cfg_showText = checked
        }

        Item { Kirigami.FormData.isSection: true }

        // ----- Monitor rows -----
        CheckBox {
            Kirigami.FormData.label: i18n("Monitor rows:")
            text: i18n("Show latency value")
            checked: root.cfg_showLatency
            onToggled: root.cfg_showLatency = checked
        }

        CheckBox {
            text: i18n("Show uptime badges (24h)")
            checked: root.cfg_showBadges
            onToggled: root.cfg_showBadges = checked
        }

        CheckBox {
            text: i18n("Show calculated uptime percentage")
            checked: root.cfg_showCalculatedUptime
            onToggled: root.cfg_showCalculatedUptime = checked
        }

        Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: i18n("Badge fetching is wired in the next release; the toggles already store but have no UI effect yet.")
        }

        Item { Kirigami.FormData.isSection: true }

        // ----- Filter -----
        TextField {
            id: servicesField
            Kirigami.FormData.label: i18n("Services to display:")
            Layout.fillWidth: true
            placeholderText: i18n("Comma-separated names, empty = show all (max 10)")
            text: root._servicesToText(root.cfg_selectedServices)
            onEditingFinished: root.cfg_selectedServices = root._textToServices(text)
        }

        Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: i18n("Matches monitors by name or id. Whitespace around commas is trimmed.")
        }
    }
}
