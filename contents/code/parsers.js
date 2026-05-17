.pragma library

// =============================================================================
//  Source:  uptime-kuma-indicator/utils/parsers.js
//  From:    https://github.com/danst0/gnome-uptime-kuma
//  Commit:  0ed98918c44d2ec38d37543d8f4b5c765fbb36c0
//  License: GPL-3.0-or-later
//
//  This file is a near-verbatim copy of the GNOME variant. Two mechanical
//  transformations are applied to make it work as a QML .pragma library:
//
//    1. ESM `import` lines (GLib and ./i18n.js) are replaced with the inline
//       shim below.
//    2. `export ` keywords are stripped from function declarations (QML JS
//       libraries expose every top-level function/var automatically).
//
//  Do not edit logic locally — re-sync by re-applying these two transforms to a
//  newer upstream commit and updating the commit hash above.
// =============================================================================

// ---- Inline shim replacing `import GLib from 'gi://GLib'` -------------------
var GLib = (function () {
    function DateTimeImpl(unixSeconds) {
        this._unix = Math.floor(unixSeconds);
    }
    DateTimeImpl.prototype.to_unix = function () { return this._unix; };
    DateTimeImpl.prototype.add_seconds = function (seconds) {
        return new DateTimeImpl(this._unix + Math.floor(seconds));
    };

    function uuidv4() {
        // RFC 4122 v4 — sufficient for our id-fallback usage.
        var buf = new Array(16);
        for (var i = 0; i < 16; i++) buf[i] = Math.floor(Math.random() * 256);
        buf[6] = (buf[6] & 0x0f) | 0x40;
        buf[8] = (buf[8] & 0x3f) | 0x80;
        var hex = buf.map(function (b) { return ("0" + b.toString(16)).slice(-2); });
        return hex.slice(0, 4).join("") + "-" +
               hex.slice(4, 6).join("") + "-" +
               hex.slice(6, 8).join("") + "-" +
               hex.slice(8, 10).join("") + "-" +
               hex.slice(10, 16).join("");
    }

    return {
        DateTime: {
            new_now_utc: function () { return new DateTimeImpl(Date.now() / 1000); },
            new_from_unix_utc: function (s) { return new DateTimeImpl(s); },
            new_from_iso8601: function (s /*, tz */) {
                var t = Date.parse(s);
                if (isNaN(t)) throw new Error("invalid iso8601: " + s);
                return new DateTimeImpl(t / 1000);
            },
            // Used in parseTimestamp instanceof check
            prototype: DateTimeImpl.prototype,
        },
        uuid_string_random: uuidv4,
    };
}());

// Patch instanceof support — `value instanceof GLib.DateTime` is used below.
// JavaScript's instanceof checks against a constructor, so alias the namespace.
GLib.DateTime = Object.assign(
    function () { throw new Error("Use GLib.DateTime.new_* factories"); },
    GLib.DateTime
);

// ---- Inline shim replacing `import { _ } from './i18n.js'` ------------------
function _(s) { return s; }

// ---- Polyfill GJS's String.prototype.format ---------------------------------
// GJS auto-extends String with a printf-style .format(). We only need %d here.
if (!String.prototype.format) {
    String.prototype.format = function () {
        var args = arguments;
        var i = 0;
        return this.replace(/%[ds]/g, function () { return String(args[i++]); });
    };
}

// =============================================================================
//  BEGIN verbatim section — keep diff against source minimal.
// =============================================================================

const STATUS_PRIORITY = ['down', 'degraded', 'maintenance', 'unknown', 'up'];
const DEFAULT_HISTORY_RANGE_SECONDS = 24 * 60 * 60;
const DEFAULT_HISTORY_POINTS = 24;

function normalizeStatus(value) {
    if (value === null || value === undefined)
        return 'unknown';

    if (typeof value === 'number') {
        switch (value) {
        case 0:
            return 'down';
        case 1:
            return 'up';
        case 2:
            return 'degraded';
        case 3:
            return 'maintenance';
        default:
            return 'unknown';
        }
    }

    const normalized = String(value).toLowerCase();
    if (['up', 'online', 'operational', 'ok'].includes(normalized))
        return 'up';
    if (['degraded', 'warning', 'partial'].includes(normalized))
        return 'degraded';
    if (['down', 'offline', 'critical', 'error', 'fail'].includes(normalized))
        return 'down';
    if (['maintenance', 'maintenance_mode'].includes(normalized))
        return 'maintenance';

    return 'unknown';
}

function parseLatency(value) {
    if (value === null || value === undefined)
        return null;

    if (typeof value === 'number')
        return Math.round(value);

    const parsed = Number.parseFloat(value);
    if (Number.isNaN(parsed))
        return null;

    return Math.round(parsed);
}

function parseTimestamp(value) {
    if (!value)
        return null;

    if (value instanceof GLib.DateTime)
        return value;

    if (typeof value === 'number') {
        if (value > 10_000_000_000)
            return GLib.DateTime.new_from_unix_utc(Math.floor(value / 1000));
        return GLib.DateTime.new_from_unix_utc(Math.floor(value));
    }

    if (typeof value === 'string') {
        try {
            return GLib.DateTime.new_from_iso8601(value, null);
        } catch (error) {
            const parsed = Number.parseInt(value, 10);
            if (!Number.isNaN(parsed))
                return parseTimestamp(parsed);
        }
    }

    return null;
}

function toUnixSeconds(dateTime) {
    if (!dateTime || typeof dateTime.to_unix !== 'function')
        return null;

    return dateTime.to_unix();
}

function buildHistorySeries(entries, nowSeconds, rangeSeconds, maxPoints) {
    if (!Number.isFinite(nowSeconds))
        nowSeconds = Math.floor(Date.now() / 1000);

    if (!Number.isFinite(rangeSeconds) || rangeSeconds <= 0)
        rangeSeconds = DEFAULT_HISTORY_RANGE_SECONDS;

    if (!Number.isFinite(maxPoints) || maxPoints <= 0)
        maxPoints = DEFAULT_HISTORY_POINTS;

    const start = nowSeconds - rangeSeconds;
    const bucketSize = rangeSeconds / maxPoints;
    const result = [];

    const sorted = Array.isArray(entries) ? entries.slice().sort((a, b) => a.timestamp - b.timestamp) : [];
    let index = 0;
    let currentStatus = 'unknown';

    while (index < sorted.length && sorted[index].timestamp < start) {
        currentStatus = sorted[index].status ?? currentStatus;
        index++;
    }

    for (let i = 0; i < maxPoints; i++) {
        const bucketEnd = Math.round(start + (i + 1) * bucketSize);
        while (index < sorted.length && sorted[index].timestamp <= bucketEnd) {
            currentStatus = sorted[index].status ?? currentStatus;
            index++;
        }

        result.push({
            status: currentStatus,
            timestamp: bucketEnd,
        });
    }

    return result;
}

function normalizeHeartbeatHistory(entries, { nowSeconds = null, rangeSeconds = DEFAULT_HISTORY_RANGE_SECONDS, maxPoints = DEFAULT_HISTORY_POINTS } = {}) {
    const list = Array.isArray(entries)
        ? entries
        : (entries?.heartbeatList ?? entries?.data ?? entries?.items ?? entries ?? []);

    if (!Array.isArray(list) || list.length === 0)
        return buildHistorySeries([], nowSeconds ?? Math.floor(Date.now() / 1000), rangeSeconds, maxPoints);

    const normalized = [];
    for (const entry of list) {
        if (!entry)
            continue;

        const status = normalizeStatus(entry.status ?? entry.up ?? entry.down ?? entry.heartbeat ?? entry.statusClass ?? entry.value);
        const timestamp = parseTimestamp(entry.time ?? entry.timestamp ?? entry.datetime ?? entry.created_at ?? entry.createdAt ?? entry.date ?? entry.heartbeat_time ?? entry.heartbeatTime);
        const unix = toUnixSeconds(timestamp);
        if (!unix)
            continue;

        normalized.push({ status, timestamp: unix });
    }

    const referenceNow = Number.isFinite(nowSeconds) ? nowSeconds : Math.floor(Date.now() / 1000);
    return buildHistorySeries(normalized, referenceNow, rangeSeconds, maxPoints);
}

function normalizeMonitor(monitor) {
    const status = normalizeStatus(monitor.status ?? monitor.statusClass);
    const latencyMs = parseLatency(monitor.ping ?? monitor.latency ?? monitor.responseTime);
    const lastCheck = parseTimestamp(monitor.lastCheck ?? monitor.lastHeartbeat ?? monitor.lastUpdated);
    const id = (monitor.id !== undefined && monitor.id !== null) ? String(monitor.id) : (monitor.slug ?? monitor.name ?? GLib.uuid_string_random());

    return {
        id,
        name: monitor.name ?? monitor.title ?? _('Unnamed monitor'),
        status,
        latencyMs,
        lastCheck,
        message: monitor.message ?? monitor.msg ?? monitor.lastMessage ?? null,
    };
}

function normalizeStatusPage(payload, { includeHistory = false, nowSeconds = null, historyRangeSeconds = DEFAULT_HISTORY_RANGE_SECONDS, historyPoints = DEFAULT_HISTORY_POINTS } = {}) {
    const monitors = [];
    const heartbeatMap = new Map();

    if (!payload)
        return { monitors, heartbeatMap };

    if (includeHistory) {
        const rawHeartbeatMap = payload.heartbeatList ?? payload.heartbeat_map ?? payload.heartbeat ?? {};
        for (const [monitorId, entries] of Object.entries(rawHeartbeatMap ?? {})) {
            const key = String(monitorId);
            heartbeatMap.set(key, normalizeHeartbeatHistory(entries, {
                nowSeconds,
                rangeSeconds: historyRangeSeconds,
                maxPoints: historyPoints,
            }));
        }
    }

    const list = payload.monitors ?? payload.data ?? [];
    const entries = Array.isArray(list) ? list : (list.monitors ?? Object.values(list));

    if (!entries)
        return { monitors, heartbeatMap };

    for (const item of entries) {
        if (!item)
            continue;

        const monitor = normalizeMonitor(item);
        if (includeHistory) {
            const candidates = [item.id, item.monitor_id, item.monitorId, monitor.id, item.slug];
            let series = null;
            for (const candidate of candidates) {
                if (candidate === undefined || candidate === null)
                    continue;
                const key = String(candidate);
                if (heartbeatMap.has(key)) {
                    series = heartbeatMap.get(key);
                    break;
                }
            }
            monitor.history = series ?? [];
        }

        monitors.push(monitor);
    }

    return { monitors, heartbeatMap };
}

function normalizeApi(payload) {
    if (!payload)
        return [];

    const entries = payload.monitors ?? payload.data ?? payload.result ?? [];
    if (!entries)
        return [];

    return entries.map(entry => normalizeMonitor(entry));
}

function parsePrometheusLabels(labelString) {
    const labels = {};
    const regex = /([A-Za-z_][A-Za-z0-9_]*)="([^"\\]*(?:\\.[^"\\]*)*)"/g;
    let match;
    while ((match = regex.exec(labelString)) !== null)
        labels[match[1]] = match[2].replace(/\\(.)/g, '$1');

    return labels;
}

function parsePrometheusLine(line) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#'))
        return null;

    const match = /^([A-Za-z_][\w:]*)\{([^}]*)\}\s+([^\s]+)$/.exec(trimmed);
    if (!match)
        return null;

    const [, metric, labelString, valueString] = match;
    const value = Number(valueString);
    if (!Number.isFinite(value))
        return null;

    const labels = parsePrometheusLabels(labelString);
    return { metric, labels, value };
}

function normalizeMetrics(text) {
    if (!text)
        return [];

    const monitors = new Map();

    for (const line of text.split('\n')) {
        const entry = parsePrometheusLine(line);
        if (!entry)
            continue;

        const { metric, labels, value } = entry;
        if (!labels.monitor_name)
            continue;

        const key = `${labels.monitor_name}::${labels.monitor_url ?? ''}`;
        const monitor = monitors.get(key) ?? {
            id: labels.monitor_id ?? labels.monitor_name,
            name: labels.monitor_name,
            status: 'unknown',
            latencyMs: null,
            lastCheck: null,
            message: null,
            type: labels.monitor_type ?? null,
        };

        switch (metric) {
        case 'monitor_status':
            monitor.status = normalizeStatus(value);
            break;
        case 'monitor_response_time':
            if (Number.isFinite(value) && value >= 0)
                monitor.latencyMs = Math.round(value);
            break;
        case 'monitor_cert_days_remaining':
            monitor._certDaysRemaining = value;
            break;
        case 'monitor_cert_is_valid':
            monitor._certValid = value === 1;
            break;
        default:
            break;
        }

        monitor.type = labels.monitor_type ?? monitor.type ?? null;
        monitors.set(key, monitor);
    }

    const result = [];
    for (const monitor of monitors.values()) {
        if (monitor._certValid === false) {
            monitor.message = _('Certificate invalid');
            if (monitor.status === 'up')
                monitor.status = 'degraded';
        } else if (typeof monitor._certDaysRemaining === 'number' && monitor._certDaysRemaining < 0) {
            const expiredDays = Math.abs(Math.round(monitor._certDaysRemaining));
            monitor.message = _('Certificate expired %d days ago').format(expiredDays);
            if (monitor.status === 'up')
                monitor.status = 'degraded';
        }

        delete monitor._certValid;
        delete monitor._certDaysRemaining;
        result.push(monitor);
    }

    return result;
}

function aggregateMonitors(monitors) {
    const summary = {
        up: 0,
        down: 0,
        degraded: 0,
        unknown: 0,
        total: 0,
        status: 'unknown',
    };

    if (!Array.isArray(monitors))
        return summary;

    let worstStatus = 'up';

    for (const monitor of monitors) {
        const status = monitor.status ?? 'unknown';
        if (status === 'down')
            summary.down++;
        else if (status === 'degraded' || status === 'maintenance')
            summary.degraded++;
        else if (status === 'up')
            summary.up++;
        else
            summary.unknown++;

        const currentWorstIndex = STATUS_PRIORITY.indexOf(worstStatus);
        const candidateIndex = STATUS_PRIORITY.indexOf(status);
        if (candidateIndex !== -1 && (currentWorstIndex === -1 || candidateIndex < currentWorstIndex))
            worstStatus = status;

        summary.total++;
    }

    summary.status = worstStatus === 'maintenance' ? 'degraded' : worstStatus;
    if (summary.total === 0)
        summary.status = 'unknown';

    return summary;
}

function mockMonitors() {
    const now = GLib.DateTime.new_now_utc();
    const nowSeconds = now.to_unix();
    const startSeconds = nowSeconds - DEFAULT_HISTORY_RANGE_SECONDS;
    const stepSeconds = DEFAULT_HISTORY_RANGE_SECONDS / DEFAULT_HISTORY_POINTS;

    const generateHistory = statuses => {
        if (!Array.isArray(statuses) || statuses.length === 0) {
            return buildHistorySeries([], nowSeconds, DEFAULT_HISTORY_RANGE_SECONDS, DEFAULT_HISTORY_POINTS);
        }

        const expanded = [];
        const points = Math.min(DEFAULT_HISTORY_POINTS, statuses.length);
        for (let i = 0; i < points; i++) {
            expanded.push({
                status: statuses[i],
                timestamp: Math.round(startSeconds + (i + 1) * stepSeconds),
            });
        }

        return buildHistorySeries(expanded, nowSeconds, DEFAULT_HISTORY_RANGE_SECONDS, DEFAULT_HISTORY_POINTS);
    };

    const create = (overrides = {}) => {
        const deltaSeconds = overrides.delta !== undefined ? overrides.delta : 60;
        return {
            id: overrides.id ?? GLib.uuid_string_random(),
            name: overrides.name,
            status: overrides.status,
            latencyMs: overrides.latencyMs ?? null,
            lastCheck: overrides.lastCheck ?? now.add_seconds(-deltaSeconds),
            message: overrides.message ?? null,
            history: overrides.history ?? generateHistory(overrides.historyStatuses ?? Array(DEFAULT_HISTORY_POINTS).fill(overrides.status ?? 'unknown')),
        };
    };

    return [
        create({
            name: _('Frontend'),
            status: 'up',
            latencyMs: 185,
            delta: 45,
            historyStatuses: Array(DEFAULT_HISTORY_POINTS).fill('up').map((value, index) => (index % 12 === 8 ? 'degraded' : value)),
        }),
        create({
            name: _('API Gateway'),
            status: 'degraded',
            latencyMs: 420,
            delta: 120,
            message: _('Slight latency increase detected'),
            historyStatuses: Array(DEFAULT_HISTORY_POINTS).fill('degraded').map((value, index) => (index % 10 >= 8 ? 'down' : value)),
        }),
        create({
            name: _('Database'),
            status: 'down',
            delta: 15,
            message: _('No heartbeat received'),
            historyStatuses: Array(DEFAULT_HISTORY_POINTS).fill('down').map((value, index) => (index % 14 < 9 ? 'up' : value)),
        }),
        create({
            name: _('Background Jobs'),
            status: 'up',
            latencyMs: 98,
            delta: 360,
            historyStatuses: Array(DEFAULT_HISTORY_POINTS).fill('up').map((value, index) => (index % 16 === 4 ? 'unknown' : value)),
        }),
        create({
            name: _('External Ping'),
            status: 'unknown',
            delta: 720,
            historyStatuses: Array(DEFAULT_HISTORY_POINTS).fill('unknown').map((value, index) => (index % 9 === 6 ? 'up' : value)),
        }),
    ];
}
