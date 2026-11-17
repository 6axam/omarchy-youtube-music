import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  property var mediaService: null
  property var queueController: null
  property var player: null
  property var sources: []
  property bool active: false
  property real revealProgress: 1
  function phase(from, to) { return Math.max(0, Math.min(1, (revealProgress - from) / (to - from))) }
  property color foreground: Commons.Color.foreground
  property color surface: Commons.Color.popups.background
  property color accent: Commons.Color.accent
  readonly property bool seeking: timeline.dragging
  property real position: 0
  readonly property bool hasMedia: player !== null && !!(player.trackTitle || player.trackArtist)
  readonly property bool playing: player ? player.isPlaying : false
  readonly property real duration: player && player.lengthSupported ? Math.max(0, player.length) : 0
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.58)
  signal closeRequested()

  implicitHeight: content.implicitHeight
  Keys.onEscapePressed: closeRequested()
  onActiveChanged: { if (active) { syncPosition(); forceActiveFocus(); Qt.callLater(upcomingList.revealCurrent) } }
  onPlayerChanged: syncPosition()

  function syncPosition() {
    position = player && player.positionSupported ? Math.max(0, player.position) : 0
  }
  function timeLabel(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0))
    var m = Math.floor(s / 60)
    return m + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
  }
  function action(name) {
    if (mediaService && player) mediaService.runAction(name, false, mediaService.playerKey(player))
  }
  Timer {
    interval: 1000
    running: root.active && root.playing && !!root.player && root.player.positionSupported
    repeat: true
    onTriggered: root.syncPosition()
  }
  Connections {
    target: root.player
    ignoreUnknownSignals: true
    function onPositionChanged() { root.syncPosition() }
    function onTrackTitleChanged() { root.syncPosition() }
  }

  Column {
    id: content
    width: parent.width
    spacing: 14

    Item {
      width: parent.width
      height: 20
      opacity: root.phase(0.2, 0.65)
      transform: Translate { y: -6 * (1 - root.phase(0.2, 0.65)) }
      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "СЕЙЧАС ИГРАЕТ" : (root.hasMedia ? "НА ПАУЗЕ" : "МУЗЫКА")
        color: root.accent
        font.family: Style.font.family
        font.pixelSize: 10
        font.letterSpacing: 1.4
      }
      MediaButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰅖"
        label: "Закрыть"
        diameter: 24
        foreground: root.foreground
        onClicked: root.closeRequested()
      }
    }

    Item {
      width: parent.width
      height: 168
      MediaArtwork {
        x: 0
        y: -34 * (1 - root.revealProgress)
        width: 56 + (parent.width - 56) * root.revealProgress
        height: 56 + (parent.height - 56) * root.revealProgress
        renderSize: 640
        opacity: root.phase(0, 0.18)
        artUrl: root.player ? (root.player.trackArtUrl || "") : ""
        foreground: root.foreground
        accent: root.accent
      }
      Rectangle {
        anchors.fill: parent
        opacity: root.phase(0.22, 0.72)
        gradient: Gradient {
          GradientStop { position: 0; color: "#08000000" }
          GradientStop { position: 0.4; color: "#10000000" }
          GradientStop { position: 1; color: "#e6000000" }
        }
      }
      Rectangle {
        opacity: root.phase(0.38, 0.8)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        width: appName.implicitWidth + 16
        height: 22
        radius: 11
        color: "#a0000000"
        Text {
          id: appName
          anchors.centerIn: parent
          text: root.player ? (root.player.identity || "Плеер") : "Нет источника"
          color: "#eeeeee"
          font.family: Style.font.family
          font.pixelSize: 10
          textFormat: Text.PlainText
        }
      }
      Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14 + 54 * (1 - root.revealProgress)
        anchors.rightMargin: 14
        anchors.bottomMargin: 14
        opacity: root.phase(0.16, 0.55)
        transform: Translate { y: -118 * (1 - root.revealProgress) }
        spacing: 5
        MotionText {
          width: parent.width
          text: root.hasMedia ? (root.player.trackTitle || "Без названия") : "Включи что-нибудь"
          color: "white"
          font.family: Style.font.family
          font.pixelSize: 12 + 6 * root.revealProgress
          font.bold: true
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        MotionText {
          width: parent.width
          text: root.hasMedia ? (root.player.trackArtist || root.player.identity || "") : "Музыка появится здесь автоматически"
          color: "#c7ffffff"
          font.family: Style.font.family
          font.pixelSize: 11
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        MotionText {
          width: parent.width
          visible: text !== ""
          text: root.player ? (root.player.trackAlbum || "") : ""
          color: "#99ffffff"
          font.family: Style.font.family
          font.pixelSize: 10
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }
    }

    Column {
      width: parent.width
      spacing: 1
      opacity: root.phase(0.3, 0.78)
      transform: Translate { y: 12 * (1 - root.phase(0.3, 0.78)) }
      visible: root.duration > 0 && root.player && root.player.positionSupported
      MediaSlider {
        id: timeline
        width: parent.width
        value: root.position
        maximum: Math.max(1, root.duration)
        step: 5
        restingTrackHeight: 3
        restingKnobSize: 8
        fillColor: root.accent
        knobColor: root.accent
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        enabled: root.player && root.player.canSeek
        onReleased: function(value) {
          if (root.player && root.player.canSeek) {
            if (root.queueController) root.queueController.seek(value)
            else root.player.position = value
            root.syncPosition()
          }
        }
      }
      Item {
        width: parent.width
        height: 13
        Text {
          text: root.timeLabel(root.position)
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 10
        }
        Text {
          anchors.right: parent.right
          text: root.timeLabel(root.duration)
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 10
        }
      }
    }

    Item {
      width: parent.width
      height: 48
      opacity: root.phase(0.4, 0.86)
      transform: Translate { y: 14 * (1 - root.phase(0.4, 0.86)) }
      Row {
        anchors.centerIn: parent
        spacing: 14
        ModeButton {
          kind: "shuffle"
          controller: root.queueController
          modeState: root.queueController && root.queueController.shuffled ? "on" : "off"
          animateChanges: root.active
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰒝"
          label: "Перемешивание"
          diameter: 30
          glyphSize: 19
          foreground: root.foreground
          accent: root.accent
          enabled: root.queueController && root.queueController.canShuffle
          onClicked: if (root.queueController) root.queueController.toggleShuffle()
        }
        MediaButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰒮"
          label: "Предыдущий трек"
          diameter: 36
          glyphSize: 22
          enabled: root.player && root.player.canGoPrevious
          foreground: root.foreground
          onClicked: root.action("previous")
        }
        MediaButton {
          icon: root.playing ? "󰏤" : "󰐊"
          label: root.playing ? "Пауза" : "Продолжить"
          diameter: 48
          glyphSize: 24
          primary: true
          foreground: root.foreground
          surface: root.surface
          accent: root.accent
          enabled: root.player && (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause)
          onClicked: root.action("playPause")
        }
        MediaButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰒭"
          label: "Следующий трек"
          diameter: 36
          glyphSize: 22
          enabled: root.player && root.player.canGoNext
          foreground: root.foreground
          onClicked: root.action("next")
        }
        ModeButton {
          kind: "repeat"
          controller: root.queueController
          modeState: root.queueController ? root.queueController.repeatMode : "off"
          animateChanges: root.active
          anchors.verticalCenter: parent.verticalCenter
          icon: "󰑖"
          label: "Повтор"
          diameter: 30
          glyphSize: 19
          foreground: root.foreground
          accent: root.accent
          enabled: root.queueController && root.queueController.canRepeat
          onClicked: if (root.queueController) root.queueController.cycleRepeat()
        }
      }
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: root.queueController ? root.queueController.errorText : ""
      color: root.accent
      font.family: Style.font.family
      font.pixelSize: 10
      wrapMode: Text.Wrap
    }

    Column {
      width: parent.width
      spacing: 8
      opacity: root.phase(0.5, 1)
      transform: Translate { y: 18 * (1 - root.phase(0.5, 1)) }
      visible: root.queueController && root.queueController.items.length > 0
      Item {
        width: parent.width
        height: 16
        Text {
          text: root.queueController && root.queueController.queueTitle ? root.queueController.queueTitle : "ОЧЕРЕДЬ"
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 10
          font.letterSpacing: 1.3
        }
        Text {
          anchors.right: parent.right
          text: root.queueController ? ((root.queueController.currentIndex >= 0 ? (root.queueController.currentIndex + 1) + " / " : "") + root.queueController.items.length) : ""
          color: root.muted
          font.family: Style.font.family
          font.pixelSize: 10
        }
      }
      ListView {
        id: upcomingList
        width: parent.width
        height: Math.min(5, count) * 46
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        NumberAnimation {
          id: wheelScroll
          target: upcomingList
          property: "contentY"
          duration: 180
          easing.type: Easing.OutCubic
        }
        onDraggingChanged: if (dragging) wheelScroll.stop()
        WheelHandler {
          target: null
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 2 : event.angleDelta.y / 120 * 92
            if (delta === 0) { event.accepted = false; return }
            var top = upcomingList.originY
            var bottom = Math.max(top, top + upcomingList.contentHeight - upcomingList.height)
            upcomingList.cancelFlick()
            var continuing = wheelScroll.running && (wheelScroll.to - upcomingList.contentY) * delta <= 0
            var base = continuing ? wheelScroll.to : upcomingList.contentY
            wheelScroll.stop()
            var destination = Math.max(top, Math.min(bottom, base - delta))
            wheelScroll.duration = event.pixelDelta.y !== 0 ? 65 : 220
            wheelScroll.to = destination
            wheelScroll.restart()
            event.accepted = true
          }
        }
        model: root.queueController ? root.queueController.items : []
        function revealCurrent() {
          if (root.active && root.queueController && root.queueController.currentIndex >= 0)
            positionViewAtIndex(root.queueController.currentIndex, ListView.Contain)
        }
        onModelChanged: { wheelScroll.stop(); Qt.callLater(revealCurrent) }
        delegate: Rectangle {
          id: trackRow
          required property var modelData
          width: upcomingList.width
          height: 46
          radius: 5
          property real arrival: 0
          Component.onCompleted: arrival = 1
          opacity: arrival
          scale: trackPointer.pressed ? 0.975 : 1
          transform: Translate { x: (1 - trackRow.arrival) * 8 }
          Behavior on arrival { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 160 } }
          Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, modelData.current ? 0.16 : (trackPointer.containsMouse ? 0.08 : 0))
          Text {
            id: trackNumber
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            text: trackRow.modelData.current ? "●" : trackRow.modelData.index + 1
            color: trackRow.modelData.current ? root.accent : root.muted
            horizontalAlignment: Text.AlignHCenter
            font.family: Style.font.family
            font.pixelSize: 9
          }
          MediaArtwork {
            id: trackCover
            anchors.left: trackNumber.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            artUrl: trackRow.modelData.artUrl || ""
            foreground: root.foreground
            accent: root.accent
          }
          Column {
            anchors.left: trackCover.right
            anchors.right: trackPlay.left
            anchors.leftMargin: 10
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            MotionText {
              width: parent.width
              text: trackRow.modelData.title
              color: trackRow.modelData.current ? root.accent : root.foreground
              font.family: Style.font.family
              font.pixelSize: 11
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
            MotionText {
              width: parent.width
              text: trackRow.modelData.artist || ""
              color: root.muted
              font.family: Style.font.family
              font.pixelSize: 10
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }
          }
          Text {
            id: trackPlay
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: trackRow.modelData.current && root.playing ? "󰎈" : "󰐊"
            color: root.accent
            font.family: Style.font.family
            font.pixelSize: 16
            opacity: trackPointer.containsMouse || trackRow.modelData.current ? 1 : 0.35
            scale: trackPointer.containsMouse ? 1.1 : 1
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
          }
          MouseArea {
            id: trackPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!root.queueController) return
              if (!trackRow.modelData.current) root.queueController.selectTrack(trackRow.modelData)
              else if (!root.playing) root.action("playPause")
            }
          }
        }
      }
    }

    Column {
      width: parent.width
      spacing: 5
      opacity: root.phase(0.62, 1)
      transform: Translate { y: 20 * (1 - root.phase(0.62, 1)) }
      visible: root.queueController && root.queueController.sources.length > 1
      Text {
        text: "ПЛЕЕР YOUTUBE MUSIC"
        color: root.muted
        font.family: Style.font.family
        font.pixelSize: 9
        font.letterSpacing: 1
        bottomPadding: 3
      }
      Repeater {
        model: root.queueController ? root.queueController.sources : []
        Rectangle {
          id: sourceRow
          required property var modelData
          readonly property bool selected: modelData.selected === true
          width: content.width
          height: 46
          radius: 6
          scale: sourcePointer.pressed ? 0.975 : 1
          Behavior on color { ColorAnimation { duration: 180 } }
          Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, selected ? 0.13 : (sourcePointer.containsMouse ? 0.07 : 0))
          Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 10
            spacing: 4
            MotionText {
              width: parent.width
              text: (sourceRow.selected ? "●  " : "○  ") + (sourceRow.modelData.title || "YouTube Music")
              color: sourceRow.selected ? root.accent : root.foreground
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: 11
              textFormat: Text.PlainText
            }
            MotionText {
              width: parent.width
              text: (sourceRow.modelData.artist || "YouTube Music") + (sourceRow.modelData.playing ? " · играет" : " · на паузе")
              color: root.muted
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: 9
              textFormat: Text.PlainText
            }
          }
          MouseArea {
            id: sourcePointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.queueController) root.queueController.bindSource(sourceRow.modelData.sessionId)
          }
        }
      }
    }
  }
}
