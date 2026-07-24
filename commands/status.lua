local json = require("json")
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"

local c = {
  reset = "\27[0m", bold = "\27[1m", dim = "\27[2m",
  green = "\27[38;5;114m", yellow = "\27[38;5;220m",
  red = "\27[38;5;203m", cyan = "\27[38;5;80m",
  gray = "\27[38;5;245m",
}

local function check(label, path, is_dir)
  local exists
  if is_dir then
    local h = io.popen("test -d '" .. path .. "' && echo ok 2>/dev/null")
    exists = h and h:read("*a"):match("ok")
    if h then h:close() end
  else
    exists = io.open(path, "r")
    if exists then exists:close() end
  end
  local icon = exists and (c.green .. "✓") or (c.red .. "✗")
  io.write("  " .. icon .. " " .. c.reset .. label .. "\n")
end

io.write("\n")
io.write(c.bold .. c.cyan .. "  TermAI — Status do Sistema" .. c.reset .. "\n")
io.write(c.gray .. "  " .. string.rep("─", 35) .. c.reset .. "\n\n")

-- Config
io.write(c.bold .. "  Configuração:" .. c.reset .. "\n")
check("config.json",         HOME .. "/.TermAI/config.json")
check("workspace/",          HOME .. "/.TermAI/workspace", true)
check("memory/",             HOME .. "/.TermAI/workspace/memory", true)
check("SOUL.md",             HOME .. "/.TermAI/workspace/SOUL.md")
check("IDENTITY.md",         HOME .. "/.TermAI/workspace/IDENTITY.md")
check("MEMORY.md",           HOME .. "/.TermAI/workspace/MEMORY.md")
check("USER.md",             HOME .. "/.TermAI/workspace/USER.md")
io.write("\n")

-- Módulos
io.write(c.bold .. "  Módulos:" .. c.reset .. "\n")
local modules = {
  "agente.lua", "editor.lua", "json.lua", "memoryflush.lua",
  "prompt.lua", "renderer.lua", "tools.lua", "ui.lua",
}
for _, mod in ipairs(modules) do
  check(mod, HOME .. "/TermAI/" .. mod)
end
io.write("\n")

-- UI
io.write(c.bold .. "  Interface:" .. c.reset .. "\n")
local ui_modules = {
  "core.lua", "header.lua", "messages.lua",
  "tools.lua", "spinner.lua", "stream.lua", "misc.lua",
}
for _, mod in ipairs(ui_modules) do
  check("ui/" .. mod, HOME .. "/TermAI/ui/" .. mod)
end
io.write("\n")

-- Config info
local f = io.open(HOME .. "/.TermAI/config.json", "r")
if f then
  local ok, cfg = pcall(json.decode, f:read("*a"))
  f:close()
  if ok and cfg then
    io.write(c.bold .. "  API:" .. c.reset .. "\n")
    io.write("  " .. c.gray .. "modelo :" .. c.reset .. " " .. (cfg.modelo or "?") .. "\n")
    io.write("  " .. c.gray .. "endpoint:" .. c.reset .. " " .. (cfg.endpoint or "?") .. "\n")
    io.write("  " .. c.gray .. "max_ctx :" .. c.reset .. " " .. (cfg.max_contexto or "?") .. "\n")
    io.write("  " .. c.gray .. "max_tok :" .. c.reset .. " " .. (cfg.max_tokens or "?") .. "\n")
    if cfg.limites then
      io.write("  " .. c.gray .. "flush   :" .. c.reset .. " cada " .. (cfg.limites.flush_tokens or "?") .. " tokens\n")
      io.write("  " .. c.gray .. "compact :" .. c.reset .. " a " .. ((cfg.limites.compactacao_pct or 0.9) * 100) .. "% do contexto\n")
    end
    io.write("\n")
  end
else
  io.write(c.red .. "  ✗ config.json não encontrado ou inválido" .. c.reset .. "\n\n")
end

io.write(c.gray .. "  " .. string.rep("─", 35) .. c.reset .. "\n")
io.write("  Use " .. c.bold .. "TermAI tui" .. c.reset .. " para iniciar.\n\n")
