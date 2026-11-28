local ui = require("commands.models.ui")
local models = require("models")
local c = ui.c
local M = {}
local keys = require("commands.config.fallback_keys")
local keys_view = require("commands.config.fallback_keys_view")
local core = require("ui.core")
local saver = require("commands.config.menus.request.saver")

local function choose_provider()
  local providers = models.list_providers()
  if #providers == 0 then
    io.write(c.yellow .. "  Nenhum provedor cadastrado.\n" .. c.reset)
    return nil
  end
  ui.header("Provedor para gerenciar chaves")
  for i, provider in ipairs(providers) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. provider.id
      .. c.gray .. " (" .. tostring(provider.key_count or 0) .. " chave(s))\n" .. c.reset)
  end
  local index = tonumber(ui.prompt_read("Número do provedor (0 para voltar)"))
  return index and providers[index] and providers[index].id or nil
end

local function test_one(provider_id)
  local index = tonumber(ui.prompt_read("Índice da chave a testar"))
  if not index then return end
  local ok, message = keys.test_key(provider_id, index)
  io.write("  Chave " .. index .. ": "
    .. (ok and c.green .. "OK" or c.red .. "FALHOU") .. c.reset
    .. (not ok and (" — " .. tostring(message)) or "") .. "\n")
end

local function test_all(provider_id)
  local results, invalid = keys.test_all(provider_id)
  if not results then
    io.write(c.yellow .. "  " .. tostring(invalid) .. "\n" .. c.reset)
    return
  end
  for _, item in ipairs(results) do
    io.write("  Chave " .. item.index .. " (" .. item.masked .. "): "
      .. (item.ok and c.green .. "OK" or c.red .. "FALHOU") .. c.reset
      .. (not item.ok and (" — " .. tostring(item.message)) or "") .. "\n")
  end
  if #invalid > 0 then
    io.write(c.yellow .. "  Revise as chaves inválidas (índices: "
      .. table.concat(invalid, ", ") .. "). Nenhuma chave foi removida.\n" .. c.reset)
  end
end

local function render_health_rows(rows, width)
  for _, row in ipairs(rows) do
    io.write(string.format("  %d. %s  %s%s\n",
      row.index, row.masked, row.state, row.active and " [ATIVA]" or ""))
    for _, line in ipairs(keys_view.format_last(row.last, width or core.tw())) do
      io.write(line .. "\n")
    end
  end
end

M.render_health_rows = render_health_rows

local function dashboard(provider_id)
  ui.header("Saúde das API Keys › " .. provider_id)
  local rows = keys.dashboard(provider_id)
  if #rows == 0 then
    io.write(c.gray .. "  Nenhuma chave cadastrada.\n" .. c.reset)
    return
  end
  render_health_rows(rows)
  io.write("\n  O teste individual e o teste geral não alteram a chave ativa.\n")
end

local function manage_keys()
  local provider_id = choose_provider()
  if not provider_id then return end
  while true do
    local items = models.list_api_keys(provider_id) or {}
    ui.header("API Keys › " .. provider_id)
    if #items == 0 then io.write(c.gray .. "  Nenhuma chave cadastrada.\n" .. c.reset) end
    local key_rows = keys.dashboard(provider_id)
    for _, item in ipairs(key_rows) do
      item.state = item.state == "OK" and c.green .. item.state .. c.reset
        or item.state == "FALHA" and c.red .. item.state .. c.reset
        or c.yellow .. item.state .. c.reset
    end
    render_health_rows(key_rows)
    io.write("\n  1. Adicionar chave\n  2. Remover chave\n"
      .. "  3. Testar uma chave\n  4. Testar todas as chaves\n"
      .. "  5. Definir chave ativa\n  6. Painel de saúde\n  0. Voltar\n\n")
    local choice = ui.prompt_read("Escolha")
    if ui.is_cancel(choice) or choice == "0" then break
    elseif choice == "1" then
      local key = ui.prompt_read("Nova API Key/Token (0 para cancelar)")
      if not ui.is_cancel(key) and key ~= "0" then
        local ok, err = models.add_api_key(provider_id, key)
        io.write(ok and (c.green .. "  [OK] Chave adicionada.\n" .. c.reset)
          or (c.red .. "  " .. tostring(err) .. "\n" .. c.reset))
      end
    elseif choice == "2" then
      local index = tonumber(ui.prompt_read("Índice da chave a remover"))
      if index then
        local ok, err = models.remove_api_key(provider_id, index)
        io.write(ok and (c.green .. "  [OK] Chave removida.\n" .. c.reset)
          or (c.red .. "  " .. tostring(err) .. "\n" .. c.reset))
      end
    elseif choice == "3" then test_one(provider_id)
    elseif choice == "4" then test_all(provider_id)
    elseif choice == "5" then
      local index = tonumber(ui.prompt_read("Índice da chave ativa"))
      if index then
        local ok, err = models.set_active_api_key(provider_id, index)
        io.write(ok and (c.green .. "  [OK] Chave ativa atualizada.\n" .. c.reset)
          or (c.red .. "  " .. tostring(err) .. "\n" .. c.reset))
      end
    elseif choice == "6" then dashboard(provider_id)
    end
    ui.pause()
  end
end

local manage_model_fallbacks = require("commands.config.menus.request.fallback.models")

function M.run(ctx)
  while true do
    local req = ctx.cfg.agents.defaults.request or {}
    local model_cfg = ctx.cfg.agents.defaults.model or {}
    ui.header("Fallback unificado")
    io.write("  Chaves: provedor ativo / múltiplas chaves\n")
    io.write("  Limite por chave: " .. tostring(req.max_retries or 10)
      .. " tentativas (usa Max tentativas de Requisições)\n")
    io.write("  Modelos fallback: " .. tostring(#(model_cfg.fallbacks or {})) .. "\n")
    io.write("  Transparência: " .. (req.fallback_transparency == false and "desativada" or "ativada") .. "\n\n")
    io.write("  1. Gerenciar chaves por provedor\n  2. Gerenciar fallback de modelos/provedores\n"
      .. "  3. Alternar mensagens de rotação\n  0. Voltar\n\n")
    local choice = ui.prompt_read("Escolha")
    if ui.is_cancel(choice) or choice == "0" then break end
    if choice == "1" then manage_keys()
    elseif choice == "2" then manage_model_fallbacks(ctx)
    elseif choice == "3" then
      saver.save_req(ctx, "fallback_transparency", req.fallback_transparency == false)
      io.write(c.green .. "  [OK] Transparência atualizada.\n" .. c.reset)
    end
    ui.pause()
  end
end

return M
