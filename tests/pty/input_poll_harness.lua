-- tests/pty/input_poll_harness.lua — Harness do teste de pseudo-terminal para ui/input.lua (polling).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local input = require("ui.input")
local mode = arg[1] or "type"

local ticks = 0
local r = { input.read({ on_idle = function(buffer_empty)
  ticks = ticks + 1
  if mode == "wake"    then return buffer_empty and ticks >= 2 end   -- só acorda com buffer vazio
  if mode == "partial" then return true end                          -- pede acordar mesmo com texto
  return false
end }) }
io.write("\nRESULT=" .. tostring(r[1]) .. "|" .. tostring(r[4] == true) .. "|ticks=" .. tostring(ticks) .. "\n")
