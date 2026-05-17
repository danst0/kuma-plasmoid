import QtQuick
import org.kde.kcmutils as KCM

// Base for every config page. AppletConfiguration pushes every `cfg_<key>` and
// `cfg_<key>Default` from main.xml as initial properties; the page errors on
// unknown ones. Declaring the full set here keeps individual config pages clean.
// `title` is inherited from Kirigami.Page; do not redeclare (it's FINAL).
KCM.SimpleKCM {
    // ---- Connection ----
    property string cfg_baseUrl: ""
    property string cfg_baseUrlDefault: ""
    property int    cfg_apiMode: 0
    property int    cfg_apiModeDefault: 0
    property string cfg_statusPageSlug: "default"
    property string cfg_statusPageSlugDefault: "default"
    property string cfg_statusPageEndpoint: "status/{{slug}}/status.json"
    property string cfg_statusPageEndpointDefault: "status/{{slug}}/status.json"
    property string cfg_statusPageJsonUrl: ""
    property string cfg_statusPageJsonUrlDefault: ""
    property string cfg_apiEndpoint: "api/monitor"
    property string cfg_apiEndpointDefault: "api/monitor"
    property string cfg_metricsEndpoint: "metrics"
    property string cfg_metricsEndpointDefault: "metrics"

    // ---- Polling / behaviour ----
    property int  cfg_refreshSeconds: 60
    property int  cfg_refreshSecondsDefault: 60
    property bool cfg_demoMode: true
    property bool cfg_demoModeDefault: true
    property int  cfg_logLevel: 1
    property int  cfg_logLevelDefault: 1

    // ---- Appearance ----
    property int  cfg_appearance: 0
    property int  cfg_appearanceDefault: 0
    property bool cfg_showText: true
    property bool cfg_showTextDefault: true
    property bool cfg_showLatency: true
    property bool cfg_showLatencyDefault: true
    property bool cfg_showBadges: true
    property bool cfg_showBadgesDefault: true
    property bool cfg_showCalculatedUptime: false
    property bool cfg_showCalculatedUptimeDefault: false

    property var  cfg_selectedServices: []
    property var  cfg_selectedServicesDefault: []

    // ---- Notifications ----
    property bool cfg_enableNotifications: true
    property bool cfg_enableNotificationsDefault: true
    property bool cfg_notifyOnRecovery: true
    property bool cfg_notifyOnRecoveryDefault: true
}
