#!/usr/bin/env node
"use strict"

const assert = require("assert")
const Model = require("../Model.js")

const helper = "/home/u/.config/omarchy/plugins/io.github.cempack.zipline/bin/omarchy-zipline"

// Actions: only the four panel actions, options passed as separate argv.
assert.deepStrictEqual(Model.ACTIONS.map(a => a.action), ["clipboard", "file", "recording", "last"])
assert.deepStrictEqual(Model.actionCommand(helper, "clipboard"), [helper, "clipboard"])
assert.deepStrictEqual(Model.actionCommand(helper, "file", { expires: "7d", maxViews: 1 }), [helper, "--expires", "7d", "--max-views", "1", "file"])
assert.deepStrictEqual(Model.actionCommand(helper, "last", { expires: "7d", maxViews: 5 }), [helper, "last"], "copying the last link takes no options")
assert.deepStrictEqual(Model.actionCommand(helper, "file", { expires: "; rm -rf ~", maxViews: "1; x" }), [helper, "file"], "unknown option values are dropped")
assert.deepStrictEqual(Model.actionCommand(helper, "file", { maxViews: 2.5 }), [helper, "file"])
for (const bad of ["screenshot", "setup", "shorten", "rm -rf", "region", "window", "fullscreen"])
  assert.deepStrictEqual(Model.actionCommand(helper, bad), [], bad)
assert.deepStrictEqual(Model.actionCommand("", "clipboard"), [])

// Setup runs in Omarchy's terminal, which joins argv into one bash -c string.
assert.deepStrictEqual(Model.setupCommand("/a b/it's/x"), ["omarchy-launch-floating-terminal-with-presentation", "'/a b/it'\\''s/x' setup"])
assert.deepStrictEqual(Model.setupCommand(""), [])

// Option cycling.
assert.strictEqual(Model.nextExpiry("", 1), "1h")
assert.strictEqual(Model.nextExpiry("", -1), "30d")
assert.strictEqual(Model.expiryLabel(""), "Default")
assert.strictEqual(Model.nextViews(0, 1), 1)
assert.strictEqual(Model.nextViews(10, 1), 0)
assert.strictEqual(Model.nextViews(0, -1), 10)
assert.strictEqual(Model.viewsLabel(0), "Unlimited")
assert.strictEqual(Model.viewsLabel(1), "1 view")
assert.strictEqual(Model.viewsLabel(5), "5 views")

// Paths and links.
assert.strictEqual(Model.localPathFromUrl("file:///home/u/My%20Plugins/bin/x"), "/home/u/My Plugins/bin/x")
assert.strictEqual(Model.hostOf("https://i.example.com/u/abc.png"), "i.example.com")
assert.strictEqual(Model.hostOf("not a url"), "")
assert.ok(Model.isLink("https://x.test/a"))
assert.ok(!Model.isLink("javascript:alert(1)"))
assert.ok(!Model.isLink("https://x.test/a b"))

// History: old 4-field and new 6-field lines, non-links dropped, duplicates collapsed.
const history = [
  "https://x.test/u/1.png\tscreenshot\tscreenshot-1.png\t2026-10-24T10:00:00+02:00\t1d\t3",
  "garbage line",
  "file:///etc/passwd\tfile\tpasswd\t2026-10-24T10:00:00+02:00",
  "https://x.test/go/abc\tshorten\thttps://example.com\t2026-10-24T09:00:00+02:00",
  "https://x.test/u/1.png\tscreenshot\tscreenshot-1.png\t2026-10-24T08:00:00+02:00",
  ""
].join("\n")
const rows = Model.parseHistory(history, 5)
assert.strictEqual(rows.length, 2)
assert.deepStrictEqual(rows[0], { url: "https://x.test/u/1.png", kind: "screenshot", name: "screenshot-1.png", time: "2026-10-24T10:00:00+02:00", expires: "1d", maxViews: 3 })
assert.strictEqual(rows[1].expires, "")
assert.strictEqual(rows[1].maxViews, 0)
assert.strictEqual(Model.parseHistory(history, 1).length, 1)

const now = Date.parse("2026-10-24T10:00:00+02:00")
assert.strictEqual(Model.rowDetail(rows[0], now), "x.test · just now · 󰔛 1d · 󰈈 3 views")
assert.strictEqual(Model.rowDetail(rows[1], now), "→ example.com · 1 h ago")
assert.strictEqual(Model.shortTime("2026-10-24T09:30:00+02:00", now), "30 min ago")
assert.strictEqual(Model.shortTime("2026-10-21T10:00:00+02:00", now), "3 d ago")
assert.strictEqual(Model.shortTime("nope", now), "")

// Markdown: images embed, short links label with the destination host.
assert.strictEqual(Model.markdownLink(rows[0]), "![screenshot-1.png](https://x.test/u/1.png)")
assert.strictEqual(Model.markdownLink(rows[1]), "[example.com](https://x.test/go/abc)")
assert.strictEqual(Model.markdownLink({ url: "https://x.test/u/a.pdf", kind: "file", name: "a [draft].pdf" }), "[a draft.pdf](https://x.test/u/a.pdf)")
assert.strictEqual(Model.markdownLink({ url: "javascript:x", kind: "file", name: "a" }), "")

// Status from `omarchy-zipline status --json`.
const ok = Model.parseStatus('{"state":"ok","server":"https://z.test","user":"me","error":"","stats":{"files":3,"storage":1536,"views":1200,"urls":1}}')
assert.strictEqual(ok.user, "me")
assert.strictEqual(Model.statsLine(ok.stats), "3 files · 1.5 KB · 1.2k views")
assert.strictEqual(Model.statusProblem(ok), "")
assert.ok(Model.needsSetup(Model.parseStatus('{"state":"unconfigured"}').state))
assert.ok(Model.needsSetup(Model.parseStatus('{"state":"no-token"}').state))
assert.strictEqual(Model.statusProblem(Model.parseStatus('{"state":"unreachable","server":"https://z.test"}')), "Can't reach z.test")
assert.strictEqual(Model.parseStatus("garbage").state, "error")
assert.strictEqual(Model.formatBytes(0), "0 B")
assert.strictEqual(Model.formatBytes(5 * 1024 * 1024), "5 MB")
assert.strictEqual(Model.cliError("omarchy-zipline: Server said no\n", "x"), "Server said no")
assert.strictEqual(Model.lastLink("noise\nhttps://z.test/u/a\n"), "https://z.test/u/a")

// Cursor: 2×2 action grid, then the recent rows.
assert.strictEqual(Model.moveCursor(0, 1, 0, 3), 1)
assert.strictEqual(Model.moveCursor(1, 1, 0, 3), 1, "right edge of the grid")
assert.strictEqual(Model.moveCursor(0, 0, 1, 3), 2)
assert.strictEqual(Model.moveCursor(2, 0, 1, 3), 4, "down from the grid enters the list")
assert.strictEqual(Model.moveCursor(2, 0, 1, 0), 2, "no list: stay")
assert.strictEqual(Model.moveCursor(4, 0, -1, 3), 2, "up from the list returns to the grid")
assert.strictEqual(Model.moveCursor(6, 0, 1, 3), 6, "bottom of the list")

console.log("model-test: ok")
