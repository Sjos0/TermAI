-- commands/models/models/edit.lua — Editor interativo de um modelo já
-- cadastrado. Mostra os campos editáveis, deixa escolher qual mudar, e
-- persiste em models.json via models_mod.update_model (não em config.json —
-- config.json guarda preferências do agente, models.json guarda modelos).
local ui = require("commands.models.ui")
local c  = ui.c
local M = {}

local STYLES = {"openrouter", "reasoning_effort", "chat_template_kwargs", "thinking_tags"}

-- Cada campo devolve uma tabela de updates (ou nil se cancelado/inválido).
local FIELDS = {}

FIELDS["1"] = function(resolved)
  local v = ui.prompt_read("Novo nome (Enter = manter '" .. resolved.name .. "')")
  if not v or v == "" then return nil end
  return { name = v }
end

FIELDS["2"] = function(resolved)
  local v = ui.prompt_read("Novo ID (cuidado: é a chave de busca do modelo)")
  if not v or v == "" then return nil end
  return { id = v }
end

FIELDS["3"] = function(resolved)
  local v = ui.prompt_read("Novo context window em tokens (atual: " .. ui.fmt_ctx(resolved.context_window) .. ")")
  local n = tonumber(v)
  if not n or n <= 0 then return nil end
  return { contextWindow = n }
end

FIELDS["4"] = function(resolved)
  local v = ui.prompt_read("Novo max tokens de saída (atual: " .. ui.fmt_ctx(resolved.max_tokens) .. ")")
  local n = tonumber(v)
  if not n or n <= 0 then return nil end
  return { maxTokens = n }
end

FIELDS["5"] = function(resolved)
  local v = ui.prompt_read("Possui Reasoning nativo? (s/n)")
  if v == "s" or v == "S" then return { reasoning = true } end
  if v == "n" or v == "N" then return { reasoning = false } end
  io.write(c.red .. "  ❌ Digite exatamente 's' ou 'n'.\n" .. c.reset)
  return nil
end

FIELDS["6"] = function(resolved)
  io.write("\n")
  for i, s in ipairs(STYLES) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. s .. "\n")
  end
  io.write("  " .. c.white .. "0. " .. c.reset .. "Cancelar\n\n")
  local ch = ui.prompt_read("Escolha")
  local idx = tonumber(ch)
  if not idx or not STYLES[idx] then return nil end
  return { reasoning_style = STYLES[idx] }
end

FIELDS["7"] = function(resolved)
  local v = ui.prompt_read("Default effort (ex: high, low, no_think, medium)")
  if not v or v == "" then return nil end
  return { default_effort = v }
end

local function print_fields(resolved, model_id)
  io.write("  " .. c.gray .. "1. Nome:            " .. c.reset .. resolved.name .. "\n")
  io.write("  " .. c.gray .. "2. ID:              " .. c.reset .. model_id .. "\n")
  io.write("  " .. c.gray .. "3. Context Window:  " .. c.reset .. ui.fmt_ctx(resolved.context_window) .. "\n")
  io.write("  " .. c.gray .. "4. Max Tokens:      " .. c.reset .. ui.fmt_ctx(resolved.max_tokens) .. "\n")
  io.write("  " .. c.gray .. "5. Reasoning:       " .. c.reset .. (resolved.reasoning and "sim" or "não") .. "\n")
  io.write("  " .. c.gray .. "6. Reasoning Style: " .. c.reset .. (resolved.reasoning_style or "-") .. "\n")
  io.write("  " .. c.gray .. "7. Default Effort:  " .. c.reset .. (resolved.default_effort or "-") .. "\n")
  io.write("  " .. c.white .. "0." .. c.reset .. " Voltar\n\n")
end

function M.edit(models_mod, ref)
  if not ref then
    ref = ui.prompt_read("Referência do modelo pra editar (0 para voltar)")
    if ui.is_cancel(ref) then return end
  end
  local provider_id, model_id = ref:match("^([^/]+)/(.+)$")
  if not provider_id then
    io.write(c.red .. "  Referência inválida.\n" .. c.reset)
    return
  end

  while true do
    local resolved, err = models_mod.resolve(provider_id .. "/" .. model_id)
    if not resolved then
      io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
      return
    end

    io.write("\27[2J\27[H"); io.flush()
    ui.header("Editar Modelo: " .. provider_id .. "/" .. model_id)
    print_fields(resolved, model_id)

    local ch = ui.prompt_read("Escolha o campo (0 pra voltar)")
    if ui.is_cancel(ch) then break end

    local handler = FIELDS[ch]
    if not handler then
      io.write(c.red .. "  Opção inválida.\n" .. c.reset)
      ui.pause()
    else
      local updates = handler(resolved)
      if updates then
        local ok, e = models_mod.update_model(provider_id, model_id, updates)
        if ok then
          io.write(c.green .. "\n  ✅ Salvo.\n" .. c.reset)
          if updates.id then model_id = updates.id end
        else
          io.write(c.red .. "\n  ❌ " .. tostring(e) .. "\n" .. c.reset)
        end
        ui.pause()
      end
    end
  end
end

return M
