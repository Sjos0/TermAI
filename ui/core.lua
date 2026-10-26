-- ui/core.lua — fachada do núcleo de UI: raiz, cores e os módulos terminal/texto.
local core = {}

-- ── Root do projeto ────────────────────────────────────────────────────────
core.ROOT = (os.getenv("HOME") or "/data/data/com.termux/files/home") .. "/TermAI"

-- ── Cores ──────────────────────────────────────────────────────────────────
core.c = {
  reset="\27[0m", bold="\27[1m", dim="\27[2m",
  white="\27[38;5;255m", gray="\27[38;5;245m",
  green="\27[38;5;114m", yellow="\27[38;5;220m", red="\27[38;5;203m",
  cyan="\27[38;5;80m", orange="\27[38;5;208m", blue="\27[38;5;39m",
  bg="\27[48;5;234m", bg_user="\27[48;5;236m",
  clear="\27[K", cls="\27[2J\27[H"
}

require("ui.core.terminal")(core)
require("ui.core.texto")(core)

return core
