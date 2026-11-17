import QtQuick

Text {
  id: root
  transform: Translate { id: offset }
  Behavior on text {
    SequentialAnimation {
      ParallelAnimation {
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 65; easing.type: Easing.InQuad }
        NumberAnimation { target: offset; property: "y"; to: -3; duration: 65; easing.type: Easing.InQuad }
      }
      PropertyAction { }
      ScriptAction { script: offset.y = 3 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { target: offset; property: "y"; to: 0; duration: 210; easing.type: Easing.OutCubic }
      }
    }
  }
  Behavior on color { ColorAnimation { duration: 170 } }
}
