import QtQuick
import QtQuick.Shapes

Item {
  id: root
  property color ink: "white"
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
        path: "M3.6 9 C4.8 4.5 8.9 2.1 13.1 2.8 C16.1 3 18.8 4.9 20 7.6 M16.2 6.3 L20.2 7.9 L21.1 3.9 M20.4 15 C19.2 19.5 15.1 21.9 10.9 21.2 C7.9 21 5.2 19.1 4 16.4 M7.8 17.7 L3.8 16.1 L2.9 20.1"
      }
    }
  }
}
