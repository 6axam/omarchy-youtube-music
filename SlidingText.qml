import QtQuick

Item {
  id: root
  property string text: ""
  property bool active: false
  property color color: "white"
  property alias font: first.font
  property int wrapMode: Text.NoWrap
  property int maximumLineCount: 1
  property int elide: Text.ElideNone
  property int textFormat: Text.PlainText
  property int front: 0
  property string displayedText: ""
  property string pendingText: ""
  property bool initialized: false
  property bool updateQueued: false
  property real progress: 0
  readonly property bool sliding: slide.running
  readonly property real outgoing: Math.min(1,progress/0.4)
  readonly property real incoming: Math.max(0,(progress-0.4)/0.6)
  implicitWidth: Math.max(first.implicitWidth,second.implicitWidth)
  implicitHeight: sliding ? Math.max(first.implicitHeight,second.implicitHeight) : (front===0 ? first.implicitHeight : second.implicitHeight)
  height: implicitHeight
  clip: true

  function slot(index) { return index===0 ? first : second }
  function scheduleUpdate() {
    if (updateQueued) return
    updateQueued=true
    Qt.callLater(function() { root.updateQueued=false; root.updateText() })
  }
  function updateText() {
    if (!initialized) {
      initialized=true
      slot(front).text=text
      displayedText=text
      return
    }
    if (!active) {
      slide.stop()
      progress=0
      slot(front).text=text
      displayedText=text
      return
    }
    if (sliding || text===displayedText) return
    pendingText=text
    slot(1-front).text=pendingText
    progress=0
    slide.restart()
  }
  onTextChanged: scheduleUpdate()
  onActiveChanged: if (!active) scheduleUpdate()
  Component.onCompleted: scheduleUpdate()

  Text {
    id: first
    width: root.width
    x: root.front===0 ? -28*root.outgoing : -28*(1-root.incoming)
    opacity: root.front===0 ? 1-root.outgoing : root.incoming
    color: root.color
    wrapMode: root.wrapMode; maximumLineCount: root.maximumLineCount
    elide: root.elide; textFormat: root.textFormat
  }
  Text {
    id: second
    width: root.width
    x: root.front===1 ? -28*root.outgoing : -28*(1-root.incoming)
    opacity: root.front===1 ? 1-root.outgoing : root.incoming
    color: root.color; font: first.font
    wrapMode: root.wrapMode; maximumLineCount: root.maximumLineCount
    elide: root.elide; textFormat: root.textFormat
  }
  NumberAnimation {
    id: slide
    target: root; property: "progress"
    from: 0; to: 1; duration: 400
    easing.type: Easing.InOutCubic
    onFinished: {
      root.front=1-root.front
      root.displayedText=root.pendingText
      root.progress=0
      root.scheduleUpdate()
    }
  }
}
