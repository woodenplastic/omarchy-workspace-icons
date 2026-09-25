import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Workspace indicators with the icons of the apps on each workspace.
//
// The grid symbol at the start opens the settings popup; right click on a
// workspace opens it too. Hotkey: `omarchy-shell woodenplastic.workspace-icons toggle`.
Panel {
  id: root
  moduleName: "woodenplastic.workspace-icons"
  ipcTarget: "woodenplastic.workspace-icons"

  // ---- Settings (inline on the shell.json entry).

  readonly property bool showIcons: setting("showIcons", true) !== false
  readonly property bool smallIcons: setting("smallIcons", false) === true
  readonly property bool coloredIcons: setting("coloredIcons", true) !== false
  readonly property bool showNumbers: setting("showNumbers", true) !== false
  readonly property bool showTerminalPrograms: setting("showTerminalPrograms", true) !== false
  readonly property int maxIcons: Math.max(1, Number(setting("maxIcons", 4)))
  // Where the app icons sit around the workspace number, and where the grid
  // symbol sits among the workspaces: "left", "center" or "right".
  readonly property string iconPosition: root.positionSetting("iconPosition", "right")
  readonly property string symbolPosition: root.positionSetting("symbolPosition", "left")
  // Map a window class or terminal program name to a theme icon name or an
  // absolute image path, for apps without an icon of their own.
  readonly property var iconOverrides: setting("iconOverrides", ({}))

  readonly property real iconSize: Math.round(Style.font.body * (smallIcons ? 0.9 : 1.15))

  function positionSetting(key, fallback) {
    var value = String(setting(key, fallback))
    return ["left", "center", "right"].indexOf(value) !== -1 ? value : fallback
  }

  function setSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    // Applied locally first so the bar updates on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ---- Bar layout state owned by other entries (the Omarchy logo and this
  //      widget's own section), read back from shell.json.

  property bool omarchyLogoShown: true
  property string widgetSection: "left"

  function readShellConfig(text) {
    var config
    try { config = JSON.parse(text) } catch (e) { return }
    var layout = config && config.bar && config.bar.layout ? config.bar.layout : {}
    var logo = false
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++) {
        var id = entries[i] && entries[i].id
        if (id === "omarchy.menu") logo = true
        if (id === root.moduleName) root.widgetSection = sections[s]
      }
    }
    root.omarchyLogoShown = logo
  }

  FileView {
    id: shellConfigFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readShellConfig(text())
  }

  function setOmarchyLogo(shown) {
    if (!root.bar) return
    root.omarchyLogoShown = shown
    // Removing the bar entry only hides the logo; the Omarchy menu and its
    // hotkey keep working.
    root.bar.run(shown ? "omarchy bar put omarchy.menu --section left --index 0" : "omarchy plugin disable omarchy.menu")
  }

  function setWidgetSection(section) {
    if (!root.bar || section === root.widgetSection) return
    root.close()
    root.bar.run("omarchy bar move " + root.moduleName + " --section " + section)
  }

  readonly property var toggles: [
    { key: "showIcons", label: "Show app icons", description: "An icon for each app open on a workspace." },
    { key: "smallIcons", label: "Small icons", description: "Smaller icons, closer to the text size." },
    { key: "coloredIcons", label: "Colored icons", description: "Off shows the icons in greyscale." },
    { key: "showNumbers", label: "Show numbers", description: "Off hides the number on workspaces that have icons." },
    { key: "omarchyLogo", label: "Show Omarchy logo", description: "The Omarchy menu button on the bar. The menu hotkey keeps working." }
  ]

  readonly property var choices: [
    { key: "widgetSection", label: "Bar section" },
    { key: "iconPosition", label: "Icon position" },
    { key: "symbolPosition", label: "Symbol position" }
  ]

  readonly property var positionOptions: [
    { value: "left", label: "Left" },
    { value: "center", label: "Center" },
    { value: "right", label: "Right" }
  ]

  function toggleValue(key) {
    if (key === "showIcons") return root.showIcons
    if (key === "smallIcons") return root.smallIcons
    if (key === "coloredIcons") return root.coloredIcons
    if (key === "showNumbers") return root.showNumbers
    if (key === "omarchyLogo") return root.omarchyLogoShown
    return false
  }

  function flipToggle(key) {
    if (key === "omarchyLogo") root.setOmarchyLogo(!root.omarchyLogoShown)
    else root.setSetting(key, !root.toggleValue(key))
  }

  function choiceValue(key) {
    if (key === "widgetSection") return root.widgetSection
    if (key === "iconPosition") return root.iconPosition
    if (key === "symbolPosition") return root.symbolPosition
    return ""
  }

  function setChoice(key, value) {
    if (key === "widgetSection") root.setWidgetSection(value)
    else root.setSetting(key, value)
  }

  // Step a choice left/right (keyboard), clamped to the ends.
  function stepChoice(key, direction) {
    var values = ["left", "center", "right"]
    var next = values.indexOf(root.choiceValue(key)) + direction
    if (next >= 0 && next < values.length) root.setChoice(key, values[next])
  }

  // ---- Workspaces.

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---- App icons.

  readonly property var shells: ["bash", "zsh", "fish", "sh", "dash", "nu", "xonsh", "elvish", "ksh", "tcsh"]
  // Terminal window pid -> name of the program in the terminal's foreground.
  property var terminalPrograms: ({})

  function windowInfo(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    var appId = toplevel.wayland && toplevel.wayland.appId ? toplevel.wayland.appId : String(ipc.class || "")
    return {
      appId: appId,
      initialClass: String(ipc.initialClass || ""),
      initialTitle: String(ipc.initialTitle || ""),
      pid: Number(ipc.pid || 0)
    }
  }

  function themedIcon(name) {
    if (!name) return ""
    if (name.charAt(0) === "/") return "file://" + name
    return Quickshell.iconPath(name, true)
  }

  function entryIcon(name) {
    if (!name) return ""
    var entry = DesktopEntries.heuristicLookup(name)
    return entry && entry.icon ? root.themedIcon(entry.icon) : ""
  }

  function isTerminalEntry(name) {
    if (!name) return false
    var entry = DesktopEntries.heuristicLookup(name)
    return !!entry && !!entry.categories && entry.categories.indexOf("TerminalEmulator") !== -1
  }

  // Terminals launched with a custom app id (e.g. `foot --app-id=x`) still
  // carry the terminal's name as their initial title.
  function isTerminal(info) {
    return root.isTerminalEntry(info.appId) || root.isTerminalEntry(info.initialClass) || root.isTerminalEntry(info.initialTitle)
  }

  function programIcon(name) {
    if (!name || root.shells.indexOf(name) !== -1) return ""
    var override = root.iconOverrides[name]
    if (override) return root.themedIcon(String(override))
    return root.entryIcon(name) || root.themedIcon(name)
  }

  function iconFor(info) {
    var override = root.iconOverrides[info.appId]
    if (override) return root.themedIcon(String(override))

    if (root.showTerminalPrograms && root.isTerminal(info)) {
      var program = root.programIcon(root.terminalPrograms[String(info.pid)])
      if (program) return program
    }

    var path = root.entryIcon(info.appId)
      || root.themedIcon(info.appId)
      || root.themedIcon(info.appId.toLowerCase())
      || root.entryIcon(info.initialClass)
      || root.entryIcon(info.initialTitle)
    return path || Quickshell.iconPath("application-x-executable", true)
  }

  // One icon per distinct app (or terminal program) on the workspace, in window order.
  function workspaceIcons(workspace) {
    if (workspace === null || !root.showIcons) return []
    var seen = []
    var icons = []
    var toplevels = workspace.toplevels.values
    for (var i = 0; i < toplevels.length && icons.length < root.maxIcons; i++) {
      var info = root.windowInfo(toplevels[i])
      if (info.appId === "") continue
      var icon = root.iconFor(info)
      if (seen.indexOf(icon) !== -1) continue
      seen.push(icon)
      icons.push(icon)
    }
    return icons
  }

  function terminalPids() {
    var pids = []
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var info = root.windowInfo(values[i])
      if (info.pid > 0 && root.isTerminal(info)) pids.push(String(info.pid))
    }
    return pids
  }

  function refreshTerminalPrograms() {
    if (!root.showIcons || !root.showTerminalPrograms || programProbe.running) return
    var pids = root.terminalPids()
    if (pids.length === 0) {
      root.terminalPrograms = ({})
      return
    }
    programProbe.command = ["bash", "-c", root.probeScript, "probe"].concat(pids)
    programProbe.running = true
  }

  // For each terminal pid, print the foreground program on the terminal's tty.
  readonly property string probeScript: 'for pid in "$@"; do\n'
    + '  name=""\n'
    + '  child=$(cat /proc/"$pid"/task/*/children 2>/dev/null | tr " " "\\n" | grep -m1 .)\n'
    + '  if [ -n "$child" ] && stat=$(cat /proc/"$child"/stat 2>/dev/null); then\n'
    + '    set -- ${stat##*) }\n'
    + '    [ "${6:-0}" -gt 0 ] && name=$(cat /proc/"$6"/comm 2>/dev/null)\n'
    + '  fi\n'
    + '  echo "$pid $name"\n'
    + 'done\n'

  Process {
    id: programProbe
    stdout: StdioCollector {
      onStreamFinished: {
        var next = ({})
        var lines = this.text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].trim().split(" ")
          if (parts[0]) next[parts[0]] = parts.slice(1).join(" ")
        }
        if (JSON.stringify(next) !== JSON.stringify(root.terminalPrograms)) root.terminalPrograms = next
      }
    }
  }

  Timer {
    interval: Math.max(1, Number(root.setting("terminalPollSeconds", 2))) * 1000
    running: root.showIcons && root.showTerminalPrograms
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshTerminalPrograms()
  }

  Component.onCompleted: Hyprland.refreshToplevels()

  // ---- Bar.

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property color symbolColor: bar ? bar.barForeground : Color.foreground
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property var workspaceList: root.workspaceIds()
  // Slot the grid symbol takes in the row; workspaces after it shift by one.
  readonly property int symbolSlot: root.symbolPosition === "left" ? 0
    : (root.symbolPosition === "right" ? root.workspaceList.length : Math.ceil(root.workspaceList.length / 2))

  implicitWidth: layout.implicitWidth + trailingGap
  implicitHeight: layout.implicitHeight

  GridLayout {
    id: layout
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceList.length + 1
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    WidgetButton {
      id: launcher
      Layout.row: root.vertical ? root.symbolSlot : 0
      Layout.column: root.vertical ? 0 : root.symbolSlot
      bar: root.bar
      hasVisualContent: true
      labelVisible: false
      tooltipText: "Workspace Icons settings"
      fixedWidth: root.vertical ? root.barSize : Style.space(22)
      fixedHeight: root.barSize
      onPressed: function() { root.toggle() }

      // 2x2 workspace grid, the first cell filled as the "current" one.
      Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: Math.max(1, Style.space(2))

        Repeater {
          model: 4

          Rectangle {
            required property int index
            width: Math.round(Style.font.body * 0.42)
            height: width
            radius: Style.cornerRadius > 0 ? Math.max(1, width * 0.25) : 0
            color: index === 0 ? root.symbolColor : "transparent"
            border.width: Math.max(1, Style.space(1.5))
            border.color: root.symbolColor
          }
        }
      }
    }

    Repeater {
      model: root.workspaceList

      WidgetButton {
        id: button
        required property int modelData
        required property int index

        readonly property int slot: index < root.symbolSlot ? index : index + 1
        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property var icons: root.vertical ? [] : root.workspaceIcons(workspace)
        // "center" splits the icons around the number.
        readonly property int iconsBefore: root.iconPosition === "left" ? icons.length
          : (root.iconPosition === "right" ? 0 : Math.floor(icons.length / 2))
        // Workspaces with icons may drop their number; the focus mark and
        // empty workspaces always keep a label so every slot stays visible.
        readonly property string label: focused ? "󱓻"
          : (root.showNumbers || icons.length === 0 ? (modelData === 10 ? "0" : String(modelData)) : "")

        Layout.row: root.vertical ? slot : 0
        Layout.column: root.vertical ? 0 : slot
        bar: root.bar
        text: focused ? "󱓻" : (modelData === 10 ? "0" : String(modelData))
        labelVisible: false
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Math.max(Style.space(20), content.implicitWidth + Style.spaceReal(6) * 2)
        fixedHeight: root.barSize
        onPressed: function(mouseButton) {
          if (mouseButton === Qt.RightButton) root.toggle()
          else root.focusWorkspace(modelData)
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: Style.spaceReal(3)

          Repeater {
            model: button.icons.slice(0, button.iconsBefore)
            delegate: appIcon
          }

          Text {
            visible: button.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: button.label
            color: button.foreground
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
          }

          Repeater {
            model: button.icons.slice(button.iconsBefore)
            delegate: appIcon
          }
        }
      }
    }
  }

  Component {
    id: appIcon

    Image {
      required property string modelData
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      width: root.iconSize
      height: root.iconSize
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
      sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
      source: modelData
      smooth: true
      layer.enabled: !root.coloredIcons
      layer.effect: MultiEffect {
        saturation: -1
      }
    }
  }

  // ---- Settings popup.

  // Keyboard cursor over the popup rows: toggles first, then the choices.
  property int cursorIndex: -1
  readonly property int rowCount: toggles.length + choices.length
  readonly property color panelForeground: bar ? bar.foreground : Color.foreground
  readonly property string panelFont: bar ? bar.fontFamily : Style.font.family

  function activateRow(row, direction) {
    if (row < 0) return
    if (row < root.toggles.length) {
      root.flipToggle(root.toggles[row].key)
      return
    }
    var choice = root.choices[row - root.toggles.length]
    if (!choice) return
    if (direction !== 0) {
      root.stepChoice(choice.key, direction)
    } else {
      // Enter cycles through the three values.
      var values = ["left", "center", "right"]
      root.setChoice(choice.key, values[(values.indexOf(root.choiceValue(choice.key)) + 1) % values.length])
    }
  }

  onOpenedChanged: if (opened) {
    cursorIndex = -1
    shellConfigFile.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  KeyboardPanel {
    id: panel
    anchorItem: launcher
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.cursorIndex < 0) { root.cursorIndex = 0; return }
        if (dy !== 0) root.cursorIndex = Math.max(0, Math.min(root.rowCount - 1, root.cursorIndex + dy))
        else if (dx !== 0 && root.cursorIndex >= root.toggles.length) root.activateRow(root.cursorIndex, dx)
      }
      onActivateRequested: root.activateRow(root.cursorIndex, 0)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: flick.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "WORKSPACE ICONS"
            foreground: root.panelForeground
            fontFamily: root.panelFont
          }

          Repeater {
            model: root.toggles

            Toggle {
              required property var modelData
              required property int index
              width: column.width
              label: modelData.label
              description: modelData.description
              checked: root.toggleValue(modelData.key)
              hasCursor: root.cursorIndex === index
              foreground: root.panelForeground
              fontFamily: root.panelFont
              onHovered: function(h) { if (h) root.cursorIndex = index }
              onClicked: root.flipToggle(modelData.key)
            }
          }

          PanelSeparator {
            foreground: root.panelForeground
          }

          PanelSectionHeader {
            text: "POSITION"
            foreground: root.panelForeground
            fontFamily: root.panelFont
          }

          Repeater {
            model: root.choices

            Item {
              id: choiceRow
              required property var modelData
              required property int index
              readonly property int row: root.toggles.length + index
              width: column.width
              implicitHeight: Math.max(choiceLabel.implicitHeight, group.implicitHeight)

              Text {
                id: choiceLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: group.left
                anchors.rightMargin: Style.space(10)
                textFormat: Text.PlainText
                text: choiceRow.modelData.label
                color: root.panelForeground
                font.family: root.panelFont
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }

              ButtonGroup {
                id: group
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                options: root.positionOptions
                value: root.choiceValue(choiceRow.modelData.key)
                focusable: false
                cursorIndex: root.cursorIndex === choiceRow.row
                  ? root.positionOptions.findIndex(function(o) { return o.value === group.value }) : -1
                foreground: root.panelForeground
                fontFamily: root.panelFont
                fontSize: Style.font.bodySmall
                onChanged: function(v) { root.setChoice(choiceRow.modelData.key, v) }
                onHovered: function(i, h) { if (h) root.cursorIndex = choiceRow.row }
              }
            }
          }
        }
      }
    }
  }
}
