# Uptime Kuma Plasmoid

A KDE Plasma 6 widget that polls an [Uptime Kuma](https://github.com/louislam/uptime-kuma)
instance and shows monitor status in the panel and as a desktop widget.

Sister project of the GNOME Shell extension
[`uptime-kuma-indicator`](https://extensions.gnome.org/extension/8710/uptime-kuma-indicator/).

## Status

Early scaffolding (M1). See `docs/ARCHITECTURE.md` and the plan file for the roadmap.

## Install (development)

```fish
make install            # kpackagetool6 --install
make upgrade            # kpackagetool6 --upgrade (after edits)
make preview-panel      # plasmoidviewer6 in horizontal form factor
make preview-desktop    # plasmoidviewer6 in planar form factor
make lint               # qmllint6 on all QML
make pack               # produces .plasmoid archive for distribution
```

## Configuration modes

Same three fetch strategies as the GNOME variant:

- **Status page** — public `status/<slug>/status.json`
- **API key** — private `api/monitor` with bearer token (stored in `secret-tool` /
  KWallet, not in KConfig)
- **Metrics** — Prometheus `metrics` endpoint

## License

GPL-3.0-or-later. Parser code in `contents/code/parsers.js` is derived from the
GNOME extension — see file header for source commit.
