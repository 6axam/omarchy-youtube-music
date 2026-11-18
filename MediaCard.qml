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
  onActiveChanged: { if (active) { syncPosition(); forceActiveFocus(); Qt.callLater(upcomingList.revealCurrent) } else upcomingList.stopWheel() }
  onQueueControllerChanged: Qt.callLater(upcomingList.syncQueue)
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
    if (name==="previous" || name==="next") artworkSlide.hintDirection(name==="previous" ? -1 : 1)
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
      SlidingArtwork {
        id: artworkSlide
        x: 0
        y: -34 * (1 - root.revealProgress)
        width: 56 + (parent.width - 56) * root.revealProgress
        height: 56 + (parent.height - 56) * root.revealProgress
        renderSize: 640
        opacity: root.phase(0, 0.18)
        artUrl: root.player ? (root.player.trackArtUrl || "") : ""
        trackKey: root.player ? String(root.player.trackTitle || "") : ""
        trackIndex: root.queueController ? root.queueController.currentIndex : -1
        active: root.active
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
        SlidingText {
          active: root.active
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
        SlidingText {
          active: root.active
          width: parent.width
          text: root.hasMedia ? (root.player.trackArtist || root.player.identity || "") : "Музыка появится здесь автоматически"
          color: "#c7ffffff"
          font.family: Style.font.family
          font.pixelSize: 11
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        SlidingText {
          active: root.active
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
      // Keep the timeline in place while the next track is loading.
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
        enabled: root.player && root.player.canSeek && root.duration > 0
        onReleased: function(value) {
          if (root.player && root.player.canSeek && root.duration > 0) {
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
          text: root.duration > 0 ? root.timeLabel(root.duration) : "—:—"
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
          playbackIcon: true
          playing: root.playing
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
        cacheBuffer: height
        property real wheelGoal: 0
        property real wheelVelocity: 0
        property real wheelBurst: 0
        property real wheelDirection: 0
        property double lastWheelTime: 0
        property bool pixelWheel: false

        function clampScroll(value) {
          var top=originY
          return Math.max(top,Math.min(Math.max(top,top+contentHeight-height),value))
        }
        function stopWheel() {
          wheelScroll.stop()
          wheelVelocity=0
          wheelGoal=contentY
          wheelBurst=0
          lastWheelTime=0
        }
        function scrollWheel(pixelDelta,angleDelta) {
          var delta=pixelDelta !== 0 ? pixelDelta : angleDelta/120
          if (!delta) return false
          var now=Date.now(),direction=delta>0 ? 1 : -1
          var sameBurst=now-lastWheelTime<190 && direction===wheelDirection
          if (!sameBurst) wheelBurst=0
          if (wheelDirection && direction!==wheelDirection) wheelVelocity=0
          if (!wheelScroll.running) wheelGoal=contentY
          pixelWheel=pixelDelta !== 0
          // Deliberate first notch, then quadratic gain as wheel input builds.
          var distance=pixelWheel ? delta*1.35 : delta*92*(0.65+0.5*wheelBurst+0.5*wheelBurst*wheelBurst)
          if (!pixelWheel) wheelBurst=Math.min(1,wheelBurst+Math.min(3,Math.abs(delta))*0.18)
          lastWheelTime=now
          wheelDirection=direction
          cancelFlick()
          wheelGoal=clampScroll(wheelGoal-distance)
          if (!wheelScroll.running) wheelScroll.start()
          return true
        }
        function advanceScroll(frameSeconds) {
          if (!root.active || dragging) { stopWheel(); return }
          var dt=Math.max(0.001,Math.min(0.034,frameSeconds || 1/60))
          wheelGoal=clampScroll(wheelGoal)
          // Exact critically damped step: continuous velocity, short coasting
          // tail and no repeated restart of an easing animation on every tick.
          var omega=pixelWheel ? 30 : 19
          var offset=contentY-wheelGoal
          var decay=Math.exp(-omega*dt)
          var step=(wheelVelocity+omega*offset)*dt
          var next=wheelGoal+(offset+step)*decay
          wheelVelocity=(wheelVelocity-omega*step)*decay
          contentY=clampScroll(next)
          if (Math.abs(next-contentY)>0.01) wheelVelocity=0
          if (Math.abs(wheelGoal-contentY)<0.15 && Math.abs(wheelVelocity)<3) {
            contentY=wheelGoal
            wheelScroll.stop()
            wheelVelocity=0
          }
        }
        FrameAnimation {
          id: wheelScroll
          onTriggered: upcomingList.advanceScroll(frameTime)
        }
        onDraggingChanged: if (dragging) stopWheel()
        onFlickingChanged: if (flicking) stopWheel()
        WheelHandler {
          target: null
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            event.accepted=upcomingList.scrollWheel(event.pixelDelta.y,event.angleDelta.y)
          }
        }

        // A persistent model keeps delegates alive when only "current" changes.
        ListModel { id: queueRows; dynamicRoles: true }
        model: queueRows
        function syncQueue() {
          var entries=root.queueController ? root.queueController.items : []
          var wasEmpty=queueRows.count===0
          var occurrences={}
          for (var i=0;i<entries.length;i++) {
            var entry=entries[i]
            var identity=String(entry.id || entry.videoId || "index:"+entry.index)
            var occurrence=occurrences[identity] || 0
            occurrences[identity]=occurrence+1
            var key=identity+"#"+occurrence
            var json=JSON.stringify(entry)
            if (i>=queueRows.count || queueRows.get(i).entryKey!==key) {
              var found=-1
              for (var j=i+1;j<queueRows.count;j++) {
                if (queueRows.get(j).entryKey===key) { found=j; break }
              }
              if (found>=0) queueRows.move(found,i,1)
              else queueRows.insert(i,{entryKey:key,entryJson:json,trackData:entry})
            }
            if (queueRows.get(i).entryJson!==json) {
              queueRows.setProperty(i,"trackData",entry)
              queueRows.setProperty(i,"entryJson",json)
            }
          }
          if (queueRows.count>entries.length) queueRows.remove(entries.length,queueRows.count-entries.length)
          if (wasEmpty && queueRows.count) Qt.callLater(revealCurrent)
          wheelGoal=clampScroll(wheelGoal)
        }
        function revealCurrent() {
          if (root.active && root.queueController && root.queueController.currentIndex>=0) {
            stopWheel()
            positionViewAtIndex(root.queueController.currentIndex,ListView.Contain)
            wheelGoal=contentY
          }
        }
        Component.onCompleted: syncQueue()
        Connections {
          target: root.queueController
          ignoreUnknownSignals: true
          function onItemsChanged() { upcomingList.syncQueue() }
          function onSourceChanged() {
            upcomingList.stopWheel()
            upcomingList.syncQueue()
            Qt.callLater(upcomingList.revealCurrent)
          }
        }
        delegate: Rectangle {
          id: trackRow
          required property var trackData
          required property int index
          readonly property var modelData: trackData
          width: upcomingList.width
          height: 46
          radius: 5
          property real arrival: 0
          property real pressScale: trackPointer.pressed ? 0.975 : 1
          readonly property real viewportCenter: y-upcomingList.contentY+height/2
          readonly property real edgeDistance: Math.min(viewportCenter,upcomingList.height-viewportCenter)
          readonly property real edgeFraction: Math.max(0,Math.min(1,edgeDistance/52))
          readonly property real edgeReveal: edgeFraction*edgeFraction*(3-2*edgeFraction)
          readonly property real edgeSide: viewportCenter<upcomingList.height/2 ? -1 : 1
          Component.onCompleted: arrival=1
          opacity: arrival*(0.35+0.65*edgeReveal)
          readonly property real endpointScroll: index===0
            ? upcomingList.contentY-upcomingList.originY
            : (index===upcomingList.count-1
              ? upcomingList.originY+Math.max(0,upcomingList.contentHeight-upcomingList.height)-upcomingList.contentY
              : 24)
          readonly property real endpointRelease: Math.max(0,Math.min(1,endpointScroll/24))
          scale: (1-0.12*(1-edgeReveal)*endpointRelease)*pressScale
          transformOrigin: Item.Center
          transform: Translate { y: trackRow.edgeSide*(11*(1-trackRow.edgeReveal)+8*(1-trackRow.arrival)) }
          Behavior on arrival { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: 160 } }
          Behavior on pressScale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
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
              if (!trackRow.modelData.current) {
                if (root.queueController.currentIndex>=0)
                  artworkSlide.hintDirection(trackRow.modelData.index<root.queueController.currentIndex ? -1 : 1)
                root.queueController.selectTrack(trackRow.modelData)
              } else if (!root.playing) root.action("playPause")
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
