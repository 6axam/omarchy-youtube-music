import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  property var player: null
  property var queueController: null
  property bool active: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property real position: 0
  property real seekHoldUntil: 0
  readonly property real duration: player && player.lengthSupported ? Math.max(0, player.length) : 0
  readonly property bool seeking: timeline.dragging
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  signal expandRequested()
  implicitHeight: layout.implicitHeight

  function syncPosition() {
    if (!timeline.dragging && Date.now() >= seekHoldUntil)
      position = player && player.positionSupported ? Math.max(0, player.position) : 0
  }
  function seek(seconds) {
    if (!player || !player.canSeek || duration <= 0) return
    position = seconds
    seekHoldUntil = Date.now() + 800
    if (queueController) queueController.seek(seconds)
    else player.position = seconds
  }
  function timeLabel(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0))
    return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60
  }
  onPlayerChanged: { seekHoldUntil = 0; syncPosition() }
  onActiveChanged: if (active) syncPosition()
  Timer {
    interval: 500
    repeat: true
    running: root.active && !!root.player && root.player.isPlaying
    onTriggered: root.syncPosition()
  }
  Connections {
    target: root.player
    ignoreUnknownSignals: true
    function onPositionChanged() { root.syncPosition() }
    function onTrackTitleChanged() { root.seekHoldUntil = 0; root.syncPosition() }
  }

  Column {
    id: layout
    width: parent.width
    spacing: 8

    Item {
      width: parent.width
      height: 56
      MediaArtwork {
        id: cover
        scale: coverPointer.pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
        width: 56
        height: 56
        radius: 7
        artUrl: root.player ? (root.player.trackArtUrl || "") : ""
        foreground: root.foreground
        accent: root.accent
        MouseArea {
          id: coverPointer
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expandRequested()
        }
      }
      Column {
        anchors.left: cover.right
        anchors.right: expand.left
        anchors.leftMargin: 12
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        MotionText {
          width: parent.width
          text: root.player ? (root.player.trackTitle || "Без названия") : "Музыка"
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: 12
          font.weight: Font.DemiBold
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        MotionText {
          width: parent.width
          text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 10
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }
      MediaButton {
        id: expand
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰒺"
        label: "Открыть очередь"
        diameter: 26
        glyphSize: 17
        foreground: root.foreground
        onClicked: root.expandRequested()
      }
    }

    Column {
      width: parent.width
      spacing: 0
      // Keep the timeline in place while the next track is loading.
      MediaSlider {
        id: timeline
        width: parent.width
        value: root.position
        maximum: Math.max(1, root.duration)
        step: 5
        restingTrackHeight: 3
        restingKnobSize: 9
        fillColor: root.accent
        knobColor: root.accent
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.13)
        enabled: root.player && root.player.canSeek && root.duration > 0
        onReleased: function(value) { root.seek(value) }
      }
      Item {
        width: parent.width
        height: 12
        Text {
          text: root.timeLabel(timeline.dragging ? timeline.liveValue : root.position)
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 9
        }
        Text {
          anchors.right: parent.right
          text: root.duration > 0 ? root.timeLabel(root.duration) : "—:—"
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 9
        }
      }
    }
  }
}
