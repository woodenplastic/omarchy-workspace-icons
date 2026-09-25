# Workspace Icons

An Omarchy bar widget that works like the built-in workspace indicators, but
also shows an icon for each app open on a workspace.

![Workspace Icons in the Omarchy bar](preview.png)

## Install

```bash
omarchy plugin add https://github.com/woodenplastic/omarchy-workspace-icons
```

Then swap the stock widget for this one in `~/.config/omarchy/shell.json`:

```json
"left": [
  { "id": "omarchy.menu" },
  { "id": "woodenplastic.workspace-icons" }
]
```

## Settings

| Key             | Default | Description                                         |
|-----------------|---------|-----------------------------------------------------|
| `showIcons`     | `true`  | Show app icons next to the workspace numbers.       |
| `maxIcons`      | `4`     | Maximum icons per workspace (one per distinct app). |
| `iconScale`     | `1.15`  | Icon size relative to the bar font size.            |
| `showTerminalPrograms` | `true` | Show the program running in a terminal instead of the terminal icon. |
| `terminalPollSeconds`  | `2`    | How often to check what runs in terminals.          |
| `iconOverrides` | `{}`    | Window class or program name → icon name or absolute image path. |

Icons are looked up from the app's desktop entry, then the icon theme. Apps
without either show a generic icon; give them one with `iconOverrides`:

```json
{
  "id": "woodenplastic.workspace-icons",
  "maxIcons": 3,
  "iconOverrides": {
    "xfreerdp": "windows",
    "MyTauriApp": "/home/me/projects/my-app/src-tauri/icons/128x128.png"
  }
}
```

Find a window's class with `hyprctl clients`.

## Programs in terminals

For terminal windows (any app whose desktop entry is a `TerminalEmulator`), the
widget shows the program in the terminal's foreground, such as `nvim` or
`btop`. A plain shell keeps the terminal icon.

Programs are matched by process name. Programs without an icon in your theme
fall back to the terminal icon. Give them one either with `iconOverrides`
(`"claude": "/path/to/claude.svg"`), or by dropping an SVG named after the
program into `~/.local/share/icons/hicolor/scalable/apps/`, e.g.
`~/.local/share/icons/hicolor/scalable/apps/claude.svg`.

## Notes

- Chrome/Chromium web apps share the browser's window class, so they show the
  browser icon.
- Icons are shown on horizontal bars only; vertical bars show numbers.

## License

MIT
