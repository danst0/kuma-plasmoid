# Uptime Kuma Plasmoid

KDE Plasma 6 widget that polls an [Uptime Kuma](https://github.com/louislam/uptime-kuma)
instance and shows monitor status in the panel and as a desktop widget.

Sister project of the GNOME Shell extension
[`uptime-kuma-indicator`](https://extensions.gnome.org/extension/8710/uptime-kuma-indicator/).

## Features

- **Panel + desktop** — same plasmoid, two form factors. Panel shows a status
  dot with optional summary text and a tooltip listing the down/degraded
  monitors. Desktop widget renders the full list inline.
- **Three fetch modes** — public status page (`status/<slug>/status.json`),
  private API (Bearer token), or Prometheus metrics with Basic auth.
- **API key in the keyring** — token stored via `secret-tool`, works with both
  KWallet and GNOME Keyring.
- **Notifications** — `notify-send` on every outage / degradation, optional
  recovery notifications. First refresh seeds without firing, and a
  clock-skew-based wake-up detection silences the diff after suspend so you
  don't get a flood of stale alerts.
- **24h uptime badges** per monitor, fetched from `/api/badge/<id>/uptime/24h`
  and color-coded (green ≥99.5 %, yellow ≥95 %, red below).
- **Demo mode** for screenshot-friendly mock monitors without touching a
  server.
- **i18n** — English and German strings shipped, gettext-based.

## Install (binary)

Either:

- KDE Store: search „Uptime Kuma" in *Get New Widgets…* and install with one
  click (once the store entry is approved).
- Manual: grab `kuma-plasmoid.plasmoid` from the [Releases page](https://github.com/danst0/kuma-plasmoid/releases),
  then right-click on the desktop → *Add Widgets…* → *Get New Widgets…* →
  *Install Widget from Local File* and pick the `.plasmoid`. Or:

  ```fish
  kpackagetool6 --type Plasma/Applet --install kuma-plasmoid.plasmoid
  ```

## Install (from source)

```fish
git clone https://github.com/danst0/kuma-plasmoid && cd kuma-plasmoid
make install            # kpackagetool6 --install + msgfmt for translations
make preview-panel      # plasmoidviewer in horizontal form factor
make preview-desktop    # plasmoidviewer in planar form factor
make upgrade            # after edits
make pack               # produces kuma-plasmoid.plasmoid
make lint               # qmllint on all QML (optional)
```

Requirements: `kpackagetool6`, `plasmoidviewer`, `gettext` (xgettext + msgfmt),
optionally `qmllint`. On Fedora: `sudo dnf install plasma-sdk`.

## Configuration

Right-click the widget → *Configure Uptime Kuma…*. Three tabs:

- **Connection** — base URL, fetch mode, slug/endpoint overrides, API key.
- **Appearance** — Normal vs. Compact panel layout, summary text, latency,
  uptime badges, service filter.
- **Notifications** — toggle outage + recovery alerts.

The API key field is masked; clicking *Save key* shells out to `secret-tool`,
which stores the token under `service=me.dumke.kuma key=apikey` in the
session keyring. Multiple plasmoid instances share the same key automatically.

### Fetch modes

| Mode | URL | Auth | Notes |
|---|---|---|---|
| Public status page | `${baseUrl}/status/${slug}/status.json` | none | Slug must exist as a published status page in Kuma. |
| Private API (token) | `${baseUrl}/${apiEndpoint}` (default `api/monitor`) | `Authorization: <token>` | Requires a Kuma fork/extension that exposes a JSON monitor list — vanilla Uptime Kuma has no such REST endpoint. |
| Prometheus metrics | `${baseUrl}/metrics` | Basic auth, user empty, password = token | Works with vanilla Uptime Kuma. The most reliable mode for private setups. |

## Logging

Logs are tagged `[kuma]` and end up in plasmashell's journal:

```fish
journalctl --user -f -t plasmashell | grep -i kuma
```

Verbosity is configurable in the Connection tab (`Error` / `Info` / `Debug`).
For raw QML/JS errors during development:

```fish
QT_LOGGING_RULES='*.debug=true' plasmoidviewer -a me.dumke.kuma
```

## License

GPL-3.0-or-later. Parser code in `contents/code/parsers.js` is a near-verbatim
copy from the GNOME variant — see file header for the source commit. Network
code is original Plasma-side work.
