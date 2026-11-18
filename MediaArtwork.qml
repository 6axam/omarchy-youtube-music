import QtQuick
import qs.Commons
import qs.Commons as Commons

Rectangle {
  id: root
  property string artUrl: ""
  property color accent: Commons.Color.accent
  property color foreground: Commons.Color.foreground
  property int renderSize: 0
  property bool fadeOnChange: true
  readonly property bool artworkSettled: !artUrl ||
    (hasArt && (front === 0 ? first : second).source.toString() === artUrl && (front === 0 ? first : second).status === Image.Ready) ||
    (first.source.toString() === artUrl && first.status === Image.Error) ||
    (second.source.toString() === artUrl && second.status === Image.Error)
  property int front: 0
  property bool hasArt: false
  radius: 4
  color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
  clip: true
  HoverHandler { id: hover }
  Behavior on color { ColorAnimation { duration: 220 } }

  function loadArtwork() {
    if (!artUrl) { hasArt = false; first.source = ""; second.source = ""; return }
    var current = front === 0 ? first : second
    if (current.source.toString() === artUrl && current.status === Image.Ready) return
    var next = front === 0 ? second : first
    next.source = artUrl
    if (next.status === Image.Ready) { front = next === first ? 0 : 1; hasArt = true }
  }
  onArtUrlChanged: Qt.callLater(loadArtwork)
  Component.onCompleted: loadArtwork()

  Image {
    id: first
    anchors.fill: parent
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: root.renderSize > 0 ? root.renderSize : Math.ceil(width * 2)
    sourceSize.height: root.renderSize > 0 ? root.renderSize : Math.ceil(height * 2)
    opacity: root.hasArt && root.front === 0 ? 1 : 0
    scale: root.front === 0 ? (hover.hovered ? 1.035 : 1) : 1.04
    Behavior on opacity { enabled: root.fadeOnChange; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    onStatusChanged: {
      if (source.toString() !== root.artUrl) return
      if (status === Image.Ready) { root.front = 0; root.hasArt = true }
      else if (status === Image.Error) root.hasArt = false
    }
  }
  Image {
    id: second
    anchors.fill: parent
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: root.renderSize > 0 ? root.renderSize : Math.ceil(width * 2)
    sourceSize.height: root.renderSize > 0 ? root.renderSize : Math.ceil(height * 2)
    opacity: root.hasArt && root.front === 1 ? 1 : 0
    scale: root.front === 1 ? (hover.hovered ? 1.035 : 1) : 1.04
    Behavior on opacity { enabled: root.fadeOnChange; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
    onStatusChanged: {
      if (source.toString() !== root.artUrl) return
      if (status === Image.Ready) { root.front = 1; root.hasArt = true }
      else if (status === Image.Error) root.hasArt = false
    }
  }
  Text {
    anchors.centerIn: parent
    opacity: root.hasArt ? 0 : 1
    Behavior on opacity { enabled: root.fadeOnChange; NumberAnimation { duration: 180 } }
    text: "󰝚"
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Math.max(14, root.height * 0.3)
  }
}
