import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "Glyphs.js" as Glyphs
import "Icons.js" as Icons

// Workspace indicators with the icons of the apps on each workspace.
//
// The plugin symbol at the start opens the settings popup; right click on a
// workspace opens it too. Hotkey: `omarchy-shell woodenplastic.workspace-icons toggle`.
//
// Pieces: WorkspaceButton.qml draws one workspace, AppIconButton.qml one app
// on it, WorkspacePreview.qml the hover preview. This file holds the
// settings, the window data, icon lookup and the settings popup.
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

  // `omarchy bar set` stores plain strings unless given --json, so "false"
  // and "0" have to read as false.
  function boolOption(name, fallback) {
    var value = option(name, fallback)
    if (typeof value === "boolean") return value
    if (typeof value === "number") return value !== 0
    var text = String(value).trim().toLowerCase()
    if (["false", "0", "no", "off"].indexOf(text) !== -1) return false
    if (["true", "1", "yes", "on"].indexOf(text) !== -1) return true
    return fallback
  }

  function numberOption(name, fallback, min, max) {
    var value = Number(option(name, fallback))
    if (!isFinite(value)) value = fallback
    return Math.max(min, Math.min(max, value))
  }

  function objectOption(name) {
    var value = option(name, ({}))
    if (typeof value === "string") {
      try { value = JSON.parse(value) } catch (e) { value = ({}) }
    }
    return value && typeof value === "object" && !Array.isArray(value) ? value : ({})
  }

  readonly property bool showIcons: boolOption("showIcons", true)
  readonly property bool coloredIcons: boolOption("coloredIcons", true)
  // Opacity of the app icons (0.2 to 1); the numbers stay opaque.
  readonly property real iconOpacity: numberOption("iconOpacity", 1, 0.2, 1)
  readonly property real shownIconOpacity: shownSliderValue("iconOpacity")
  // Workspaces shown even when empty (1 to 10); occupied ones past that show too.
  readonly property int workspaceCount: Math.round(numberOption("workspaceCount", 5, 1, 10))
  readonly property int shownWorkspaceCount: Math.round(shownSliderValue("workspaceCount"))
  // Slider key -> value while its slider is dragged, before the value is
  // saved, so the bar follows the drag.
  property var sliderPreview: ({})
  // With tinted icons, mark the focused workspace by showing its icons in
  // full color instead of the focus mark.
  readonly property bool colorFocused: boolOption("colorFocused", false)
  // With colored icons, show only the focused workspace's icons in color.
  readonly property bool grayscaleUnfocused: boolOption("grayscaleUnfocused", false)
  // Color that icons (and numbers) take with colored icons off: the theme's
  // "accent" color or its "normal" text color. Older values map across.
  readonly property string tintStyle: ["normal", "greyscale"].indexOf(String(option("tintStyle", "accent"))) !== -1 ? "normal" : "accent"
  readonly property color tintColor: tintStyle === "accent" ? Color.accent : symbolColor
  readonly property bool showNumbers: boolOption("showNumbers", true)
  readonly property bool showTerminalPrograms: boolOption("showTerminalPrograms", true)
  readonly property bool showCounts: boolOption("showCounts", true)
  readonly property bool showUrgent: boolOption("showUrgent", true)
  // Only workspaces with windows, and the one each monitor shows.
  readonly property bool hideEmpty: boolOption("hideEmpty", false)
  // Each bar lists only the workspaces on its own monitor.
  readonly property bool perMonitor: boolOption("perMonitor", false)
  // Clicking a workspace brings it to this bar's monitor.
  readonly property bool clickSummons: boolOption("clickSummons", false)
  readonly property bool showSpecial: boolOption("showSpecial", true)
  readonly property bool scrollSwitch: boolOption("scrollSwitch", true)
  readonly property bool scrollWrap: boolOption("scrollWrap", true)
  readonly property bool animations: boolOption("animations", true)
  // "classic": numbers with icons beside them. "dots": a dot per workspace,
  // the focused one a pill with its icons and/or number (pillContent:
  // "icons", "number" or "both").
  readonly property bool dotsStyle: option("barStyle", "classic") === "dots"
  // "tiles": classic with a rounded tile behind each workspace with windows.
  readonly property bool tilesStyle: option("barStyle", "classic") === "tiles"
  // The tile of the workspace you're on: "subtle" (brighter), "solid" (the
  // bar's text color) or "accent".
  readonly property string activeTile: ["subtle", "solid", "accent"].indexOf(String(option("activeTile", "subtle"))) !== -1
    ? String(option("activeTile", "subtle")) : "subtle"

  function activeTileFill() {
    if (root.activeTile === "solid") return root.symbolColor
    if (root.activeTile === "accent") return Color.accent
    return Qt.rgba(root.symbolColor.r, root.symbolColor.g, root.symbolColor.b, 0.2)
  }
  readonly property string pillContent: ["icons", "number", "both", "none"].indexOf(String(option("pillContent", "icons"))) !== -1
    ? String(option("pillContent", "icons")) : "icons"
  // The filled or outlined shape around the pill's icons and number.
  readonly property bool pillFrame: boolOption("pillFrame", true)
  // A preview of the workspace's windows while the pointer rests on it.
  readonly property bool showPreview: boolOption("showPreview", true)
  readonly property bool previewLive: boolOption("previewLive", false)
  readonly property bool previewPrivacy: boolOption("previewPrivacy", true)
  readonly property int maxIcons: Math.round(numberOption("maxIcons", 4, 1, 10))
  // Which side of the workspace number the app icons sit on: "left" or "right".
  readonly property string iconPosition: option("iconPosition", "right") === "left" ? "left" : "right"
  // Map a window class or terminal program name to a theme icon name or an
  // absolute image path, for apps without an icon of their own.
  readonly property var iconOverrides: objectOption("iconOverrides")
  // Settings for single workspaces, by workspace number: { name,
  // alwaysShow, hidden, showIcons, preview }.
  readonly property var workspaceSettings: objectOption("workspaceSettings")

  function workspaceSetting(key, name, fallback) {
    var entry = root.workspaceSettings[String(key)]
    var value = entry && typeof entry === "object" ? entry[name] : undefined
    if (value === undefined || value === null) return fallback
    if (typeof fallback === "boolean" && typeof value !== "boolean") {
      var text = String(value).toLowerCase()
      return text === "true" || text === "1" || text === "on" || text === "yes"
    }
    return value
  }

  // Stores one workspace's setting; values equal to the default are dropped
  // so the entry stays small.
  function setWorkspaceSetting(key, name, value, fallback) {
    var next = {}
    for (var k in root.workspaceSettings) next[k] = root.workspaceSettings[k]
    var entry = {}
    var old = next[String(key)]
    if (old && typeof old === "object") for (var e in old) entry[e] = old[e]
    if (value === fallback || value === "") delete entry[name]
    else entry[name] = value
    if (Object.keys(entry).length === 0) delete next[String(key)]
    else next[String(key)] = entry
    root.setSetting("workspaceSettings", next)
  }
  // The plugin symbol shown as a system tray icon (scripts/tray-icon) instead of on the bar.
  readonly property bool symbolInTray: boolOption("symbolInTray", false)

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

  // ---- Settings popup rows. Headers split them into sections; `parentKey`
  //      rows are sub-options, shown while the parent has `shownWhen`.

  readonly property var sectionOptions: [
    { value: "left", label: "Left" },
    { value: "center", label: "Center" },
    { value: "right", label: "Right" }
  ]

  // General settings, for every workspace.
  readonly property var generalRows: [
    { header: "WORKSPACE ICONS" },
    { key: "showIcons", label: "App icons", description: "An icon for each app open on a workspace." },
    { key: "iconOpacity", label: "Icon opacity", parentKey: "showIcons", shownWhen: true, slider: true, min: 0.2, max: 1, step: 0.05, percent: true },
    { key: "showTerminalPrograms", label: "Programs in terminals", description: "nvim, btop or claude instead of the terminal's icon.", parentKey: "showIcons", shownWhen: true },
    { key: "showCounts", label: "Window counts", description: "A number on apps with several windows.", parentKey: "showIcons", shownWhen: true },
    { key: "coloredIcons", label: "Colored icons", description: "Off tints the icons, see Tint below." },
    // Sub-options of Colored icons, shown only while that is off.
    { key: "tintStyle", label: "Tint", parentKey: "coloredIcons", shownWhen: false,
      options: [{ value: "accent", label: "Accent" }, { value: "normal", label: "Normal" }] },
    { key: "colorFocused", label: "Color the focused workspace", description: "Show its icons in color instead of the focus mark.", parentKey: "coloredIcons", shownWhen: false },
    { key: "grayscaleUnfocused", label: "Gray out other workspaces", description: "Only the focused workspace in color.", parentKey: "coloredIcons", shownWhen: true },
    { header: "WORKSPACES" },
    { key: "barStyle", label: "Style", options: [{ value: "classic", label: "Classic" }, { value: "tiles", label: "Tiles" }, { value: "dots", label: "Dots" }] },
    { key: "activeTile", label: "Active tile", parentKey: "barStyle", shownWhen: "tiles",
      options: [{ value: "subtle", label: "Subtle" }, { value: "solid", label: "Solid" }, { value: "accent", label: "Accent" }] },
    { key: "pillContent", label: "Focused pill", parentKey: "barStyle", shownWhen: "dots",
      options: [{ value: "icons", label: "Icons" }, { value: "number", label: "Number" }, { value: "both", label: "Both" }, { value: "none", label: "None" }] },
    { key: "pillFrame", label: "Pill frame", description: "The shape around the focused workspace's icons and number.", parentKey: "barStyle", shownWhen: "dots" },
    { key: "showNumbers", label: "Workspace numbers", description: "Hides the number on workspaces that have icons." },
    { key: "hideEmpty", label: "Hide empty workspaces", description: "Only workspaces with windows, and the one you're on." },
    // Shown even when empty; workspaces with windows past it show too.
    { key: "workspaceCount", label: "Workspaces shown", parentKey: "hideEmpty", shownWhen: false, slider: true, min: 1, max: 10, step: 1 },
    { key: "perMonitor", label: "Only this monitor's workspaces", description: "Each bar lists the workspaces on its own monitor." },
    { key: "showSpecial", label: "Special workspaces", description: "The scratchpad and others, while they hold windows." },
    { key: "showUrgent", label: "Highlight urgent windows", description: "Pulse workspaces whose apps want attention." },
    { key: "scrollSwitch", label: "Scroll to switch", description: "The mouse wheel moves between workspaces." },
    { key: "animations", label: "Animations" },
    { key: "omarchyLogo", label: "Show Omarchy logo", description: "The Omarchy menu button on the bar. The menu hotkey keeps working." },
    { header: "PREVIEW" },
    { key: "showPreview", label: "Workspace preview", description: "Hover a workspace to see its windows." },
    { key: "previewLive", label: "Live preview", description: "Windows keep updating while the preview is open.", parentKey: "showPreview", shownWhen: true },
    { key: "previewPrivacy", label: "Hide while screen sharing", parentKey: "showPreview", shownWhen: true },
    { header: "POSITION" },
    { key: "widgetSection", label: "Bar section", options: sectionOptions },
    { key: "iconPosition", label: "Icon position", options: [{ value: "left", label: "Left" }, { value: "right", label: "Right" }] },
    { key: "symbolPosition", label: "Plugin symbol", options: sectionOptions.concat([{ value: "tray", label: "Tray" }]) }
  ]


  // Settings of the one workspace the popup was opened for.
  readonly property var workspaceRows: [
    { nameField: true, label: "Name" },
    { wsKey: "alwaysShow", fallback: false, label: "Always show", description: "On the bar even when empty or past the workspace count." },
    { wsKey: "hidden", fallback: false, label: "Hide from the bar", description: "Shown only while you're on it." },
    { wsKey: "showIcons", fallback: true, label: "App icons", description: "Icons for the apps on this workspace." },
    { wsKey: "preview", fallback: true, label: "Preview", description: "Its preview when you hover it." }
  ]

  // The two folding sections and what is unfolded of them.
  property bool generalOpen: true
  property bool workspaceOpen: false
  readonly property var rows: {
    var list = []
    if (root.thisWorkspaceKey !== "") {
      list.push({ fold: "workspace" })
      if (root.workspaceOpen) list = list.concat(root.workspaceRows)
    }
    list.push({ fold: "general" })
    if (root.generalOpen) list = list.concat(root.generalRows)
    return list
  }

  function choiceValues(choice) {
    return choice.options.map(function(o) { return o.value })
  }

  function toggleValue(key) {
    if (key === "omarchyLogo") return root.omarchyLogoShown
    var values = {
      showIcons: root.showIcons, coloredIcons: root.coloredIcons, colorFocused: root.colorFocused,
      grayscaleUnfocused: root.grayscaleUnfocused, showNumbers: root.showNumbers, pillFrame: root.pillFrame,
      showTerminalPrograms: root.showTerminalPrograms, showCounts: root.showCounts,
      showUrgent: root.showUrgent, hideEmpty: root.hideEmpty, perMonitor: root.perMonitor,
      showSpecial: root.showSpecial, scrollSwitch: root.scrollSwitch, animations: root.animations,
      showPreview: root.showPreview, previewLive: root.previewLive, previewPrivacy: root.previewPrivacy
    }
    return values[key] === true
  }

  function rowVisible(row) {
    var toggle = root.rows[row]
    if (!toggle || !toggle.parentKey) return true
    var parentValue = typeof toggle.shownWhen === "string" ? root.choiceValue(toggle.parentKey) : root.toggleValue(toggle.parentKey)
    return parentValue === toggle.shownWhen
  }

  function rowSelectable(row) {
    return !!root.rows[row] && root.rowVisible(row) && !root.rows[row].header
  }

  function workspaceToggleValue(row) {
    return root.workspaceSetting(root.thisWorkspaceKey, row.wsKey, row.fallback) === true
  }

  function flipWorkspaceToggle(row) {
    root.setWorkspaceSetting(root.thisWorkspaceKey, row.wsKey, !root.workspaceToggleValue(row), row.fallback)
  }

  function flipFold(fold, open) {
    if (fold === "workspace") root.workspaceOpen = open === undefined ? !root.workspaceOpen : open
    else root.generalOpen = open === undefined ? !root.generalOpen : open
  }

  function foldTitle(fold) {
    if (fold === "general") return "General"
    var key = root.thisWorkspaceKey
    var name = root.workspaceName(key)
    return "This workspace · " + (key === "10" ? "0" : key) + (name !== "" ? " " + name : "")
  }

  // Move the keyboard cursor by one visible row.
  function moveCursor(direction) {
    var row = root.cursorIndex
    do {
      row += direction
      if (row < 0 || row >= root.rowCount) return
    } while (!root.rowSelectable(row))
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
    if (key === "barStyle") return root.dotsStyle ? "dots" : (root.tilesStyle ? "tiles" : "classic")
    if (key === "activeTile") return root.activeTile
    if (key === "pillContent") return root.pillContent
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

  // ---- The bar's own monitor. A bar per monitor means one widget per
  //      monitor; each marks what its own monitor shows.

  property var barWindow: null
  readonly property var barScreen: barWindow ? barWindow.screen : null
  // Null for the zero-size placeholder the bar keeps for centered modules;
  // that one shows everything, like a single-monitor bar.
  readonly property var barMonitor: barScreen ? Hyprland.monitorFor(barScreen) : null
  // Bumped when monitors or their workspaces change, for bindings that read
  // lastIpcObject (which does not notify).
  property int monitorRevision: 0

  // QsWindow has no change notification, so look it up until it is set.
  function resolveBarWindow() {
    var window = root.QsWindow ? root.QsWindow.window : null
    if (window !== root.barWindow) root.barWindow = window
  }

  Timer {
    interval: 200
    repeat: true
    running: root.barWindow === null
    onTriggered: root.resolveBarWindow()
  }

  function primaryMonitorName() {
    var monitors = Hyprland.monitors.values.slice()
    monitors.sort(function(a, b) { return a.x - b.x || a.y - b.y })
    return monitors.length > 0 ? monitors[0].name : ""
  }

  // Workspace rules from Hyprland: id -> monitor, for placing empty
  // workspaces on the right bar.
  property var workspaceRules: ({})

  Process {
    id: rulesProbe
    command: ["bash", "-c", "hyprctl workspacerules -j 2>/dev/null | jq -c 'map({w: .workspaceString, m: (.monitor // \"\")})'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var rules = ({})
        var list = []
        try { list = JSON.parse(this.text) } catch (e) {}
        for (var i = 0; i < list.length; i++) {
          if (list[i] && list[i].m && /^\d+$/.test(String(list[i].w))) rules[String(list[i].w)] = list[i].m
        }
        root.workspaceRules = rules
      }
    }
  }

  // Whether an empty workspace number belongs on this bar with
  // "Only this monitor's workspaces" on: its rule's monitor, else the
  // leftmost monitor.
  function emptyBelongsHere(id) {
    if (!root.perMonitor || !root.barMonitor) return true
    var rule = root.workspaceRules[String(id)]
    if (rule) return rule === root.barMonitor.name || rule === "desc:" + root.barMonitor.description
    return root.barMonitor.name === root.primaryMonitorName()
  }

  function onBarMonitor(workspace) {
    if (!root.perMonitor || !root.barMonitor || !workspace) return true
    return !workspace.monitor || workspace.monitor.name === root.barMonitor.name
  }

  function shownOnBarMonitor(workspace) {
    return !!workspace && !!root.barMonitor && root.barMonitor.activeWorkspace === workspace
  }

  function specialOpenHere(key) {
    void root.monitorRevision
    var monitor = root.barMonitor || Hyprland.focusedMonitor
    var ipc = monitor ? monitor.lastIpcObject : null
    return !!ipc && !!ipc.specialWorkspace && ipc.specialWorkspace.name === key
  }

  // ---- Workspaces.

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceByName(name) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].name === name) return values[i]
    }
    return null
  }

  function workspaceByKey(key) {
    if (key.indexOf("special:") === 0) return root.workspaceByName(key)
    if (key.indexOf("name:") === 0) return root.workspaceByName(key.substring(5))
    return root.workspaceById(Number(key))
  }

  function isSpecialName(name) {
    return String(name || "").indexOf("special:") === 0
  }

  // Keys of the workspaces this bar shows: numbered ones in order, then
  // named ones, then special ones.
  function computeWorkspaceKeys() {
    if (root.symbolMode) return []
    void root.monitorRevision
    var values = Hyprland.workspaces.values
    var shown = root.barMonitor && root.barMonitor.activeWorkspace ? root.barMonitor.activeWorkspace : Hyprland.focusedWorkspace
    var ids = []
    var named = []
    var special = []
    var i

    for (i = 0; i < values.length; i++) {
      var workspace = values[i]
      var occupied = workspace.toplevels.values.length > 0
      if (root.isSpecialName(workspace.name)) {
        if (root.showSpecial && occupied) special.push(workspace.name)
        continue
      }
      if (!root.onBarMonitor(workspace)) continue
      var visible = workspace === shown || workspace === Hyprland.focusedWorkspace
      if (workspace.id > 0 && workspace.id <= 99) {
        var key = String(workspace.id)
        if (root.workspaceSetting(key, "hidden", false) && !visible) continue
        if (occupied || visible || root.workspaceSetting(key, "alwaysShow", false)
            || (!root.hideEmpty && workspace.id <= root.shownWorkspaceCount)) ids.push(workspace.id)
      } else if (workspace.id < 0 && (occupied || visible)) {
        named.push("name:" + workspace.name)
      }
    }

    // Empty numbers that do not exist yet: the always-shown count, and
    // workspaces set to always show.
    for (var n = 1; n <= 99; n++) {
      var wanted = root.workspaceSetting(String(n), "alwaysShow", false) || (!root.hideEmpty && n <= root.shownWorkspaceCount)
      if (!wanted || root.workspaceSetting(String(n), "hidden", false)) continue
      if (ids.indexOf(n) === -1 && root.workspaceById(n) === null && root.emptyBelongsHere(n)) ids.push(n)
    }

    ids.sort(function(a, b) { return a - b })
    named.sort()
    special.sort()
    return ids.map(String).concat(named, special)
  }

  // Replaced only when the keys change: a new array makes the Repeater
  // rebuild every button, and each rebuild re-registers the bar's click
  // targets, which bursts of window events turn into real load.
  readonly property var computedKeys: computeWorkspaceKeys()
  property var workspaceList: []
  onComputedKeysChanged: {
    if (JSON.stringify(computedKeys) !== JSON.stringify(workspaceList)) workspaceList = computedKeys
  }

  function workspaceName(key) {
    if (key.indexOf(":") !== -1) return ""
    var name = root.workspaceSetting(key, "name", "")
    return name ? Icons.cleanTitle(name, 24) : ""
  }

  function specialLabel(key) {
    var name = key.substring(8)
    return name === "scratchpad" ? "S" : (name ? name.charAt(0).toUpperCase() : "S")
  }

  function workspaceAccessibleName(button) {
    var name = button.isSpecial ? "Special workspace " + button.key.substring(8)
      : (button.isNamed ? "Workspace " + button.key.substring(5) : "Workspace " + button.numberText)
    if (button.customName !== "") name += ", " + button.customName
    var apps = button.groups.map(function(group) { return group.name })
    if (apps.length > 0) name += ", " + apps.join(", ")
    if (button.focused) name += ", focused"
    return name
  }

  function dispatch(expression) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function workspaceSelector(key) {
    if (key.indexOf("name:") === 0) return "name:" + key.substring(5)
    return key
  }

  function activateKey(key) {
    if (key.indexOf("special:") === 0) {
      root.dispatch("hl.dsp.workspace.toggle_special(" + Icons.luaString(key.substring(8)) + ")")
      return
    }
    var selector = Icons.luaString(root.workspaceSelector(key))
    var workspace = root.workspaceByKey(key)
    var monitor = root.barMonitor
    if (root.clickSummons && monitor) {
      // Bring the workspace to this monitor: move it here if it lives
      // elsewhere, or create it here by focusing this monitor first.
      var here = Icons.luaString(monitor.name)
      if (workspace && workspace.monitor && workspace.monitor.name !== monitor.name) {
        root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.workspace.move({ workspace = " + selector + ", monitor = " + here + " })")
          + " && hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = " + selector + " })"))
        return
      }
      if (!workspace && Hyprland.focusedMonitor !== monitor) {
        root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = " + here + " })")
          + " && hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = " + selector + " })"))
        return
      }
    }
    root.dispatch("hl.dsp.focus({ workspace = " + selector + " })")
  }

  function focusWindow(address) {
    if (/^[0-9a-f]+$/i.test(address)) root.dispatch("hl.dsp.focus({ window = \"address:0x" + address + "\" })")
  }

  function closeWindow(address) {
    if (/^[0-9a-f]+$/i.test(address)) root.dispatch("hl.dsp.window.close({ window = \"address:0x" + address + "\" })")
  }

  // Middle click on a workspace sends the focused window there.
  function moveFocusedWindowTo(key) {
    if (key.indexOf("special:") === 0) return
    root.dispatch("hl.dsp.window.move({ workspace = " + Icons.luaString(root.workspaceSelector(key)) + ", follow = false })")
  }

  function workspacePressed(button, mouseButton) {
    root.closePreview()
    if (mouseButton === Qt.RightButton) root.openSettingsFor(button.key)
    else if (mouseButton === Qt.MiddleButton) root.moveFocusedWindowTo(button.key)
    else root.activateKey(button.key)
  }

  // An app's icon: focus its most recent window; clicked again while one of
  // them has focus, the next one.
  function groupPressed(group, mouseButton) {
    root.closePreview()
    if (!group || !group.addresses || group.addresses.length === 0) return
    if (mouseButton === Qt.RightButton) {
      root.openSettingsFor(group.workspaceKey || "")
      return
    }
    var active = Hyprland.activeToplevel ? String(Hyprland.activeToplevel.address).replace(/^0x/, "") : ""
    var addresses = root.byFocusHistory(group.addresses)
    var current = addresses.indexOf(active)
    if (mouseButton === Qt.MiddleButton) {
      root.closeWindow(current !== -1 ? active : addresses[0])
      return
    }
    root.focusWindow(current !== -1 ? addresses[(current + 1) % addresses.length] : addresses[0])
  }

  // Addresses ordered by how recently their windows had focus.
  function byFocusHistory(addresses) {
    var list = addresses.slice()
    list.sort(function(a, b) {
      var ca = root.clientInfo[a], cb = root.clientInfo[b]
      return (ca ? ca.focusHistoryID : 999) - (cb ? cb.focusHistoryID : 999)
    })
    return list
  }

  // Scrolling steps through the shown workspaces; trackpads send small
  // deltas, so they add up to whole 120-unit notches.
  property real wheelAccumulator: 0

  function wheelStep(delta) {
    if (!root.scrollSwitch) return
    root.wheelAccumulator += delta
    if (Math.abs(root.wheelAccumulator) < 120) return
    var direction = root.wheelAccumulator > 0 ? -1 : 1
    root.wheelAccumulator = 0
    var keys = root.workspaceList.filter(function(key) { return key.indexOf("special:") !== 0 })
    if (keys.length === 0) return
    var current = -1
    for (var i = 0; i < keys.length; i++) {
      if (root.workspaceByKey(keys[i]) === Hyprland.focusedWorkspace) current = i
    }
    var next = current + direction
    if (next < 0) next = root.scrollWrap ? keys.length - 1 : 0
    if (next >= keys.length) next = root.scrollWrap ? 0 : keys.length - 1
    if (next !== current) root.activateKey(keys[next])
  }

  // ---- App icons.
  //
  // Icons come only from what is installed on this computer; the plugin ships
  // none. Lookup order for a window:
  //   1. iconOverrides (by window class)
  //   2. terminals: the program in the terminal's foreground, by its own
  //      icon, an Omarchy agent icon, a terminal launcher entry, its
  //      package, or a Nerd Font glyph (see programIcon)
  //   3. Omarchy TUI launchers (class "org.omarchy.<program>")
  //   4. web apps: the desktop entry that launches the window's site
  //   5. Steam games (class "steam_app_<id>")
  //   6. the app's desktop entry (exact id, StartupWMClass, then fuzzy), then
  //      an icon theme icon named after the class
  //   7. /usr/share/pixmaps or the owning package's icons (scripts/resolve-icons)
  //   8. a generic app icon

  readonly property var shells: ["bash", "zsh", "fish", "sh", "dash", "nu", "xonsh", "elvish", "ksh", "tcsh"]
  // Interpreters a program can run under; their name says nothing about the program.
  readonly property var interpreters: ["node", "bun", "deno", "python", "python3", "ruby", "perl", "java", "bash", "sh"]
  // Agents Omarchy ships icons for (its agents plugin).
  readonly property var agentIcons: ["claude", "codex"]
  // Window address -> client data from `hyprctl clients`; Quickshell's cached
  // copy of it is not reliably filled in for new windows.
  property var clientInfo: ({})
  // Monitors from `hyprctl monitors`, for the preview's geometry.
  property var monitorInfo: []
  // Window pid -> { name, exe } of the program in the foreground of its terminal.
  property var terminalPrograms: ({})
  // Name -> icon path found by scripts/resolve-icons ("" when none).
  property var resolvedIcons: ({})
  property bool hasTerminalWindows: false
  property bool recorderRunning: false
  property string wallpaperStamp: ""
  // Bumped when desktop entries finish loading or change, so icons that
  // missed early re-resolve.
  property int iconRevision: 0
  // Per-class lookups, cleared with iconRevision. Plain object mutated in
  // place: writing a property from inside a binding would loop.
  property var iconCache: ({})

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { iconRefreshDelay.restart() }
  }

  Timer {
    id: iconRefreshDelay
    interval: 250
    onTriggered: {
      root.iconCache = ({})
      root.iconRevision++
    }
  }

  onIconOverridesChanged: {
    root.iconCache = ({})
    root.iconRevision++
  }

  function windowInfo(toplevel) {
    var address = String(toplevel.address).replace(/^0x/, "")
    var client = root.clientInfo[address]
    var ipc = client || toplevel.lastIpcObject || {}
    var appId = toplevel.wayland && toplevel.wayland.appId ? toplevel.wayland.appId : String(ipc.class || "")
    return {
      address: address,
      appId: appId,
      initialClass: String(ipc.initialClass || ""),
      initialTitle: String(ipc.initialTitle || ""),
      pid: Number(ipc.pid || 0)
    }
  }

  // An icon name or, for overrides and desktop entries, an absolute path.
  function themedIcon(name) {
    if (!name) return ""
    if (name.charAt(0) === "/") return "file://" + name
    return Quickshell.iconPath(name, true)
  }

  // An icon theme icon named after a window class or program; never a path.
  function namedIcon(name) {
    return name && name.indexOf("/") === -1 ? Quickshell.iconPath(name, true) : ""
  }

  // Exact desktop entry id first: a short class like "zen" can lose to a
  // longer name in the fuzzy lookup.
  function desktopEntry(name) {
    if (!name) return null
    return DesktopEntries.byId(name) || DesktopEntries.byId(name.toLowerCase()) || DesktopEntries.heuristicLookup(name)
  }

  function entryIcon(name) {
    var entry = root.desktopEntry(name)
    return entry && entry.icon ? root.themedIcon(entry.icon) : ""
  }

  function resolvedIcon(name) {
    var path = root.resolvedIcons[name]
    return path ? "file://" + path : ""
  }

  function isTerminalEntry(name) {
    if (!name) return false
    var entry = root.desktopEntry(name)
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

  function monogram(name) {
    return Icons.monogram(name)
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
    var handlers = []
    var crx = {}
    var startupClasses = []
    var programs = {}
    var entries = DesktopEntries.applications.values
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || !entry.icon) continue
      var exec = String(entry.execString || "")
      if (entry.startupClass) startupClasses.push({ startupClass: entry.startupClass, icon: entry.icon })
      var url = exec.match(/(?:omarchy-launch-(?:or-focus-)?webapp\s+|--app=)["']?https?:\/\/([^\/\s"':?#]+)([^\s"'?#]*)/)
      if (url) {
        webapps.push({ host: url[1].replace(/^www\./, "").toLowerCase(), path: url[2] || "", icon: entry.icon })
        continue
      }
      // Web apps opened through a handler script (HEY, Zoom) carry no URL.
      var handler = exec.match(/omarchy-webapp-handler-([a-z0-9-]+)/)
      if (handler) {
        handlers.push({ slug: handler[1].toLowerCase(), icon: entry.icon })
        continue
      }
      var appId = exec.match(/--app-id=([a-p]{32})/)
      if (appId) crx[appId[1]] = entry.icon
      var program = root.terminalProgramOf(entry)
      if (program && !programs[program]) programs[program] = entry.icon
    }
    return { webapps: webapps, handlers: handlers, crx: crx, startupClasses: startupClasses, programs: programs }
  }

  // The site a browser app window shows: its initial title starts with it
  // ("discord.com_/channels/@me") or its class carries it.
  function webappSite(info) {
    var app = Icons.browserApp(info.appId) || Icons.browserApp(info.initialClass)
    if (app) return app
    var title = info.initialTitle.toLowerCase().replace(/^www\./, "")
    var appId = info.appId.toLowerCase()
    if (title.indexOf(" ") !== -1 && appId.indexOf(".") === -1) return null
    var match = title.match(/^([a-z0-9.-]+\.[a-z]{2,})(?:_(.*))?$/)
    if (match) return { host: match[1], path: (match[2] || "").toLowerCase() }
    var fromClass = appId.match(/([a-z0-9-]+(?:\.[a-z0-9-]+)+\.[a-z]{2,})/)
    return fromClass ? { host: fromClass[1].replace(/^www\./, ""), path: "" } : null
  }

  // Match the site to the web app entry that launches it, preferring the
  // longest path.
  function webappIcon(info) {
    var crxId = Icons.crxId(info.appId) || Icons.crxId(info.initialClass)
    if (crxId && root.launcherIndex.crx[crxId]) return root.themedIcon(root.launcherIndex.crx[crxId])
    var site = root.webappSite(info)
    if (!site) return ""
    var best = null
    var bestScore = -1
    var webapps = root.launcherIndex.webapps
    for (var i = 0; i < webapps.length; i++) {
      var app = webapps[i]
      if (site.host !== app.host && site.host.indexOf("." + app.host) === -1 && app.host.indexOf("." + site.host) === -1) continue
      var path = app.path.toLowerCase().replace(/\//g, "_").replace(/^_/, "")
      var score = path && site.path.replace(/^_/, "").indexOf(path) === 0 ? path.length : 0
      if (score > bestScore) {
        best = app
        bestScore = score
      }
    }
    if (best) return root.themedIcon(best.icon)
    // A handler script's name against the site's labels, never its TLD.
    var labels = site.host.split(".").slice(0, -1)
    var handlers = root.launcherIndex.handlers
    for (var h = 0; h < handlers.length; h++) {
      if (labels.indexOf(handlers[h].slug) !== -1) return root.themedIcon(handlers[h].icon)
    }
    return ""
  }

  function startupClassIcon(appId) {
    if (!appId) return ""
    var list = root.launcherIndex.startupClasses
    for (var i = 0; i < list.length; i++) {
      if (Icons.startupClassMatches(list[i].startupClass, appId)) return root.themedIcon(list[i].icon)
    }
    return ""
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
      if (root.agentIcons.indexOf(names[i]) !== -1)
        return "file://" + Quickshell.shellDir + "/plugins/agents/assets/" + names[i] + ".svg"
    }
    for (i = 0; i < names.length; i++) {
      var launcher = root.launcherIndex.programs[names[i]]
      var path = root.entryIcon(names[i]) || root.namedIcon(names[i])
        || (launcher ? root.themedIcon(launcher) : "") || root.resolvedIcon(names[i])
      if (path) return path
    }
    for (i = 0; i < names.length; i++) {
      var glyph = Glyphs.forProgram(names[i])
      if (glyph) return "glyph:" + glyph
    }
    return ""
  }

  // The icon for a window's app, ignoring what runs in terminals. Cached per
  // class; the cache is cleared when desktop entries or overrides change.
  function appIcon(info) {
    var cacheKey = info.appId + "\n" + info.initialClass + "\n" + info.initialTitle
    var cached = root.iconCache[cacheKey]
    if (cached !== undefined && cached !== "") return cached

    var path = ""
    var program = Icons.omarchyProgram(info.appId) || Icons.omarchyProgram(info.initialClass)
    if (program) path = root.programIcon({ name: program, exe: "" })
    if (!path) path = root.webappIcon(info)
    var steam = info.appId.match(/^steam_app_(\d+)$/)
    if (!path && steam) path = root.namedIcon("steam_icon_" + steam[1])
    if (!path) {
      var names = Icons.nameVariants(info.appId)
      for (var i = 0; i < names.length && !path; i++) {
        var exact = DesktopEntries.byId(names[i])
        if (exact && exact.icon) path = root.themedIcon(exact.icon)
      }
    }
    if (!path) path = root.startupClassIcon(info.appId) || root.startupClassIcon(info.initialClass)
    if (!path) path = root.entryIcon(info.appId)
    if (!path) {
      var variants = Icons.nameVariants(info.appId)
      for (var v = 0; v < variants.length && !path; v++) path = root.namedIcon(variants[v])
    }
    if (!path) path = root.entryIcon(info.initialClass) || root.entryIcon(info.initialTitle) || root.resolvedIcon(info.appId)
    // Only found icons are cached, so a later resolve-icons result shows up.
    if (path) root.iconCache[cacheKey] = path
    return path || Quickshell.iconPath("application-x-executable", true)
  }

  function iconFor(info) {
    var override = root.iconOverrides[info.appId]
    if (override) return root.themedIcon(String(override))
    if (root.showTerminalPrograms && root.isTerminal(info)) {
      var program = root.programIcon(root.terminalPrograms[String(info.pid)])
      if (program) return program
    }
    return root.appIcon(info)
  }

  function appName(info) {
    var program = root.showTerminalPrograms && root.isTerminal(info) ? root.terminalPrograms[String(info.pid)] : null
    if (program && root.programNames(program).length > 0) return program.name
    var entry = root.desktopEntry(info.appId) || root.desktopEntry(info.initialClass)
    return entry && entry.name ? entry.name : (info.appId || info.initialClass || "App")
  }

  // One group per distinct app (or terminal program) on the workspace, in
  // on-screen order: { key, source, name, count, addresses, titles, urgent,
  // focused, workspaceKey }.
  function workspaceGroups(workspace) {
    void root.iconRevision
    if (workspace === null || !root.showIcons) return []
    var key = root.isSpecialName(workspace.name) ? workspace.name
      : (workspace.id > 0 ? String(workspace.id) : "name:" + workspace.name)
    if (!root.workspaceSetting(key, "showIcons", true)) return []
    var groups = []
    var byIcon = {}
    var active = Hyprland.activeToplevel
    var toplevels = workspace.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i]
      var info = root.windowInfo(toplevel)
      if (info.appId === "" && !root.clientInfo[info.address]) continue
      var icon = root.iconFor(info)
      var client = root.clientInfo[info.address]
      var at = client && client.at ? client.at : [0, 0]
      var group = byIcon[icon]
      if (!group) {
        group = { key: icon, source: icon, name: root.appName(info), count: 0, addresses: [], titles: [],
                  urgent: false, focused: false, workspaceKey: key, x: at[0], y: at[1] }
        byIcon[icon] = group
        groups.push(group)
      }
      group.count++
      group.addresses.push(info.address)
      group.titles.push(Icons.stripAppSuffix(Icons.cleanTitle(toplevel.title, 80), group.name))
      if (toplevel.urgent) group.urgent = true
      if (toplevel === active) group.focused = true
      group.x = Math.min(group.x, at[0])
      group.y = Math.min(group.y, at[1])
    }
    var vertical = root.vertical
    groups.sort(function(a, b) { return Icons.spatialCompare(a, b, vertical) })
    return groups
  }

  // The groups that fit, always including the focused app's.
  function visibleGroups(groups, vertical) {
    var limit = vertical ? Math.min(root.maxIcons, 4) : root.maxIcons
    if (groups.length <= limit) return groups
    var shown = groups.slice(0, limit)
    for (var i = limit; i < groups.length; i++) {
      if (groups[i].focused) {
        shown[limit - 1] = groups[i]
        break
      }
    }
    return shown
  }

  function groupTooltip(group) {
    if (!group || !group.titles) return ""
    var lines = [group.name + (group.count > 1 ? " (" + group.count + ")" : "")]
    for (var i = 0; i < group.titles.length && i < 6; i++) {
      if (group.titles[i] && group.titles[i] !== group.name) lines.push("  " + group.titles[i])
    }
    if (group.titles.length > 6) lines.push("  …")
    return lines.join("\n")
  }

  // ---- Window data from Hyprland, refreshed on its events.
  //
  // Hyprland reports window changes as events; each burst of them triggers
  // one `hyprctl clients` read. Title changes are frequent (terminals and
  // spinners set them constantly), so they wait longer. A slow poll picks up
  // what runs in terminals, which Hyprland does not report.

  function scheduleRefresh(slow) {
    if (root.symbolMode) return
    // Not restarted while pending: a steady stream of events must not keep
    // postponing fresh data.
    if (slow) { if (!slowRefresh.running) slowRefresh.start() }
    else if (!fastRefresh.running) fastRefresh.start()
  }

  Timer {
    id: fastRefresh
    interval: 40
    onTriggered: root.refreshWindows()
  }

  Timer {
    id: slowRefresh
    interval: 600
    onTriggered: root.refreshWindows()
  }

  property bool refreshPending: false

  function refreshWindows() {
    if (root.symbolMode) return
    if (windowProbe.running) {
      root.refreshPending = true
      return
    }
    windowProbe.command = ["bash", "-c", root.probeScript]
    windowProbe.running = true
    probeWatchdog.restart()
  }

  // A hung hyprctl must not stall every later refresh.
  Timer {
    id: probeWatchdog
    interval: 4000
    onTriggered: if (windowProbe.running) windowProbe.running = false
  }

  // Prints the window list ("C <json>"), the monitors ("M <json>"), for each
  // window pid the program in the foreground of the tty its first child runs
  // on ("P pid name exe") — for a terminal window that is the program running
  // in the terminal — whether a screen recorder runs ("R 0|1"), and a stamp
  // of the wallpaper file ("W <stamp>").
  readonly property string probeScript: 'clients=$(hyprctl clients -j 2>/dev/null) || exit 0\n'
    + 'printf "C %s\\n" "$(jq -c \'map({a: (.address | ltrimstr("0x")), class, initialClass, initialTitle, pid, at, size,'
    + ' ws: .workspace.id, wsName: .workspace.name, monitor, floating, fullscreen, focusHistoryID, hidden, mapped, pinned})\' <<<"$clients" | head -c 1048576)"\n'
    + 'printf "M %s\\n" "$(hyprctl monitors -j 2>/dev/null | jq -c \'map({id, name, x, y, width, height, scale, transform, reserved})\')"\n'
    + 'for pid in $(jq -r \'.[].pid\' <<<"$clients" | sort -u | head -n 256); do\n'
    + '  child=$(cat /proc/"$pid"/task/*/children 2>/dev/null | tr " " "\\n" | grep -m1 .)\n'
    + '  [ -n "$child" ] && stat=$(cat /proc/"$child"/stat 2>/dev/null) || continue\n'
    + '  set -- ${stat##*) }\n'
    + '  [ "${6:-0}" -gt 0 ] || continue\n'
    + '  name=$(cat /proc/"$6"/comm 2>/dev/null)\n'
    + '  echo "P $pid ${name// /_} $(readlink /proc/"$6"/exe 2>/dev/null)"\n'
    + 'done\n'
    + 'pgrep -x "wf-recorder|gpu-screen-reco|wl-screenrec|obs|kooha" >/dev/null && echo "R 1" || echo "R 0"\n'
    + 'echo "W $(stat -L -c %i-%Y "$HOME/.local/state/omarchy/current/background" 2>/dev/null)"\n'

  Process {
    id: windowProbe
    stdout: StdioCollector {
      onStreamFinished: {
        probeWatchdog.stop()
        var clients = null
        var monitors = null
        var programs = ({})
        var lines = this.text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i]
          if (line.indexOf("C ") === 0) {
            var list = null
            try { list = JSON.parse(line.substring(2)) } catch (e) {}
            if (Array.isArray(list)) {
              clients = ({})
              for (var j = 0; j < list.length; j++) {
                if (list[j] && list[j].a) clients[String(list[j].a)] = list[j]
              }
            }
          } else if (line.indexOf("M ") === 0) {
            try { monitors = JSON.parse(line.substring(2)) } catch (e) {}
          } else if (line.indexOf("P ") === 0) {
            var parts = line.substring(2).split(" ")
            programs[parts[0]] = { name: parts[1] || "", exe: parts.slice(2).join(" ") }
          } else if (line.indexOf("R ") === 0) {
            root.recorderRunning = line.substring(2).trim() === "1"
          } else if (line.indexOf("W ") === 0) {
            root.wallpaperStamp = line.substring(2).trim()
          }
        }
        // Mid-move, `hyprctl clients` can briefly report no windows; a
        // failed read keeps the last good data too.
        var emptyGlitch = clients !== null && Object.keys(clients).length === 0 && Hyprland.toplevels.values.length > 0
        if (clients !== null && !emptyGlitch && JSON.stringify(clients) !== JSON.stringify(root.clientInfo)) root.clientInfo = clients
        if (Array.isArray(monitors) && JSON.stringify(monitors) !== JSON.stringify(root.monitorInfo)) root.monitorInfo = monitors
        if (JSON.stringify(programs) !== JSON.stringify(root.terminalPrograms)) root.terminalPrograms = programs
        root.updateTerminalFlag()
        root.resolveMissingIcons()
        if (root.refreshPending) {
          root.refreshPending = false
          root.scheduleRefresh(false)
        }
      }
    }
  }

  function updateTerminalFlag() {
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      if (root.isTerminal(root.windowInfo(values[i]))) {
        root.hasTerminalWindows = true
        return
      }
    }
    root.hasTerminalWindows = false
  }

  // Events that change what the bar or the preview shows.
  readonly property var windowEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode",
    "fullscreen", "pin", "urgent", "workspacev2", "createworkspacev2", "destroyworkspacev2"]
  readonly property var titleEvents: ["windowtitle", "windowtitlev2"]
  readonly property var monitorEvents: ["moveworkspace", "moveworkspacev2", "focusedmon", "focusedmonv2", "activespecial",
    "activespecialv2", "monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "renameworkspace"]

  Connections {
    target: Hyprland
    enabled: !root.symbolMode
    function onRawEvent(event) {
      var name = event.name
      if (name === "closewindow") root.previewDropWindow(String(event.data || "").replace(/^0x/, ""))
      if (root.windowEvents.indexOf(name) !== -1) root.scheduleRefresh(false)
      else if (root.titleEvents.indexOf(name) !== -1) root.scheduleRefresh(true)
      else if (root.monitorEvents.indexOf(name) !== -1) monitorRefresh.restart()
      else if (name === "configreloaded") {
        rulesProbe.running = true
        monitorRefresh.restart()
      }
    }
  }

  // Quickshell leaves a monitor's active workspace stale after a workspace
  // moves between monitors, and lastIpcObject (specialWorkspace) only
  // updates on a refresh.
  Timer {
    id: monitorRefresh
    interval: 30
    onTriggered: {
      Hyprland.refreshMonitors()
      Hyprland.refreshWorkspaces()
      root.monitorRevision++
      root.scheduleRefresh(false)
    }
  }

  // Names that none of the quick lookups found an icon for and that
  // scripts/resolve-icons has not been asked about yet.
  function missingIconNames() {
    var names = []
    function want(name) {
      if (name && !(name in root.resolvedIcons) && names.indexOf(name) === -1
          && !root.entryIcon(name) && !root.namedIcon(name) && !root.launcherIndex.programs[name])
        names.push(name)
    }
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var info = root.windowInfo(values[i])
      if (root.isTerminal(info)) {
        var programNames = root.programNames(root.terminalPrograms[String(info.pid)])
        for (var j = 0; j < programNames.length; j++) {
          if (root.agentIcons.indexOf(programNames[j]) === -1) want(programNames[j])
        }
      } else if (!root.webappIcon(info) && !Icons.omarchyProgram(info.appId)) {
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

  // What runs in a terminal changes without a Hyprland event, so terminals
  // are polled; without any, a slow poll only reconciles.
  Timer {
    interval: root.hasTerminalWindows ? Math.max(1, Number(root.setting("terminalPollSeconds", 2))) * 1000 : 15000
    running: !root.symbolMode
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshWindows()
  }

  // Icons fade in when apps appear, not while the bar first builds.
  property bool startedUp: false
  readonly property bool animationsReady: root.animations && root.startedUp

  Timer {
    interval: 1500
    running: true
    onTriggered: root.startedUp = true
  }

  Component.onCompleted: {
    root.resolveBarWindow()
    if (!root.symbolMode) {
      Hyprland.refreshToplevels()
      Hyprland.refreshWorkspaces()
      Hyprland.refreshMonitors()
      rulesProbe.running = true
    }
  }

  // ---- Bar.

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property color symbolColor: bar ? bar.barForeground : Color.foreground
  readonly property color barBackground: bar && bar.background !== undefined ? bar.background : Color.background
  readonly property color urgentColor: bar && bar.urgent !== undefined ? bar.urgent : Color.urgent

  // The theme's background or foreground, whichever reads better on a fill.
  function contrastOn(fill) {
    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    var dark = Color.background
    var light = Color.foreground
    var l = luminance(fill)
    return Math.abs(l - luminance(dark)) >= Math.abs(l - luminance(light)) ? dark : light
  }
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
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
      onPressed: function() { root.toggleSettings("") }

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
      id: buttonRepeater
      model: root.workspaceList

      WorkspaceButton {
        required property string modelData
        panel: root
        key: modelData
      }
    }
  }

  // ---- Workspace preview.
  //
  // Resting the pointer on a workspace shows its windows where they sit on
  // the monitor, each captured from the window. A window shows its app icon
  // until its capture arrives, or when the compositor gives none.

  // Workspace button under the pointer and its key.
  property Item previewHoverButton: null
  property string previewHoverKey: ""
  property Item previewAnchor: null
  property bool previewOpen: false
  // Windows of the previewed workspace, back to front: { address, toplevel,
  // icon, title, x, y, width, height } in preview pixels.
  property var previewWindows: []
  property size previewSize: Qt.size(0, 0)
  property string previewWallpaper: ""
  // Header ("Workspace 2", "2 windows") and the footer line, which names
  // the window or app under the pointer and otherwise says what a click does.
  property string previewTitle: ""
  property string previewCount: ""
  property string previewCaption: ""
  readonly property string previewHint: "Click a window to jump to it"
  property var previewHighlight: []
  property bool previewCardHover: false
  readonly property real previewMaxSize: Style.space(420)
  readonly property int previewMaxWindows: 12

  // Screen shares go through PipeWire video streams; bound only while the
  // preview can show.
  PwObjectTracker {
    objects: root.showPreview && root.previewPrivacy && !root.symbolMode ? Pipewire.nodes.values : []
  }

  function screenSharing() {
    if (root.recorderRunning) return true
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      var props = node ? node.properties : null
      if (!props) continue
      if (String(props["media.class"] || "").toLowerCase().indexOf("video") === -1) continue
      var marker = [props["media.role"], props["media.name"], props["node.name"], props["node.description"],
        props["application.name"], props["pipewire.access.portal.app_id"]].join(" ").toLowerCase()
      // A portal name alone is not enough: portals back other video too.
      if (/(screen[ _.-]?(cast|shar|captur)|desktop[ _.-]?(cast|shar|captur)|monitor[ _.-]?captur|xdg[ _.-]?desktop[ _.-]?portal.*(screen|cast|captur))/.test(marker))
        return true
    }
    return false
  }

  function canPreview() {
    return root.showPreview && !root.symbolMode && !root.opened
      && !(root.bar && root.bar.activePopout)
      && !(root.previewPrivacy && root.screenSharing())
  }

  function hoverWorkspace(button, key, hovered) {
    if (hovered) {
      root.previewHoverButton = button
      root.previewHoverKey = key
      previewCloseDelay.stop()
      // With a preview already up, follow the pointer without waiting again.
      if (root.previewOpen) root.buildPreview()
      else previewOpenDelay.restart()
    } else if (root.previewHoverButton === button) {
      root.previewHoverButton = null
      root.previewHoverKey = ""
      previewOpenDelay.stop()
      previewCloseDelay.restart()
    }
  }

  // A button can go away under the pointer (monitor unplugged, list
  // rebuilt) without a leave event.
  onPreviewHoverButtonChanged: if (!previewHoverButton && previewOpen && !previewCardHover) previewCloseDelay.restart()

  function previewCardHovered(hovered) {
    root.previewCardHover = hovered
    if (hovered) previewCloseDelay.stop()
    else if (!root.previewHoverButton) previewCloseDelay.restart()
  }

  function closePreview() {
    previewOpenDelay.stop()
    previewCloseDelay.stop()
    root.previewHoverButton = null
    root.previewHoverKey = ""
    root.previewOpen = false
  }

  function peek(key) {
    var index = root.workspaceList.indexOf(String(key))
    var button = index !== -1 ? buttonRepeater.itemAt(index) : null
    if (!button) return
    root.previewHoverButton = button
    root.previewHoverKey = String(key)
    previewCloseDelay.stop()
    root.buildPreview()
  }

  function previewClosed() {
    root.previewWindows = []
    root.previewHighlight = []
  }

  Timer {
    id: previewOpenDelay
    interval: 400
    onTriggered: root.buildPreview()
  }

  Timer {
    id: previewCloseDelay
    // Long enough to cross the gap between the bar and the card.
    interval: 220
    onTriggered: if (!root.previewCardHover && !root.previewHoverButton) root.previewOpen = false
  }

  function monitorFor(workspace, windows) {
    var name = workspace && workspace.monitor ? workspace.monitor.name : ""
    var id = windows.length > 0 ? windows[0].monitor : -1
    for (var i = 0; i < root.monitorInfo.length; i++) {
      var monitor = root.monitorInfo[i]
      if (monitor.name === name || monitor.id === id) return monitor
    }
    return null
  }

  function buildPreview() {
    var key = root.previewHoverKey
    var workspace = key !== "" ? root.workspaceByKey(key) : null
    if (!root.canPreview() || !workspace || workspace.toplevels.values.length === 0 || !root.workspaceSetting(key, "preview", true)) {
      root.previewOpen = false
      return
    }
    var clients = []
    for (var address in root.clientInfo) {
      var client = root.clientInfo[address]
      if (client.ws === workspace.id && client.hidden !== true && client.mapped !== false && client.at && client.size) clients.push(client)
    }
    var monitor = root.monitorFor(workspace, clients)
    if (!monitor || clients.length === 0) {
      root.previewOpen = false
      return
    }
    // Window positions are in logical pixels, monitor sizes in physical
    // ones; the bar's reserved strip is left out of the miniature.
    var rotated = monitor.transform % 2 === 1
    var scale = monitor.scale || 1
    var reserved = Array.isArray(monitor.reserved) ? monitor.reserved : [0, 0, 0, 0]
    var left = monitor.x + (reserved[0] || 0)
    var top = monitor.y + (reserved[1] || 0)
    var usableWidth = Math.max(1, (rotated ? monitor.height : monitor.width) / scale - (reserved[0] || 0) - (reserved[2] || 0))
    var usableHeight = Math.max(1, (rotated ? monitor.width : monitor.height) / scale - (reserved[1] || 0) - (reserved[3] || 0))
    var factor = Math.min(root.previewMaxSize / usableWidth, root.previewMaxSize / usableHeight)

    var toplevels = {}
    var values = workspace.toplevels.values
    for (var t = 0; t < values.length; t++) toplevels[String(values[t].address).replace(/^0x/, "")] = values[t]

    // The most recently focused windows, drawn tiled below floating below
    // fullscreen and oldest first within those.
    clients.sort(function(a, b) { return a.focusHistoryID - b.focusHistoryID })
    clients = clients.slice(0, root.previewMaxWindows)
    function layer(client) { return client.fullscreen ? 2 : (client.floating ? 1 : 0) }
    clients.sort(function(a, b) { return layer(a) - layer(b) || b.focusHistoryID - a.focusHistoryID })

    var windows = []
    for (var i = 0; i < clients.length; i++) {
      var entry = clients[i]
      var toplevel = toplevels[entry.a]
      if (!toplevel) continue
      var x = Math.max(0, (entry.at[0] - left) * factor)
      var y = Math.max(0, (entry.at[1] - top) * factor)
      windows.push({
        address: entry.a,
        toplevel: toplevel,
        icon: root.iconFor(root.windowInfo(toplevel)),
        title: Icons.cleanTitle(toplevel.title, 90),
        x: Math.round(x),
        y: Math.round(y),
        width: Math.max(1, Math.min(Math.round(entry.size[0] * factor), Math.round(usableWidth * factor - x))),
        height: Math.max(1, Math.min(Math.round(entry.size[1] * factor), Math.round(usableHeight * factor - y)))
      })
    }
    if (windows.length === 0) {
      root.previewOpen = false
      return
    }
    var label = root.workspaceName(key) || (key.indexOf("special:") === 0 ? "Special: " + key.substring(8)
      : (key.indexOf("name:") === 0 ? key.substring(5) : "Workspace " + (key === "10" ? "0" : key)))
    root.previewTitle = label
    root.previewCount = values.length + (values.length === 1 ? " window" : " windows")
    root.previewCaption = root.previewHint
    root.previewSize = Qt.size(Math.round(usableWidth * factor), Math.round(usableHeight * factor))
    root.previewWallpaper = "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background#" + root.wallpaperStamp
    root.previewHighlight = []
    root.previewWindows = windows
    root.previewAnchor = root.previewHoverButton
    root.previewOpen = true
    previewCard.card.anchor.updateAnchor()
    // Refresh the data behind it for the next look.
    root.scheduleRefresh(false)
  }

  // A closing window's capture is detached before its handle goes away.
  function previewDropWindow(address) {
    if (!root.previewOpen || !address) return
    var next = root.previewWindows.filter(function(w) { return w.address !== address })
    if (next.length !== root.previewWindows.length) root.previewWindows = next
  }

  // Hovering an app's icon marks its windows in the preview.
  function iconHovered(item, group, hovered) {
    if (!root.previewOpen) return
    if (hovered) {
      root.previewHighlight = group.addresses || []
      root.previewCaption = root.groupTooltip(group).split("\n").map(function(line) { return line.trim() }).join(" · ")
    } else {
      root.previewHighlight = []
      root.previewCaption = root.previewHint
    }
  }

  function previewWindowHovered(window, hovered) {
    root.previewHighlight = hovered ? [window.address] : []
    root.previewCaption = hovered && window.title ? window.title : root.previewHint
  }

  function previewWindowClicked(window) {
    root.focusWindow(window.address)
    root.closePreview()
  }

  WorkspacePreview {
    id: previewCard
    panel: root
    fallbackAnchor: layout
  }

  // ---- Settings popup.

  // Keyboard cursor over the popup rows.
  property int cursorIndex: -1
  readonly property int rowCount: rows.length
  readonly property color panelForeground: bar ? bar.foreground : Color.foreground
  readonly property string panelFont: bar ? bar.fontFamily : Style.font.family
  // The numbered workspace the popup was opened from (right click); "" when
  // opened otherwise, and "This workspace" is then the focused one.
  property string settingsKey: ""
  readonly property string thisWorkspaceKey: root.settingsKey !== "" ? root.settingsKey
    : (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0 ? String(Hyprland.focusedWorkspace.id) : "")
  // The name field has the keyboard; the popup's keys pause meanwhile.
  property bool nameEditing: false

  function sliderRow(key) {
    for (var i = 0; i < root.generalRows.length; i++) {
      if (root.generalRows[i].key === key) return root.generalRows[i]
    }
    return null
  }

  function sliderValue(key) {
    if (key === "iconOpacity") return root.iconOpacity
    if (key === "workspaceCount") return root.workspaceCount
    return 0
  }

  function shownSliderValue(key) {
    return key in root.sliderPreview ? root.sliderPreview[key] : root.sliderValue(key)
  }

  function sliderText(row, value) {
    return row.percent ? Math.round(value * 100) + "%" : String(Math.round(value))
  }

  function previewSlider(key, value) {
    var next = {}
    for (var k in root.sliderPreview) next[k] = root.sliderPreview[k]
    next[key] = value
    root.sliderPreview = next
  }

  // Saves a slider value clamped to its range and snapped to its step.
  function setSlider(key, value) {
    var row = root.sliderRow(key)
    var snapped = row.min + Math.round((Math.max(row.min, Math.min(row.max, value)) - row.min) / row.step) * row.step
    var next = {}
    for (var k in root.sliderPreview) if (k !== key) next[k] = root.sliderPreview[k]
    root.sliderPreview = next
    root.setSetting(key, Math.round(snapped * 100) / 100)
  }

  function setWorkspaceName(key, name) {
    root.setWorkspaceSetting(key, "name", Icons.cleanTitle(name, 24), "")
  }

  // Rows that change with left/right: choices, sliders and the folds.
  function rowChoice(row) {
    var item = root.rows[row]
    return item && (item.options || item.slider || item.fold) ? item : null
  }

  signal nameFieldRequested()

  function activateRow(row, direction) {
    var item = root.rows[row]
    if (!item || item.header) return
    if (item.fold) {
      // Enter flips a section; right unfolds it, left folds it.
      root.flipFold(item.fold, direction === 0 ? undefined : direction > 0)
      return
    }
    if (item.slider) {
      if (direction !== 0) root.setSlider(item.key, root.sliderValue(item.key) + direction * item.step)
      return
    }
    if (item.nameField) {
      if (direction === 0) root.nameFieldRequested()
      return
    }
    if (item.wsKey) {
      if (direction === 0) root.flipWorkspaceToggle(item)
      return
    }
    if (!item.options) {
      if (direction === 0) root.flipToggle(item.key)
      return
    }
    var choice = item
    if (direction !== 0) {
      root.stepChoice(choice, direction)
    } else {
      // Enter cycles through the values.
      var values = root.choiceValues(choice)
      root.setChoice(choice.key, values[(values.indexOf(root.choiceValue(choice.key)) + 1) % values.length])
    }
  }

  onOpenedChanged: if (opened) {
    closePreview()
    cursorIndex = -1
    shellConfigFile.reload()
    focusDelay.restart()
  }

  // A component-owned Timer rather than Qt.callLater: a queued closure can
  // outlive this component across a plugin reload.
  Timer {
    id: focusDelay
    interval: 0
    onTriggered: keyCatcher.forceActiveFocus()
  }

  onCursorIndexChanged: root.ensureCursorVisible()

  // Keep the keyboard cursor's row on screen when the popup scrolls.
  function ensureCursorVisible() {
    var item = root.cursorIndex >= 0 ? rowRepeater.itemAt(root.cursorIndex) : null
    if (!item) return
    var y = item.mapToItem(column, 0, 0).y
    if (y < flick.contentY) flick.contentY = Math.max(0, y - Style.space(8))
    else if (y + item.height > flick.contentY + flick.height)
      flick.contentY = Math.min(flick.contentHeight - flick.height, y + item.height - flick.height + Style.space(8))
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

  // Opened for a workspace (right click), the popup starts on that
  // workspace's own settings; otherwise on the general ones.
  function openSettingsFor(key) {
    var workspaceKey = /^\d+$/.test(String(key)) ? String(key) : ""
    if (root.opened && root.settingsKey === workspaceKey) {
      root.close()
      return
    }
    root.settingsKey = workspaceKey
    root.workspaceOpen = workspaceKey !== ""
    root.generalOpen = workspaceKey === ""
    root.openHere()
  }

  function toggleSettings(key) {
    if (root.opened) root.close()
    else root.openSettingsFor(key)
  }

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
    root.settingsKey = ""
    root.workspaceOpen = false
    root.generalOpen = true
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

  // What this bar shows, for scripts and debugging:
  // `omarchy-shell woodenplastic.workspace-icons status`.
  function statusJson() {
    var workspaces = []
    var buttons = []
    for (var i = 0; i < root.workspaceList.length; i++) {
      var key = root.workspaceList[i]
      var workspace = root.workspaceByKey(key)
      var groups = root.workspaceGroups(workspace)
      workspaces.push({
        key: key,
        name: root.workspaceName(key),
        focused: workspace !== null && Hyprland.focusedWorkspace === workspace,
        urgent: workspace !== null && workspace.urgent,
        apps: groups.map(function(g) { return { name: g.name, count: g.count, icon: g.source } })
      })
    }
    return JSON.stringify({
      version: 2,
      screen: root.barScreen ? root.barScreen.name : "",
      monitor: root.barMonitor ? root.barMonitor.name : "",
      perMonitor: root.perMonitor,
      settingsOpen: root.opened,
      workspaces: workspaces,
      windows: Object.keys(root.clientInfo).length,
      terminals: root.hasTerminalWindows,
      preview: { open: root.previewOpen, key: root.previewHoverKey, windows: root.previewWindows.length, sharing: root.screenSharing(), can: root.canPreview() }
    })
  }

  IpcHandler {
    enabled: root.ipcTarget !== ""
    target: root.ipcTarget

    function open(): void { if (!root.opened) root.openSettingsFor("") }
    function close(): void { root.close() }
    function show(): void { if (!root.opened) root.openSettingsFor("") }
    function hide(): void { root.close() }
    function toggle(): void { root.toggleSettings("") }
    // Settings opened on one workspace's section, like a right click on it:
    // `omarchy-shell woodenplastic.workspace-icons settings 3`.
    function settings(key: string): void { root.openSettingsFor(String(key)) }
    function toggleAt(x: string, y: string): void { root.routeToggleAt(Number(x), Number(y)) }
    // Preview a workspace as if hovered, until `unpeek` or the pointer moves
    // over the bar: `omarchy-shell woodenplastic.workspace-icons peek 3`.
    function peek(key: string): void { root.peek(key) }
    function unpeek(): void { root.closePreview() }
    function status(): string {
      var widgets = root.bar ? root.bar.moduleWidgets(root.moduleName) : [root]
      var list = []
      for (var i = 0; i < widgets.length; i++) {
        if (widgets[i] && !widgets[i].symbolMode && widgets[i].statusJson) list.push(JSON.parse(widgets[i].statusJson()))
      }
      return JSON.stringify(list.length > 0 ? list : [JSON.parse(root.statusJson())])
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorAtPoint ? pointAnchor : (root.showSymbol ? launcher : layout)
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(800))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.nameEditing
      onMoveRequested: function(dx, dy) {
        if (root.cursorIndex < 0) { root.moveCursor(1); return }
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

          Repeater {
            id: rowRepeater
            model: root.rows

            Item {
              id: toggleRow
              required property var modelData
              required property int index
              readonly property bool isFold: !!modelData.fold
              readonly property bool isHeader: !!modelData.header
              readonly property bool isChoice: !!modelData.options
              readonly property bool isSlider: !!modelData.slider
              readonly property bool isName: !!modelData.nameField
              readonly property bool isWorkspaceToggle: !!modelData.wsKey
              readonly property bool isToggle: !isFold && !isHeader && !isChoice && !isSlider && !isName
              readonly property bool hasCursor: root.cursorIndex === index
              readonly property real indent: modelData.parentKey ? Style.space(24) : 0
              visible: root.rowVisible(index)
              x: indent
              width: column.width - indent
              implicitHeight: isFold ? foldRow.implicitHeight
                : (isHeader ? headerRow.implicitHeight
                  : (isSlider ? subSlider.implicitHeight
                    : (isChoice ? subChoice.implicitHeight
                      : (isName ? nameRow.implicitHeight : toggle.implicitHeight))))

              // A folding section: "This workspace" or "General".
              Item {
                id: foldRow
                visible: toggleRow.isFold
                width: parent.width
                // Room and a rule between the two sections.
                readonly property real gapAbove: toggleRow.index > 0 ? Style.space(20) : 0
                implicitHeight: gapAbove + foldTitle.implicitHeight + Style.space(16)
                readonly property bool unfolded: toggleRow.modelData.fold === "workspace" ? root.workspaceOpen : root.generalOpen

                PanelSeparator {
                  visible: foldRow.gapAbove > 0
                  y: Math.round((foldRow.gapAbove - height) / 2)
                  width: parent.width
                  foreground: root.panelForeground
                }

                Rectangle {
                  id: foldBox
                  anchors.fill: parent
                  anchors.topMargin: foldRow.gapAbove
                  radius: Style.cornerRadius
                  color: toggleRow.hasCursor || foldMouse.containsMouse
                    ? Qt.rgba(root.panelForeground.r, root.panelForeground.g, root.panelForeground.b, 0.08) : "transparent"
                  border.width: toggleRow.hasCursor ? Math.max(1, Style.space(1.5)) : 0
                  border.color: Qt.rgba(root.panelForeground.r, root.panelForeground.g, root.panelForeground.b, 0.4)
                }

                Text {
                  id: foldTitle
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.right: foldChevron.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: foldBox.verticalCenter
                  textFormat: Text.PlainText
                  text: toggleRow.isFold ? root.foldTitle(toggleRow.modelData.fold) : ""
                  color: root.panelForeground
                  elide: Text.ElideRight
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  id: foldChevron
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: foldBox.verticalCenter
                  textFormat: Text.PlainText
                  // Nerd Font chevrons: down while unfolded, right while folded.
                  text: foldRow.unfolded ? "\uf078" : "\uf054"
                  color: root.panelForeground
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  id: foldMouse
                  anchors.fill: foldBox
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.cursorIndex = toggleRow.index
                  onClicked: root.flipFold(toggleRow.modelData.fold)
                }
              }

              Column {
                id: headerRow
                visible: toggleRow.isHeader
                width: parent.width
                spacing: Style.space(10)

                // No rule right under a section's own title.
                PanelSeparator {
                  visible: toggleRow.index > 0 && !(root.rows[toggleRow.index - 1] || {}).fold
                  foreground: root.panelForeground
                }

                PanelSectionHeader {
                  text: toggleRow.modelData.header || ""
                  foreground: root.panelForeground
                  fontFamily: root.panelFont
                }
              }

              // The workspace's name, shown instead of its number.
              Item {
                id: nameRow
                visible: toggleRow.isName
                width: parent.width
                implicitHeight: Math.max(nameLabel.implicitHeight, nameField.implicitHeight)

                Text {
                  id: nameLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: toggleRow.modelData.label || ""
                  color: root.panelForeground
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                }

                TextField {
                  id: nameField
                  anchors.left: nameLabel.right
                  anchors.leftMargin: Style.space(16)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  foreground: root.panelForeground
                  hasCursor: toggleRow.hasCursor
                  placeholderText: "Shown instead of the number"
                  text: toggleRow.isName ? root.workspaceSetting(root.thisWorkspaceKey, "name", "") : ""
                  onActiveFocusChanged: if (toggleRow.isName) root.nameEditing = activeFocus
                  onAccepted: {
                    root.setWorkspaceName(root.thisWorkspaceKey, text)
                    keyCatcher.forceActiveFocus()
                  }
                  Keys.onEscapePressed: keyCatcher.forceActiveFocus()

                  Connections {
                    target: root
                    enabled: toggleRow.isName
                    function onNameFieldRequested() { nameField.forceActiveFocus() }
                  }
                }
              }

              Item {
                id: subSlider
                visible: toggleRow.isSlider
                width: parent.width
                implicitHeight: Math.max(sliderLabel.implicitHeight, Style.space(30))

                Text {
                  id: sliderLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: toggleRow.modelData.label || ""
                  color: root.panelForeground
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                }

                PanelSlider {
                  id: rowSlider
                  bar: root.bar
                  anchors.left: sliderLabel.right
                  anchors.leftMargin: Style.space(16)
                  anchors.right: sliderValue.left
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  minimum: toggleRow.isSlider ? toggleRow.modelData.min : 0
                  maximum: toggleRow.isSlider ? toggleRow.modelData.max : 1
                  step: toggleRow.isSlider ? toggleRow.modelData.step : 0.1
                  value: toggleRow.isSlider ? root.sliderValue(toggleRow.modelData.key) : 0
                  // Whole-number sliders snap to, and show a notch for, every value.
                  integer: toggleRow.isSlider && toggleRow.modelData.step === 1
                  tickCount: integer ? toggleRow.modelData.max - toggleRow.modelData.min + 1 : 0
                  opacity: toggleRow.hasCursor || dragging ? 1 : 0.85
                  onMoved: function(v) { root.previewSlider(toggleRow.modelData.key, v) }
                  onReleased: function(v) { root.setSlider(toggleRow.modelData.key, v) }
                }

                Text {
                  id: sliderValue
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(44)
                  horizontalAlignment: Text.AlignRight
                  textFormat: Text.PlainText
                  text: toggleRow.isSlider ? root.sliderText(toggleRow.modelData, root.shownSliderValue(toggleRow.modelData.key)) : ""
                  color: root.panelForeground
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.NoButton
                  hoverEnabled: true
                  onEntered: root.cursorIndex = toggleRow.index
                }
              }

              Toggle {
                id: toggle
                visible: toggleRow.isToggle
                width: parent.width
                label: toggleRow.modelData.label || ""
                description: toggleRow.modelData.description || ""
                checked: toggleRow.isWorkspaceToggle ? root.workspaceToggleValue(toggleRow.modelData) : root.toggleValue(toggleRow.modelData.key)
                hasCursor: toggleRow.hasCursor
                foreground: root.panelForeground
                fontFamily: root.panelFont
                onHovered: function(h) { if (h) root.cursorIndex = toggleRow.index }
                onClicked: {
                  if (toggleRow.isWorkspaceToggle) root.flipWorkspaceToggle(toggleRow.modelData)
                  else root.flipToggle(toggleRow.modelData.key)
                }
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
                  anchors.right: subGroup.left
                  anchors.rightMargin: Style.space(10)
                  textFormat: Text.PlainText
                  text: toggleRow.modelData.label || ""
                  color: root.panelForeground
                  elide: Text.ElideRight
                  font.family: root.panelFont
                  font.pixelSize: Style.font.body
                }

                ButtonGroup {
                  id: subGroup
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  options: toggleRow.isChoice ? toggleRow.modelData.options : []
                  value: root.choiceValue(toggleRow.modelData.key || "")
                  focusable: false
                  cursorIndex: toggleRow.hasCursor && toggleRow.isChoice
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
        }
      }
    }
  }
}
