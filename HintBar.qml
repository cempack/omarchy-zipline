import QtQuick
import QtQuick.Layouts
import qs.Commons

// Footer: key hints for the selection, replaced by a short toast for feedback.
Item {
  id: root

  property var hints: []
  property string notice: ""
  property string tone: "info"   // info | success | error
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family

  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color toastColor: tone === "error" ? urgent : tone === "success" ? accent : foreground

  implicitHeight: Style.space(24)

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 1
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
  }

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 2
    spacing: Style.space(9)
    opacity: root.notice === "" ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Repeater {
      model: root.hints
      Row {
        required property var modelData
        spacing: Style.space(3)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: keyText.implicitWidth + Style.space(8)
          implicitHeight: keyText.implicitHeight + Style.space(2)
          radius: Style.space(3)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
          Text {
            id: keyText
            anchors.centerIn: parent
            text: modelData[0]
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: modelData[1]
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
        }
      }
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.topMargin: 2
    spacing: Style.space(6)
    opacity: root.notice === "" ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Text {
      text: root.tone === "error" ? "󰅚" : root.tone === "success" ? "󰄬" : "󰋽"
      color: root.toastColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Text {
      Layout.fillWidth: true
      text: root.notice
      textFormat: Text.PlainText
      color: root.toastColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
    }
  }
}
