import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

// A recent upload: kind icon, name, host · age · limits, and quick actions.
CursorSurface {
  id: root

  property var row: null
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family

  signal copy()
  signal open()
  signal markdown()
  signal hovered()

  implicitHeight: content.implicitHeight + Style.space(10)

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered()
    onClicked: root.copy()
  }

  RowLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(4)
    spacing: Style.space(10)

    Text {
      text: root.row ? Model.kindIcon(root.row.kind) : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Text {
        Layout.fillWidth: true
        text: root.row ? root.row.name : ""
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: root.hasCursor
        elide: Text.ElideMiddle
      }
      Text {
        Layout.fillWidth: true
        text: root.row ? Model.rowDetail(root.row, Date.now()) : ""
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    PanelActionButton {
      visible: root.hasCursor
      iconText: "󰍔"
      tooltipText: "Copy as Markdown (m)"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.markdown()
    }
    PanelActionButton {
      iconText: "󰏌"
      tooltipText: "Open in browser (o)"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.open()
    }
  }
}
