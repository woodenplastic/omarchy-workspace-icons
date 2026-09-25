import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "woodenplastic.workspace-icons"

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

  readonly property bool showIcons: setting("showIcons", true) !== false
  readonly property int maxIcons: Math.max(1, Number(setting("maxIcons", 4)))
  readonly property real iconSize: Math.round(Style.font.body * Number(setting("iconScale", 1.15)))
  // Map a window class to a theme icon name or an absolute image path, for
  // apps without a desktop entry. Set inline in shell.json (see README).
  readonly property var iconOverrides: setting("iconOverrides", ({}))

  function windowInfo(toplevel) {
    var ipc = toplevel.lastIpcObject || {}
    var appId = toplevel.wayland && toplevel.wayland.appId ? toplevel.wayland.appId : String(ipc.class || "")
    return { appId: appId, initialClass: String(ipc.initialClass || ""), initialTitle: String(ipc.initialTitle || "") }
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

  function iconFor(info) {
    var override = root.iconOverrides[info.appId]
    if (override) return root.themedIcon(String(override))

    var path = root.entryIcon(info.appId)
      || root.themedIcon(info.appId)
      || root.themedIcon(info.appId.toLowerCase())
      || root.entryIcon(info.initialClass)
      // Terminals launched with a custom app id (e.g. `foot --app-id=x`)
      // still carry the terminal's name as their initial title.
      || root.entryIcon(info.initialTitle)
    return path || Quickshell.iconPath("application-x-executable", true)
  }

  // One icon per distinct app on the workspace, in window order.
  function workspaceIcons(workspace) {
    if (workspace === null || !root.showIcons) return []
    var seen = []
    var icons = []
    var toplevels = workspace.toplevels.values
    for (var i = 0; i < toplevels.length && icons.length < root.maxIcons; i++) {
      var info = root.windowInfo(toplevels[i])
      if (info.appId === "" || seen.indexOf(info.appId) !== -1) continue
      seen.push(info.appId)
      icons.push(root.iconFor(info))
    }
    return icons
  }

  Component.onCompleted: Hyprland.refreshToplevels()

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property var icons: root.vertical ? [] : root.workspaceIcons(workspace)

        id: button
        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        labelVisible: false
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Math.max(Style.space(20), content.implicitWidth + Style.spaceReal(6) * 2)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        Row {
          id: content
          anchors.centerIn: parent
          spacing: Style.spaceReal(3)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: button.text
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
            }
          }
        }
      }
    }
  }
}
