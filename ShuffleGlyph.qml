import QtQuick
import "ShuffleMotion.js" as Motion

Canvas {
  id: root
  property real travel: 0
  property bool reverse: false
  property color ink: "white"
  property real glyphSize: 21
  property real verticalScale: 0.80
  readonly property real idleWidth: glyphSize * 0.75
  antialiasing: true
  renderTarget: Canvas.Image
  onTravelChanged: if (visible) requestPaint()
  onReverseChanged: if (visible) requestPaint()
  onInkChanged: if (visible) requestPaint()
  onGlyphSizeChanged: if (visible) requestPaint()
  onVisibleChanged: if (visible) requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  Component.onCompleted: requestPaint()

  onPaint: {
    var ctx=getContext("2d");ctx.clearRect(0,0,width,height);
    var geometry=Motion.geometry(reverse ? 1-travel : travel);
    var scale=idleWidth/Motion.idleSpan;
    ctx.strokeStyle=ink;ctx.lineWidth=glyphSize*1.9/24;
    ctx.lineCap="round";ctx.lineJoin="round";
    for(var k=1;k>=0;k--) {
      var points=geometry[k],mapped=[];
      for(var i=0;i<points.length;i++)mapped.push([width/2+points[i][0]*scale,height/2+points[i][1]*scale*verticalScale]);
      ctx.beginPath();ctx.moveTo(mapped[0][0],mapped[0][1]);
      for(var j=1;j<mapped.length;j++)ctx.lineTo(mapped[j][0],mapped[j][1]);
      ctx.stroke();
      var tip=mapped[mapped.length-1],before=mapped[mapped.length-3];
      var angle=Math.atan2(tip[1]-before[1],tip[0]-before[0]);
      var headSize=glyphSize*0.16;
      ctx.beginPath();
      ctx.moveTo(tip[0]-headSize*Math.cos(angle-0.64),tip[1]-headSize*Math.sin(angle-0.64));
      ctx.lineTo(tip[0],tip[1]);
      ctx.lineTo(tip[0]-headSize*Math.cos(angle+0.64),tip[1]-headSize*Math.sin(angle+0.64));
      ctx.stroke();
    }
  }
}
