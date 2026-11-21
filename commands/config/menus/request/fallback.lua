local ui = require("commands.models.ui")
local models = require("models")
local validate = require("models.validate")
local saver = require("commands.config.menus.request.saver")
local c = ui.c
local M = {}
local health = require("commands.config.fallback_health")

local function mask(key)
  if #key <= 4 then return string.rep("*", math.max(4, #key)) end
  return string.rep("*", #key - 4) .. key:sub(-4)
end

local function choose_provider()
  local providers = models.list_providers()
  if #providers == 0 then io.write(c.yellow .. "  Nenhum provedor cadastrado.\n" .. c.reset); return nil end
  ui.header("Provedor para gerenciar chaves")
  for i, provider in ipairs(providers) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. provider.id
      .. c.gray .. " (" .. tostring(provider.key_count or 0) .. " chave(s))\n" .. c.reset)
  end
  local choice = ui.prompt_read("Número do provedor (0 para voltar)")
  local index = tonumber(choice)
  return index and providers[index] and providers[index].id or nil
end

local function test_all(provider_id)
  local keys = models.list_api_keys(provider_id) or {}
  local provider_models = models.list(provider_id)
  if #keys == 0 or #provider_models == 0 then
    io.write(c.yellow .. "  Adicione ao menos uma chave e um modelo para testar.\n" .. c.reset)
    return
  end
  local _, previous = models.active_api_key(provider_id)
  local invalid = {}
  local active_ref = models.get_active()
  local active_is_valid = false
  for _, item in ipairs(provider_models) do
    if item.ref == active_ref then active_is_valid = true; break end
  end
  if not active_is_valid then active_ref = provider_models[1].ref end
  for i, item in ipairs(keys) do
    models.set_active_api_key(provider_id, i)
    local active = models.resolve(active_ref)
    local ok, message
    if active then
      local called, result, detail = pcall(validate.test_connection, active)
      ok, message = called and result or false, called and detail or result
    else ok, message = false, "Não foi possível resolver o modelo" end
    message = health.error_message(message, item.key)
    io.write("  Chave " .. i .. " (" .. mask(item.key) .. "): "
      .. (ok and c.green .. "OK" or c.red .. "FALHOU") .. c.reset
      .. (not ok and (" — " .. tostring(message)) or "") .. "\n")
    models.record_api_key(provider_id, i, ok)
    if not ok then invalid[#invalid + 1] = i end
  end
  if previous then models.set_active_api_key(provider_id, previous) end
  if #invalid > 0 then
    io.write(c.yellow .. "  Sugestão: revise/remova as chaves inválidas (índices: "
      .. table.concat(invalid, ", ") .. "). Nenhuma chave foi removida.\n" .. c.reset)
  end
end

local function manage_keys()
  local provider_id = choose_provider()
  if not provider_id then return end
  while true do
    local keys = models.list_api_keys(provider_id) or {}
    ui.header("API Keys › " .. provider_id)
    if #keys == 0 then io.write(c.gray .. "  Nenhuma chave cadastrada.\n" .. c.reset) end
    for i, item in ipairs(keys) do
      io.write("  " .. i .. ". " .. mask(item.key)
        .. (item.active and (c.green .. "  [ATIVA]" .. c.reset) or "")
        .. health.label(item) .. "\n")
    end
    io.write("\n  1. Adicionar chave\n  2. Remover chave\n  3. Testar todas as chaves\n  4. Definir chave ativa\n  0. Voltar\n\n")
    local choice = ui.prompt_read("Escolha")
    if ui.is_cancel(choice) or choice == "0" then break end
    if choice == "1" then
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
    elseif choice == "3" then
      test_all(provider_id)
    elseif choice == "4" then
      local index = tonumber(ui.prompt_read("Índice da chave ativa"))
      if index then
        local ok, err = models.set_active_api_key(provider_id, index)
        io.write(ok and (c.green .. "  [OK] Chave ativa atualizada.\n" .. c.reset)
          or (c.red .. "  " .. tostring(err) .. "\n" .. c.reset))
      end
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
    io.write("  1. Gerenciar chaves por provedor\n  2. Gerenciar fallback de modelos/provedores\n  3. Alternar mensagens de rotação\n  0. Voltar\n\n")
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
