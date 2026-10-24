local ui = {}

local header     = require("ui.header")
local messages   = require("ui.messages")
local tools_init = require("ui.tools_init")
local spinner    = require("ui.spinner")
local stream     = require("ui.stream")
local misc       = require("ui.misc")

local modules = { header, messages, tools_init, spinner, stream, misc }
for _, mod in ipairs(modules) do
  for k, v in pairs(mod) do
    ui[k] = v
  end
end

return ui
