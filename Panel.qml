import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.cempack.zipline"
  ipcTarget: "io.github.cempack.zipline"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string serverUrl: ""
  property bool serverChecked: false
  property var recent: []
  property int cursorIndex: 0

  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string helperPath: Model.localPathFromUrl(Qt.resolvedUrl("bin/omarchy-zipline"))
  readonly property int historyCount: Math.max(1, Math.min(10, Number(setting("historyCount", 5)) || 5))
  readonly property var actionRows: [
    { action: "clipboard", icon: "󰅇", label: "Clipboard" },
    { action: "file", icon: "󰈔", label: "File" },
    { action: "recording", icon: "󰕧", label: "Recording" },
    { action: "last", icon: "󰆏", label: "Last link" }
  ]
  readonly property int itemCount: actionRows.length + recent.length

  function open() {
    cursorIndex = 0
    root.refresh()
    root.controller.show()
  }

  function openFromHotkey() {
    root.open()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refresh() {
    if (!serverProc.running) serverProc.running = true
    if (!historyProc.running) {
      historyProc.command = [root.helperPath, "history", String(root.historyCount)]
      historyProc.running = true
    }
  }

  function runAction(action) {
    root.close()
    var command = Model.actionCommand(root.helperPath, action)
    if (command.length > 0) Quickshell.execDetached(command)
  }

  function copyLink(url) {
    if (!Model.isLink(url)) return
    root.close()
    Quickshell.execDetached(["wl-copy", url])
    Quickshell.execDetached(["omarchy-notification-send", "-g", "󰅧", "Link copied", url])
  }

  function openLink(url) {
    if (!Model.isLink(url)) return
    root.close()
    Quickshell.execDetached(["xdg-open", url])
  }

  function moveCursor(dx, dy) {
    if (itemCount === 0) return
    var next = cursorIndex
    if (cursorIndex < actionRows.length) {
      next = cursorIndex + dx + dy * 2
      if (dy > 0 && next >= actionRows.length) next = recent.length > 0 ? actionRows.length : cursorIndex
    } else {
      next = cursorIndex + dy + dx
      if (next < actionRows.length) next = actionRows.length - 2
    }
    cursorIndex = Math.max(0, Math.min(itemCount - 1, next))
  }

  function activateCursor() {
    if (cursorIndex < actionRows.length) root.runAction(actionRows[cursorIndex].action)
    else {
      var row = recent[cursorIndex - actionRows.length]
      if (row) root.copyLink(row.url)
    }
  }

  Process {
    id: serverProc
    command: [root.helperPath, "server"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.serverUrl = String(text || "").trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.serverUrl = ""
      root.serverChecked = true
    }
  }

  Process {
    id: historyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.recent = Model.parseHistory(text, root.historyCount)
    }
  }

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
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: "Zipline"
          textFormat: Text.PlainText
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          visible: root.serverChecked && root.serverUrl === ""
          text: "Not set up: run omarchy-zipline setup"
          textFormat: Text.PlainText
          color: Qt.darker(root.contentForeground, 1.45)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Grid {
          id: actionGrid
          width: parent.width
          columns: 2
          columnSpacing: Style.space(8)
          rowSpacing: Style.space(8)

          Repeater {
            model: root.actionRows

            delegate: Rectangle {
              id: actionCell
              required property var modelData
              required property int index
              readonly property bool hot: actionMouse.containsMouse || root.cursorIndex === index

              width: (actionGrid.width - actionGrid.columnSpacing) / 2
              height: Style.space(36)
              radius: Style.cornerRadius
              color: hot
                ? Style.hoverFillFor(root.contentForeground, Color.accent)
                : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: actionCell.modelData.icon
                  textFormat: Text.PlainText
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.icon
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: actionCell.modelData.label
                  textFormat: Text.PlainText
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }
              }

              MouseArea {
                id: actionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.cursorIndex = actionCell.index
                onClicked: root.runAction(actionCell.modelData.action)
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: root.recent.length > 0
          text: "Recent"
          textFormat: Text.PlainText
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Repeater {
          model: root.recent

          delegate: Rectangle {
            id: recentRow
            required property var modelData
            required property int index
            readonly property int itemIndex: root.actionRows.length + index
            readonly property bool hot: recentMouse.containsMouse || root.cursorIndex === itemIndex

            width: content.width
            height: Style.space(32)
            radius: Style.cornerRadius
            color: hot ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"

            Text {
              id: recentIcon
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              text: Model.kindIcon(recentRow.modelData.kind)
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.icon
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: recentIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: openButton.left
              anchors.rightMargin: Style.space(6)

              Text {
                width: parent.width
                text: recentRow.modelData.name
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

            }

            MouseArea {
              id: recentMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.cursorIndex = recentRow.itemIndex
              onClicked: root.copyLink(recentRow.modelData.url)
            }

            PanelActionButton {
              id: openButton
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              iconText: "󰏌"
              tooltipText: "Open in browser"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.openLink(recentRow.modelData.url)
            }
          }
        }

      }
    }
  }
}
