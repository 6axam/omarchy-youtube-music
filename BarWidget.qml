import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons

BarWidget {
  id: root
  moduleName: "6axam.youtube-music"
  readonly property var queueController: musicQueue
  readonly property bool useMusicQueue: musicQueue.available
  readonly property var activePlayer: musicQueue.available ? musicQueue.player : null
  readonly property var sourcePlayers: musicQueue.available ? [musicQueue.player] : []
  readonly property var mediaService: mediaRouter
  MusicQueue { id: musicQueue }
  QtObject {
    id: mediaRouter
    function playerKey(player) { return player === musicQueue.player ? String(musicQueue.snapshot.sessionId || "") : "" }
    function selectPlayer(key) { musicQueue.bindSource(key) }
    function runAction(action, feedback, key) {
      if (key === String(musicQueue.snapshot.sessionId || "")) musicQueue.send(action)
    }
  }
  readonly property bool hasMedia: activePlayer !== null && !!(activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool playing: activePlayer ? activePlayer.isPlaying : false
  readonly property string title: hasMedia ? (activePlayer.trackTitle || "Без названия") : "YouTube Music"
  readonly property string artist: hasMedia ? (activePlayer.trackArtist || activePlayer.identity || "") : "Открой музыку в Opera"
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color surface: bar ? bar.background : Commons.Color.background
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  property bool hoverOpen: false
  readonly property bool playerHovered: hover.hovered || popup.containsMouse || popup.seeking
  readonly property bool hoverWanted: hasMedia && !popupOpen && playerHovered
  property bool controlsVisible: hover.hovered || hoverOpen || popupOpen
  onPlayerHoveredChanged: {
    if (playerHovered) hideHover.stop()
    else if (hoverOpen || popupOpen) hideHover.restart()
  }
  onHoverWantedChanged: {
    if (hoverWanted) {
      if (!hoverOpen) showHover.restart()
    } else showHover.stop()
  }
  onPopupOpenChanged: if (popupOpen) {
    showHover.stop()
    hoverOpen = false
    if (playerHovered) hideHover.stop()
    else hideHover.restart()
  }
  Timer { id: showHover; interval: 180; onTriggered: if (root.hoverWanted) root.hoverOpen = true }
  Timer { id: hideHover; interval: 100; onTriggered: if (!root.playerHovered) root.close() }

  implicitWidth: vertical ? barSize : Number(setting("width", 140))
  implicitHeight: barSize

  function open() { popupOpen = true }
  function close() { popupOpen = false; hoverOpen = false }
  function collapseToMini() {
    showHover.stop()
    hideHover.stop()
    // Keep the shared popup open while only its expanded state changes.
    hoverOpen = hasMedia
    popupOpen = false
    if (hoverOpen && !playerHovered) hideHover.restart()
  }
  function togglePopup() {
    if (popupOpen) collapseToMini()
    else open()
  }
  function action(name) {
    if (mediaService && activePlayer) mediaService.runAction(name, false, mediaService.playerKey(activePlayer))
  }
  HoverHandler { id: hover }

  Rectangle {
    id: pill
    anchors.fill: parent
    anchors.topMargin: 2
    anchors.bottomMargin: 2
    anchors.leftMargin: 3
    anchors.rightMargin: 3
    radius: 6
    scale: root.controlsVisible ? 1.015 : 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 180 } }
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { Behavior on color { ColorAnimation { duration: 180 } }
        position: 0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.controlsVisible ? 0.17 : 0.11) }
      GradientStop { Behavior on color { ColorAnimation { duration: 180 } }
        position: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.controlsVisible ? 0.11 : 0.065) }
    }
    border.width: 1
    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.popupOpen ? 0.45 : 0.12)

    MediaArtwork {
      id: cover
      scale: coverPointer.pressed ? 0.94 : 1
      Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
      anchors.left: parent.left
      anchors.leftMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(16, Math.min(26, pill.height - 4))
      height: width
      artUrl: root.activePlayer ? (root.activePlayer.trackArtUrl || "") : ""
      accent: root.accent
      foreground: root.foreground
      MouseArea {
        id: coverPointer
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.MiddleButton) root.action("playPause")
          else root.togglePopup()
        }
      }
    }

    Item {
      id: body
      anchors.left: cover.right
      anchors.right: parent.right
      anchors.leftMargin: 3
      anchors.rightMargin: 3
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      visible: !root.vertical

      Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        opacity: root.controlsVisible ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        transform: Translate {
          y: root.controlsVisible ? -3 : 0
          Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }
        MotionText {
          width: parent.width
          text: root.title
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: 11
          font.weight: Font.DemiBold
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        MotionText {
          width: parent.width
          text: root.artist
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.88)
          font.family: Style.font.family
          font.pixelSize: 9
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }

      Row {
        anchors.centerIn: parent
        spacing: 0
        opacity: root.controlsVisible ? 1 : 0
        visible: opacity > 0
        enabled: root.controlsVisible
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        transform: Translate {
          y: root.controlsVisible ? 0 : 3
          Behavior on y { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
        }
        MediaButton {
          icon: "󰒮"
          label: "Предыдущий трек"
          diameter: 24
          glyphSize: 20
          foreground: root.foreground
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          onClicked: root.action("previous")
        }
        MediaButton {
          playbackIcon: true
          playing: root.playing
          label: root.playing ? "Пауза" : "Продолжить"
          diameter: 24
          glyphSize: 20
          foreground: root.foreground
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          onClicked: root.action("playPause")
        }
        MediaButton {
          icon: "󰒭"
          label: "Следующий трек"
          diameter: 24
          glyphSize: 20
          foreground: root.foreground
          enabled: root.activePlayer && root.activePlayer.canGoNext
          onClicked: root.action("next")
        }
        MediaButton {
          icon: "󰖲"
          label: "Открыть плеер"
          diameter: 24
          glyphSize: 20
          foreground: root.foreground
          onClicked: root.togglePopup()
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: !root.controlsVisible
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePopup()
      }
    }
  }

  PlayerPopup {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.hoverOpen || root.popupOpen
    expanded: root.popupOpen
    triggerMode: "hover"
    expandedSeeking: playerCard.seeking
    player: root.activePlayer
    queueController: musicQueue
    onExpandRequested: root.open()
    padding: 14
    contentWidth: fittedContentWidth(350)
    contentHeight: fittedContentHeight(playerCard.implicitHeight)
    MediaCard {
      id: playerCard
      anchors.fill: parent
      mediaService: root.mediaService
      player: root.activePlayer
      sources: root.sourcePlayers
      active: root.popupOpen
      revealProgress: popup.expansion
      queueController: musicQueue
      foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
      accent: root.accent
      onCloseRequested: root.collapseToMini()
    }
  }
}
