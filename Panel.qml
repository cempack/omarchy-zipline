import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Zipline panel: account and stats, upload options (expiry, view limit), the
// four actions and recent links. Uploads run detached through the CLI, which
// shows its own progress and result notifications.
//   ←→↑↓ move · ↵ run / copy · e expiry · v view limit · o open · m Markdown
//   x forget · r refresh · Esc close · Tab next panel
Panel {
  id: root
  moduleName: "io.github.cempack.zipline"
  ipcTarget: "io.github.cempack.zipline"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ── Theme ───────────────────────────────────────────────────────────────────
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color faint: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ── State ───────────────────────────────────────────────────────────────────
  readonly property string helperPath: Model.localPathFromUrl(Qt.resolvedUrl("bin/omarchy-zipline"))
  readonly property int historyCount: Math.max(1, Math.min(10, Number(setting("historyCount", 5)) || 5))
  property var status: null           // Model.parseStatus result; null until the first check
  property var recent: []
  property int cursor: 0
  property string expires: ""          // "" = config default
  property int maxViews: 0             // 0 = no limit
  property string notice: ""
  property string noticeTone: "info"

  readonly property bool checking: statusProc.running && status === null
  readonly property bool needsSetup: status !== null && Model.needsSetup(status.state)
  readonly property string problem: Model.statusProblem(status)
  readonly property int actionCount: Model.ACTIONS.length
  readonly property int itemCount: actionCount + recent.length
  readonly property var cursorRow: cursor >= actionCount ? recent[cursor - actionCount] || null : null

  // ── Opening ─────────────────────────────────────────────────────────────────

  function open() {
    cursor = 0
    notice = ""
    refresh()
    root.controller.show()
  }

  function openFromHotkey() { open() }

  function close() { root.controller.hide() }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
    loadHistory()
  }

  function loadHistory() {
    if (historyProc.running) return
    historyProc.command = [root.helperPath, "history", String(root.historyCount)]
    historyProc.running = true
  }

  function notify(text, tone) {
    notice = String(text || "")
    noticeTone = tone || "info"
    noticeTimer.restart()
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  function runAction(action) {
    if (needsSetup) return setup()
    var command = Model.actionCommand(root.helperPath, action, { expires: root.expires, maxViews: root.maxViews })
    if (command.length === 0) return
    close()
    Quickshell.execDetached(command)
  }

  function setup() {
    close()
    Quickshell.execDetached(Model.setupCommand(root.helperPath))
  }

  function copyLink(row) {
    if (!row || !Model.isLink(row.url)) return
    close()
    Quickshell.execDetached(["wl-copy", row.url])
    Quickshell.execDetached(["omarchy-notification-send", "-g", "󰅧", "Link copied", row.url])
  }

  function copyMarkdown(row) {
    var text = Model.markdownLink(row)
    if (text === "") return
    close()
    Quickshell.execDetached(["wl-copy", text])
    Quickshell.execDetached(["omarchy-notification-send", "-g", "󰅧", "Markdown copied", text])
  }

  function openLink(row) {
    if (!row || !Model.isLink(row.url)) return
    close()
    Quickshell.execDetached(["xdg-open", row.url])
  }

  // Removes the link from this machine's history only; the file stays online.
  function forget(row) {
    if (!row || forgetProc.running) return
    forgetProc.command = [root.helperPath, "forget", row.url]
    forgetProc.running = true
  }

  function cycleExpiry(step) {
    expires = Model.nextExpiry(expires, step || 1)
    notify("Expires: " + Model.expiryLabel(expires).toLowerCase(), "info")
  }

  function cycleViews(step) {
    maxViews = Model.nextViews(maxViews, step || 1)
    notify("View limit: " + Model.viewsLabel(maxViews).toLowerCase(), "info")
  }

  function activate() {
    if (cursor < actionCount) runAction(Model.ACTIONS[cursor].action)
    else copyLink(cursorRow)
  }

  onRecentChanged: if (cursor >= itemCount) cursor = Math.max(0, itemCount - 1)

  // ── Processes ───────────────────────────────────────────────────────────────

  Process {
    id: statusProc
    command: [root.helperPath, "status", "--json"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: Qt.callLater(function() { root.status = Model.parseStatus(statusOut.text) })
  }

  Process {
    id: historyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.recent = Model.parseHistory(text, root.historyCount)
    }
  }

  Process {
    id: forgetProc
    stderr: StdioCollector { id: forgetErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.notify("Removed from history (still online)", "success")
      else root.notify(Model.cliError(forgetErr.text, "Could not update the history"), "error")
      root.loadHistory()
    }
  }

  Timer {
    id: noticeTimer
    interval: root.noticeTone === "error" ? 4000 : 1800
    onTriggered: root.notice = ""
  }

  // ── Layout ──────────────────────────────────────────────────────────────────

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { root.cursor = Model.moveCursor(root.cursor, dx, dy, root.recent.length) }
      onActivateRequested: root.activate()
      onDeleteRequested: root.forget(root.cursorRow)
      onTextKey: function(text, modifiers) {
        if (text === "e") root.cycleExpiry(1)
        else if (text === "E") root.cycleExpiry(-1)
        else if (text === "v") root.cycleViews(1)
        else if (text === "V") root.cycleViews(-1)
        else if (text === "o") root.openLink(root.cursorRow)
        else if (text === "m") root.copyMarkdown(root.cursorRow)
        else if (text === "r") root.refresh()
        else if (text === "s" && root.needsSetup) root.setup()
      }

      ColumnLayout {
        id: content
        width: parent.width
        spacing: Style.space(10)

        // Header: account and stats.
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          ZiplineIcon {
            iconSize: Style.font.display
            color: root.accent
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: root.status && root.status.user
                ? root.status.user + " @ " + Model.hostOf(root.status.server)
                : "Zipline"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: root.checking ? "Checking the server…"
                : root.problem !== "" ? root.problem
                : root.needsSetup ? "Not set up yet"
                : root.status && root.status.stats ? Model.statsLine(root.status.stats)
                : root.status ? Model.hostOf(root.status.server) : ""
              textFormat: Text.PlainText
              color: root.problem !== "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          PanelActionButton {
            visible: root.status !== null && !root.needsSetup
            iconText: "󰏌"
            tooltipText: "Open the Zipline dashboard"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              root.close()
              Quickshell.execDetached(["xdg-open", root.status.server + "/dashboard"])
            }
          }
        }

        // Setup.
        ColumnLayout {
          Layout.fillWidth: true
          visible: root.needsSetup
          spacing: Style.space(8)

          Text {
            Layout.fillWidth: true
            text: "Add your server URL and an API token (Zipline → Settings → Token). The token is stored in ~/.config/omarchy-zipline with private permissions."
            color: root.dim
            wrapMode: Text.WordWrap
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          Button {
            Layout.fillWidth: true
            text: "Set up Zipline"
            iconText: "󰒓"
            selected: true
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.setup()
          }
        }

        // Upload options.
        RowLayout {
          Layout.fillWidth: true
          visible: !root.needsSetup
          spacing: Style.space(6)

          OptionChip {
            Layout.fillWidth: true
            icon: "󰔛"
            label: "Expires"
            value: Model.expiryLabel(root.expires)
            active: root.expires !== ""
            hint: "e"
            onClicked: root.cycleExpiry(1)
            onRightClicked: root.cycleExpiry(-1)
          }
          OptionChip {
            Layout.fillWidth: true
            icon: "󰈈"
            label: "Views"
            value: Model.viewsLabel(root.maxViews)
            active: root.maxViews > 0
            hint: "v"
            onClicked: root.cycleViews(1)
            onRightClicked: root.cycleViews(-1)
          }
        }

        // Actions.
        GridLayout {
          Layout.fillWidth: true
          visible: !root.needsSetup
          columns: Model.ACTION_COLUMNS
          columnSpacing: Style.space(8)
          rowSpacing: Style.space(8)

          Repeater {
            model: Model.ACTIONS

            ActionTile {
              required property var modelData
              required property int index
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              icon: modelData.icon
              label: modelData.label
              hasCursor: root.cursor === index
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onHovered: root.cursor = index
              onClicked: root.runAction(modelData.action)
            }
          }
        }

        // Recent links.
        Row {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(2)
          visible: root.recent.length > 0
          spacing: Style.space(6)
          Text {
            text: "RECENT"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }
          Text {
            text: String(root.recent.length)
            color: root.dim
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.recent.length === 0 && !root.needsSetup && !historyProc.running
          text: "Nothing uploaded yet. Press Print, then ↵ on Clipboard."
          color: root.dim
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Column {
          Layout.fillWidth: true
          spacing: Style.space(1)

          Repeater {
            model: root.recent

            RecentRow {
              required property var modelData
              required property int index
              width: parent.width
              row: modelData
              hasCursor: root.cursor === root.actionCount + index
              foreground: root.foreground
              dim: root.dim
              fontFamily: root.fontFamily
              onHovered: root.cursor = root.actionCount + index
              onCopy: root.copyLink(modelData)
              onOpen: root.openLink(modelData)
              onMarkdown: root.copyMarkdown(modelData)
            }
          }
        }

        HintBar {
          Layout.fillWidth: true
          hints: root.needsSetup ? [["↵", "set up"], ["Esc", "close"]]
            : root.cursorRow ? [["↵", "copy"], ["o", "open"], ["m", "markdown"], ["x", "forget"]]
            : [["↵", "upload"], ["e", "expiry"], ["v", "views"], ["r", "refresh"]]
          notice: root.notice
          tone: root.noticeTone
          foreground: root.foreground
          accent: root.accent
          urgent: root.urgent
          fontFamily: root.fontFamily
        }
      }
    }
  }

  // Expiry / view-limit selector: click cycles forward, right-click back.
  component OptionChip: CursorSurface {
    id: chip
    property string icon: ""
    property string label: ""
    property string value: ""
    property string hint: ""
    property bool active: false
    signal clicked()
    signal rightClicked()

    foreground: root.foreground
    implicitHeight: chipRow.implicitHeight + Style.space(12)
    hasCursor: chipMouse.containsMouse

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: chip.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16) : root.faint
      border.width: chip.active ? 1 : 0
      border.color: root.accent
    }

    RowLayout {
      id: chipRow
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(6)

      Text {
        text: chip.icon
        color: chip.active ? root.accent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
          text: chip.label
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        Text {
          Layout.fillWidth: true
          text: chip.value
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: chip.active
          elide: Text.ElideRight
        }
      }
      Text {
        text: chip.hint
        color: root.dim
        opacity: 0.7
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) chip.rightClicked()
        else chip.clicked()
      }
    }
  }
}
