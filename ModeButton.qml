import QtQuick
import qs.Commons

MediaButton {
  id: root
  property string kind: "repeat"
  property string modeState: "off"
  property bool animateChanges: true
  property bool ready: false
  property string visualState: "off"
  property var pendingModes: []
  property var controller: null
  property real spin: 0
  property real shuffleTravel: 0
  property real shuffleDirection: 1
  readonly property real orbit: shuffleDirection * shuffleTravel * Math.PI * 2
  readonly property real orbitX: 6 * Math.sin(orbit)
  readonly property real orbitY: 4.5 * Math.sin(orbit * 2)
  readonly property real orbitTwist: 38 * Math.sin(orbit)
  property real badgeProgress: 0
  property color ink: idleInk
  readonly property color idleInk: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.43)
  readonly property color activeInk: "#ffffff"

  radius: Math.min(width, height) / 2
  glyphVisible: false
  toggled: visualState !== "off"

  function settle() {
    spin = 0
    shuffleTravel = 0
    ink = visualState === "off" ? idleInk : activeInk
    badgeProgress = kind === "repeat" && visualState === "one" ? 1 : 0
  }
  function animateMode() {
    repeatMotion.stop()
    shuffleMotion.stop()
    if (!animateChanges) { settle(); return }
    if (kind === "repeat") {
      repeatSpin.from = spin
      repeatSpin.to = spin + (visualState === "off" ? -360 : (visualState === "one" ? 720 : 360))
      repeatSpin.duration = visualState === "one" ? 980 : 620
      repeatTint.to = visualState === "off" ? idleInk : activeInk
      badgeWait.duration = visualState === "one" ? 650 : 0
      repeatMotion.restart()
    } else {
      shuffleTravel = 0
      shuffleDirection = visualState === "off" ? -1 : 1
      shuffleTint.to = visualState === "off" ? idleInk : activeInk
      shuffleMotion.restart()
    }
  }
  function reconcile() {
    pendingModes = []
    confirmationTimeout.stop()
    if (visualState !== modeState) { visualState = modeState; animateMode() }
  }
  function animateClick() {
    var base = pendingModes.length ? pendingModes[pendingModes.length - 1] : modeState
    var next = kind === "repeat" ? (base === "off" ? "all" : (base === "all" ? "one" : "off")) : (base === "off" ? "on" : "off")
    pendingModes = pendingModes.concat([next])
    visualState = next
    confirmationTimeout.restart()
    animateMode()
  }
  onFeedbackRequested: if (ready) animateClick()
  onModeStateChanged: if (ready) {
    if (pendingModes.length) {
      var confirmed = pendingModes.indexOf(modeState)
      if (confirmed >= 0) {
        pendingModes = pendingModes.slice(confirmed + 1)
        if (!pendingModes.length) {
          confirmationTimeout.stop()
          if (visualState !== modeState) { visualState = modeState; animateMode() }
        }
      } else reconcile()
    } else if (visualState !== modeState) { visualState = modeState; animateMode() }
  }
  Timer { id: confirmationTimeout; interval: 3000; onTriggered: root.reconcile() }
  Connections {
    target: root.controller
    ignoreUnknownSignals: true
    function onCommandFailed(command) { if (command === root.kind) root.reconcile() }
    function onSourceChanged() { root.reconcile() }
  }
  onAnimateChangesChanged: if (ready && !animateChanges) {
    repeatMotion.stop()
    shuffleMotion.stop()
    settle()
  }
  Component.onCompleted: { visualState = modeState; settle(); ready = true }

  Item {
    anchors.centerIn: parent
    width: root.glyphSize + 2
    height: width
    rotation: root.spin
    RepeatGlyph {
      anchors.fill: parent
      visible: root.kind === "repeat"
      ink: root.ink
    }
    ShuffleArrow {
      width: parent.width
      height: width
      visible: root.kind === "shuffle"
      ink: root.ink
      x: root.orbitX
      y: root.orbitY
      rotation: root.orbitTwist
    }
    ShuffleArrow {
      width: parent.width
      height: width
      visible: root.kind === "shuffle"
      upper: true
      ink: root.ink
      x: -root.orbitX
      y: root.orbitY
      rotation: -root.orbitTwist
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.kind === "repeat" && opacity > 0
    text: "1"
    color: root.activeInk
    font.family: Style.font.family
    font.pixelSize: 8
    font.bold: true
    style: Text.Outline
    styleColor: root.surface
    opacity: Math.max(0, Math.min(1, root.badgeProgress))
    scale: 0.25 + root.badgeProgress * 0.75
    rotation: -35 * (1 - root.badgeProgress)
    transform: Translate { y: 3 * (1 - root.badgeProgress) }
  }

  ParallelAnimation {
    id: repeatMotion
    NumberAnimation {
      id: repeatSpin
      target: root
      property: "spin"
      easing.type: Easing.InOutCubic
    }
    ColorAnimation {
      id: repeatTint
      target: root
      property: "ink"
      duration: 360
      easing.type: Easing.OutCubic
    }
    SequentialAnimation {
      NumberAnimation { target: root; property: "badgeProgress"; to: 0; duration: 80 }
      PauseAnimation { id: badgeWait }
      NumberAnimation {
        target: root
        property: "badgeProgress"
        to: root.visualState === "one" ? 1 : 0
        duration: 300
        easing.type: Easing.OutBack
        easing.overshoot: 1.25
      }
    }
    onFinished: root.settle()
  }
  ParallelAnimation {
    id: shuffleMotion
    NumberAnimation {
      target: root
      property: "shuffleTravel"
      from: 0
      to: 1
      duration: 1040
      easing.type: Easing.InOutCubic
    }
    ColorAnimation {
      id: shuffleTint
      target: root
      property: "ink"
      duration: 220
      easing.type: Easing.OutCubic
    }
    onFinished: root.settle()
  }
}
