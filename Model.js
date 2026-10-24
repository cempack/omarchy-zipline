// Pure helpers for the Zipline bar panel.
// Qt-free so Node can unit-test the same functions the QML imports.

var ACTIONS = {
  region: ["screenshot", "smart"],
  window: ["screenshot", "windows"],
  fullscreen: ["screenshot", "fullscreen"],
  recording: ["recording"],
  clipboard: ["clipboard"],
  file: ["file"],
  shorten: ["shorten"],
  last: ["last"]
}

// Screenshot actions wait for the panel to close so it isn't captured.
var CAPTURE_DELAY = "0.35"

function localPathFromUrl(url) {
  var value = String(url || "")
  if (value.indexOf("file://") === 0) value = value.slice(7)
  try {
    return decodeURIComponent(value)
  } catch (e) {
    return value
  }
}

function actionCommand(helperPath, action) {
  var args = ACTIONS[action]
  if (!args || !helperPath) return []
  var command = [helperPath]
  if (args[0] === "screenshot") command.push("--delay", CAPTURE_DELAY)
  return command.concat(args)
}

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

function setupCommand(helperPath) {
  if (!helperPath) return []
  return ["omarchy-launch-floating-terminal-with-presentation", shellQuote(helperPath) + " setup"]
}

function isLink(value) {
  return /^https?:\/\/[^\s]+$/.test(String(value || ""))
}

function hostOf(url) {
  var match = String(url || "").match(/^https?:\/\/([^\/?#]+)/)
  return match ? match[1] : ""
}

// `omarchy-zipline history` prints url<TAB>kind<TAB>name<TAB>time, newest first.
function parseHistory(text, limit) {
  var max = Math.max(1, Math.min(20, Number(limit) || 5))
  var rows = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length && rows.length < max; i++) {
    var fields = lines[i].split("\t")
    if (fields.length < 4 || !isLink(fields[0])) continue
    rows.push({ url: fields[0], kind: fields[1], name: fields[2], time: fields[3] })
  }
  return rows
}

function kindIcon(kind) {
  switch (kind) {
  case "screenshot": return "󰆞"
  case "recording": return "󰕧"
  case "clipboard": return "󰅇"
  case "shorten": return "󰌹"
  default: return "󰈔"
  }
}

function shortTime(iso, now) {
  var then = Date.parse(String(iso || ""))
  if (isNaN(then)) return ""
  var seconds = Math.max(0, Math.round(((now || Date.now()) - then) / 1000))
  if (seconds < 60) return "just now"
  if (seconds < 3600) return Math.floor(seconds / 60) + " min ago"
  if (seconds < 86400) return Math.floor(seconds / 3600) + " h ago"
  return Math.floor(seconds / 86400) + " d ago"
}

if (typeof module !== "undefined") {
  module.exports = {
    ACTIONS: ACTIONS,
    CAPTURE_DELAY: CAPTURE_DELAY,
    localPathFromUrl: localPathFromUrl,
    actionCommand: actionCommand,
    shellQuote: shellQuote,
    setupCommand: setupCommand,
    isLink: isLink,
    hostOf: hostOf,
    parseHistory: parseHistory,
    kindIcon: kindIcon,
    shortTime: shortTime
  }
}
