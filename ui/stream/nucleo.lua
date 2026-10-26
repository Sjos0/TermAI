-- ui/stream/nucleo.lua — dependências, cores, estado do sink e tema de raciocínio do streaming.
local core    = require("ui.core")
local spinner = require("ui.spinner")
local state   = require("ui.stream.state")
local ansi    = require("ui.stream.ansi_helpers")
local box     = require("ui.stream.reasoning_box")
local c = core.c

local ESTADO = { sink = nil }

local function get_thinking_mode()
  local ok, config_mod = pcall(require, "config")
  if ok and config_mod then
    local ok_val, val = pcall(config_mod.get, "agents.defaults.thinking_mode")
    if ok_val and val then
      return val
    end
  end
  return "expanded"
end


return {
  core = core, spinner = spinner, state = state, ansi = ansi, box = box, c = c,
  ESTADO = ESTADO, get_thinking_mode = get_thinking_mode,
}
