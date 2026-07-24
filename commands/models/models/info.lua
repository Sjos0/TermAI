-- info.lua — Exibe detalhes completos de um modelo: provedor, endpoint, contexto, custo etc.
local ui = require("commands.models.ui")
local c  = ui.c
local M = {}

local function info(models_mod, ref)
  if not ref then
    ref = ui.prompt_read("Referência do modelo (0 para voltar)")
    if ui.is_cancel(ref) then return end
  end
  local resolved, err = models_mod.resolve(ref)
  if not resolved then
    io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
    return
  end
  ui.header("Detalhes do Modelo")
  local function row(label, val)
    io.write("  " .. c.gray .. label .. ":" .. c.reset)
    io.write(string.rep(" ", math.max(1, 14 - #label)))
    io.write(c.white .. tostring(val) .. c.reset .. "\n")
  end
  row("Referência",  resolved.ref)
  row("Nome",        resolved.name)
  row("Provedor",    resolved.provider)
  row("Endpoint",    resolved.endpoint)
  row("API Type",    resolved.api_type)
  row("Auth",        resolved.auth_style)
  row("Contexto",    ui.fmt_ctx(resolved.context_window))
  row("Max Tokens",  ui.fmt_ctx(resolved.max_tokens))
  row("Reasoning",   resolved.reasoning and "sim" or "não")
  row("Input",       table.concat(resolved.input, ", "))
  if resolved.cost then
    row("Custo Input",  "$" .. tostring(resolved.cost.input))
    row("Custo Output", "$" .. tostring(resolved.cost.output))
  end
  io.write("\n")
end

M.info = info
return M
