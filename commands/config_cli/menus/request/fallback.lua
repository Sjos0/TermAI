local models = require("models")
local validate = require("models.validate")
local M = {}

local function mask(key)
  if #key <= 4 then return string.rep("*", math.max(4, #key)) end
  return string.rep("*", #key - 4) .. key:sub(-4)
end

local function choose_provider(ui)
  local providers = models.list_providers()
  if #providers == 0 then io.write(ui.YL .. "  Nenhum provedor cadastrado.\n" .. ui.R); return nil end
  for i, provider in ipairs(providers) do
    io.write("  " .. i .. ". " .. provider.id .. " (" .. tostring(provider.key_count or 0) .. " chave(s))\n")
  end
  local index = tonumber(ui.rdl("Número do provedor (0 para voltar)"))
  return index and providers[index] and providers[index].id or nil
end

local function test_all(ui, provider_id)
  local keys, provider_models = models.list_api_keys(provider_id) or {}, models.list(provider_id)
  if #keys == 0 or #provider_models == 0 then
    io.write(ui.YL .. "  Adicione uma chave e um modelo antes de testar.\n" .. ui.R); return
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
    else ok, message = false, "Modelo não resolvido" end
    if type(message) == "string" and item.key ~= "" then
      message = message:gsub(item.key:gsub("([^%w])", "%%%1"), "[REDACTED]")
    end
    io.write("  Chave " .. i .. " (" .. mask(item.key) .. "): "
      .. (ok and ui.G .. "OK" or ui.RE .. "FALHOU") .. ui.R
      .. (not ok and (" — " .. tostring(message)) or "") .. "\n")
    models.record_api_key(provider_id, i, ok)
    if not ok then invalid[#invalid + 1] = i end
  end
  if previous then models.set_active_api_key(provider_id, previous) end
  if #invalid > 0 then
    io.write(ui.YL .. "  Sugestão: revise/remova as chaves inválidas (índices: "
      .. table.concat(invalid, ", ") .. "). Nada foi removido.\n" .. ui.R)
  end
end

local function manage_keys(ui)
  local provider_id = choose_provider(ui)
  if not provider_id then return end
  while true do
    local keys = models.list_api_keys(provider_id) or {}
    ui.hdr("Fallback › API Keys › " .. provider_id)
    for i, item in ipairs(keys) do
      local health = item.last_error_at and ("  [última falha: " .. item.last_error_at .. "]")
        or item.last_ok and ("  [último OK: " .. item.last_ok .. "]") or "  [sem teste]"
      io.write("  " .. i .. ". " .. mask(item.key)
        .. (item.active and "  [ATIVA]" or "") .. health .. "\n")
    end
    io.write("\n  1. Adicionar chave\n  2. Remover chave\n  3. Testar todas as chaves\n  4. Definir chave ativa\n  0. Voltar\n\n")
    local choice = ui.rdl("Escolha")
    if ui.cancel(choice) or choice == "0" then break end
    if choice == "1" then
      local key = ui.rdl("Nova API Key/Token (0 para cancelar)")
      if not ui.cancel(key) and key ~= "0" then
        local ok, err = models.add_api_key(provider_id, key)
        io.write(ok and ui.G .. "  [OK] Chave adicionada.\n" .. ui.R
          or ui.RE .. "  " .. tostring(err) .. "\n" .. ui.R)
      end
    elseif choice == "2" then
      local index = tonumber(ui.rdl("Índice da chave a remover"))
      if index then
        local ok, err = models.remove_api_key(provider_id, index)
        io.write(ok and ui.G .. "  [OK] Chave removida.\n" .. ui.R
          or ui.RE .. "  " .. tostring(err) .. "\n" .. ui.R)
      end
    elseif choice == "3" then test_all(ui, provider_id)
    elseif choice == "4" then
      local index = tonumber(ui.rdl("Índice da chave ativa"))
      if index then
        local ok, err = models.set_active_api_key(provider_id, index)
        io.write(ok and ui.G .. "  [OK] Chave ativa atualizada.\n" .. ui.R
          or ui.RE .. "  " .. tostring(err) .. "\n" .. ui.R)
      end
    end
    ui.pause()
  end
end

local manage_fallbacks = require("commands.config_cli.menus.request.fallback.models")

function M.run(config_mod, ui)
  models.load()
  while true do
    local cfg = ui.get_cfg()
    local req = cfg.agents.defaults.request or {}
    local fallbacks = cfg.agents.defaults.model.fallbacks or {}
    ui.hdr("Fallback unificado")
    ui.row("Limite por chave:", tostring(req.max_retries or 10) .. " tentativas (Max tentativas)")
    ui.row("Modelos fallback:", tostring(#fallbacks))
    ui.row("Transparência:", req.fallback_transparency == false and "desativada" or "ativada")
    io.write("\n  1. Gerenciar chaves por provedor\n  2. Gerenciar fallback de modelos/provedores\n  3. Alternar mensagens de rotação\n  0. Voltar\n\n")
    local choice = ui.rdl("Escolha")
    if ui.cancel(choice) or choice == "0" then break end
    if choice == "1" then manage_keys(ui)
    elseif choice == "2" then manage_fallbacks(config_mod, ui)
    elseif choice == "3" then
      config_mod.set("agents.defaults.request.fallback_transparency", req.fallback_transparency == false)
      io.write(ui.G .. "  [OK] Transparência atualizada.\n" .. ui.R)
    end
    ui.pause()
  end
end

return M
