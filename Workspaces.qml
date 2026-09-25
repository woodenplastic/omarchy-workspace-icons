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
  // Map a window class or terminal program name to a theme icon name or an
  // absolute image path, for apps without an icon of their own.
  readonly property var iconOverrides: setting("iconOverrides", ({}))

  readonly property real iconSize: Math.round(Style.font.body * (smallIcons ? 0.9 : 1.15))

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

  readonly property var options: [
    { key: "showIcons", label: "Show app icons", description: "An icon for each app open on a workspace." },
    { key: "smallIcons", label: "Small icons", description: "Smaller icons, closer to the text size." },
    { key: "coloredIcons", label: "Colored icons", description: "Off shows the icons in greyscale." },
    { key: "showNumbers", label: "Show numbers", description: "Off hides the number on workspaces that have icons." }
  ]

  function optionValue(key) {
    if (key === "showIcons") return root.showIcons
    if (key === "smallIcons") return root.smallIcons
    if (key === "coloredIcons") return root.coloredIcons
    if (key === "showNumbers") return root.showNumbers
    return false
  }

  function toggleOption(index) {
    var option = root.options[index]
    if (option) root.setSetting(option.key, !root.optionValue(option.key))
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

  implicitWidth: layout.implicitWidth + trailingGap
  implicitHeight: layout.implicitHeight

  GridLayout {
    id: layout
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : 2
    columnSpacing: Style.space(1)
    rowSpacing: Style.space(2)

    WidgetButton {
      id: launcher
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

    GridLayout {
      id: grid
      columns: root.vertical ? 1 : root.workspaceIds().length
      columnSpacing: root.vertical ? 0 : Style.space(1)
      rowSpacing: root.vertical ? Style.space(2) : 0

      Repeater {
        model: root.workspaceIds()

        WidgetButton {
          id: button
          required property int modelData

          readonly property var workspace: root.workspaceById(modelData)
          readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
          readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
          readonly property var icons: root.vertical ? [] : root.workspaceIcons(workspace)
          // Workspaces with icons may drop their number; the focus mark and
          // empty workspaces always keep a label so every slot stays visible.
          readonly property string label: focused ? "󱓻"
            : (root.showNumbers || icons.length === 0 ? (modelData === 10 ? "0" : String(modelData)) : "")

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
              model: button.icons

              Image {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
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
          }
        }
      }
    }
  }

  // ---- Settings popup.

  property int cursorIndex: -1
  readonly property color panelForeground: bar ? bar.foreground : Color.foreground
  readonly property string panelFont: bar ? bar.fontFamily : Style.font.family

  onOpenedChanged: if (opened) {
    cursorIndex = -1
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  KeyboardPanel {
    id: panel
    anchorItem: launcher
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy === 0) return
        if (root.cursorIndex < 0) root.cursorIndex = 0
        else root.cursorIndex = Math.max(0, Math.min(root.options.length - 1, root.cursorIndex + dy))
      }
      onActivateRequested: if (root.cursorIndex >= 0) root.toggleOption(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelSectionHeader {
          text: "WORKSPACE ICONS"
          foreground: root.panelForeground
          fontFamily: root.panelFont
        }

        Repeater {
          model: root.options

          Toggle {
            required property var modelData
            required property int index
            width: column.width
            label: modelData.label
            description: modelData.description
            checked: root.optionValue(modelData.key)
            hasCursor: root.cursorIndex === index
            foreground: root.panelForeground
            fontFamily: root.panelFont
            onHovered: function(h) { if (h) root.cursorIndex = index }
            onClicked: root.toggleOption(index)
          }
        }
      }
    }
  }
}
