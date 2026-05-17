.pragma library

// =============================================================================
//  Adapted from:  uptime-kuma-indicator/utils/network.js
//  From:          https://github.com/danst0/gnome-uptime-kuma
//  Commit:        0ed98918c44d2ec38d37543d8f4b5c765fbb36c0
//  License:       GPL-3.0-or-later
//
//  Unlike parsers.js, this file is *not* a verbatim copy — GJS-only APIs
//  (Soup.Session, GLib.timeout_add) have no QML equivalent. The mode dispatch,
//  retry/backoff timing, and helpers below mirror the upstream behaviour.
// =============================================================================

const DEFAULT_TIMEOUT_SECONDS = 8;
const DEFAULT_RETRIES = 3;
const RETRY_BACKOFF = 1.6;
const RETRY_INITIAL_MS = 400;
const RETRY_MAX_MS = 4000;
const USER_AGENT = "UptimeKumaPlasmoid/1.0";
const BADGE_PERCENTAGE_PATTERN = />\s*(\d+(?:[.,]\d+)?)\s*%/;

function joinUrl(base, path) {
    if (!base) return path;
    if (!path) return base;
    if (path.indexOf("http://") === 0 || path.indexOf("https://") === 0)
        return path;
    const cleanedBase = base.endsWith("/") ? base.slice(0, -1) : base;
    const cleanedPath = path.startsWith("/") ? path.slice(1) : path;
    return cleanedBase + "/" + cleanedPath;
}

function parseBadgePercentage(svg) {
    if (typeof svg !== "string" || svg.length === 0)
        return null;
    const match = BADGE_PERCENTAGE_PATTERN.exec(svg);
    if (!match) return null;
    const normalized = match[1].replace(",", ".");
    const value = Number.parseFloat(normalized);
    return Number.isFinite(value) ? value : null;
}

function resolveApiMode(raw) {
    if (raw === "metrics") return "metrics";
    if (raw === "api-key") return "api-key";
    return "status-page";
}

class MonitorFetcher {
    constructor(options) {
        options = options || {};
        if (!options.qmlParent)
            throw new Error("MonitorFetcher requires qmlParent for Timer creation");

        this._qmlParent = options.qmlParent;
        this._timeoutMs = (options.timeoutSeconds || DEFAULT_TIMEOUT_SECONDS) * 1000;
        this._retries = options.retries || DEFAULT_RETRIES;
        this._backoff = options.backoff || RETRY_BACKOFF;
        this._parsers = options.parsers;
        this._logger = options.logger || null;

        this._activeXhrs = new Set();
        this._activeTimers = new Set();
        this._destroyed = false;
    }

    destroy() {
        this._destroyed = true;
        for (const xhr of this._activeXhrs) {
            try { xhr.abort(); } catch (e) { /* ignore */ }
        }
        this._activeXhrs.clear();
        for (const timer of this._activeTimers) {
            try { timer.stop(); timer.destroy(); } catch (e) { /* ignore */ }
        }
        this._activeTimers.clear();
    }

    fetch(config, helpers) {
        helpers = helpers || {};
        const mode = resolveApiMode(config.apiMode);

        if (mode === "status-page")
            return this._fetchStatusPage(config);
        if (mode === "metrics")
            return this._fetchMetrics(config, helpers);
        return this._fetchPrivateApi(config, helpers);
    }

    fetchUptimeBadge(monitorId, config) {
        if (monitorId === undefined || monitorId === null)
            return Promise.resolve(null);
        if (!config.baseUrl)
            return Promise.reject(new Error("Base URL is missing."));

        const encodedId = encodeURIComponent(String(monitorId));
        const url = joinUrl(config.baseUrl, "api/badge/" + encodedId + "/uptime/24h");
        return this._request(url, {
            headers: { "Accept": "image/svg+xml,*/*;q=0.8" }
        }).then(svg => ({
            svg: svg,
            percentage: parseBadgePercentage(svg)
        }));
    }

    _fetchStatusPage(config) {
        if (!config.baseUrl)
            return Promise.reject(new Error("Base URL is missing."));

        let endpoint = config.statusPageJsonUrl || "";
        if (!endpoint) {
            const template = config.statusPageEndpoint || "status/{{slug}}/status.json";
            const slug = encodeURIComponent(config.statusPageSlug || "default");
            endpoint = template.indexOf("{{slug}}") >= 0
                ? template.replace("{{slug}}", slug)
                : template + "/" + slug;
        }
        const url = joinUrl(config.baseUrl, endpoint);
        this._log("debug", "fetch status-page: " + url);

        return this._getJson(url, { headers: { "Accept": "application/json" } })
            .then(json => {
                const { monitors, heartbeatMap } = this._parsers.normalizeStatusPage(json);
                return { source: "status-page", monitors: monitors, heartbeatMap: heartbeatMap };
            });
    }

    _fetchPrivateApi(config, helpers) {
        if (!config.baseUrl)
            return Promise.reject(new Error("Base URL is missing."));

        return this._resolveApiKey(helpers).then(apiKey => {
            if (!apiKey)
                throw new Error("API token is not available.");

            const endpoint = config.apiEndpoint || "api/monitor";
            const url = joinUrl(config.baseUrl, endpoint);
            this._log("debug", "fetch api: " + url);

            return this._getJson(url, {
                headers: {
                    "Accept": "application/json",
                    "Authorization": apiKey
                }
            });
        }).then(json => ({
            source: "api",
            monitors: this._parsers.normalizeApi(json)
        }));
    }

    _fetchMetrics(config, helpers) {
        if (!config.baseUrl)
            return Promise.reject(new Error("Base URL is missing."));

        return this._resolveApiKey(helpers).then(apiKey => {
            if (!apiKey)
                throw new Error("API token is not available.");

            const endpoint = config.metricsEndpoint || "metrics";
            const url = joinUrl(config.baseUrl, endpoint);
            this._log("debug", "fetch metrics: " + url);

            const encoded = Qt.btoa(":" + apiKey);
            return this._request(url, {
                headers: {
                    "Accept": "text/plain",
                    "Authorization": "Basic " + encoded
                }
            });
        }).then(text => ({
            source: "metrics",
            monitors: this._parsers.normalizeMetrics(text)
        }));
    }

    _resolveApiKey(helpers) {
        if (!helpers || typeof helpers.getApiKey !== "function")
            return Promise.resolve(null);
        try {
            const result = helpers.getApiKey();
            return Promise.resolve(result);
        } catch (error) {
            return Promise.reject(error);
        }
    }

    _getJson(url, options) {
        return this._request(url, options).then(text => {
            if (!text) return null;
            try {
                return JSON.parse(text);
            } catch (error) {
                const trimmed = text.trim();
                const looksLikeHtml = trimmed.startsWith("<");
                const hint = looksLikeHtml
                    ? "server returned HTML (wrong slug or endpoint URL?)"
                    : ("response: " + trimmed.slice(0, 80));
                throw new Error("Invalid JSON — " + hint);
            }
        });
    }

    _request(url, options) {
        options = options || {};
        const headers = options.headers || {};
        const method = options.method || "GET";
        const self = this;

        return new Promise((resolve, reject) => {
            let attempt = 0;
            let waitMs = RETRY_INITIAL_MS;
            let lastError = null;

            function scheduleRetry() {
                attempt++;
                if (attempt >= self._retries) {
                    reject(lastError || new Error("Unknown network error"));
                    return;
                }
                const delay = waitMs;
                waitMs = Math.min(waitMs * self._backoff, RETRY_MAX_MS);
                self._delay(delay).then(tryOnce, reject);
            }

            function tryOnce() {
                if (self._destroyed) {
                    reject(new Error("Fetcher destroyed"));
                    return;
                }

                const xhr = new XMLHttpRequest();
                self._activeXhrs.add(xhr);
                xhr.timeout = self._timeoutMs;

                xhr.onreadystatechange = function () {
                    if (xhr.readyState !== XMLHttpRequest.DONE) return;
                    self._activeXhrs.delete(xhr);

                    if (self._destroyed) {
                        reject(new Error("Fetcher destroyed"));
                        return;
                    }

                    // status 0 → network/abort/CORS/TLS error
                    if (xhr.status === 0) {
                        lastError = new Error("Network error (DNS, TLS, or connection refused)");
                        scheduleRetry();
                        return;
                    }
                    if (xhr.status >= 200 && xhr.status < 300) {
                        resolve(xhr.responseText);
                        return;
                    }
                    lastError = new Error("HTTP " + xhr.status);
                    scheduleRetry();
                };

                xhr.ontimeout = function () {
                    self._activeXhrs.delete(xhr);
                    lastError = new Error("Request timed out");
                    scheduleRetry();
                };

                try {
                    xhr.open(method, url, true);
                    xhr.setRequestHeader("User-Agent", USER_AGENT);
                    for (const key in headers) {
                        if (Object.prototype.hasOwnProperty.call(headers, key))
                            xhr.setRequestHeader(key, headers[key]);
                    }
                    xhr.send(options.body || null);
                } catch (error) {
                    self._activeXhrs.delete(xhr);
                    lastError = error;
                    scheduleRetry();
                }
            }

            tryOnce();
        });
    }

    _delay(ms) {
        const self = this;
        return new Promise((resolve, reject) => {
            if (self._destroyed) {
                reject(new Error("Fetcher destroyed"));
                return;
            }
            const timer = Qt.createQmlObject(
                'import QtQuick; Timer { repeat: false }',
                self._qmlParent,
                "MonitorFetcher.delay"
            );
            timer.interval = ms;
            self._activeTimers.add(timer);
            timer.triggered.connect(() => {
                self._activeTimers.delete(timer);
                timer.destroy();
                if (self._destroyed) {
                    reject(new Error("Fetcher destroyed"));
                } else {
                    resolve();
                }
            });
            timer.start();
        });
    }

    _log(level, msg) {
        if (!this._logger) return;
        if (level === "debug" && typeof this._logger.debug === "function")
            this._logger.debug(msg);
        else if (level === "error" && typeof this._logger.error === "function")
            this._logger.error(msg);
        else if (typeof this._logger.info === "function")
            this._logger.info(msg);
    }
}
