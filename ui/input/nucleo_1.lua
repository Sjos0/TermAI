-- ui/input/nucleo_1.lua — helpers internos: is_empty.
return function(M)
  local P = require("ui.input.nucleo")(M)
  local seg = P.seg


  -- ── M.read ─────────────────────────────────────────────────────────────────
  -- Buffer vazio (nada digitado): só então é seguro acordar o orquestrador.
  local function is_empty(segs)
    return (seg.get_input(segs) or "") == ""
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.is_empty = is_empty
  return N
end
