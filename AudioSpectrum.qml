import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property bool active: false
  property bool playing: false
  property string artUrl: ""
  property color fallbackColor: "#dddddd"
  property color spectrumColor: fallbackColor
  property var levels: []
  property bool processFailed: false
  readonly property int barCount: Math.max(0, Math.min(24, Math.floor(width / 8)))
  opacity: active ? 0.9 : 0
  Behavior on opacity { NumberAnimation { duration: 220 } }
  Behavior on spectrumColor { ColorAnimation { duration: 380 } }
  onActiveChanged: if (!active) { levels = []; processFailed = false }
  onArtUrlChanged: palette.loadArtwork()
  Component.onCompleted: palette.loadArtwork()

  Process {
    id: analyzer
    command: ["cava", "-p", decodeURIComponent(Qt.resolvedUrl("cava.conf").toString().replace(/^file:\/\//, ""))]
    running: root.active && root.playing && !root.processFailed
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).split(";")
        if (parts.length < 24) return
        var frame = []
        for (var i = 0; i < 24; ++i) {
          var value = Number(parts[i])
          if (!isFinite(value)) return
          frame.push(Math.max(0, Math.min(100, value)) / 100)
        }
        root.levels = frame
      }
    }
    onExited: function(exitCode, exitStatus) {
      root.levels = []
      if (root.active && root.playing && exitCode !== 0) root.processFailed = true
    }
  }

  Row {
    anchors.fill: parent
    spacing: 3
    layoutDirection: Qt.RightToLeft
    Repeater {
      model: root.barCount
      Rectangle {
        required property int index
        anchors.bottom: parent.bottom
        width: 5
        height: root.playing && root.levels.length ? Math.max(3, root.levels[Math.min(23, Math.floor(index * 24 / Math.max(1, root.barCount)))] * root.height) : 3
        radius: width / 2
        color: root.spectrumColor
        Behavior on height { NumberAnimation { duration: 95; easing.type: Easing.OutCubic } }
      }
    }
  }

  Canvas {
    id: palette
    width: 32; height: 32
    opacity: 0
    property string requested: ""
    function loadArtwork() {
      requested = root.artUrl
      if (!requested) { root.spectrumColor = root.fallbackColor; return }
      loadImage(requested)
      if (isImageLoaded(requested)) requestPaint()
    }
    onImageLoaded: if (isImageLoaded(requested)) requestPaint()
    onPaint: {
      if (!requested || !isImageLoaded(requested)) return
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.drawImage(requested, 0, 0, width, height)
      var pixels = ctx.getImageData(0, 0, width, height).data
      var bins = []
      for (var b = 0; b < 12; b++) bins.push({weight: 0, r: 0, g: 0, b: 0})
      for (var i = 0; i < pixels.length; i += 4) {
        var r = pixels[i] / 255, g = pixels[i+1] / 255, blue = pixels[i+2] / 255
        var max = Math.max(r, g, blue), min = Math.min(r, g, blue), delta = max - min
        if (pixels[i+3] < 128 || max < 0.2 || delta < 0.12) continue
        var hue = max === r ? (g-blue)/delta : max === g ? 2+(blue-r)/delta : 4+(r-g)/delta
        hue = (hue + 6) % 6
        var bin = bins[Math.min(11, Math.floor(hue * 2))]
        var weight = delta * (0.4 + max * 0.6)
        bin.weight += weight; bin.r += r * weight; bin.g += g * weight; bin.b += blue * weight
      }
      var best = bins[0]
      for (var j = 1; j < bins.length; j++) if (bins[j].weight > best.weight) best = bins[j]
      if (best.weight < 1) { root.spectrumColor = root.fallbackColor; return }
      var rr = best.r / best.weight, gg = best.g / best.weight, bb = best.b / best.weight
      var brightness = Math.max(rr, gg, bb)
      var boost = Math.max(1, 0.82 / Math.max(0.01, brightness))
      root.spectrumColor = Qt.rgba(Math.min(1, rr*boost), Math.min(1, gg*boost), Math.min(1, bb*boost), 1)
    }
  }
}
