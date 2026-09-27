import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// One app on a workspace: its icon, a count when the app has several
// windows there, and a dot while one of them wants attention. Left click
// focuses the app's window (again to cycle through them), middle click
// closes it, right click opens the settings.
WidgetButton {
  id: root

  required property var panel
  // { key, source, name, count, addresses, titles, urgent, focused }
  property var group: ({})
  property bool colored: true
  property bool grayscale: false
  property real iconSize: 16
  // Color of tinted icons and glyphs; the dots style's pill sets a
  // contrasting one.
  property color tint: panel.tintColor
  property color glyphColor: panel.symbolColor
  // A soft square behind the icon, for the focused window's app.
  property bool highlighted: false
  property color highlightColor: panel.symbolColor
  // The window-count badge.
  property color badgeFill: panel.barBackground
  property color badgeInk: colored ? glyphColor : tint

  readonly property bool isGlyph: String(group.source || "").indexOf("glyph:") === 0
  readonly property bool imageFailed: !isGlyph && (String(group.source || "") === "" || image.status === Image.Error)
  readonly property bool tinted: !colored
  readonly property bool tintIsLight: 0.2126 * tint.r + 0.7152 * tint.g + 0.0722 * tint.b > 0.45

  hasVisualContent: true
  labelVisible: false
  horizontalMargin: 0
  verticalPadding: 0
  fixedWidth: iconSize
  fixedHeight: iconSize
  // The hover preview shows the windows already; the tooltip is for when
  // it's off.
  tooltipText: panel.showPreview ? "" : panel.groupTooltip(group)

  Accessible.role: Accessible.Button
  Accessible.name: (group.name || "App") + (group.count > 1 ? ", " + group.count + " windows" : "")

  onPressed: function(mouseButton) { panel.groupPressed(root.group, mouseButton) }
  onWheelMoved: function(delta) { panel.wheelStep(delta) }
  onTooltipHoveredChanged: panel.iconHovered(root, root.group, tooltipHovered)

  Rectangle {
    visible: root.highlighted
    anchors.centerIn: parent
    width: parent.width + Style.spaceReal(3)
    height: parent.height + Style.spaceReal(3)
    radius: Style.cornerRadius > 0 ? Style.space(5) : 0
    color: Qt.rgba(root.highlightColor.r, root.highlightColor.g, root.highlightColor.b, 0.18)
  }

  Item {
    id: iconBox
    anchors.fill: parent
    opacity: panel.shownIconOpacity

    Image {
      id: image
      visible: !root.isGlyph && !root.imageFailed
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
      sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
      source: root.isGlyph ? "" : (root.group.source || "")
      smooth: true
      // The effect stays on and only its strength changes: switching
      // `layer.enabled` on and off can leave an icon blank until it is
      // rebuilt, and the focused workspace flips that on every switch.
      layer.enabled: true
      // Render at physical pixels; the default logical-size layer blurs
      // icons on scaled displays.
      layer.textureSize: Qt.size(Math.round(width * Screen.devicePixelRatio), Math.round(height * Screen.devicePixelRatio))
      layer.smooth: true
      layer.effect: MultiEffect {
        // Lifted (or, for a dark tint, lowered) so tinted icons come out
        // close to the tint color. Tinted with a theme color, so they follow theme changes.
        brightness: root.tinted ? (root.tintIsLight ? 0.6 : -0.4) : 0
        colorization: root.tinted ? 1.0 : 0
        colorizationColor: root.tint
        saturation: root.grayscale && !root.tinted ? -1 : 0
      }
    }

    Text {
      visible: root.isGlyph
      anchors.centerIn: parent
      text: root.isGlyph ? String(root.group.source).substring(6) : ""
      // Glyphs have no colors of their own: the bar's text color, or the tint.
      color: root.colored ? root.glyphColor : root.tint
      opacity: root.grayscale && root.colored ? 0.7 : 1
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
      font.pixelSize: root.iconSize
      renderType: Text.NativeRendering
    }

    // A letter for an app whose icon did not load.
    Rectangle {
      visible: root.imageFailed
      anchors.fill: parent
      radius: Style.cornerRadius > 0 ? width * 0.25 : 0
      color: "transparent"
      border.width: Math.max(1, Style.space(1.5))
      border.color: root.colored ? root.glyphColor : root.tint

      Text {
        anchors.centerIn: parent
        text: panel.monogram(root.group.name || root.group.key)
        color: root.colored ? root.glyphColor : root.tint
        font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
        font.pixelSize: Math.round(root.iconSize * 0.62)
        font.bold: true
        renderType: Text.NativeRendering
      }
    }
  }

  // Number of this app's windows on the workspace.
  Rectangle {
    visible: panel.showCounts && root.group.count > 1
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: -Math.round(width * 0.35)
    anchors.bottomMargin: -Math.round(height * 0.25)
    width: Math.max(height, countText.implicitWidth + Style.space(4))
    height: Math.round(root.iconSize * 0.6)
    radius: height / 2
    color: root.badgeFill
    border.width: Math.max(1, Style.space(1))
    border.color: root.badgeInk

    Text {
      id: countText
      anchors.centerIn: parent
      text: root.group.count > 9 ? "9+" : String(root.group.count || "")
      color: root.badgeInk
      font.family: panel.bar ? panel.bar.fontFamily : Style.font.family
      font.pixelSize: Math.round(root.iconSize * 0.46)
      font.bold: true
      renderType: Text.NativeRendering
    }
  }

  // One of the app's windows wants attention.
  Rectangle {
    visible: panel.showUrgent && root.group.urgent === true
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: -Math.round(width * 0.3)
    anchors.topMargin: -Math.round(height * 0.3)
    width: Math.max(4, Math.round(root.iconSize * 0.36))
    height: width
    radius: width / 2
    color: panel.urgentColor
  }

  // Fade in when the app appears, not on every rebuild of the bar.
  Component.onCompleted: {
    if (panel.animationsReady) {
      iconBox.scale = 0.6
      appear.start()
    }
  }

  ParallelAnimation {
    id: appear
    NumberAnimation { target: iconBox; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
  }
}
