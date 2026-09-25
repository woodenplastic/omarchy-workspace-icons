// Fallback icons for terminal programs that have no icon of their own: glyphs
// from the Nerd Font Omarchy installs (JetBrainsMono Nerd Font). The plugin
// ships only these code points; the artwork comes from the user's font.
.pragma library

// Programs with their own glyph in the font.
var brands = {
  git: 0xe702, lazygit: 0xe702, gitui: 0xe702, tig: 0xe702, gh: 0xe702,
  docker: 0xf308, lazydocker: 0xf308, podman: 0xf308, "docker-compose": 0xf308,
  node: 0xf0399, npm: 0xf0399, npx: 0xf0399, pnpm: 0xf0399, yarn: 0xf0399,
  python: 0xe73c, python3: 0xe73c, ipython: 0xe73c, pip: 0xe73c, pip3: 0xe73c, uv: 0xe73c, poetry: 0xe73c,
  cargo: 0xe7a8, rustc: 0xe7a8, rustup: 0xe7a8,
  go: 0xe627, gopls: 0xe627,
  lua: 0xe620, luajit: 0xe620,
  ruby: 0xe739, irb: 0xe739, bundle: 0xe739, rails: 0xe739,
  vim: 0xe62b, vi: 0xe62b, nvim: 0xf36f,
  emacs: 0xe632,
  java: 0xe738, javac: 0xe738, gradle: 0xe738, mvn: 0xe738,
  php: 0xe73d, composer: 0xe73d,
  kubectl: 0xf10fe, k9s: 0xf10fe, helm: 0xf10fe,
  pacman: 0xf303, yay: 0xf303, paru: 0xf303, makepkg: 0xf303
}

// Generic glyphs by kind of program, not anyone's logo.
var categories = [
  { glyph: 0xf06a9, programs: ["claude", "codex", "aider", "opencode", "gemini", "crush", "goose", "cursor-agent", "copilot", "amp", "qwen", "llm", "ollama"] }, // robot: AI agents
  { glyph: 0xf029a, programs: ["btop", "htop", "top", "gotop", "btm", "nvtop", "glances", "bpytop", "bashtop", "zenith", "atop"] }, // gauge: system monitors
  { glyph: 0xf024b, programs: ["yazi", "ranger", "lf", "nnn", "mc", "vifm", "superfile", "spf", "broot", "xplr"] }, // folder: file managers
  { glyph: 0xf075a, programs: ["cmus", "ncmpcpp", "spotify_player", "spt", "musikcube", "termusic", "mocp"] }, // music
  { glyph: 0xf01ee, programs: ["neomutt", "mutt", "aerc", "himalaya", "alpine"] }, // mail
  { glyph: 0xf01bc, programs: ["psql", "mysql", "mariadb", "sqlite3", "redis-cli", "mongosh", "usql", "pgcli", "mycli", "litecli", "duckdb"] }, // database
  { glyph: 0xf048b, programs: ["ssh", "mosh", "sftp", "et"] }, // server: remote shells
  { glyph: 0xf02d, programs: ["man", "info", "tldr", "tlrc"] }, // book: docs
  { glyph: 0xf0ad, programs: ["make", "cmake", "ninja", "meson", "just"] }, // wrench: build tools
  { glyph: 0xeb56, programs: ["tmux", "zellij", "screen", "herdr", "byobu"] }, // split pane: multiplexers
  { glyph: 0xf03eb, programs: ["nano", "micro", "hx", "helix", "kak", "ne", "joe"] }, // pencil: editors
  { glyph: 0xf01da, programs: ["curl", "wget", "yt-dlp", "aria2c"] }, // download
  { glyph: 0xf00ec, programs: ["bc", "qalc", "calc"] } // calculator
]

var byProgram = {}
for (var i = 0; i < categories.length; i++)
  for (var j = 0; j < categories[i].programs.length; j++)
    byProgram[categories[i].programs[j]] = categories[i].glyph
for (var name in brands) byProgram[name] = brands[name]

// The glyph for a program as a string, or "".
function forProgram(name) {
  var code = byProgram[String(name || "")]
  return code ? String.fromCodePoint(code) : ""
}
