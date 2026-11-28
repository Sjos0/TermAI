local models = require("models")
local M = {}
local keys = require("commands.config.fallback_keys")
local keys_view = require("commands.config.fallback_keys_view")
local core = require("ui.core")

local function choose_provider(ui)
  local providers = models.list_providers()
  if #providers == 0 then io.write(ui.YL .. "  Nenhum provedor cadastrado.\n" .. ui.R); return nil end
  for i, provider in ipairs(providers) do
    io.write("  " .. i .. ". " .. provider.id .. " (" .. tostring(provider.key_count or 0) .. " chave(s))\n")
  end
  local index = tonumber(ui.rdl("Número do provedor (0 para voltar)"))
  return index and providers[index] and providers[index].id or nil
end

local function test_one(ui, provider_id)
  local index = tonumber(ui.rdl("Índice da chave a testar"))
  if not index then return end
  local ok, message = keys.test_key(provider_id, index)
  io.write("  Chave " .. index .. ": " .. (ok and ui.G .. "OK" or ui.RE .. "FALHOU") .. ui.R
    .. (not ok and (" — " .. tostring(message)) or "") .. "\n")
end

local function test_all(ui, provider_id)
  local results, invalid = keys.test_all(provider_id)
  if not results then
    io.write(ui.YL .. "  " .. tostring(invalid) .. "\n" .. ui.R)
    return
  end
  for _, item in ipairs(results) do
    io.write("  Chave " .. item.index .. " (" .. item.masked .. "): "
      .. (item.ok and ui.G .. "OK" or ui.RE .. "FALHOU") .. ui.R
      .. (not item.ok and (" — " .. tostring(item.message)) or "") .. "\n")
  end
  if #invalid > 0 then
    io.write(ui.YL .. "  Revise as chaves inválidas (índices: "
      .. table.concat(invalid, ", ") .. "). Nenhuma chave foi removida.\n" .. ui.R)
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

local function dashboard(ui, provider_id)
  ui.hdr("Saúde das API Keys › " .. provider_id)
  local rows = keys.dashboard(provider_id)
  if #rows == 0 then io.write(ui.YL .. "  Nenhuma chave cadastrada.\n" .. ui.R); return end
  render_health_rows(rows)
  io.write("\n  O teste individual e o teste geral não alteram a chave ativa.\n")
end

local function manage_keys(ui, provider_id)
  while true do
    local items = models.list_api_keys(provider_id) or {}
    ui.hdr("Fallback › API Keys › " .. provider_id)
    if #items == 0 then io.write(ui.YL .. "  Nenhuma chave cadastrada.\n" .. ui.R) end
    local key_rows = keys.dashboard(provider_id)
    for _, item in ipairs(key_rows) do
      item.state = item.state == "OK" and ui.G .. item.state .. ui.R
        or item.state == "FALHA" and ui.RE .. item.state .. ui.R
        or ui.YL .. item.state .. ui.R
    end
    render_health_rows(key_rows)
    io.write("\n  1. Adicionar chave\n  2. Remover chave\n"
      .. "  3. Testar uma chave\n  4. Testar todas as chaves\n"
      .. "  5. Definir chave ativa\n  6. Painel de saúde\n  0. Voltar\n\n")
    local choice = ui.rdl("Escolha")
    if ui.cancel(choice) or choice == "0" then break
    elseif choice == "1" then
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
    elseif choice == "3" then test_one(ui, provider_id)
    elseif choice == "4" then test_all(ui, provider_id)
    elseif choice == "5" then
      local index = tonumber(ui.rdl("Índice da chave ativa"))
      if index then
        local ok, err = models.set_active_api_key(provider_id, index)
        io.write(ok and ui.G .. "  [OK] Chave ativa atualizada.\n" .. ui.R
          or ui.RE .. "  " .. tostring(err) .. "\n" .. ui.R)
      end
    elseif choice == "6" then dashboard(ui, provider_id)
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
    local model_cfg = cfg.agents.defaults.model or {}
    local fallbacks = model_cfg.fallbacks or {}
    ui.hdr("Fallback unificado")
    ui.row("Limite por chave:", tostring(req.max_retries or 10) .. " tentativas (Max tentativas)")
    ui.row("Modelos fallback:", tostring(#fallbacks))
    ui.row("Transparência:", req.fallback_transparency == false and "desativada" or "ativada")
    io.write("\n  1. Gerenciar chaves por provedor\n  2. Gerenciar fallback de modelos/provedores\n"
      .. "  3. Alternar mensagens de rotação\n  0. Voltar\n\n")
    local choice = ui.rdl("Escolha")
    if ui.cancel(choice) or choice == "0" then break end
    if choice == "1" then
      local provider_id = choose_provider(ui)
      if provider_id then manage_keys(ui, provider_id) end
    elseif choice == "2" then manage_fallbacks(config_mod, ui)
    elseif choice == "3" then
      config_mod.set("agents.defaults.request.fallback_transparency", req.fallback_transparency == false)
      io.write(ui.G .. "  [OK] Transparência atualizada.\n" .. ui.R)
    end
    ui.pause()
  end
end

return M
