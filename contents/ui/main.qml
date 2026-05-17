import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "../code/parsers.js" as Parsers
import "../code/network.js" as Network
import "../code/secrets.js" as Secrets
import "../code/logger.js" as Logger

PlasmoidItem {
    id: root

    property var monitors: []
    property var summary: ({ up: 0, down: 0, degraded: 0, unknown: 0, total: 0, status: "unknown" })
    property string lastError: ""
    property bool isLoading: false
    property double lastUpdateUnix: 0

    // API key cache. null = unknown, "" = known-missing, "<value>" = known-good.
    property var _apiKey: null

    // Created lazily on first non-demo refresh; destroyed in onDestruction.
    property var _fetcher: null

    // Status map for notification diffing. id → status. null before the first
    // successful refresh; an empty map after.
    property var _previousStatuses: null

    // Badge cache: id → percentage (Number) or null while a fetch is in flight.
    property var _badgeCache: ({})
    property double _lastBadgeFetchUnix: 0
    readonly property int _badgeRefreshSeconds: 5 * 60

    // Wake-up detection: if pollTimer goes silent for much longer than its
    // configured interval, we likely resumed from suspend. Used to silence the
    // notification diff on the first post-wake refresh (otherwise dozens of
    // "Down" notifications might fire at once for unrelated state changes).
    property double _lastPollUnix: 0
    property bool _skipNextNotifications: false

    ShellExecutor { id: shell }

    // ----- Lifecycle -----
    Component.onCompleted: {
        Logger.setLevel(_logLevelName());
        Logger.info("plasmoid initialized, version", "0.6.0");
        refresh();
    }

    Component.onDestruction: {
        if (_fetcher) {
            _fetcher.destroy();
            _fetcher = null;
        }
    }

    function _logLevelName() {
        const lvl = Plasmoid.configuration.logLevel;
        if (lvl === 0) return "Error";
        if (lvl === 2) return "Debug";
        return "Info";
    }

    function _apiModeName() {
        // KConfigXT Enum: 0=StatusPage, 1=ApiKey, 2=Metrics
        const m = Plasmoid.configuration.apiMode;
        if (m === 1) return "api-key";
        if (m === 2) return "metrics";
        return "status-page";
    }

    function _buildConfig() {
        const c = Plasmoid.configuration;
        return {
            baseUrl: c.baseUrl,
            apiMode: _apiModeName(),
            statusPageSlug: c.statusPageSlug,
            statusPageEndpoint: c.statusPageEndpoint,
            statusPageJsonUrl: c.statusPageJsonUrl,
            apiEndpoint: c.apiEndpoint,
            metricsEndpoint: c.metricsEndpoint
        };
    }

    function _ensureFetcher() {
        if (!_fetcher) {
            _fetcher = new Network.MonitorFetcher({
                qmlParent: root,
                parsers: Parsers,
                logger: Logger
            });
        }
        return _fetcher;
    }

    // ----- Notifications --------------------------------------------------
    function _notifyOnChanges(freshMonitors) {
        const prev = root._previousStatuses;
        // Build the new map regardless — needed for the next call even if
        // notifications are disabled.
        const next = {};
        for (let i = 0; i < freshMonitors.length; i++) {
            const m = freshMonitors[i];
            if (m && m.id !== undefined && m.id !== null)
                next[m.id] = m.status || "unknown";
        }
        root._previousStatuses = next;

        // First refresh after startup: seed only, never spam on the initial
        // snapshot (e.g. don't fire "down" notifications for every red monitor
        // when the plasmoid is added).
        if (prev === null) return;
        if (root._skipNextNotifications) {
            root._skipNextNotifications = false;
            Logger.debug("notification diff skipped (post-wake)");
            return;
        }
        if (!Plasmoid.configuration.enableNotifications) return;

        const notifyRecovery = Plasmoid.configuration.notifyOnRecovery;
        for (let i = 0; i < freshMonitors.length; i++) {
            const m = freshMonitors[i];
            if (!m || m.id === undefined || m.id === null) continue;
            const prevStatus = prev[m.id];
            if (prevStatus === undefined) continue; // newly-discovered monitor
            const cur = m.status || "unknown";
            if (cur === prevStatus) continue;

            const isFailNow  = (cur === "down" || cur === "degraded");
            const wasFailing = (prevStatus === "down" || prevStatus === "degraded");

            if (isFailNow) {
                root._notify(m, cur, prevStatus, /*recovery=*/ false);
            } else if (wasFailing && cur === "up" && notifyRecovery) {
                root._notify(m, cur, prevStatus, /*recovery=*/ true);
            }
            // up→unknown / unknown→up transitions are ignored intentionally
            // (Uptime Kuma reports "unknown" during restart windows etc.).
        }
    }

    function _notify(monitor, cur, prev, recovery) {
        const icon = recovery
            ? "network-connect"
            : (cur === "down" ? "network-disconnect" : "dialog-warning");
        const urgency = recovery ? "normal" : (cur === "down" ? "critical" : "normal");
        const title = recovery
            ? i18n("Recovered: %1", monitor.name || "monitor")
            : (cur === "down"
                ? i18n("Down: %1", monitor.name || "monitor")
                : i18n("Degraded: %1", monitor.name || "monitor"));
        const body = (monitor.message && monitor.message.length > 0)
            ? monitor.message
            : i18n("Status changed from %1 to %2", prev, cur);

        const cmd =
            "notify-send" +
            " --app-name=" + _shEscape("Uptime Kuma") +
            " --icon=" + _shEscape(icon) +
            " --urgency=" + _shEscape(urgency) +
            " --category=" + _shEscape("network.status") +
            " " + _shEscape(title) +
            " " + _shEscape(body);
        shell.exec(cmd, function (exitCode, _stdout, stderr) {
            if (exitCode !== 0)
                Logger.error("notify-send failed:", stderr || ("exit " + exitCode));
        });
    }

    function _shEscape(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    // ----- Badges ---------------------------------------------------------
    function _decorateWithBadges(monitors) {
        if (!Plasmoid.configuration.showBadges) return monitors;
        const cache = root._badgeCache || {};
        return monitors.map(function (m) {
            if (!m || m.id === undefined || m.id === null) return m;
            const cached = cache[m.id];
            if (cached !== undefined) {
                // Mutate-in-place is safe — these are fresh parser outputs every refresh.
                m.badgePercentage = cached;
            }
            return m;
        });
    }

    function _maybeFetchBadges() {
        if (!Plasmoid.configuration.showBadges) return;
        if (Plasmoid.configuration.demoMode) return;       // no real ids to fetch against
        if (!Plasmoid.configuration.baseUrl) return;
        if (root.monitors.length === 0) return;
        const now = Math.floor(Date.now() / 1000);
        if (now - root._lastBadgeFetchUnix < root._badgeRefreshSeconds) return;
        root._lastBadgeFetchUnix = now;

        const fetcher = _ensureFetcher();
        const cfg = _buildConfig();
        const list = root.monitors.slice(); // snapshot
        Logger.debug("badge fetch: " + list.length + " monitors");
        for (let i = 0; i < list.length; i++) {
            const m = list[i];
            if (!m || m.id === undefined || m.id === null) continue;
            const id = m.id;
            // null in cache while in-flight so the UI can show a placeholder.
            if (root._badgeCache[id] === undefined)
                root._badgeCache[id] = null;
            fetcher.fetchUptimeBadge(id, cfg).then(function (badge) {
                if (!badge) return;
                root._setBadge(id, badge.percentage);
            }).catch(function (err) {
                Logger.debug("badge fetch failed for " + id + ": " + (err && err.message ? err.message : err));
            });
        }
    }

    function _setBadge(id, percentage) {
        // Reassign the cache map and re-decorate the monitor list so QML
        // binding bumps and rows re-render.
        const next = Object.assign({}, root._badgeCache);
        next[id] = (percentage === null || percentage === undefined) ? null : Number(percentage);
        root._badgeCache = next;
        root.monitors = _decorateWithBadges(root.monitors.slice());
    }

    function _applyServiceFilter(monitors) {
        const raw = Plasmoid.configuration.selectedServices;
        if (!raw || raw.length === 0) return monitors;
        const wanted = {};
        for (let i = 0; i < raw.length; i++) {
            const k = String(raw[i]).toLowerCase().trim();
            if (k.length > 0) wanted[k] = true;
        }
        if (Object.keys(wanted).length === 0) return monitors;
        return monitors.filter(function (m) {
            if (!m) return false;
            const byName = m.name ? wanted[String(m.name).toLowerCase().trim()] : false;
            const byId   = (m.id !== undefined && m.id !== null) ? wanted[String(m.id).toLowerCase().trim()] : false;
            return Boolean(byName || byId);
        });
    }

    function _apiKeyHelper() {
        return {
            getApiKey: function () {
                if (root._apiKey !== null)
                    return Promise.resolve(root._apiKey || null);
                // Cache miss — kick off a lookup and wait for it.
                return new Promise(function (resolve) {
                    Secrets.lookup(shell, function (err, value) {
                        if (err) {
                            Logger.error("api key lookup failed:", err.message);
                            root._apiKey = "";
                            resolve(null);
                            return;
                        }
                        root._apiKey = value || "";
                        resolve(value || null);
                    });
                });
            }
        };
    }

    // ----- Refresh loop -----
    Timer {
        id: pollTimer
        interval: Math.max(10, Plasmoid.configuration.refreshSeconds) * 1000
        repeat: true
        running: true
        onTriggered: {
            const now = Math.floor(Date.now() / 1000);
            const expectedSec = pollTimer.interval / 1000;
            if (root._lastPollUnix > 0 && now - root._lastPollUnix > expectedSec * 3) {
                Logger.info("resumed after " + (now - root._lastPollUnix) + "s pause — silencing notification diff");
                root._skipNextNotifications = true;
            }
            root._lastPollUnix = now;
            root.refresh();
        }
    }

    // Force a refresh when the popup is opened, but throttle so a quick
    // click-close-click doesn't hammer the server.
    onExpandedChanged: {
        if (expanded) {
            const now = Math.floor(Date.now() / 1000);
            if (now - root.lastUpdateUnix > 5) {
                Logger.debug("refresh on expand");
                root.refresh();
            }
        }
    }

    Connections {
        target: Plasmoid.configuration
        function onRefreshSecondsChanged() {
            pollTimer.interval = Math.max(10, Plasmoid.configuration.refreshSeconds) * 1000;
        }
        function onLogLevelChanged() {
            Logger.setLevel(root._logLevelName());
        }
        function onDemoModeChanged()   { root.refresh(); }
        function onBaseUrlChanged()    { root.refresh(); }
        function onApiModeChanged() {
            // Invalidate the cached key so a fresh lookup runs on next refresh
            // (handles "user just stored a key in the config page" case).
            root._apiKey = null;
            root.refresh();
        }
        function onSelectedServicesChanged() { root.refresh(); }
        function onShowBadgesChanged() {
            // Reset the throttle so toggling on triggers an immediate fetch.
            root._lastBadgeFetchUnix = 0;
            if (Plasmoid.configuration.showBadges) {
                _maybeFetchBadges();
            } else {
                // Strip stale badges so rows stop rendering them.
                root._badgeCache = ({});
                root.monitors = root.monitors.map(function (m) {
                    if (m) m.badgePercentage = undefined;
                    return m;
                });
            }
        }
    }

    function refresh() {
        if (Plasmoid.configuration.demoMode) {
            Logger.debug("refresh: demo mode → mockMonitors()");
            const mocks = _applyServiceFilter(Parsers.mockMonitors());
            root._notifyOnChanges(mocks);
            root.monitors = mocks;
            root.summary = Parsers.aggregateMonitors(mocks);
            root.lastError = "";
            root.lastUpdateUnix = Math.floor(Date.now() / 1000);
            return;
        }

        if (!Plasmoid.configuration.baseUrl) {
            root.monitors = [];
            root.summary = Parsers.aggregateMonitors([]);
            root.lastError = "";
            return;
        }

        if (root.isLoading) {
            Logger.debug("refresh: already in flight, skipping");
            return;
        }

        const fetcher = _ensureFetcher();
        const cfg = _buildConfig();
        root.isLoading = true;
        Logger.debug("refresh: fetching mode=" + cfg.apiMode);

        fetcher.fetch(cfg, _apiKeyHelper()).then(result => {
            const filtered = _applyServiceFilter(result.monitors || []);
            const decorated = _decorateWithBadges(filtered);
            root._notifyOnChanges(decorated);
            root.monitors = decorated;
            root.summary = Parsers.aggregateMonitors(decorated);
            root.lastError = "";
            root.lastUpdateUnix = Math.floor(Date.now() / 1000);
            root.isLoading = false;
            Logger.debug("refresh: ok, " + decorated.length + " monitors");
            _maybeFetchBadges();
        }).catch(err => {
            const msg = (err && err.message) ? err.message : String(err);
            Logger.error("refresh failed:", msg);
            root.monitors = [];
            root.summary = Parsers.aggregateMonitors([]);
            root.lastError = msg;
            root.isLoading = false;
        });
    }

    // ----- Representations -----
    // ----- Plasma tooltip (panel hover) -----
    // toolTipMainText / toolTipSubText are direct PlasmoidItem properties; the
    // `Plasmoid.` attached prefix would silently set unrelated stuff instead.
    toolTipMainText: "Uptime Kuma"
    toolTipSubText: _tooltipText()

    function _tooltipText() {
        const s = root.summary;
        if (root.lastError && root.lastError.length > 0)
            return i18n("Last fetch failed: %1", root.lastError);
        if (s.total === 0)
            return i18n("No monitors loaded yet.");

        const failing = [];
        const degraded = [];
        for (let i = 0; i < root.monitors.length; i++) {
            const m = root.monitors[i];
            if (!m) continue;
            if (m.status === "down") failing.push(m.name || "");
            else if (m.status === "degraded" || m.status === "maintenance") degraded.push(m.name || "");
        }

        const parts = [
            i18n("%1 up · %2 down · %3 degraded · %4 total",
                 s.up, s.down, s.degraded, s.total)
        ];
        if (failing.length > 0)
            parts.push(i18n("Down: %1", failing.join(", ")));
        if (degraded.length > 0)
            parts.push(i18n("Degraded: %1", degraded.join(", ")));
        return parts.join("\n");
    }

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
        summary: root.summary
    }

    fullRepresentation: FullRepresentation {
        monitors: root.monitors
        summary: root.summary
        lastError: root.lastError
        isLoading: root.isLoading
        onRefreshRequested: root.refresh()
    }

    // On the desktop (planar form factor) default to the full representation —
    // a Kuma widget pinned to the desktop should show the monitor list inline,
    // not a tiny click-to-popup tile. Panels keep the compact-then-popup flow.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? fullRepresentation
        : compactRepresentation

    Plasmoid.icon: "network-server"
}
