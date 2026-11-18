import QtQuick
import qs.Commons
import qs.Commons as Commons

Rectangle {
  id: root
  property string icon: ""
  property string label: ""
  property bool primary: false
  property bool glyphVisible: true
  property bool playbackIcon: false
  property bool playing: false
  property bool toggled: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color surface: Commons.Color.background
  property int diameter: 28
  property int glyphSize: 15
  property real ripple: 0
  readonly property bool hot: enabled && pointer.containsMouse
  signal clicked()
  signal feedbackRequested()

  function activate() {
    if (!enabled) return
    feedbackRequested()
    pulse.restart()
    clicked()
  }
  implicitWidth: diameter
  implicitHeight: diameter
  width: implicitWidth
  height: implicitHeight
  radius: height / 2
  color: primary ? accent : (hot ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.13) : (toggled ? Qt.rgba(accent.r, accent.g, accent.b, 0.15) : "transparent"))
  opacity: enabled ? 1 : 0.25
  scale: pointer.pressed ? 0.88 : (hot ? 1.075 : 1)
  activeFocusOnTab: enabled
  Accessible.role: Accessible.Button
  Accessible.name: label
  Accessible.onPressAction: activate()
  Keys.onSpacePressed: activate()
  Keys.onReturnPressed: activate()
  border.width: activeFocus ? 1 : 0
  border.color: foreground
  Behavior on color { ColorAnimation { duration: 160 } }
  Behavior on opacity { NumberAnimation { duration: 170 } }
  Behavior on scale {
    NumberAnimation {
      duration: pointer.pressed ? 75 : 230
      easing.type: pointer.pressed ? Easing.OutCubic : Easing.OutBack
      easing.overshoot: 0.65
    }
  }
  Rectangle {
    anchors.centerIn: parent
    width: root.width * (0.85 + root.ripple * 0.5)
    height: width
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: root.accent
    opacity: pulse.running ? (1 - root.ripple) * 0.32 : 0
  }
  SequentialAnimation {
    id: pulse
    PropertyAction { target: root; property: "ripple"; value: 0 }
    NumberAnimation { target: root; property: "ripple"; to: 1; duration: 340; easing.type: Easing.OutCubic }
  }
  MotionText {
    visible: root.glyphVisible && !root.playbackIcon
    anchors.centerIn: parent
    text: root.icon
    color: root.primary ? root.surface : (root.toggled ? root.accent : root.foreground)
    font.family: Style.font.family
    font.pixelSize: root.glyphSize
    textFormat: Text.PlainText
  }
  Loader {
    anchors.centerIn: parent
    width: root.glyphSize; height: root.glyphSize
    active: root.glyphVisible && root.playbackIcon
    sourceComponent: PlaybackGlyph {
      playing: root.playing
      ink: root.primary ? root.surface : (root.toggled ? root.accent : root.foreground)
    }
  }
  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activate()
  }
}
