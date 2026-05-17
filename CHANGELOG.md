# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning
follows the `KPlugin.Version` field in `metadata.json`.

## [0.6.0] — 2026-05-17

### Added
- Wake-up detection: if the poll timer goes silent for more than 3× its
  interval, the next refresh is treated as a fresh seed and the notification
  diff is skipped — no flood of stale alerts after suspend/resume.
- Refresh on popup expand (throttled to once per 5 s) so opening the popup
  always shows current data.
- Vertical-panel support: square icon, summary text hidden.
- i18n: `make pot` extraction, runtime/config strings wrapped, German `.po`
  with 63 translated strings shipped (catalog `plasma_applet_me.dumke.kuma`).

## [0.5.0] — 2026-05-17

### Added
- 24h uptime badges per monitor row, fetched from `/api/badge/<id>/uptime/24h`
  (no auth required). 5-minute fetch throttle, color-coded against
  Kirigami's positive/neutral/negative palette.
- Reactive relative-time labels — `Xm ago` / `Xh ago` tick every minute
  without needing a full Kuma refetch.
- `UptimeBadge.qml` component.

## [0.4.0] — 2026-05-17

### Added
- Notification trigger logic via `notify-send`. Status diff per refresh:
  critical urgency for new outages, normal for degraded and recovery.
  Respects `enableNotifications` and `notifyOnRecovery`. First refresh
  seeds without firing.
- `configAppearance.qml` — panel appearance (Normal / Compact), show-text,
  show-latency, show-badges, show-uptime, service filter.
- `configNotifications.qml` — notification toggles.
- `ConfigBase.qml` — KCM-page base declaring every `cfg_*` and
  `cfg_*Default` absorber so individual pages stay readable.
- Service filter (`selectedServices`) applied to the monitor list before
  rendering, summary aggregation, and notification diffing.
- Plasma-native panel tooltip listing down/degraded monitors.
- Click handler now uses the explicit `plasmoidItem` reference (the
  `Plasmoid` attached singleton's `expanded` property is read-only in
  sub-components).

## [0.3.0] — 2026-05-17

### Added
- API key storage via `secret-tool` (`secrets.js`). Works with both KWallet
  and GNOME Keyring through `org.freedesktop.secrets`.
- `ShellExecutor.qml` — wrapper around `Plasma5Support.DataSource`'s
  executable engine with a clean `exec(cmd, callback)` API.
- `configConnection.qml` — first config page: base URL, fetch mode,
  endpoints, masked API key field with *Save* / *Clear* buttons and live
  keyring status.
- `MonitorFetcher` now accepts a `helpers.getApiKey` callback; lookup is
  lazy and cached per-instance.

## [0.2.0] — 2026-05-17

### Added
- `network.js` — `MonitorFetcher` class. XMLHttpRequest-based, retry/backoff
  via `Qt.createQmlObject` timers, abort-on-destroy. Mode dispatch
  (status-page / api-key / metrics) mirrors the GNOME upstream.
- Live refresh loop in `main.qml`, real-error display in the empty state,
  manual refresh button in the popup header.
- Makefile fallbacks for systems where Plasma CLI tools ship without a `6`
  suffix (Fedora).

### Fixed
- TDZ warnings on `scheduleRetry` (function declarations instead of arrow
  consts).
- `Component.onDestruction` properly tears down the fetcher.

## [0.1.0] — 2026-05-17

### Added
- M1 scaffolding: `PlasmoidItem` root, `CompactRepresentation`,
  `FullRepresentation`, `MonitorRow`, `StatusDot`, `EmptyState`.
- Parser library `parsers.js` ported verbatim from the GNOME variant with a
  minimal GLib shim.
- KConfigXT schema (`main.xml`) with 18 settings.
- Demo Mode toggle renders mock monitors so the UI is testable without a
  server.
