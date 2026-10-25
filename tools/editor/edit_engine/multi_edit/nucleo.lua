-- tools/editor/edit_engine/multi_edit/nucleo.lua — cabeçalho (requires e constantes) do módulo.
return function(M)
  local norm = require("tools.editor.normalizer")
  local val = require("tools.editor.validator")
  local matcher = require("tools.editor.edit_engine.matcher")
  local recovery = require("tools.editor.edit_engine.recovery")

  local N = {}
  N.norm = norm
  N.val = val
  N.matcher = matcher
  N.recovery = recovery
  return N
end
