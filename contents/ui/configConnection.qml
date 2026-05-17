import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "../code/secrets.js" as Secrets

ConfigBase {
    id: root

    // ---- API key state ---------------------------------------------------
    property string _apiKeyDraft: ""
    property string _apiKeyStatus: ""
    property bool   _apiKeyBusy: false

    ShellExecutor { id: shell }

    Component.onCompleted: _refreshApiKeyStatus()

    function _refreshApiKeyStatus() {
        _apiKeyBusy = true;
        Secrets.lookup(shell, function (err, value) {
            _apiKeyBusy = false;
            if (err)
                _apiKeyStatus = i18n("Keyring error: %1", err.message);
            else if (value && value.length > 0)
                _apiKeyStatus = i18n("Stored (%1 characters)", value.length);
            else
                _apiKeyStatus = i18n("Not set");
        });
    }

    function _saveApiKey() {
        if (_apiKeyDraft.length === 0) return;
        _apiKeyBusy = true;
        Secrets.store(shell, _apiKeyDraft, function (err) {
            _apiKeyBusy = false;
            if (err) {
                _apiKeyStatus = i18n("Save failed: %1", err.message);
                return;
            }
            _apiKeyDraft = "";
            _refreshApiKeyStatus();
        });
    }

    function _clearApiKey() {
        _apiKeyBusy = true;
        Secrets.clear(shell, function (err) {
            _apiKeyBusy = false;
            if (err)
                _apiKeyStatus = i18n("Clear failed: %1", err.message);
            else
                _refreshApiKeyStatus();
        });
    }

    Kirigami.FormLayout {
        anchors.fill: parent

        // ----- Server -----
        TextField {
            Kirigami.FormData.label: i18n("Base URL:")
            Layout.fillWidth: true
            placeholderText: "https://kuma.example.com"
            text: root.cfg_baseUrl
            onTextChanged: root.cfg_baseUrl = text
        }

        CheckBox {
            Kirigami.FormData.label: i18n("Demo mode:")
            text: i18n("Render mock monitors without contacting the server")
            checked: root.cfg_demoMode
            onToggled: root.cfg_demoMode = checked
        }

        Item { Kirigami.FormData.isSection: true }

        // ----- API mode -----
        ComboBox {
            id: apiModeBox
            Kirigami.FormData.label: i18n("Fetch mode:")
            model: [
                i18n("Public status page"),
                i18n("Private API (token)"),
                i18n("Prometheus metrics")
            ]
            currentIndex: root.cfg_apiMode
            onActivated: root.cfg_apiMode = currentIndex
        }

        TextField {
            Kirigami.FormData.label: i18n("Status page slug:")
            visible: apiModeBox.currentIndex === 0
            Layout.fillWidth: true
            placeholderText: "default"
            text: root.cfg_statusPageSlug
            onTextChanged: root.cfg_statusPageSlug = text
        }

        TextField {
            Kirigami.FormData.label: i18n("Status page endpoint:")
            visible: apiModeBox.currentIndex === 0
            Layout.fillWidth: true
            placeholderText: "status/{{slug}}/status.json"
            text: root.cfg_statusPageEndpoint
            onTextChanged: root.cfg_statusPageEndpoint = text
        }

        TextField {
            Kirigami.FormData.label: i18n("Override JSON URL:")
            visible: apiModeBox.currentIndex === 0
            Layout.fillWidth: true
            placeholderText: i18n("Optional full URL — overrides slug/endpoint")
            text: root.cfg_statusPageJsonUrl
            onTextChanged: root.cfg_statusPageJsonUrl = text
        }

        TextField {
            Kirigami.FormData.label: i18n("API endpoint:")
            visible: apiModeBox.currentIndex === 1
            Layout.fillWidth: true
            placeholderText: "api/monitor"
            text: root.cfg_apiEndpoint
            onTextChanged: root.cfg_apiEndpoint = text
        }

        TextField {
            Kirigami.FormData.label: i18n("Metrics endpoint:")
            visible: apiModeBox.currentIndex === 2
            Layout.fillWidth: true
            placeholderText: "metrics"
            text: root.cfg_metricsEndpoint
            onTextChanged: root.cfg_metricsEndpoint = text
        }

        Item { Kirigami.FormData.isSection: true }

        // ----- API key -----
        Label {
            Kirigami.FormData.label: i18n("API key status:")
            text: root._apiKeyBusy ? i18n("Working…") : root._apiKeyStatus
            opacity: 0.8
        }

        TextField {
            Kirigami.FormData.label: i18n("New API key:")
            visible: apiModeBox.currentIndex !== 0
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: i18n("Paste token, then click Save")
            text: root._apiKeyDraft
            onTextChanged: root._apiKeyDraft = text
        }

        RowLayout {
            visible: apiModeBox.currentIndex !== 0
            spacing: Kirigami.Units.smallSpacing

            Button {
                text: i18n("Save key")
                enabled: !root._apiKeyBusy && root._apiKeyDraft.length > 0
                onClicked: root._saveApiKey()
            }
            Button {
                text: i18n("Clear stored key")
                enabled: !root._apiKeyBusy
                onClicked: root._clearApiKey()
            }
        }

        Item { Kirigami.FormData.isSection: true }

        // ----- Polling -----
        SpinBox {
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 10
            to: 3600
            stepSize: 10
            value: root.cfg_refreshSeconds
            onValueModified: root.cfg_refreshSeconds = value
            textFromValue: function (v) { return v + " s"; }
            valueFromText: function (t) { return parseInt(t, 10); }
        }

        ComboBox {
            Kirigami.FormData.label: i18n("Log level:")
            model: [i18n("Error"), i18n("Info"), i18n("Debug")]
            currentIndex: root.cfg_logLevel
            onActivated: root.cfg_logLevel = currentIndex
        }
    }
}
