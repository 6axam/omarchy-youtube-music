import QtQuick
import qs.Ui

PanelSlider {
  id: root
  property real restingTrackHeight: 3
  property real restingKnobSize: 8
  HoverHandler { id: hover }
  trackHeight: restingTrackHeight + (dragging ? 2 : (hover.hovered ? 1 : 0))
  knobSize: restingKnobSize + (dragging ? 4 : (hover.hovered ? 2 : 0))
  Behavior on trackHeight { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
  Behavior on knobSize { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 0.55 } }
  Behavior on fillColor { ColorAnimation { duration: 180 } }
  Behavior on knobColor { ColorAnimation { duration: 180 } }
  Behavior on opacity { NumberAnimation { duration: 160 } }
}
