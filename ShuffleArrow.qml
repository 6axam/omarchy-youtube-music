import QtQuick
import QtQuick.Shapes

Item {
  id: root
  property color ink: "white"
  property bool upper: false
  Shape {
    width: 24
    height: 24
    scale: root.width / 24
    transformOrigin: Item.TopLeft
    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.9
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg {
        path: root.upper
          ? "M3 19 H5 C10 19 14 5 19 5 H21 M18 8 L21 5 L18 2"
          : "M3 5 H5 C10 5 14 19 19 19 H21 M18 16 L21 19 L18 22"
      }
    }
  }
}
