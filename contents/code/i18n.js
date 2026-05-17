.pragma library

// In QML the global i18n()/i18nc()/i18ncp() functions from KI18n are available
// directly. This file is just a stub so JS modules (parsers.js, network.js) that
// expect a `_` symbol can be wired up via the GLib-shim wrapper inside parsers.js.
//
// If you ever need to use gettext from a .pragma library JS file (which has no
// access to QML globals), wrap the call site in QML and pass the localized string
// in as a property instead.

function _(s) { return s; }
function ngettext(singular, plural, n) { return n === 1 ? singular : plural; }
