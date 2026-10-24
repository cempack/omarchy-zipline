#!/usr/bin/env node
"use strict"

const assert = require("assert")
const fs = require("fs")
const path = require("path")

const ROOT = path.join(__dirname, "..")
const PLUGIN_ID = "io.github.cempack.zipline"

const INHERITED_METHODS = {
  Panel: new Set(["setting", "closeForPopoutSwitch"]),
  BarWidget: new Set(["broadcast", "setting"])
}

function stripComments(source) {
  return source
    .replace(/\/\/[^\n]*/g, "")
    .replace(/\/\*[\s\S]*?\*\//g, "")
}

function extractBaseType(source) {
  const cleaned = stripComments(source).replace(/^[\s\S]*?(?=^[A-Za-z_][A-Za-z0-9_.]*\s*\{)/m, "")
  const match = cleaned.match(/^([A-Za-z_][A-Za-z0-9_.]*)\s*\{/)
  return match ? match[1] : ""
}

function extractRootId(source) {
  const match = source.match(/^\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$/m)
  return match ? match[1] : "root"
}

function extractRootDeclarations(source) {
  const functions = new Set()
  const properties = new Set()
  const lines = source.split("\n")
  for (const raw of lines) {
    const line = stripComments(raw)
    if (/^\s{2}function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/.test(line)) {
      functions.add(line.match(/function\s+([A-Za-z_][A-Za-z0-9_]*)/)[1])
      continue
    }
    const propertyMatch = line.match(/^\s{2}(?:readonly\s+)?property\s+[A-Za-z_<>,\s]+\s+([A-Za-z_][A-Za-z0-9_]*)\b/)
    if (propertyMatch) properties.add(propertyMatch[1])
  }
  return { functions, properties }
}

function assertNoShellInterpolation(source, fileName) {
  const cleaned = stripComments(source)
  assert.ok(!/\bbash\s+-c\b/.test(cleaned), fileName + " must not call bash -c")
  assert.ok(!/\bsh\s+-c\b/.test(cleaned), fileName + " must not call sh -c")
  assert.ok(!/\.bar\.run\(/.test(cleaned), fileName + " must not run commands through bar.run")
}

function analyzeFile(fileName) {
  const source = fs.readFileSync(path.join(ROOT, fileName), "utf8")
  const baseType = extractBaseType(source)
  const rootId = extractRootId(source)
  const decl = extractRootDeclarations(source)
  const inherited = INHERITED_METHODS[baseType] || new Set()
  const callable = new Set([...decl.functions, ...inherited])
  const cleaned = stripComments(source)
  const pattern = new RegExp("\\b" + rootId + "\\.([A-Za-z_][A-Za-z0-9_]*)\\s*\\(", "g")
  let match
  while ((match = pattern.exec(cleaned)) !== null) {
    const name = match[1]
    if (decl.properties.has(name)) continue
    assert.ok(callable.has(name), fileName + " calls missing " + rootId + "." + name + "()")
  }
  assertNoShellInterpolation(source, fileName)
  assert.ok(source.includes('moduleName: "' + PLUGIN_ID + '"'), fileName + " must use the permanent plugin id")
  return source
}

const bar = analyzeFile("BarWidget.qml")
assert.ok(/\bfunction open\(/.test(bar), "BarWidget must expose open()")
assert.ok(/\bfunction close\(/.test(bar), "BarWidget must expose close()")
assert.ok(/readonly property bool opened:/.test(bar), "BarWidget must expose opened")
assert.ok(bar.includes('target: "' + PLUGIN_ID + '"'), "BarWidget IPC target must match the plugin id")
assert.ok(bar.includes('bin/omarchy-zipline'), "BarWidget must launch the bundled helper by path")

const panel = analyzeFile("Panel.qml")
assert.ok(/\bfunction open\(/.test(panel), "Panel must expose open()")
assert.ok(/\bfunction close\(/.test(panel), "Panel must expose close()")
assert.ok(panel.includes('bin/omarchy-zipline'), "Panel must launch the bundled helper by path")
assert.ok(!/centerOnBar\s*:\s*true/.test(panel), "right-section popout must anchor to the bar icon, not screen center")
assert.ok(!/ZIPLINE_TOKEN|authorization/i.test(panel + bar), "QML must never handle the token")

const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, "manifest.json"), "utf8"))
assert.strictEqual(manifest.id, PLUGIN_ID)
assert.strictEqual(manifest.entryPoints.barWidget, "BarWidget.qml")

console.log("qml-contract-test: ok")
