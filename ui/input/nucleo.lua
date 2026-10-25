-- ui/input/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local core  = require("ui.core")
  local c     = core.c
  local width = require("ui.input.unicode_width")
  local seg   = require("ui.input.segments")
  local tread = require("ui.input.terminal_read")

  local N = {}
  N.core = core
  N.c = c
  N.width = width
  N.seg = seg
  N.tread = tread
  return N
end
