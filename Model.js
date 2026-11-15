// Pure helpers for the Zipline bar panel.
// Qt-free so Node can unit-test the same functions the QML imports.

// The plugin never captures the screen: Omarchy's Print key does that and puts
// the image on the clipboard, these actions only upload what already exists.
var ACTIONS = [
  { action: "clipboard", icon: "󰅇", label: "Clipboard", busy: "Uploading the clipboard…" },
  { action: "file", icon: "󰈔", label: "File", busy: "Uploading…" },
  { action: "recording", icon: "󰕧", label: "Recording", busy: "Uploading the recording…" },
  { action: "last", icon: "󰆏", label: "Last link", busy: "" }
]
var ACTION_COLUMNS = 2

// Upload options the panel offers. Expiry values are what Zipline's
// x-zipline-deletes-at header takes (ms durations); "" keeps the config default.
var EXPIRY_CHOICES = [
  { value: "", label: "Default" },
  { value: "1h", label: "1 hour" },
  { value: "1d", label: "1 day" },
  { value: "7d", label: "7 days" },
  { value: "30d", label: "30 days" }
]

// View limits the panel offers (0 = no limit). Zipline stops serving a file or
// short link after this many views (x-zipline-max-views).
var VIEW_CHOICES = [0, 1, 5, 10]

function nextViews(current, step) {
  var index = Math.max(0, VIEW_CHOICES.indexOf(Number(current) || 0))
  var n = VIEW_CHOICES.length
  return VIEW_CHOICES[((index + (step || 1)) % n + n) % n]
}

function viewsLabel(value) {
  var n = Number(value) || 0
  return n > 0 ? plural(n, "view") : "Unlimited"
}

function findAction(action) {
  for (var i = 0; i < ACTIONS.length; i++) if (ACTIONS[i].action === action) return ACTIONS[i]
  return null
}

function localPathFromUrl(url) {
  var value = String(url || "")
  if (value.indexOf("file://") === 0) value = value.slice(7)
  try {
    return decodeURIComponent(value)
  } catch (e) {
    return value
  }
}

function validExpiry(value) {
  for (var i = 0; i < EXPIRY_CHOICES.length; i++) if (EXPIRY_CHOICES[i].value === value) return true
  return false
}

// argv for one action. Only known actions and known option values make it
// into the command; everything is passed as separate arguments, never a shell.
function actionCommand(helperPath, action, options) {
  if (!helperPath || !findAction(action)) return []
  var args = [helperPath]
  var opts = options || {}
  // "last" only copies an existing link; uploads take the expiry and view limit
  // (a link on the clipboard is shortened by the clipboard action and gets the
  // view limit too; Zipline short links have no expiry).
  if (action !== "last") {
    if (opts.expires && validExpiry(opts.expires)) args.push("--expires", opts.expires)
    var views = Number(opts.maxViews)
    if (isFinite(views) && views >= 1 && Math.floor(views) === views) args.push("--max-views", String(views))
  }
  args.push(action)
  return args
}

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

// Omarchy's floating terminal joins its arguments into one bash -c string, so
// the helper path is quoted for that shell.
function setupCommand(helperPath) {
  if (!helperPath) return []
  return ["omarchy-launch-floating-terminal-with-presentation", shellQuote(helperPath) + " setup"]
}

function nextExpiry(current, step) {
  var index = 0
  for (var i = 0; i < EXPIRY_CHOICES.length; i++) if (EXPIRY_CHOICES[i].value === current) index = i
  var n = EXPIRY_CHOICES.length
  return EXPIRY_CHOICES[((index + (step || 1)) % n + n) % n].value
}

function expiryLabel(value) {
  for (var i = 0; i < EXPIRY_CHOICES.length; i++) if (EXPIRY_CHOICES[i].value === value) return EXPIRY_CHOICES[i].label
  return String(value || "")
}

function isLink(value) {
  return /^https?:\/\/[^\s]+$/.test(String(value || ""))
}

function hostOf(url) {
  var match = String(url || "").match(/^https?:\/\/([^\/?#]+)/)
  return match ? match[1] : ""
}

// `omarchy-zipline history` prints
// url<TAB>kind<TAB>name<TAB>time[<TAB>expires<TAB>max-views], newest first.
// Lines from before 3.0 have only the first four fields.
function parseHistory(text, limit) {
  var max = Math.max(1, Math.min(20, Number(limit) || 5))
  var rows = []
  var seen = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length && rows.length < max; i++) {
    var fields = lines[i].split("\t")
    if (fields.length < 4 || !isLink(fields[0]) || seen[fields[0]]) continue
    seen[fields[0]] = true
    var views = parseInt(fields[5] || "", 10)
    rows.push({
      url: fields[0],
      kind: fields[1],
      name: fields[2] || fields[0],
      time: fields[3],
      expires: fields[4] || "",
      maxViews: isFinite(views) && views > 0 ? views : 0
    })
  }
  return rows
}

// `omarchy-zipline status --json`; anything unreadable counts as an error.
function parseStatus(text) {
  var data = null
  try {
    data = JSON.parse(String(text || "").trim().split("\n").pop() || "null")
  } catch (e) {
    data = null
  }
  if (!data || typeof data !== "object" || typeof data.state !== "string")
    return { state: "error", server: "", user: "", error: "Could not read the plugin's status", stats: null }
  var stats = data.stats && typeof data.stats === "object" ? {
    files: Number(data.stats.files) || 0,
    storage: Number(data.stats.storage) || 0,
    views: Number(data.stats.views) || 0,
    urls: Number(data.stats.urls) || 0
  } : null
  return {
    state: data.state,
    server: String(data.server || ""),
    user: String(data.user || ""),
    error: String(data.error || ""),
    stats: stats
  }
}

// Whether uploads can even be tried: missing URL or token means setup first.
function needsSetup(state) {
  return state === "unconfigured" || state === "no-token"
}

function statusProblem(status) {
  if (!status) return ""
  switch (status.state) {
  case "rejected": return "The server refused the token. Run omarchy-zipline setup"
  case "unreachable": return "Can't reach " + (hostOf(status.server) || "the server")
  case "error": return status.error || "The server answered with an error"
  default: return ""
  }
}

function formatBytes(bytes) {
  var value = Number(bytes) || 0
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024
    i++
  }
  return (i === 0 || value >= 10 ? Math.round(value) : Math.round(value * 10) / 10) + " " + units[i]
}

function compactNumber(n) {
  var value = Number(n) || 0
  if (value < 1000) return String(Math.round(value))
  if (value < 1000000) return (Math.round(value / 100) / 10).toString().replace(/\.0$/, "") + "k"
  return (Math.round(value / 100000) / 10).toString().replace(/\.0$/, "") + "M"
}

function plural(n, word) {
  return n + " " + word + (n === 1 ? "" : "s")
}

function statsLine(stats) {
  if (!stats) return ""
  return [plural(stats.files, "file"), formatBytes(stats.storage), compactNumber(stats.views) + " views"].join(" · ")
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

function isImageName(name) {
  return /\.(png|jpe?g|gif|webp|avif|bmp|svg)$/i.test(String(name || ""))
}

// Markdown for pasting into issues and chats: images embed, the rest link.
function markdownLink(row) {
  if (!row || !isLink(row.url)) return ""
  var label = String(row.kind === "shorten" ? hostOf(row.name) || row.url : row.name || row.url)
    .replace(/[\[\]\\]/g, "")
  var image = row.kind === "screenshot" || (row.kind !== "shorten" && isImageName(row.name))
  return (image ? "!" : "") + "[" + label + "](" + row.url + ")"
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

// Second line of a recent row: host, age, then the limits it was uploaded with.
function rowDetail(row, now) {
  if (!row) return ""
  var parts = []
  var host = hostOf(row.kind === "shorten" ? row.name : row.url)
  if (row.kind === "shorten") parts.push("→ " + (host || row.name))
  else if (host) parts.push(host)
  var age = shortTime(row.time, now)
  if (age) parts.push(age)
  if (row.expires && row.expires !== "never") parts.push("󰔛 " + row.expires)
  if (row.maxViews > 0) parts.push("󰈈 " + plural(row.maxViews, "view"))
  return parts.join(" · ")
}

// First line of stderr from the CLI, without its "omarchy-zipline: " prefix.
function cliError(stderr, fallback) {
  var lines = String(stderr || "").split("\n")
  for (var i = lines.length - 1; i >= 0; i--) {
    var line = lines[i].trim()
    if (line === "") continue
    return line.replace(/^omarchy-zipline:\s*/, "")
  }
  return fallback || "Something went wrong"
}

function lastLink(stdout) {
  var lines = String(stdout || "").split("\n")
  for (var i = lines.length - 1; i >= 0; i--) if (isLink(lines[i].trim())) return lines[i].trim()
  return ""
}

// Cursor over the action grid (indices 0..ACTIONS.length-1, ACTION_COLUMNS
// wide) followed by the recent rows. Returns the new index.
function moveCursor(cursor, dx, dy, recentCount) {
  var actions = ACTIONS.length
  var total = actions + Math.max(0, recentCount || 0)
  var c = Math.max(0, Math.min(total - 1, cursor))
  if (c < actions) {
    var col = c % ACTION_COLUMNS
    if (dx !== 0) {
      var nextCol = col + dx
      if (nextCol >= 0 && nextCol < ACTION_COLUMNS) c += dx
      return c
    }
    var next = c + dy * ACTION_COLUMNS
    if (next < 0) return c
    if (next >= actions) return recentCount > 0 ? actions : c
    return next
  }
  if (dx !== 0) return c
  var row = c + dy
  if (row < actions) return actions - ACTION_COLUMNS
  return Math.min(total - 1, row)
}

if (typeof module !== "undefined") {
  module.exports = {
    ACTIONS: ACTIONS,
    ACTION_COLUMNS: ACTION_COLUMNS,
    EXPIRY_CHOICES: EXPIRY_CHOICES,
    VIEW_CHOICES: VIEW_CHOICES,
    nextViews: nextViews,
    viewsLabel: viewsLabel,
    findAction: findAction,
    localPathFromUrl: localPathFromUrl,
    actionCommand: actionCommand,
    shellQuote: shellQuote,
    setupCommand: setupCommand,
    nextExpiry: nextExpiry,
    expiryLabel: expiryLabel,
    isLink: isLink,
    hostOf: hostOf,
    parseHistory: parseHistory,
    parseStatus: parseStatus,
    needsSetup: needsSetup,
    statusProblem: statusProblem,
    formatBytes: formatBytes,
    compactNumber: compactNumber,
    statsLine: statsLine,
    kindIcon: kindIcon,
    isImageName: isImageName,
    markdownLink: markdownLink,
    shortTime: shortTime,
    rowDetail: rowDetail,
    cliError: cliError,
    lastLink: lastLink,
    moveCursor: moveCursor
  }
}
