-- update_key.lua — Atualiza a API key de um provedor existente e testa a conexão.
local ui = require("commands.models.ui")
local test_connection = require("commands.models.providers.test_connection")
local c  = ui.c
local M = {}

local function update_key(models_mod)
  local providers = models_mod.list_providers()
  if #providers == 0 then
    io.write(c.gray .. "  Nenhum provedor cadastrado.\n" .. c.reset)
    return
  end

  ui.header("Atualizar API Key")
  for i, p in ipairs(providers) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. p.id .. "\n")
  end
  io.write("\n")
  local ch = ui.prompt_read("Número do provedor (0 para voltar)")
  if ui.is_cancel(ch) then return end
  local idx = tonumber(ch)
  if not idx or idx < 1 or idx > #providers then
    io.write(c.red .. "  Opção inválida.\n" .. c.reset); return
  end

  local provider = providers[idx]
  if provider.id == "mimo" then
    io.write("\n" .. c.bold .. c.yellow .. "  Como obter seu Token Xiaomi MiMo Gratuito:" .. c.reset .. "\n")
    io.write("  1. Acesse no navegador: " .. c.cyan .. "https://platform.xiaomimimo.com" .. c.reset .. "\n")
    io.write("  2. Faça login com sua conta (Google/GitHub/E-mail)\n")
    io.write("  3. Vá em 'Configurações de Desenvolvedor' ou 'API Keys'\n")
    io.write("  4. Copie seu Token de Acesso (Bearer Token)\n\n")
  end

  local new_key = ui.prompt_read("Nova API Key/Token")
  if ui.is_cancel(new_key) or new_key == "" then
    io.write(c.gray .. "  Cancelado.\n" .. c.reset); return
  end

  local ok, err = models_mod.update_api_key(provider.id, new_key)
  if ok then
    io.write(c.green .. "  ✅ API Key/Token atualizada.\n" .. c.reset)
    test_connection.test_and_confirm(models_mod, provider.id)
  else
    io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
  end
  ui.pause()
end

M.update_key = update_key
return M
