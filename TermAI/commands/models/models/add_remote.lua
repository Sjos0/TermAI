-- add_remote.lua — Fluxo assistido: lista modelos remotos de um provider (se
-- suportado via fetch_remote_models) e monta o model_data pré-preenchido.
-- Se a busca falhar ou o usuário escolher "Outro", cai pro fluxo manual.
local ui = require("commands.models.ui")
local c  = ui.c

local M = {}

-- Retorna:
--   table  -> model_data pronto para add_model()
--   nil    -> cair no fluxo manual (fetch falhou ou usuário escolheu "Outro")
--   false  -> usuário cancelou, abortar o add() inteiro
function M.pick(provider_mod, provider_id)
  local list, err = provider_mod.fetch_remote_models()
  if not list then
    io.write(c.yellow .. "  Lista remota indisponível (" .. tostring(err)
      .. "). Modo manual.\n" .. c.reset)
    return nil
  end

  io.write("\n" .. c.gray .. "  Modelos disponíveis em " .. provider_id .. ":\n" .. c.reset)
  for i, m in ipairs(list) do
    local curated = provider_mod.find_curated and provider_mod.find_curated(m.id)
    local tag = curated and (c.green .. " ✓" .. c.reset) or ""
    io.write("  " .. c.white .. i .. ". " .. c.reset .. m.id .. tag .. "\n")
  end
  local outro_n = #list + 1
  io.write("  " .. c.white .. outro_n .. ". " .. c.reset .. c.gray .. "Outro (ID manual)\n" .. c.reset)
  io.write("\n")

  local ch = ui.prompt_read("Número do modelo (0 para cancelar)")
  if ui.is_cancel(ch) then return false end
  local idx = tonumber(ch)
  if not idx or idx < 1 or idx > outro_n then
    io.write(c.red .. "  Opção inválida.\n" .. c.reset)
    return false
  end
  if idx == outro_n then return nil end -- "Outro" -> fluxo manual

  local picked = list[idx]
  local curated = provider_mod.find_curated and provider_mod.find_curated(picked.id)

  local default_name = curated and curated.name or picked.id
  local name = ui.prompt_read("Nome de exibição (Enter = " .. default_name .. ")")
  if name == nil then return false end
  if name == "" then name = default_name end

  local default_ctx = curated and curated.contextWindow or 200000
  local ctx_str = ui.prompt_read("Context window em tokens (Enter = " .. ui.fmt_ctx(default_ctx) .. ")")
  if ctx_str == nil then return false end
  local ctx = (ctx_str ~= "" and tonumber(ctx_str)) or default_ctx

  local default_max = curated and curated.maxTokens or 4096
  local max_str = ui.prompt_read("Max tokens de saída (Enter = " .. tostring(default_max) .. ")")
  if max_str == nil then return false end
  local max_tok = (max_str ~= "" and tonumber(max_str)) or default_max

  local default_reason = false
  if curated and curated.reasoning then default_reason = true end
  local reason_str = ui.prompt_read("Possui Reasoning nativo? (s/n) (Enter = "
    .. (default_reason and "s" or "n") .. ")")
  if reason_str == nil then return false end
  local reasoning = default_reason
  if reason_str ~= "" then
    reasoning = reason_str:lower() == "s" or reason_str:lower() == "y"
  end

  return {
    id            = picked.id,
    name          = name,
    reasoning     = reasoning,
    input         = {"text"},
    cost          = (curated and curated.cost) or {input=0, output=0, cacheRead=0, cacheWrite=0},
    contextWindow = ctx,
    maxTokens     = max_tok,
  }
end

return M
