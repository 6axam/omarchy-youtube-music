import QtQuick
import qs.Commons as Commons

Item {
  id: root
  property string artUrl: ""
  property string trackKey: ""
  property int trackIndex: -1
  property bool active: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property int renderSize: 0
  property int front: 0
  property string displayedKey: ""
  property string displayedUrl: ""
  property int displayedIndex: -1
  property int displayedDirection: 1
  property string pendingKey: ""
  property string pendingUrl: ""
  property int pendingIndex: -1
  property int navigationHint: 0
  property int direction: 1
  property bool initialized: false
  property bool awaitingArtwork: false
  property bool updateQueued: false
  property real progress: 0
  readonly property bool sliding: slide.running
  clip: true

  function slot(index) { return index === 0 ? first : second }
  function hintDirection(value) {
    navigationHint=value<0 ? -1 : 1
    hintTimeout.restart()
  }
  Timer { id: hintTimeout; interval: 2500; onTriggered: root.navigationHint=0 }
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
      displayedIndex=trackIndex
      return
    }
    if (!active) {
      slide.stop()
      progress=0
      awaitingArtwork=false
      slot(front).artUrl=artUrl
      displayedKey=trackKey
      displayedUrl=artUrl
      displayedIndex=trackIndex
      return
    }
    if (sliding) return // Finish the current swipe, then show the latest track.
    // Late artwork or album metadata is still the same track. Update the
    // visible image in place rather than launching another full swipe.
    if (trackKey===displayedKey) {
      awaitingArtwork=false
      if (artUrl!==displayedUrl) {
        slot(front).artUrl=artUrl
        displayedUrl=artUrl
      }
      if (trackIndex>=0) displayedIndex=trackIndex
      return
    }
    // A transient empty title while the player changes tracks is not a song.
    if (!trackKey && displayedKey) return
    if (awaitingArtwork && pendingKey===trackKey && pendingUrl===artUrl) {
      if (trackIndex>=0) pendingIndex=trackIndex
      return
    }
    pendingKey=trackKey
    pendingUrl=artUrl
    pendingIndex=trackIndex
    awaitingArtwork=true
    slot(1-front).artUrl=pendingUrl
    Qt.callLater(tryStart)
  }
  function tryStart() {
    if (!awaitingArtwork || sliding || !active) return
    var next=slot(1-front)
    if (next.artUrl!==pendingUrl || !next.artworkSettled) return
    awaitingArtwork=false
    var chosen=navigationHint
    if (!chosen && pendingIndex>=0 && displayedIndex>=0 && pendingIndex!==displayedIndex)
      chosen=pendingIndex<displayedIndex ? -1 : 1
    if (!chosen && pendingKey===displayedKey) chosen=displayedDirection
    direction=chosen || 1
    navigationHint=0
    hintTimeout.stop()
    progress=0
    slide.restart()
  }
  onArtUrlChanged: scheduleUpdate()
  onTrackKeyChanged: scheduleUpdate()
  onTrackIndexChanged: scheduleUpdate()
  onActiveChanged: if (!active) scheduleUpdate()
  Component.onCompleted: scheduleUpdate()

  MediaArtwork {
    id: first
    width: root.width; height: root.height
    x: root.direction*root.width*(root.front===0 ? -root.progress : (1-root.progress))
    foreground: root.foreground; accent: root.accent; renderSize: root.renderSize
    fadeOnChange: false
    onArtworkSettledChanged: if (artworkSettled) Qt.callLater(root.tryStart)
  }
  MediaArtwork {
    id: second
    width: root.width; height: root.height
    x: root.direction*root.width*(root.front===1 ? -root.progress : (1-root.progress))
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
      root.displayedIndex=root.pendingIndex
      root.displayedDirection=root.direction
      root.progress=0
      root.scheduleUpdate()
    }
  }
}
