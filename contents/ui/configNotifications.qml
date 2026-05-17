import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ConfigBase {
    id: root

    Kirigami.FormLayout {
        anchors.fill: parent

        CheckBox {
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Notify on outages and degraded monitors")
            checked: root.cfg_enableNotifications
            onToggled: root.cfg_enableNotifications = checked
        }

        CheckBox {
            text: i18n("Also notify when a monitor recovers")
            enabled: root.cfg_enableNotifications
            checked: root.cfg_notifyOnRecovery
            onToggled: root.cfg_notifyOnRecovery = checked
        }

        Item { Kirigami.FormData.isSection: true }

        Label {
            Layout.fillWidth: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: i18n("Notifications are sent through the standard freedesktop notification service. " +
                       "Critical urgency is used for fully-down monitors; normal urgency for degraded " +
                       "and recovery messages.")
        }
    }
}
