import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var snapshot: ({})
  property var queueEntries: []
  property var sourceEntries: []
  property real now: Date.now()
  property var pending: []
  property string errorText: ""
  property string executingCommand: ""
  property bool optimisticPlaybackActive: false
  property bool optimisticPlayback: false
  readonly property bool displayPlaying: optimisticPlaybackActive ? optimisticPlayback : playing
  signal commandFailed(string command)
  signal sourceChanged()
  onPlayingChanged: if (optimisticPlaybackActive && playing === optimisticPlayback) {
    optimisticPlaybackActive = false
    playbackTimeout.stop()
  }
  onCommandFailed: function(command) {
    if (command === "playPause") { optimisticPlaybackActive = false; playbackTimeout.stop() }
  }
  onSourceChanged: { optimisticPlaybackActive = false; playbackTimeout.stop() }
  Timer { id: playbackTimeout; interval: 3000; onTriggered: root.optimisticPlaybackActive = false }
  readonly property bool available: snapshot.available === true && now - Number(snapshot.updatedAt || 0) < 15000
  readonly property bool playing: available && snapshot.playing === true
  readonly property var items: available ? queueEntries : []
  readonly property var sources: sourceEntries
  readonly property string album: available ? String(snapshot.album || "") : ""
  readonly property string queueTitle: available ? String(snapshot.queueTitle || "") : ""
  readonly property int currentIndex: available ? Number(snapshot.currentIndex === undefined ? -1 : snapshot.currentIndex) : -1
  readonly property bool shuffled: available && snapshot.shuffle === true
  readonly property string repeatMode: available ? String(snapshot.repeat || "off") : "off"
  readonly property bool canShuffle: available && snapshot.canShuffle === true
  readonly property bool canRepeat: available && snapshot.canRepeat === true
  readonly property var upcoming: {
    var current = -1
    for (var i = 0; i < items.length; i++) if (items[i].current) current = i
    return current < 0 ? [] : items.slice(current + 1)
  }
  readonly property QtObject player: QtObject {
    readonly property string trackTitle: root.available ? String(root.snapshot.title || "") : ""
    readonly property string trackArtist: root.available ? String(root.snapshot.artist || "") : ""
    readonly property string trackArtUrl: root.available ? String(root.snapshot.artUrl || "") : ""
    readonly property string trackAlbum: root.album
    readonly property string identity: "YouTube Music"
    readonly property bool isPlaying: root.displayPlaying
    readonly property bool canGoNext: root.available && root.snapshot.canNext === true
    readonly property bool canGoPrevious: root.available && root.snapshot.canPrevious === true
    readonly property bool canTogglePlaying: root.available
    readonly property bool canPlay: root.available
    readonly property bool canPause: root.available
    readonly property bool positionSupported: root.available
    readonly property bool lengthSupported: root.available && root.snapshot.duration > 0
    readonly property bool canSeek: root.available && root.snapshot.canSeek === true
    readonly property real position: root.available ? Number(root.snapshot.position || 0) : 0
    readonly property real length: root.available ? Number(root.snapshot.duration || 0) : 0
  }

  function send(command, extra) {
    if (!available && command !== "bind") return
    if (command === "playPause") {
      optimisticPlayback = !displayPlaying
      optimisticPlaybackActive = true
      playbackTimeout.restart()
    }
    var sessionId = command === "bind" && extra ? extra.sessionId : snapshot.sessionId
    var args = ["/usr/bin/python", Quickshell.env("HOME") + "/.config/omarchy/plugins/6axam.youtube-music/bridge/queuectl.py", command, "--session-id", String(sessionId)]
    if (extra && extra.id !== undefined) args.push("--id", String(extra.id))
    if (extra && extra.index !== undefined) args.push("--index", String(extra.index))
    if (extra && extra.position !== undefined) args.push("--position", String(extra.position))
    pending = pending.concat([args])
    pump()
  }
  function pump() {
    if (control.running || pending.length === 0) return
    control.command = pending[0]
    executingCommand = String(pending[0][2] || "")
    control.failureReported = false
    pending = pending.slice(1)
    control.running = true
  }
  function selectTrack(item) { send("select", {id: item.id, index: item.index}) }
  function seek(seconds) { send("seek", {position: seconds}) }
  function bindSource(sessionId) { send("bind", {sessionId: sessionId}) }
  function toggleShuffle() { send("shuffle") }
  function cycleRepeat() { send("repeat") }

  Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: root.now = Date.now()
  }
  FileView {
    path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/omarchy/youtube-music.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var incoming = JSON.parse(text())
        var entries = Array.isArray(incoming.queue) ? incoming.queue : []
        var sources = Array.isArray(incoming.sources) ? incoming.sources : []
        if (JSON.stringify(entries) !== JSON.stringify(root.queueEntries)) root.queueEntries = entries
        if (JSON.stringify(sources) !== JSON.stringify(root.sourceEntries)) root.sourceEntries = sources
        var changedSource = String(root.snapshot.sessionId || "") !== String(incoming.sessionId || "")
        root.snapshot = incoming
        root.now = Date.now()
        if (changedSource) root.sourceChanged()
      }
      catch (e) { root.snapshot = ({}) }
    }
    onLoadFailed: root.snapshot = ({})
  }
  Process {
    id: control
    property bool failureReported: false
    function reportFailure() {
      if (failureReported) return
      failureReported = true
      root.commandFailed(root.executingCommand)
    }
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result = JSON.parse(text)
          if (!result.ok) { control.reportFailure(); root.errorText = "Не удалось выполнить действие. Попробуй ещё раз."; clearError.restart() }
          else root.errorText = ""
        } catch (e) {
          control.reportFailure()
          root.errorText = "Нет связи с музыкальным плеером."
          clearError.restart()
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) reportFailure()
      Qt.callLater(root.pump)
    }
  }
  Timer { id: clearError; interval: 4500; onTriggered: root.errorText = "" }
}
