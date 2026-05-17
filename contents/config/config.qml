import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("Connection")
        icon: "network-server"
        source: "configConnection.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Notifications")
        icon: "preferences-desktop-notification"
        source: "configNotifications.qml"
    }
}
