import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Glyphs.js" as Glyphs

// Workspace indicators with the icons of the apps on each workspace.
//
// The plugin symbol at the start opens the settings popup; right click on a
// workspace opens it too. Hotkey: `omarchy-shell woodenplastic.workspace-icons toggle`.
Panel {
  id: root
  moduleName: "woodenplastic.workspace-icons"
  // The plugin symbol can sit in its own bar section as a second entry of this
  // widget with `"mode": "symbol"`; that entry draws only the symbol.
  readonly property bool symbolMode: settings && settings.mode === "symbol"
  ipcTarget: symbolMode ? "" : "woodenplastic.workspace-icons"
  // IPC is handled below so the tray icon can open the popup at its click.
  manageIpc: false

  // ---- Settings. The workspaces entry owns them; the symbol entry reads
  //      them back from shell.json so its popup shows the same values.

  readonly property var widgetSettings: symbolMode ? mainSettings : settings

  function option(name, fallback) {
    var value = widgetSettings ? widgetSettings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property bool showIcons: option("showIcons", true) !== false
  readonly property bool coloredIcons: option("coloredIcons", true) !== false
  // With tinted icons, mark the focused workspace by showing its icons in
  // full color instead of the focus mark.
  readonly property bool colorFocused: option("colorFocused", false) === true
  // Color that icons (and numbers) take with colored icons off: the theme's
  // "accent" color or its "normal" text color. Older values map across.
  readonly property string tintStyle: ["normal", "greyscale"].indexOf(String(option("tintStyle", "accent"))) !== -1 ? "normal" : "accent"
  readonly property color tintColor: tintStyle === "accent" ? Color.accent : symbolColor
  readonly property bool showNumbers: option("showNumbers", true) !== false
  readonly property bool showTerminalPrograms: option("showTerminalPrograms", true) !== false
  readonly property int maxIcons: Math.max(1, Number(option("maxIcons", 4)))
  // Which side of the workspace number the app icons sit on: "left" or "right".
  readonly property string iconPosition: option("iconPosition", "right") === "left" ? "left" : "right"
  // Map a window class or terminal program name to a theme icon name or an
  // absolute image path, for apps without an icon of their own.
  readonly property var iconOverrides: option("iconOverrides", ({}))
  // The plugin symbol shown as a system tray icon (scripts/tray-icon) instead of on the bar.
  readonly property bool symbolInTray: option("symbolInTray", false) === true

  readonly property real iconSize: Math.round(Style.font.body * 1.15)

  readonly property string configScript: Qt.resolvedUrl("scripts/config").toString().replace(/^file:\/\//, "")

  function runConfig(args) {
    if (!root.bar) return
    root.bar.run(Util.shellQuote(root.configScript) + " " + args.map(Util.shellQuote).join(" "))
  }

  // The shell's own inline-settings update rewrites every entry with this id,
  // which would turn the symbol entry into a second workspaces widget, so
  // settings go through scripts/config instead.
  function setSetting(key, value) {
    if (!root.symbolMode) {
      // Applied locally first so the bar updates on the click itself.
      var entry = {}
      for (var k in root.settings) entry[k] = root.settings[k]
      entry[key] = value
      root.settings = entry
    }
    root.runConfig(["set", key, JSON.stringify(value)])
  }

  // ---- Bar layout state owned by other entries (the Omarchy logo and this
  //      widget's own section), read back from shell.json.

  property bool omarchyLogoShown: true
  property string widgetSection: "left"
  // Section of the separate symbol entry; "" while the symbol is drawn inline.
  property string symbolSection: ""
  property var mainSettings: ({})

  function readShellConfig(text) {
    var config
    try { config = JSON.parse(text) } catch (e) { return }
    var layout = config && config.bar && config.bar.layout ? config.bar.layout : {}
    var logo = false
    var symbol = ""
    var hasMain = false
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var entries = layout[sections[s]] || []
      for (var i = 0; i < entries.length; i++) {
        var entry = entries[i] || {}
        if (entry.id === "omarchy.menu") logo = true
        if (entry.id !== root.moduleName) continue
        if (entry.mode === "symbol") {
          symbol = sections[s]
        } else {
          hasMain = true
          root.widgetSection = sections[s]
          root.mainSettings = entry
        }
      }
    }
    root.omarchyLogoShown = logo
    root.symbolSection = symbol
    if (root.symbolMode && !hasMain) root.removeOrphanSymbol()
  }

  // Disabling or removing the plugin puts omarchy.workspaces back in place of
  // the workspaces entry (manifest `clonedFrom`), but leaves a separate symbol
  // entry behind. The symbol removes itself then, through Omarchy's config
  // helper rather than a plugin file, since the plugin folder may already be
  // gone by the time the command runs.
  function removeOrphanSymbol() {
    if (!root.bar) return
    root.bar.run("bash -c " + Util.shellQuote(
      'source omarchy-shell-config && commit "$NORMALIZE | .bar.layout |= map_values(map(select((.id == \\"'
      + root.moduleName + '\\" and .mode == \\"symbol\\") | not)))"'))
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
    if (section === root.widgetSection) return
    root.close()
    root.runConfig(["main", section])
  }

  function setSymbolSection(section) {
    if (section === root.symbolSection && !root.symbolInTray) return
    root.close()
    root.runConfig(["symbol", section])
  }

  readonly property var toggles: [
    { key: "showIcons", label: "App icons", description: "An icon for each app open on a workspace." },
    { key: "coloredIcons", label: "Colored icons", description: "Off tints the icons, see Tint below." },
    // Sub-option of Colored icons, shown only while that is off.
    { key: "tintStyle", label: "Tint", parentKey: "coloredIcons", shownWhen: false,
      options: [{ value: "accent", label: "Accent" }, { value: "normal", label: "Normal" }] },
    { key: "colorFocused", label: "Color the focused workspace", description: "Show its icons in color instead of the focus mark.", parentKey: "coloredIcons", shownWhen: false },
    { key: "showNumbers", label: "Workspace numbers", description: "Off hides the number on workspaces that have icons." },
    { key: "omarchyLogo", label: "Show Omarchy logo", description: "The Omarchy menu button on the bar. The menu hotkey keeps working." }
  ]

  readonly property var sectionOptions: [
    { value: "left", label: "Left" },
    { value: "center", label: "Center" },
    { value: "right", label: "Right" }
  ]

  readonly property var choices: [
    { key: "widgetSection", label: "Bar section", options: sectionOptions },
    { key: "iconPosition", label: "Icon position", options: [{ value: "left", label: "Left" }, { value: "right", label: "Right" }] },
    { key: "symbolPosition", label: "Plugin symbol", options: sectionOptions.concat([{ value: "tray", label: "Tray" }]) }
  ]

  function choiceValues(choice) {
    return choice.options.map(function(o) { return o.value })
  }

  function toggleValue(key) {
    if (key === "showIcons") return root.showIcons
    if (key === "coloredIcons") return root.coloredIcons
    if (key === "colorFocused") return root.colorFocused
    if (key === "showNumbers") return root.showNumbers
    if (key === "omarchyLogo") return root.omarchyLogoShown
    return false
  }

  function rowVisible(row) {
    var toggle = root.toggles[row]
    return !toggle || !toggle.parentKey || root.toggleValue(toggle.parentKey) === toggle.shownWhen
  }

  // Move the keyboard cursor by one visible row.
  function moveCursor(direction) {
    var row = root.cursorIndex
    do {
      row += direction
      if (row < 0 || row >= root.rowCount) return
    } while (!root.rowVisible(row))
    root.cursorIndex = row
  }

  function flipToggle(key) {
    if (key === "omarchyLogo") root.setOmarchyLogo(!root.omarchyLogoShown)
    else root.setSetting(key, !root.toggleValue(key))
  }

  function choiceValue(key) {
    if (key === "widgetSection") return root.widgetSection
    if (key === "iconPosition") return root.iconPosition
    if (key === "tintStyle") return root.tintStyle
    if (key === "symbolPosition") return root.symbolInTray ? "tray" : (root.symbolSection || root.widgetSection)
    return ""
  }

  function setChoice(key, value) {
    if (key === "widgetSection") root.setWidgetSection(value)
    else if (key === "symbolPosition") root.setSymbolSection(value)
    else root.setSetting(key, value)
  }

  // Step a choice left/right (keyboard), clamped to the ends.
  function stepChoice(choice, direction) {
    var values = root.choiceValues(choice)
    var next = values.indexOf(root.choiceValue(choice.key)) + direction
    if (next >= 0 && next < values.length) root.setChoice(choice.key, values[next])
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
  //
  // Icons come only from what is installed on this computer; the plugin ships
  // none. Lookup order for a window:
  //   1. iconOverrides (by window class)
  //   2. terminals: the program in the terminal's foreground (see programIcon)
  //   3. web apps: the desktop entry that launches the window's site
  //   4. the app's desktop entry, then an icon theme icon named after the class
  //   5. /usr/share/pixmaps or the owning package's icons (scripts/resolve-icons)
  //   6. a generic app icon

  readonly property var shells: ["bash", "zsh", "fish", "sh", "dash", "nu", "xonsh", "elvish", "ksh", "tcsh"]
  // Interpreters a program can run under; their name says nothing about the program.
  readonly property var interpreters: ["node", "bun", "deno", "python", "python3", "ruby", "perl", "java", "bash", "sh"]
  // Window address -> { appId, initialClass, initialTitle, pid } from
  // `hyprctl clients`; Quickshell's cached copy of it is not reliably filled in.
  property var clientInfo: ({})
  // Window pid -> { name, exe } of the program in the foreground of its terminal.
  property var terminalPrograms: ({})
  // Name -> icon path found by scripts/resolve-icons ("" when none).
  property var resolvedIcons: ({})

  function windowInfo(toplevel) {
    var client = root.clientInfo[String(toplevel.address).replace(/^0x/, "")]
    var ipc = client || toplevel.lastIpcObject || {}
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

  function resolvedIcon(name) {
    var path = root.resolvedIcons[name]
    return path ? "file://" + path : ""
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

  function basename(path) {
    var value = String(path || "")
    return value.substring(value.lastIndexOf("/") + 1)
  }

  // ---- Desktop entries that launch web apps or terminal programs.

  // The program a terminal launcher entry runs: `Terminal=true` entries run
  // their command in a terminal; others pass it after `-e` (optionally
  // wrapped in `bash -c "..."`).
  function terminalProgramOf(entry) {
    var command = entry.command ? Array.from(entry.command) : []
    var program = ""
    if (entry.runInTerminal) {
      program = command[0] || ""
    } else {
      var e = command.indexOf("-e")
      if (e === -1 || e + 1 >= command.length) return ""
      program = command[e + 1]
      if (root.shells.indexOf(root.basename(program)) !== -1 && command[e + 2] === "-c")
        program = String(command[e + 3] || "").trim().split(/\s+/)[0]
    }
    program = root.basename(program)
    return root.shells.indexOf(program) !== -1 ? "" : program
  }

  readonly property var launcherIndex: {
    var webapps = []
    var programs = {}
    var entries = DesktopEntries.applications.values
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || !entry.icon) continue
      var url = String(entry.execString || "").match(/(?:omarchy-launch-webapp\s+|--app=)["']?https?:\/\/([^\/\s"':?#]+)([^\s"'?#]*)/)
      if (url) {
        webapps.push({ host: url[1].replace(/^www\./, "").toLowerCase(), path: url[2] || "", icon: entry.icon })
        continue
      }
      var program = root.terminalProgramOf(entry)
      if (program && !programs[program]) programs[program] = entry.icon
    }
    return { webapps: webapps, programs: programs }
  }

  // Browser app windows (`--app=URL`) start with the site as their title
  // ("discord.com_/channels/@me") or carry it in their class; match that to
  // the web app entry with the same site, preferring the longest path.
  function webappIcon(info) {
    var title = info.initialTitle.toLowerCase().replace(/^www\./, "")
    var appId = info.appId.toLowerCase()
    if (title.indexOf(" ") !== -1 && appId.indexOf(".") === -1) return ""
    var best = null
    var bestScore = -1
    var webapps = root.launcherIndex.webapps
    for (var i = 0; i < webapps.length; i++) {
      var app = webapps[i]
      if (title.indexOf(app.host) !== 0 && appId.indexOf(app.host) === -1) continue
      var path = app.path.toLowerCase()
      var score = path && title.indexOf(app.host + "_" + path) === 0 ? path.length : 0
      if (score > bestScore) {
        best = app
        bestScore = score
      }
    }
    return best ? root.themedIcon(best.icon) : ""
  }

  // ---- Programs in terminals.

  // Names to look a terminal program up by: its process name, and the name
  // of its executable unless that is just an interpreter running it.
  function programNames(program) {
    if (!program || !program.name || root.shells.indexOf(program.name) !== -1) return []
    var names = [program.name]
    var exe = root.basename(program.exe)
    if (exe && names.indexOf(exe) === -1 && root.interpreters.indexOf(exe) === -1) names.push(exe)
    return names
  }

  function programIcon(program) {
    var names = root.programNames(program)
    var i
    for (i = 0; i < names.length; i++) {
      var override = root.iconOverrides[names[i]]
      if (override) return root.themedIcon(String(override))
    }
    for (i = 0; i < names.length; i++) {
      var launcher = root.launcherIndex.programs[names[i]]
      var path = root.entryIcon(names[i]) || root.themedIcon(names[i])
        || (launcher ? root.themedIcon(launcher) : "") || root.resolvedIcon(names[i])
      if (path) return path
    }
    for (i = 0; i < names.length; i++) {
      var glyph = Glyphs.forProgram(names[i])
      if (glyph) return "glyph:" + glyph
    }
    return ""
  }

  function iconFor(info) {
    var override = root.iconOverrides[info.appId]
    if (override) return root.themedIcon(String(override))

    if (root.showTerminalPrograms && root.isTerminal(info)) {
      var program = root.programIcon(root.terminalPrograms[String(info.pid)])
      if (program) return program
    }

    var path = root.webappIcon(info)
      || root.entryIcon(info.appId)
      || root.themedIcon(info.appId)
      || root.themedIcon(info.appId.toLowerCase())
      || root.entryIcon(info.initialClass)
      || root.entryIcon(info.initialTitle)
      || root.resolvedIcon(info.appId)
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

  // ---- Polling windows and terminals, and resolving icons, in the background.

  function refreshWindows() {
    if (root.symbolMode || !root.showIcons || windowProbe.running) return
    windowProbe.command = ["bash", "-c", root.probeScript]
    windowProbe.running = true
  }

  // Prints the window list ("C <json>") and, for each window pid, the program
  // in the foreground of the tty its first child runs on ("P pid name exe").
  // For a terminal window that is the program running in the terminal.
  readonly property string probeScript: 'clients=$(hyprctl clients -j 2>/dev/null) || exit 0\n'
    + 'printf "C %s\\n" "$(jq -c \'map({a: (.address | ltrimstr("0x")), class, initialClass, initialTitle, pid})\' <<<"$clients")"\n'
    + 'for pid in $(jq -r \'.[].pid\' <<<"$clients" | sort -u); do\n'
    + '  child=$(cat /proc/"$pid"/task/*/children 2>/dev/null | tr " " "\\n" | grep -m1 .)\n'
    + '  [ -n "$child" ] && stat=$(cat /proc/"$child"/stat 2>/dev/null) || continue\n'
    + '  set -- ${stat##*) }\n'
    + '  [ "${6:-0}" -gt 0 ] || continue\n'
    + '  name=$(cat /proc/"$6"/comm 2>/dev/null)\n'
    + '  echo "P $pid ${name// /_} $(readlink /proc/"$6"/exe 2>/dev/null)"\n'
    + 'done\n'

  Process {
    id: windowProbe
    stdout: StdioCollector {
      onStreamFinished: {
        var clients = ({})
        var programs = ({})
        var lines = this.text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i]
          if (line.indexOf("C ") === 0) {
            var list = []
            try { list = JSON.parse(line.substring(2)) } catch (e) {}
            for (var j = 0; j < list.length; j++) clients[list[j].a] = list[j]
          } else if (line.indexOf("P ") === 0) {
            var parts = line.substring(2).split(" ")
            programs[parts[0]] = { name: parts[1] || "", exe: parts.slice(2).join(" ") }
          }
        }
        if (JSON.stringify(clients) !== JSON.stringify(root.clientInfo)) root.clientInfo = clients
        if (JSON.stringify(programs) !== JSON.stringify(root.terminalPrograms)) root.terminalPrograms = programs
        root.resolveMissingIcons()
      }
    }
  }

  // Pick up new windows right away instead of on the next poll.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "openwindow" || event.name === "closewindow") windowEventDelay.restart()
    }
  }

  Timer {
    id: windowEventDelay
    interval: 300
    onTriggered: root.refreshWindows()
  }

  // Names that none of the quick lookups found an icon for and that
  // scripts/resolve-icons has not been asked about yet.
  function missingIconNames() {
    var names = []
    function want(name) {
      if (name && !(name in root.resolvedIcons) && names.indexOf(name) === -1
          && !root.entryIcon(name) && !root.themedIcon(name) && !root.launcherIndex.programs[name])
        names.push(name)
    }
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var info = root.windowInfo(values[i])
      if (root.isTerminal(info)) {
        var programNames = root.programNames(root.terminalPrograms[String(info.pid)])
        for (var j = 0; j < programNames.length; j++) want(programNames[j])
      } else if (!root.webappIcon(info)) {
        want(info.appId)
      }
    }
    return names
  }

  function resolveMissingIcons() {
    if (iconResolver.running) return
    var names = root.missingIconNames()
    if (names.length === 0) return
    iconResolver.command = [Qt.resolvedUrl("scripts/resolve-icons").toString().replace(/^file:\/\//, "")].concat(names)
    iconResolver.running = true
  }

  Process {
    id: iconResolver
    stdout: StdioCollector {
      onStreamFinished: {
        var next = ({})
        for (var key in root.resolvedIcons) next[key] = root.resolvedIcons[key]
        var lines = this.text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var tab = lines[i].indexOf("\t")
          if (tab > 0) next[lines[i].substring(0, tab)] = lines[i].substring(tab + 1)
        }
        root.resolvedIcons = next
      }
    }
  }

  Timer {
    interval: Math.max(1, Number(root.setting("terminalPollSeconds", 2))) * 1000
    running: !root.symbolMode && root.showIcons
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshWindows()
  }

  Component.onCompleted: Hyprland.refreshToplevels()

  // ---- Bar.

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property color symbolColor: bar ? bar.barForeground : Color.foreground
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property var workspaceList: root.symbolMode ? [] : root.workspaceIds()
  // The symbol is drawn in front of the workspaces until it gets its own entry.
  readonly property bool showSymbol: root.symbolMode || (root.symbolSection === "" && !root.symbolInTray)

  // Runs while the symbol is in the tray. A bar per monitor means one widget
  // per monitor; the helper keeps a single tray icon between them.
  Process {
    running: !root.symbolMode && root.symbolInTray
    command: ["/usr/bin/python3", Qt.resolvedUrl("scripts/tray-icon").toString().replace(/^file:\/\//, "")]
  }

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
      visible: root.showSymbol
      bar: root.bar
      hasVisualContent: true
      labelVisible: false
      tooltipText: "Workspace Icons settings"
      fixedWidth: root.vertical ? root.barSize : Style.space(22)
      fixedHeight: root.barSize
      onPressed: function() { root.toggleHere() }

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

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property var icons: root.vertical ? [] : root.workspaceIcons(workspace)
        readonly property int iconsBefore: root.iconPosition === "left" ? icons.length : 0
        // Full-color icons stand in for the focus mark; an empty focused
        // workspace has no icons to color, so it keeps the mark.
        readonly property bool focusByColor: focused && icons.length > 0 && root.colorFocused && !root.coloredIcons
        readonly property bool colorIcons: root.coloredIcons || focusByColor
        // Workspaces with icons may drop their number; the focus mark and
        // empty workspaces always keep a label so every slot stays visible.
        readonly property string label: focused && !focusByColor ? "󱓻"
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
          if (mouseButton === Qt.RightButton) root.toggleHere()
          else root.focusWorkspace(modelData)
        }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: Style.spaceReal(3)

          Repeater {
            model: button.icons.slice(0, button.iconsBefore).map(function(source) { return { source: source, colored: button.colorIcons } })
            delegate: appIcon
          }

          Text {
            visible: button.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: button.label
            color: root.coloredIcons ? button.foreground : root.tintColor
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
          }

          Repeater {
            model: button.icons.slice(button.iconsBefore).map(function(source) { return { source: source, colored: button.colorIcons } })
            delegate: appIcon
          }
        }
      }
    }
  }

  Component {
    id: appIcon

    Item {
      id: iconItem
      required property var modelData
      // Glyph icons ("glyph:<char>") are Nerd Font characters from the bar font.
      readonly property bool isGlyph: String(modelData.source).indexOf("glyph:") === 0
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      width: root.iconSize
      height: root.iconSize

      Image {
        visible: !iconItem.isGlyph
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
        sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
        source: iconItem.isGlyph ? "" : iconItem.modelData.source
        smooth: true
        layer.enabled: !iconItem.modelData.colored
        // Render the tint at physical pixels; the default logical-size layer
        // blurs icons on scaled displays.
        layer.textureSize: Qt.size(Math.round(width * Screen.devicePixelRatio), Math.round(height * Screen.devicePixelRatio))
        layer.smooth: true
        // Tinted with a theme color, so they follow theme changes.
        layer.effect: MultiEffect {
          // Lifted so icons come out close to the tint color instead of darker.
          brightness: 0.6
          colorization: 1.0
          colorizationColor: root.tintColor
        }
      }

      Text {
        visible: iconItem.isGlyph
        anchors.centerIn: parent
        text: iconItem.isGlyph ? String(iconItem.modelData.source).substring(6) : ""
        // Glyphs have no colors of their own: in color they take the theme's
        // accent color, otherwise the tint.
        color: iconItem.modelData.colored ? Color.accent : root.tintColor
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: root.iconSize
        renderType: Text.NativeRendering
      }
    }
  }


  // ---- Settings popup.

  // Keyboard cursor over the popup rows: toggles first, then the choices.
  property int cursorIndex: -1
  readonly property int rowCount: toggles.length + choices.length
  readonly property color panelForeground: bar ? bar.foreground : Color.foreground
  readonly property string panelFont: bar ? bar.fontFamily : Style.font.family

  // Toggle rows that carry `options` are choices shown in the toggle list.
  function rowChoice(row) {
    if (row < root.toggles.length) return root.toggles[row].options ? root.toggles[row] : null
    return root.choices[row - root.toggles.length] || null
  }

  function activateRow(row, direction) {
    if (row < 0) return
    if (row < root.toggles.length && !root.toggles[row].options) {
      root.flipToggle(root.toggles[row].key)
      return
    }
    var choice = root.rowChoice(row)
    if (!choice) return
    if (direction !== 0) {
      root.stepChoice(choice, direction)
    } else {
      // Enter cycles through the values.
      var values = root.choiceValues(choice)
      root.setChoice(choice.key, values[(values.indexOf(root.choiceValue(choice.key)) + 1) % values.length])
    }
  }

  onOpenedChanged: if (opened) {
    cursorIndex = -1
    shellConfigFile.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // ---- Opening at a screen point (the tray icon's click).

  // The tray only tells its icon it was clicked, not where, so the tray helper
  // sends the cursor position and the popup opens under a 1px anchor there.
  // Chosen when the popup opens and kept while it closes, so its close
  // animation stays where it was opened.
  property bool anchorAtPoint: false

  // Open or toggle the popup under the widget (settings button, right click,
  // hotkey) rather than at a point.
  function openHere() {
    if (!root.opened) root.anchorAtPoint = false
    root.open()
  }

  function toggleHere() {
    if (root.opened) root.close()
    else root.openHere()
  }
  readonly property var barWindow: root.QsWindow.window

  Item {
    id: pointAnchor
    parent: root.barWindow ? root.barWindow.contentItem : root
    width: 1
    height: 1
  }

  function screenContains(item, x, y) {
    var window = item && item.QsWindow ? item.QsWindow.window : null
    var screen = window ? window.screen : null
    return !!screen && x >= screen.x && x < screen.x + screen.width && y >= screen.y && y < screen.y + screen.height
  }

  function toggleAtPoint(x, y) {
    if (root.opened) {
      root.close()
      return
    }
    var screen = root.barWindow ? root.barWindow.screen : null
    pointAnchor.x = x - (screen ? screen.x : 0)
    pointAnchor.y = y - (screen ? screen.y : 0)
    root.anchorAtPoint = true
    root.open()
  }

  // Route to the workspaces widget on the monitor under the point; there is
  // one per monitor, but only one of them owns the IPC target.
  function routeToggleAt(x, y) {
    var widgets = root.bar ? root.bar.moduleWidgets(root.moduleName) : [root]
    var target = root
    for (var i = 0; i < widgets.length; i++) {
      var widget = widgets[i]
      if (widget && !widget.symbolMode && root.screenContains(widget, x, y)) {
        target = widget
        break
      }
    }
    target.toggleAtPoint(x, y)
  }

  IpcHandler {
    enabled: root.ipcTarget !== ""
    target: root.ipcTarget

    function open(): void { root.openHere() }
    function close(): void { root.close() }
    function show(): void { root.openHere() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggleHere() }
    function toggleAt(x: string, y: string): void { root.routeToggleAt(Number(x), Number(y)) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorAtPoint ? pointAnchor : (root.showSymbol ? launcher : layout)
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.cursorIndex < 0) { root.cursorIndex = 0; return }
        if (dy !== 0) root.moveCursor(dy > 0 ? 1 : -1)
        else if (dx !== 0 && root.rowChoice(root.cursorIndex)) root.activateRow(root.cursorIndex, dx)
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

            Item {
              id: toggleRow
              required property var modelData
              required property int index
              readonly property bool isChoice: !!modelData.options
              readonly property real indent: modelData.parentKey ? Style.space(24) : 0
              visible: root.rowVisible(index)
              x: indent
              width: column.width - indent
              implicitHeight: isChoice ? subChoice.implicitHeight : toggle.implicitHeight

              Toggle {
                id: toggle
                visible: !toggleRow.isChoice
                width: parent.width
                label: toggleRow.modelData.label
                description: toggleRow.modelData.description || ""
                checked: root.toggleValue(toggleRow.modelData.key)
                hasCursor: root.cursorIndex === toggleRow.index
                foreground: root.panelForeground
                fontFamily: root.panelFont
                onHovered: function(h) { if (h) root.cursorIndex = toggleRow.index }
                onClicked: root.flipToggle(toggleRow.modelData.key)
              }

              Item {
                id: subChoice
                visible: toggleRow.isChoice
                width: parent.width
                implicitHeight: Math.max(subLabel.implicitHeight, subGroup.implicitHeight)

                Text {
                  id: subLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: toggleRow.modelData.label
                  color: root.panelForeground
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                }

                ButtonGroup {
                  id: subGroup
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  options: toggleRow.isChoice ? toggleRow.modelData.options : []
                  value: root.choiceValue(toggleRow.modelData.key)
                  focusable: false
                  cursorIndex: root.cursorIndex === toggleRow.index && toggleRow.isChoice
                    ? root.choiceValues(toggleRow.modelData).indexOf(subGroup.value) : -1
                  foreground: root.panelForeground
                  fontFamily: root.panelFont
                  fontSize: Style.font.bodySmall
                  onChanged: function(v) { root.setChoice(toggleRow.modelData.key, v) }
                  onHovered: function(i, h) { if (h) root.cursorIndex = toggleRow.index }
                }
              }
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
                options: choiceRow.modelData.options
                value: root.choiceValue(choiceRow.modelData.key)
                focusable: false
                cursorIndex: root.cursorIndex === choiceRow.row
                  ? root.choiceValues(choiceRow.modelData).indexOf(group.value) : -1
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
