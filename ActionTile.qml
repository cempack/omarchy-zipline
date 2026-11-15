import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One upload action in the grid: big icon, label, ↵ hint when selected.
CursorSurface {
  id: root

  property string icon: ""
  property string label: ""
  property string fontFamily: Style.font.family

  signal clicked()
  signal hovered()

  implicitHeight: Style.space(46)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
    z: -1
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(10)

    Text {
      text: root.icon
      color: root.hasCursor ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon + 4
    }
    Text {
      Layout.fillWidth: true
      text: root.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.hasCursor
      elide: Text.ElideRight
    }
    Text {
      visible: root.hasCursor
      text: "↵"
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered()
    onClicked: root.clicked()
  }
}
