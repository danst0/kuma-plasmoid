# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

KDE Plasma 6 plasmoid (QML + JS, no C++) that polls an Uptime Kuma instance and renders
monitor status in the panel and as a desktop widget. Applet ID `me.dumke.kuma`,
KConfigXT-backed config. Targets Plasma 6.0+.

Sister project of the GNOME Shell extension at
`/home/danst/Nextcloud/Projekte/2025-10 Uptime Kuma Widget Gnome/` — many of the
JS-layer files (`parsers.js`, `network.js`) are derived from that codebase. See file
headers for source commit references.

## Common commands

All run from the repo root:

| Command | What it does |
|---|---|
| `make install` | `kpackagetool6 --install` (first time) |
| `make upgrade` | `kpackagetool6 --upgrade` (after edits) |
| `make preview-panel` | `plasmoidviewer6 -a me.dumke.kuma -f horizontal` |
| `make preview-desktop` | `plasmoidviewer6 -a me.dumke.kuma -f planar` |
| `make lint` | `qmllint6` over `contents/ui/*.qml` |
| `make pot` | Extract `.pot` via `xgettext` |
| `make translations` | Compile every `.po` to `.mo` |
| `make pack` | Build distributable `.plasmoid` archive |
| `make clean` | Remove build artifacts |

After upgrading, no shell reload is needed if the plasmoid is re-added; for instances
already on the panel, run `kquitapp6 plasmashell && kstart plasmashell` if QML cache
gets stale.

Tail logs: `journalctl --user -f -t plasmashell | grep -i kuma`. Log prefix in code is
`[kuma]`. Log level is controlled by the `logLevel` KConfig key (`Error`/`Info`/`Debug`).

For verbose QML/JS errors during iteration:
`QT_LOGGING_RULES='*.debug=true' plasmoidviewer6 -a me.dumke.kuma`.

The fastest UI smoke test is enabling Demo Mode in the plasmoid config — `mockMonitors()`
from `contents/code/parsers.js` feeds the UI without any network.

## Architecture

### `contents/ui/main.qml` — root + lifecycle

`PlasmoidItem` root. Owns a `Timer` driven by `cfg_refreshSeconds` (min 10s) and a
`ListModel` of monitor records. Picks `compactRepresentation` vs `fullRepresentation`
based on `Plasmoid.formFactor`. Triggers refresh on config change, app focus, and the
suspend/resume DBus signal (later milestone).

### `contents/ui/CompactRepresentation.qml` — panel

`MouseArea` + status dot + optional summary text (`X up / Y down / Z total`). Clicking
toggles the popup `fullRepresentation`.

### `contents/ui/FullRepresentation.qml` — popup / desktop

`PlasmaComponents3.ScrollView` wrapping a `ListView` of `MonitorRow` items. Header row
with refresh button + current aggregate status; footer with last-update timestamp.

### `contents/ui/MonitorRow.qml`, `StatusDot.qml`, `UptimeBadge.qml`, `EmptyState.qml`

Reusable presentational components. `StatusDot` maps `ok/warn/fail/unknown` to
`Kirigami.Theme.positiveTextColor` / `neutralTextColor` / `negativeTextColor` /
`disabledTextColor`, falling back to fixed colors matching the GNOME version.

### `contents/code/parsers.js` — data normalizers

Verbatim copy from the GNOME project (see file header for commit hash). Two changes
from upstream:
- ESM imports replaced with a tiny inline `GLib` shim providing `DateTime` (subset:
  `new_now_utc`, `new_from_unix_utc`, `new_from_iso8601`, `.to_unix()`,
  `.add_seconds()`) and `uuid_string_random()` (UUIDv4).
- `String.prototype.format` polyfilled (GJS extends String automatically; vanilla JS
  does not).

Everything else is byte-identical to keep future syncs trivial (diff and merge).

### `contents/code/network.js` (later milestones)

Port of GNOME `utils/network.js`. Single `XMLHttpRequest` factory in QML, retry/backoff
loop with timer-based scheduling, active-request tracking for cancellation on
suspend/destroy. Mode dispatch (status-page / api-key / metrics) is identical to source.

### `contents/code/secrets.js` (M3)

API key read/write via `secret-tool` shell-out (works for both KWallet and GNOME Keyring
since both implement `org.freedesktop.secrets`). Attribute scheme:
`service=me.dumke.kuma`.

### `contents/config/main.xml` — KConfigXT schema

Source of truth for every setting. 18 entries, all camelCase. **API key is NOT here** —
it lives in Secret Service. Settings are accessed in QML as `Plasmoid.configuration.<name>`
or as `cfg_<name>` in config pages.

### i18n

`contents/locale/<lang>/LC_MESSAGES/kuma-plasmoid.po` compiled to `.mo`. `contents/code/i18n.js`
re-exports `i18n` / `i18nc` / `i18ncp` from the KI18n globals available in Plasma QML.

## Versioning / releases

`metadata.json` `KPlugin.Version` is the human version. Bump it and update the README
"What's New" before tagging. Tag format `v<version>` matches the sister project.

## Conventions worth knowing

- Pure QML/JS — no C++, no CMake. Build is `kpackagetool6` only.
- Long-running resources (XMLHttpRequest, Timer, DBus connections) must be torn down in
  `Component.onDestruction` — Plasma keeps the QML engine alive across applet removal
  and re-add, so leaks bloat plasmashell memory.
- Don't store secrets in KConfig — always in Secret Service.
- Keep `parsers.js` in sync with upstream by re-running the verbatim-copy step with the
  new commit hash; don't drift the file locally.
