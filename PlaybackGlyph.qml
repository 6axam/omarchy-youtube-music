import QtQuick

Canvas {
  id: root
  property bool playing: false
  property color ink: "white"
  property bool ready: false
  // 0 = two pause bars; 1 = a play triangle split into two connected shapes.
  property real morph: playing ? 0 : 1
  antialiasing: true
  renderTarget: Canvas.Image
  Behavior on morph {
    enabled: root.ready
    NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
  }
  Component.onCompleted: { ready=true; requestPaint() }
  onMorphChanged: requestPaint()
  onInkChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onPaint: {
    var ctx=getContext("2d")
    ctx.clearRect(0,0,width,height)
    var a=[[[5,4],[9,4],[9,20],[5,20]],[[14,4],[18,4],[18,20],[14,20]]]
    var b=[[[5,3],[11,6.6],[11,17.4],[5,21]],[[11,6.6],[20,12],[20,12],[11,17.4]]]
    ctx.fillStyle=ink
    ctx.beginPath()
    for(var i=0;i<2;i++) {
      for(var j=0;j<4;j++) {
        var x=(a[i][j][0]+(b[i][j][0]-a[i][j][0])*morph)*width/24
        var y=(a[i][j][1]+(b[i][j][1]-a[i][j][1])*morph)*height/24
        if(j===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)
      }
      ctx.closePath()
    }
    ctx.fill()
  }
}
