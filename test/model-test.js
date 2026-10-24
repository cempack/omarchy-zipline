#!/usr/bin/env node
"use strict"

const assert = require("assert")
const Model = require("../Model.js")

const helper = "/home/u/.config/omarchy/plugins/io.github.cempack.zipline/bin/omarchy-zipline"

assert.deepStrictEqual(Model.actionCommand(helper, "clipboard"), [helper, "clipboard"])
assert.deepStrictEqual(Model.actionCommand(helper, "last"), [helper, "last"])
assert.deepStrictEqual(Model.actionCommand(helper, "screenshot"), [])
assert.deepStrictEqual(Model.actionCommand(helper, "setup"), [])
assert.deepStrictEqual(Model.actionCommand(helper, "recording"), [helper, "recording"])
assert.deepStrictEqual(Model.actionCommand(helper, "rm -rf"), [])
assert.deepStrictEqual(Model.actionCommand("", "clipboard"), [])
// No capture modes: the plugin only uploads what Omarchy already captured.
for (const gone of ["region", "window", "fullscreen"]) assert.deepStrictEqual(Model.actionCommand(helper, gone), [])
assert.ok(Object.values(Model.ACTIONS).every(args => !args.includes("--delay")))


assert.strictEqual(Model.localPathFromUrl("file:///home/u/My%20Plugins/bin/x"), "/home/u/My Plugins/bin/x")
assert.strictEqual(Model.hostOf("https://i.example.com/u/abc.png"), "i.example.com")
assert.strictEqual(Model.hostOf("not a url"), "")
assert.ok(Model.isLink("https://x.test/a"))
assert.ok(!Model.isLink("javascript:alert(1)"))
assert.ok(!Model.isLink("https://x.test/a b"))

const history = [
  "https://x.test/u/1.png\tscreenshot\tscreenshot-1.png\t2026-10-24T10:00:00+02:00",
  "garbage line",
  "file:///etc/passwd\tfile\tpasswd\t2026-10-24T10:00:00+02:00",
  "https://x.test/go/abc\tshorten\thttps://example.com\t2026-10-24T09:00:00+02:00",
  ""
].join("\n")
const rows = Model.parseHistory(history, 5)
assert.strictEqual(rows.length, 2)
assert.deepStrictEqual(rows[0], { url: "https://x.test/u/1.png", kind: "screenshot", name: "screenshot-1.png", time: "2026-10-24T10:00:00+02:00" })
assert.strictEqual(Model.parseHistory(history, 1).length, 1)

assert.strictEqual(Model.kindIcon("recording"), "󰕧")
assert.strictEqual(Model.kindIcon("unknown"), "󰈔")

const now = Date.parse("2026-10-24T10:00:00+02:00")
assert.strictEqual(Model.shortTime("2026-10-24T09:59:30+02:00", now), "just now")
assert.strictEqual(Model.shortTime("2026-10-24T09:30:00+02:00", now), "30 min ago")
assert.strictEqual(Model.shortTime("2026-10-24T07:00:00+02:00", now), "3 h ago")
assert.strictEqual(Model.shortTime("2026-10-21T10:00:00+02:00", now), "3 d ago")
assert.strictEqual(Model.shortTime("nope", now), "")

console.log("model-test: ok")
