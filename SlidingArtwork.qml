import QtQuick
import qs.Commons as Commons

Item {
  id: root
  property string artUrl: ""
  property string trackKey: ""
  property bool active: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property int renderSize: 0
  property int front: 0
  property string displayedKey: ""
  property string displayedUrl: ""
  property string pendingKey: ""
  property string pendingUrl: ""
  property bool initialized: false
  property bool awaitingArtwork: false
  property bool updateQueued: false
  property real progress: 0
  readonly property bool sliding: slide.running
  clip: true

  function slot(index) { return index === 0 ? first : second }
  function scheduleUpdate() {
    if (updateQueued) return
    updateQueued=true
    Qt.callLater(function() { root.updateQueued=false; root.updateArtwork() })
  }
  function updateArtwork() {
    if (!initialized) {
      initialized=true
      slot(front).artUrl=artUrl
      displayedKey=trackKey
      displayedUrl=artUrl
      return
    }
    if (!active) {
      slide.stop()
      progress=0
      awaitingArtwork=false
      slot(front).artUrl=artUrl
      displayedKey=trackKey
      displayedUrl=artUrl
      return
    }
    if (sliding) return // Finish the current swipe, then show the latest track.
    if (trackKey===displayedKey && artUrl===displayedUrl) {
      awaitingArtwork=false
      return
    }
    if (awaitingArtwork && pendingKey===trackKey && pendingUrl===artUrl) return
    pendingKey=trackKey
    pendingUrl=artUrl
    awaitingArtwork=true
    slot(1-front).artUrl=pendingUrl
    Qt.callLater(tryStart)
  }
  function tryStart() {
    if (!awaitingArtwork || sliding || !active) return
    var next=slot(1-front)
    if (next.artUrl!==pendingUrl || !next.artworkSettled) return
    awaitingArtwork=false
    progress=0
    slide.restart()
  }
  onArtUrlChanged: scheduleUpdate()
  onTrackKeyChanged: scheduleUpdate()
  onActiveChanged: if (!active) scheduleUpdate()
  Component.onCompleted: scheduleUpdate()

  MediaArtwork {
    id: first
    width: root.width; height: root.height
    x: root.front===0 ? -root.progress*root.width : (1-root.progress)*root.width
    foreground: root.foreground; accent: root.accent; renderSize: root.renderSize
    fadeOnChange: false
    onArtworkSettledChanged: if (artworkSettled) Qt.callLater(root.tryStart)
  }
  MediaArtwork {
    id: second
    width: root.width; height: root.height
    x: root.front===1 ? -root.progress*root.width : (1-root.progress)*root.width
    foreground: root.foreground; accent: root.accent; renderSize: root.renderSize
    fadeOnChange: false
    onArtworkSettledChanged: if (artworkSettled) Qt.callLater(root.tryStart)
  }
  NumberAnimation {
    id: slide
    target: root
    property: "progress"
    from: 0; to: 1
    duration: 420
    easing.type: Easing.InOutCubic
    onFinished: {
      root.front=1-root.front
      root.displayedKey=root.pendingKey
      root.displayedUrl=root.pendingUrl
      root.progress=0
      root.scheduleUpdate()
    }
  }
}
