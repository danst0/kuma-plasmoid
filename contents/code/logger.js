.pragma library

// Log levels matched to GSettings enum from the GNOME variant:
//   Error=0, Info=1, Debug=2
var LEVEL_ERROR = 0;
var LEVEL_INFO = 1;
var LEVEL_DEBUG = 2;

var _level = LEVEL_INFO;
var PREFIX = "[kuma]";

function setLevel(name) {
    if (name === "Error" || name === 0) _level = LEVEL_ERROR;
    else if (name === "Debug" || name === 2) _level = LEVEL_DEBUG;
    else _level = LEVEL_INFO;
}

function error() {
    if (_level < LEVEL_ERROR) return;
    var args = Array.prototype.slice.call(arguments);
    console.warn.apply(console, [PREFIX].concat(args));
}

function info() {
    if (_level < LEVEL_INFO) return;
    var args = Array.prototype.slice.call(arguments);
    console.log.apply(console, [PREFIX].concat(args));
}

function debug() {
    if (_level < LEVEL_DEBUG) return;
    var args = Array.prototype.slice.call(arguments);
    console.log.apply(console, [PREFIX, "[debug]"].concat(args));
}
