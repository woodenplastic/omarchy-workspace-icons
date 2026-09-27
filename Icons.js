// Pure helpers for naming windows and ordering their icons. No QML types
// here, so the logic stays easy to follow and to test with plain JS.
.pragma library

// Window classes Chromium-family browsers give `--app=URL` windows:
// "chrome-discord.com__channels_@me-Default", "brave-app.hey.com__-Profile_1".
var browserAppClass = /^(?:google-)?(?:chrome|chromium|brave(?:-browser)?|msedge|microsoft-edge|vivaldi|helium|opera)-(.+?)__(.*)-[^-]+$/i

// { host, path } for a browser app window class, or null.
function browserApp(appId) {
  var match = String(appId || "").match(browserAppClass)
  if (!match) return null
  return { host: match[1].replace(/^www\./, "").toLowerCase(), path: match[2].toLowerCase() }
}

// Chrome's app-id class for installed web apps: "crx_<32 letters>".
function crxId(appId) {
  var match = String(appId || "").match(/^crx_([a-p]{32})$/)
  return match ? match[1] : ""
}

// Omarchy launches TUIs with class "org.omarchy.<binary>"; the binary names
// the program. "org.omarchy.agent" is an agent terminal, not a program.
function omarchyProgram(appId) {
  var match = String(appId || "").match(/^org\.omarchy\.([A-Za-z0-9_.+-]+)$/)
  if (!match || match[1] === "agent" || match[1] === "terminal") return ""
  return match[1]
}

// Names to look a window class up by, most specific first.
function nameVariants(appId) {
  var raw = String(appId || "")
  if (!raw) return []
  var names = []
  function add(name) { if (name && names.indexOf(name) === -1) names.push(name) }
  add(raw)
  add(raw.toLowerCase())
  var parts = raw.split(".")
  if (parts.length > 1) {
    add(parts[parts.length - 1])
    add(parts[parts.length - 1].toLowerCase())
  }
  add(raw.replace(/-bin$/, ""))
  return names
}

// Whether a desktop entry's StartupWMClass names this class, also as a run
// of whole dot-segments ("md.obsidian.Obsidian" for "obsidian").
function startupClassMatches(startupClass, appId) {
  var want = String(appId || "").toLowerCase()
  var have = String(startupClass || "").toLowerCase()
  if (!want || !have) return false
  if (want === have) return true
  var wantParts = want.split(".")
  var haveParts = have.split(".")
  for (var i = 0; i + wantParts.length <= haveParts.length; i++) {
    var same = true
    for (var j = 0; j < wantParts.length; j++) {
      if (haveParts[i + j] !== wantParts[j]) { same = false; break }
    }
    if (same) return true
  }
  return false
}

// Window titles are app-controlled: drop control and bidi-override
// characters and cap the length.
function cleanTitle(title, limit) {
  var text = String(title || "").replace(/[\u0000-\u001f\u007f-\u009f‪-‮⁦-⁩]/g, " ").replace(/\s+/g, " ").trim()
  var max = limit || 80
  return text.length > max ? text.substring(0, max - 1) + "…" : text
}

// "Inbox - Mail - Google Chrome" -> "Inbox - Mail" when the app is named.
function stripAppSuffix(title, appName) {
  var text = String(title || "")
  var name = String(appName || "")
  if (!name) return text
  var separators = [" - ", " — ", " – ", " | "]
  for (var i = 0; i < separators.length; i++) {
    var suffix = separators[i] + name
    if (text.length > suffix.length && text.substring(text.length - suffix.length).toLowerCase() === suffix.toLowerCase())
      return text.substring(0, text.length - suffix.length)
  }
  return text
}

// Sort key that puts windows in on-screen order: left to right, then top to
// bottom (or top to bottom first on vertical bars).
function spatialCompare(a, b, vertical) {
  var ax = a.x || 0, ay = a.y || 0, bx = b.x || 0, by = b.y || 0
  if (vertical) return ay - by || ax - bx
  return ax - bx || ay - by
}

// Escapes a string for a double-quoted Lua literal.
function luaString(value) {
  var text = String(value)
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var c = text.charAt(i)
    var code = text.charCodeAt(i)
    if (c === "\\" || c === "\"") out += "\\" + c
    else if (code < 32 || code === 127) out += "\\" + ("00" + code).slice(-3)
    else out += c
  }
  return "\"" + out + "\""
}

// A letter for an app with no loadable icon.
function monogram(name) {
  var text = String(name || "").replace(/^org\.|^com\.|^io\./, "")
  var parts = text.split(/[.\-_\s]+/).filter(function(p) { return p.length > 0 })
  var word = parts.length > 0 ? parts[parts.length - 1] : text
  return word ? word.charAt(0).toUpperCase() : "?"
}
