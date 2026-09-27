import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// One workspace on the bar: its number (or name) and the icons of the apps
// on it. `key` is "3" for a numbered workspace, "name:web" for a named one
// and "special:scratchpad" for a special one.
WidgetButton {
  id: button

  required property var panel
  required property string key

  readonly property bool isSpecial: key.indexOf("special:") === 0
  readonly property bool isNamed: key.indexOf("name:") === 0
  readonly property int number: isSpecial || isNamed ? 0 : Number(key)
  readonly property var workspace: panel.workspaceByKey(key)
  readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
  // Keyboard focus is here.
  readonly property bool focused: !isSpecial && workspace !== null && Hyprland.focusedWorkspace === workspace
  // Shown on this bar's monitor (with keyboard focus elsewhere).
  readonly property bool shownHere: !isSpecial && !focused && panel.shownOnBarMonitor(workspace)
  readonly property bool specialOpen: isSpecial && panel.specialOpenHere(key)
  readonly property bool urgent: panel.showUrgent && workspace !== null && workspace.urgent && occupied && !focused

  // Icon groups, replaced only when their content changes, so the icon
  // delegates stay put (see setGroups).
  readonly property var computedGroups: panel.workspaceGroups(workspace)
  property var groups: []
  property string groupsSignature: ""
  onComputedGroupsChanged: setGroups(computedGroups)
  Component.onCompleted: setGroups(computedGroups)

  function setGroups(list) {
    var signature = JSON.stringify(list)
    if (signature === groupsSignature) return
    groupsSignature = signature
    groups = list
  }

  readonly property var visibleGroups: panel.visibleGroups(groups, vertical)
  readonly property int overflow: Math.max(0, groups.length - visibleGroups.length)
  readonly property int iconsBefore: panel.iconPosition === "left" ? visibleGroups.length : 0

  // Full-color icons stand in for the focus mark; an empty focused
  // workspace has no icons to color, so it keeps the mark.
  readonly property bool focusByColor: focused && groups.length > 0 && panel.colorFocused && !panel.coloredIcons
  readonly property bool colorIcons: panel.coloredIcons || focusByColor
  readonly property bool grayIcons: panel.coloredIcons && panel.grayscaleUnfocused && !focused

  readonly property string customName: panel.workspaceName(key)
  readonly property string numberText: isSpecial ? panel.specialLabel(key)
    : (isNamed ? key.substring(5) : (number === 10 ? "0" : String(number)))
  // Workspaces with icons may drop their number; a custom name, the focus
  // mark and empty workspaces always keep a label so every slot stays visible.
  readonly property string label: (focused || shownHere) && !focusByColor && customName === "" && !tiles ? "󱓻"
    : (customName !== "" ? customName
      : (panel.showNumbers || groups.length === 0 || isSpecial || isNamed ? numberText : ""))

  // ---- Tiles style: a rounded tile behind each workspace with windows,
  //      a stronger one for the workspace you're on.
  readonly property bool tiles: panel.tilesStyle
  readonly property bool tileShown: tiles && (occupied || focused || shownHere || urgent || specialOpen || hovered)
  readonly property bool tileSolid: tiles && focused && panel.activeTile !== "subtle"
  readonly property color tileFill: focused ? panel.activeTileFill()
    : Qt.rgba(panel.symbolColor.r, panel.symbolColor.g, panel.symbolColor.b, hovered ? 0.12 : (occupied || specialOpen ? 0.07 : 0))
  // Text and tinted icons on a solid or accent tile take a color that reads on it.
  readonly property color tileInk: panel.contrastOn(panel.activeTileFill())

  // ---- Dots style: every workspace a dot, the focused one (or an open
  //      special workspace) a pill carrying its icons and/or number.
  readonly property bool dots: panel.dotsStyle
  readonly property bool pill: dots && (focused || specialOpen)
  readonly property bool pillIcons: pill && (panel.pillContent === "icons" || panel.pillContent === "both") && visibleGroups.length > 0
  readonly property bool pillLabel: pill && (panel.pillContent === "number" || panel.pillContent === "both")
  // Colored icons sit on a see-through pill so their own colors read;
  // tinted ones on a solid pill in a color that contrasts with it.
  readonly property bool pillHasContent: pillIcons || pillLabel
  // Without the frame the pill's content sits on the bar itself; an empty
  // pill keeps its shape so the focused workspace still shows.
  readonly property bool pillFramed: panel.pillFrame || !pillHasContent
  readonly property bool pillSolid: pillFramed && (!colorIcons || !pillIcons)
  readonly property color pillInk: pillSolid ? panel.contrastOn(panel.tintColor)
    : (pillFramed || panel.coloredIcons ? panel.symbolColor : panel.tintColor)
  readonly property real dotSize: Style.spaceReal(8)
  // An empty pill stays as thin as the dots.
  readonly property real pillThickness: !pillHasContent ? dotSize
    : Math.max(dotSize * 2, Math.min(panel.barSize - Style.spaceReal(6), panel.iconSize + Style.spaceReal(6)))
  readonly property real pillLength: Math.max(dotSize * 2.4, (vertical ? pillBody.implicitHeight : pillBody.implicitWidth) + Style.spaceReal(8) * (pillHasContent ? 1 : 0))
  readonly property real shapeAlong: pill ? pillLength : dotSize
  readonly property real shapeAcross: pill ? pillThickness : dotSize

  // Hovering an icon moves the pointer off this button's own hover area,
  // so the icons report their hover here.
  property int hoveredIcons: 0
  readonly property bool hovered: tooltipHovered || hoveredIcons > 0
  onHoveredChanged: panel.hoverWorkspace(button, key, hovered)

  bar: panel.bar
  text: label
  labelVisible: false
  // The label can be empty (icons only); the button still shows.
  hasVisualContent: true
  opacity: dots || occupied || focused || shownHere || specialOpen ? 1 : 0.5
  horizontalMargin: 6
  verticalPadding: 6
  fixedWidth: vertical ? panel.barSize
    : (dots ? shapeAlong + Style.spaceReal(6)
      : Math.max(Style.space(20), content.implicitWidth + Style.spaceReal(tiles ? 9 : 6) * 2))
  fixedHeight: vertical ? (dots ? shapeAlong + Style.spaceReal(6) : Math.max(panel.barSize * 0.8, content.implicitHeight + Style.spaceReal(5) * 2))
    : panel.barSize
  // Dots have no label to read; without the preview, a tooltip names them.
  tooltipText: dots && !panel.showPreview ? panel.workspaceAccessibleName(button) : ""

  Behavior on fixedWidth {
    enabled: button.dots && panel.animationsReady
    NumberAnimation { duration: 150; easing.type: Easing.InOutSine }
  }

  Behavior on fixedHeight {
    enabled: button.dots && panel.animationsReady
    NumberAnimation { duration: 150; easing.type: Easing.InOutSine }
  }

  Accessible.role: Accessible.Button
  Accessible.name: panel.workspaceAccessibleName(button)

  Behavior on opacity {
    enabled: panel.animations
    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
  }

  onPressed: function(mouseButton) { panel.workspacePressed(button, mouseButton) }
  onWheelMoved: function(delta) { panel.wheelStep(delta) }

  // The tile, with an urgent glow underneath so the tile's own look still reads.
  Rectangle {
    id: urgentGlow
    visible: button.tiles && button.urgent
    anchors.fill: tile
    radius: tile.radius
    color: panel.urgentColor
    opacity: 0.35

    SequentialAnimation on opacity {
      running: urgentGlow.visible && panel.animations
      loops: Animation.Infinite
      NumberAnimation { from: 0.15; to: 0.55; duration: 700; easing.type: Easing.InOutSine }
      NumberAnimation { from: 0.55; to: 0.15; duration: 700; easing.type: Easing.InOutSine }
    }
  }

  Rectangle {
    id: tile
    visible: button.tileShown
    anchors.fill: parent
    anchors.leftMargin: button.vertical ? Style.spaceReal(3) : Style.spaceReal(2)
    anchors.rightMargin: anchors.leftMargin
    anchors.topMargin: button.vertical ? Style.spaceReal(2) : Style.spaceReal(4)
    anchors.bottomMargin: anchors.topMargin
    radius: Style.cornerRadius > 0 ? Math.min(height / 2, Style.space(8)) : 0
    color: button.tileFill
    border.width: button.shownHere ? Math.max(1, Style.space(1.5)) : 0
    border.color: panel.tintColor

    Behavior on color {
      enabled: panel.animations
      ColorAnimation { duration: 160 }
    }
  }

  Grid {
    id: content
    visible: !button.dots
    anchors.centerIn: parent
    // One row on horizontal bars, one column on vertical ones.
    columns: button.vertical ? 1 : 64
    spacing: Style.spaceReal(3)
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Repeater {
      model: button.dots ? 0 : button.iconsBefore
      delegate: GroupIcon {}
    }

    Text {
      id: labelText
      visible: button.label !== ""
      textFormat: Text.PlainText
      text: button.label
      color: button.tileSolid ? button.tileInk
        : (button.urgent && !button.tiles ? panel.urgentColor : (panel.coloredIcons ? button.foreground : panel.tintColor))
      opacity: button.shownHere && button.label === "󱓻" ? 0.55 : 1
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      font.underline: button.specialOpen
      renderType: Text.NativeRendering

      Behavior on color {
        enabled: panel.animations
        ColorAnimation { duration: 160 }
      }

      // A pulse while a window here wants attention (the tile glows instead).
      SequentialAnimation on opacity {
        running: button.urgent && panel.animations && !button.tiles
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.35; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
      }
    }

    Repeater {
      model: button.dots ? 0 : button.visibleGroups.length - button.iconsBefore
      delegate: GroupIcon { offset: button.iconsBefore }
    }

    // Apps past the icon limit.
    Text {
      visible: button.overflow > 0
      textFormat: Text.PlainText
      text: "+" + button.overflow
      color: panel.coloredIcons ? button.foreground : panel.tintColor
      opacity: 0.8
      font.family: button.fontFamily
      font.pixelSize: Math.round(button.fontSize * 0.8)
      renderType: Text.NativeRendering
    }
  }

  // The dot, or the pill of the focused workspace.
  Rectangle {
    id: shape
    visible: button.dots
    anchors.centerIn: parent
    width: button.vertical ? button.shapeAcross : button.shapeAlong
    height: button.vertical ? button.shapeAlong : button.shapeAcross
    // Special workspaces are squarer, to tell them apart.
    radius: button.isSpecial && !button.pill ? Math.max(1, width * 0.25) : Math.min(width, height) / 2
    // The workspace another monitor shows is a ring; others are filled,
    // dimmer when empty.
    color: button.pill ? (!button.pillFramed ? "transparent"
        : (button.pillSolid ? panel.tintColor : Qt.rgba(panel.tintColor.r, panel.tintColor.g, panel.tintColor.b, 0.22)))
      : (button.shownHere ? "transparent" : (button.urgent ? panel.urgentColor : panel.symbolColor))
    opacity: button.pill || button.shownHere || button.urgent ? 1 : (button.occupied ? 0.8 : 0.35)
    border.width: (button.shownHere && !button.pill) || (button.pill && button.pillFramed && !button.pillSolid) ? Math.max(1, Style.space(1.5)) : 0
    border.color: panel.tintColor

    Behavior on width {
      enabled: panel.animationsReady
      NumberAnimation { duration: 150; easing.type: Easing.InOutSine }
    }
    Behavior on height {
      enabled: panel.animationsReady
      NumberAnimation { duration: 150; easing.type: Easing.InOutSine }
    }
    Behavior on color {
      enabled: panel.animations
      ColorAnimation { duration: 150 }
    }
    Behavior on opacity {
      enabled: panel.animations && !button.urgent
      NumberAnimation { duration: 150 }
    }

    // A pulse while a window here wants attention.
    SequentialAnimation on scale {
      running: button.dots && button.urgent && panel.animations
      loops: Animation.Infinite
      alwaysRunToEnd: true
      NumberAnimation { to: 1.35; duration: 520; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: 520; easing.type: Easing.InOutSine }
    }

    Grid {
      id: pillBody
      anchors.centerIn: parent
      visible: button.pill
      opacity: button.pill ? 1 : 0
      columns: button.vertical ? 1 : 64
      spacing: Style.spaceReal(3)
      horizontalItemAlignment: Grid.AlignHCenter
      verticalItemAlignment: Grid.AlignVCenter

      Behavior on opacity {
        enabled: panel.animationsReady
        NumberAnimation { duration: 180 }
      }

      Text {
        visible: button.pillLabel
        textFormat: Text.PlainText
        text: button.customName !== "" ? button.customName : button.numberText
        color: button.pillInk
        font.family: button.fontFamily
        font.pixelSize: Math.round(button.fontSize * 0.9)
        font.bold: true
        renderType: Text.NativeRendering
      }

      Repeater {
        model: button.pillIcons ? button.visibleGroups.length : 0
        delegate: GroupIcon {}
      }

      Text {
        visible: button.pillIcons && button.overflow > 0
        textFormat: Text.PlainText
        text: "+" + button.overflow
        color: button.pillInk
        font.family: button.fontFamily
        font.pixelSize: Math.round(button.fontSize * 0.75)
        font.bold: true
        renderType: Text.NativeRendering
      }
    }
  }

  // An icon for visibleGroups[offset + index].
  component GroupIcon: AppIconButton {
    required property int index
    property int offset: 0
    panel: button.panel
    bar: button.panel.bar
    group: button.visibleGroups[offset + index] || ({})
    colored: button.colorIcons
    grayscale: button.grayIcons
    iconSize: button.panel.iconSize
    // On the pill, tinted icons and glyphs take a color that reads on it.
    tint: button.pill && button.pillSolid ? button.pillInk : (button.tileSolid ? button.tileInk : button.panel.tintColor)
    glyphColor: button.pill && button.pillFramed ? button.pillInk : (button.tileSolid ? button.tileInk : button.panel.symbolColor)
    // In the tiles style the focused window's app gets its own highlight.
    highlighted: button.tiles && button.focused && group.focused === true && button.groups.length > 1
    highlightColor: button.tileSolid ? button.tileInk : button.panel.symbolColor
    badgeFill: button.pill && button.pillSolid ? button.pillInk : button.panel.barBackground
    badgeInk: button.pill && button.pillSolid ? button.panel.tintColor : (colored ? glyphColor : tint)
    onTooltipHoveredChanged: button.hoveredIcons = Math.max(0, button.hoveredIcons + (tooltipHovered ? 1 : -1))
    Component.onDestruction: if (tooltipHovered) button.hoveredIcons = Math.max(0, button.hoveredIcons - 1)
  }
}
