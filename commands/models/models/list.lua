-- list.lua — Lista todos os provedores e seus modelos, marcando o modelo ativo.
local ui = require("commands.models.ui")
local c  = ui.c
local M = {}

local function list(models_mod, active)
  ui.header("Modelos Disponíveis")
  local providers = models_mod.list_providers()
  if #providers == 0 then
    io.write(c.gray .. "  Nenhum provedor cadastrado.\n" .. c.reset)
    io.write(c.gray .. "  Use a opção 6 do menu para adicionar.\n\n" .. c.reset)
    return
  end
  for _, prov in ipairs(providers) do
    io.write(c.bold .. "  " .. prov.id .. c.reset
      .. c.gray .. " (" .. prov.base_url .. ")"
      .. " — " .. prov.model_count .. " modelo(s)" .. c.reset .. "\n")
    local models = models_mod.list(prov.id)
    for _, m in ipairs(models) do
      local is_active = (m.ref == active)
      local marker    = is_active and (c.green .. "★ ") or "  "
      local name_col  = is_active and c.bold or c.dim
      local flags     = ""
      if m.reasoning then flags = flags .. " " .. c.orange .. "[reasoning]" end
      for _, inp in ipairs(m.input or {}) do
        if inp == "image" then flags = flags .. " " .. c.blue .. "[vision]" end
      end
      io.write("  " .. marker .. c.reset .. name_col .. m.ref .. c.reset)
      io.write(c.gray .. "  " .. ui.fmt_ctx(m.context_window) .. flags .. c.reset .. "\n")
    end
    io.write("\n")
  end
  io.write(c.gray .. "  ★ = modelo ativo\n\n" .. c.reset)
end

M.list = list
return M
