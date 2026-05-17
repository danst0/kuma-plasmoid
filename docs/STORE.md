# KDE Store submission notes

Copy-paste material for the store.kde.org product form. Drop the file once the
listing is live.

## Category

*Plasma 6 → Widgets → Status & Notifications* (or *System*).

## Short summary (title-bar tagline)

> Monitor your Uptime Kuma instance from the Plasma panel or desktop.

## Long description

```markdown
A KDE Plasma 6 widget for [Uptime Kuma](https://github.com/louislam/uptime-kuma).
Lives in the panel as a small coloured dot with an aggregate count, or sits on
the desktop with the full monitor list inline.

## Features

- **Three fetch modes** — public status page, private API (token), or
  Prometheus metrics with Basic auth. Pick whichever your Kuma instance exposes.
- **API key in the keyring** — token stored via `secret-tool`, works with
  both KWallet and GNOME Keyring.
- **Notifications** — `notify-send` on every outage and degradation; optional
  recovery alerts. Suspend/resume aware so you don't get a flood of stale
  alerts after the laptop wakes up.
- **24h uptime badges** per monitor, color-coded.
- **Compact or full layout**, panel or desktop, vertical or horizontal panels.
- **Service filter** to show only the monitors that matter to you.
- **Demo mode** for trying the UI without a server.
- Localized: English, German, Swedish, Japanese, Spanish.

## Configuration

Right-click the widget → *Configure Uptime Kuma…*. Three tabs:
*Connection*, *Appearance*, *Notifications*.

For most self-hosted Uptime Kuma setups, the **Prometheus metrics** mode is
the most reliable choice — vanilla Uptime Kuma doesn't expose a JSON
monitor list, so the "Private API (token)" mode only works with forks.

## Source

[github.com/danst0/kuma-plasmoid](https://github.com/danst0/kuma-plasmoid)
— issues and PRs welcome.

## License

GPL-3.0-or-later.
```

## Kurzbeschreibung (Deutsch)

> Überwache deine Uptime-Kuma-Instanz direkt im Plasma-Panel oder auf dem Desktop.

## Lange Beschreibung (Deutsch)

```markdown
KDE-Plasma-6-Widget für [Uptime Kuma](https://github.com/louislam/uptime-kuma).
Wahlweise als kleiner farbiger Status-Punkt im Panel oder als vollständige
Monitor-Liste auf dem Desktop.

## Funktionen

- **Drei Abruf-Modi** — öffentliche Status-Seite, private API (Token) oder
  Prometheus-Metriken mit Basic Auth.
- **API-Schlüssel im Schlüsselbund** — Token wird via `secret-tool` gespeichert,
  funktioniert mit KWallet und GNOME Keyring.
- **Benachrichtigungen** — `notify-send` bei Ausfall, Beeinträchtigung und
  optional bei Wiederherstellung. Suspend/Resume-aware: keine Flut alter
  Meldungen nach dem Aufwachen.
- **24-h-Uptime-Badges** pro Monitor, farbcodiert.
- **Kompakte oder vollständige Darstellung**, Panel oder Desktop, horizontal
  oder vertikal.
- **Dienst-Filter** zeigt nur die Monitore, die dich interessieren.
- **Demo-Modus** zum Ausprobieren ohne Server.
- Übersetzt: Englisch, Deutsch, Schwedisch, Japanisch, Spanisch.

## Lizenz

GPL-3.0-or-later.
```

## Tags

`uptime-kuma`, `monitoring`, `status`, `notifications`, `panel`, `widget`,
`plasma6`, `network`, `system`

## Screenshots to prepare

1. **Panel + tooltip**: panel plasmoid showing red dot with summary text, mouse
   hovering to reveal the tooltip listing the down monitors.
2. **Popup**: full monitor list with mixed up/degraded/down rows, badges
   visible, latency + relative time visible.
3. **Desktop widget**: planar form factor, same as popup but pinned.
4. **Config dialog — Connection**: Prometheus metrics mode selected, API key
   field shown with "Stored (44 characters)" status.
5. *(optional)* **Notification**: a `notify-send` toast showing a "Down" alert.

Tip for screenshots: enable Demo Mode so screenshots are reproducible without
exposing real infrastructure names. The mock data includes one of each status.

## Submission checklist

- [ ] `make pack` produces `kuma-plasmoid.plasmoid`
- [ ] `unzip -l kuma-plasmoid.plasmoid` shows `.mo` files for de/sv/ja/es
- [ ] `metadata.json` Version matches `CHANGELOG.md` top entry
- [ ] Tag pushed (`git tag v0.6.0 && git push origin v0.6.0`)
- [ ] GitHub Release uploaded with `kuma-plasmoid.plasmoid` attached
- [ ] Store form submitted with title, summary, long description, screenshots
- [ ] Source URL set in store form matches `metadata.json` `Website` field
