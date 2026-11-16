import QtQuick
import QtQuick.Shapes
import qs.Commons

// Zipline mark: a Z whose last stroke shoots off as an up-right arrow
// (upload and share). Drawn on a 24-unit grid and scaled to the icon size.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: implicitWidth
  height: implicitHeight

  Shape {
    width: 24
    height: 24
    scale: root.width / 24
    transformOrigin: Item.TopLeft
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: 2.6
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M4 6.5H15.5L4.5 17.5H20" }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: 2.3
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: "M13.2 2.6H19.2V8.6M19.2 2.6L14.5 7.3" }
    }
  }
}
