import QtQuick
import qs.Ui
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons

PopupWindow {
  id: root

  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property color borderColor: Commons.Color.popups.border
  property var borderSpec: Border.localOrSurfaceSpec("popups", "border", borderColor, Commons.Color.popups.border, Math.max(1, Style.space(2)))
  property bool open: false
  property bool expanded: false
  property var player: null
  property var queueController: null
  property color artworkColor: Commons.Color.accent
  property bool tintEnabled: false
  property color backgroundColor: {
    var base = Commons.Color.popups.background
    if (!root.tintEnabled) return Qt.rgba(base.r, base.g, base.b, 1)
    var color = root.artworkColor
    return Qt.rgba(base.r * 0.72 + color.r * 0.16,
                   base.g * 0.72 + color.g * 0.16,
                   base.b * 0.72 + color.b * 0.16, 1)
  }
  Behavior on backgroundColor { ColorAnimation { duration: Style.duration(650); easing.type: Easing.InOutCubic } }
  property real reveal: 0
  property real expansion: 0
  property bool expandedSeeking: false
  readonly property bool seeking: compactCard.seeking || expandedSeeking
  readonly property real compactHeight: compactCard.implicitHeight + padding * 2
  readonly property real cardWidth: Math.min(320, contentWidth) + (contentWidth - Math.min(320, contentWidth)) * expansion
  readonly property real cardHeight: compactHeight + (contentHeight - compactHeight) * expansion
  signal expandRequested()
  property bool centerOnBar: false
  // "click" — uses HyprlandFocusGrab so clicking outside dismisses the popup.
  // "hover" — passive overlay; the owning widget controls open via hover.
  property string triggerMode: "click"

  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property var popupScreen: anchorWindow ? anchorWindow.screen : null
  readonly property bool containsMouse: cardHover.hovered
  readonly property real screenW: popupScreen ? popupScreen.width : 0
  readonly property real screenH: popupScreen ? popupScreen.height : 0
  readonly property real barW: anchorItem ? anchorItem.width : 0
  readonly property real barH: anchorItem ? anchorItem.height : 0
  readonly property real availableCardWidth: screenW > 0
    ? Math.max(120, screenW - ((bar && (bar.position === "left" || bar.position === "right")) ? barW : 0) - root.margin * 2)
    : 0
  readonly property real availableCardHeight: screenH > 0
    ? Math.max(120, screenH - ((bar && (bar.position === "top" || bar.position === "bottom")) ? barH : 0) - root.margin * 2)
    : 0
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)

  function fittedContentWidth(width, cap) {
    var desired = Math.max(1, Number(width) || 1)
    var maxWidth = root.availableCardWidth > 0 ? root.availableCardWidth : desired
    if (cap !== undefined && Number(cap) > 0) maxWidth = Math.min(maxWidth, Number(cap))
    return Math.round(Math.min(desired, maxWidth))
  }

  function fittedContentHeight(implicitHeight, cap) {
    var desired = Math.max(root.verticalContentInset, (Number(implicitHeight) || 0) + root.verticalContentInset)
    var maxHeight = root.availableCardHeight > 0 ? root.availableCardHeight : desired
    if (cap !== undefined && Number(cap) > 0) maxHeight = Math.min(maxHeight, Number(cap))
    return Math.round(Math.min(desired, maxHeight))
  }

  function cappedContentHeight(height) {
    var desired = Math.max(root.padding * 2, Number(height) || root.padding * 2)
    var maxHeight = root.availableCardHeight > 0 ? root.availableCardHeight : desired
    return Math.round(Math.min(desired, maxHeight))
  }

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }

  default property alias contentItem: contentHolder.children

  visible: open || reveal > 0
  color: "transparent"
  implicitWidth: contentWidth
  implicitHeight: Math.max(contentHeight, compactHeight) + 16
  mask: Region { item: card }
  onExpandedChanged: expansion = expanded ? 1 : 0
  Behavior on expansion {
    NumberAnimation { duration: root.expanded ? 460 : 340; easing.type: Easing.InOutCubic }
  }
  Behavior on reveal {
    NumberAnimation { duration: root.open ? 290 : 190; easing.type: Easing.OutCubic }
  }

  onOpenChanged: {
    reveal = open ? 1 : 0
    if (!bar) return
    if (open) bar.requestPopout(coordinatorKey)
    else if (bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
  }

  // Outside-click dismissal via Hyprland's focus grab. While `active`, input
  // is routed only to the listed windows; clicking anywhere else clears the
  // grab and we close the popup. Skipped for hover-mode popups so the cursor
  // can move freely between the trigger and the popup.
  HyprlandFocusGrab {
    active: root.open && root.expanded && root.triggerMode === "click"
    windows: root.anchorWindow ? [root, root.anchorWindow] : [root]
    onCleared: root.close()
  }

  anchor {
    id: popupAnchor
    window: anchorItem ? anchorItem.QsWindow.window : null
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!root.anchorItem || !root.bar) return

      var target = root.anchorItem
      var popupWidth = root.implicitWidth
      var popupHeight = root.implicitHeight
      var localX = target.width / 2 - popupWidth / 2
      var localY = target.height

      if (root.bar.position === "bottom") {
        localY = -popupHeight
      } else if (root.bar.position === "left") {
        localX = target.width + root.margin
        localY = target.height / 2 - popupHeight / 2
      } else if (root.bar.position === "right") {
        localX = -popupWidth - root.margin
        localY = target.height / 2 - popupHeight / 2
      }

      var window = target.QsWindow.window
      if (!window) return

      if (root.centerOnBar) {
        var cx = 0;
        var cy = 0;
        if (root.bar.position === "top" || root.bar.position === "bottom") {
          cx = window.width / 2 - popupWidth / 2
          cy = root.bar.position === "bottom" ? -popupHeight - root.margin : window.height + root.margin
          cx = Math.max(root.margin, Math.min(cx, window.width - popupWidth - root.margin))
        } else {
          cx = root.bar.position === "left" ? window.width + root.margin : -popupWidth - root.margin
          cy = window.height / 2 - popupHeight / 2
          cy = Math.max(root.margin, Math.min(cy, window.height - popupHeight - root.margin))
        }

        popupAnchor.rect.x = Math.round(cx)
        popupAnchor.rect.y = Math.round(cy)
        return
      }

      var point = window.contentItem.mapFromItem(target, localX, localY)

      if (root.bar.position === "top" || root.bar.position === "bottom") {
        point.x = Math.max(root.margin, Math.min(point.x, window.width - popupWidth - root.margin))
      } else {
        point.y = Math.max(root.margin, Math.min(point.y, window.height - popupHeight - root.margin))
      }

      popupAnchor.rect.x = Math.round(point.x)
      popupAnchor.rect.y = Math.round(point.y)
    }
  }

  BorderSurface {
    id: card
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.bar && root.bar.position === "bottom"
      ? root.implicitHeight - root.cardHeight - 8 + (1 - root.reveal) * 8
      : 8 * root.reveal
    width: root.cardWidth
    height: root.cardHeight
    scale: 0.98 + 0.02 * root.reveal
    transformOrigin: root.bar && root.bar.position === "bottom" ? Item.Bottom : Item.Top
    color: root.backgroundColor
    borderSpec: root.borderSpec
    padding: root.padding
    radius: 10
    opacity: root.reveal
    clip: true

    MiniPlayerCard {
      id: compactCard
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: root.padding
      width: parent.width - root.padding * 2
      height: implicitHeight
      player: root.player
      queueController: root.queueController
      active: root.open && !root.expanded
      enabled: root.open && !root.expanded
      visible: opacity > 0
      opacity: 1 - Math.max(0, Math.min(1, (root.expansion - 0.04) / 0.18))
      transform: Translate { y: -root.expansion * 8 }
      foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
      onExpandRequested: root.expandRequested()
    }

    Item {
      id: contentHolder
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: card.contentLeftInset
      anchors.topMargin: card.contentTopInset
      width: root.contentWidth - card.contentLeftInset - card.contentRightInset
      height: root.contentHeight - card.contentTopInset - card.contentBottomInset
      visible: root.expansion > 0
      enabled: root.expanded && root.expansion > 0.65
    }

    HoverHandler { id: cardHover }
  }
}
