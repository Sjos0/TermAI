-- add.lua — Adiciona um modelo a um provedor existente, com validação pós-adição.
local ui         = require("commands.models.ui")
local validate    = require("models.validate")
local add_remote  = require("commands.models.models.add_remote")
local c          = ui.c
local M = {}
local function add(models_mod)
  local providers = models_mod.list_providers()
  if #providers == 0 then
    io.write(c.red .. "  Nenhum provedor cadastrado. Use a opção 6.\n" .. c.reset)
    return
  end
  io.write("\n" .. c.bold .. c.cyan .. "  Adicionar Modelo" .. c.reset .. "\n")
  io.write(c.gray .. "  " .. string.rep("─", 45) .. c.reset .. "\n\n")
  io.write(c.gray .. "  Provedores disponíveis:\n" .. c.reset)
  for i, p in ipairs(providers) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. p.id
      .. c.gray .. " (" .. p.model_count .. " modelos)\n" .. c.reset)
  end
  io.write("\n")
  local ch = ui.prompt_read("Número do provedor (0 para voltar)")
  if ui.is_cancel(ch) then return end
  local idx = tonumber(ch)
  if not idx or idx < 1 or idx > #providers then
    io.write(c.red .. "  Opção inválida.\n" .. c.reset); return
  end
  local provider_id = providers[idx].id

  -- ── Tenta fluxo assistido (lista remota) se o provider suportar ───────
  local model_data
  local ok_req, provider_mod = pcall(require, "providers." .. provider_id)
  if ok_req and provider_mod and provider_mod.fetch_remote_models then
    local picked = add_remote.pick(provider_mod, provider_id)
    if picked == false then return end     -- cancelado pelo usuário
    if picked then model_data = picked end -- escolhido da lista remota
    -- picked == nil -> cai no fluxo manual abaixo ("Outro" ou fetch falhou)
  end

  -- ── Fluxo manual (padrão original) ────────────────────────────────────
  if not model_data then
    local model_id = ui.prompt_read("ID do modelo (0 para voltar)")
    if ui.is_cancel(model_id) then return end
    local name = ui.prompt_read("Nome de exibição (Enter = usar ID)")
    local ctx_str = ui.prompt_read("Context window em tokens (ex: 131072)")
    if ui.is_cancel(ctx_str) then return end
    local max_str = ui.prompt_read("Max tokens de saída (ex: 4096)")
    if ui.is_cancel(max_str) then return end
    local reason_str = ui.prompt_read("Possui Reasoning nativo? (s/n)")
    if ui.is_cancel(reason_str) then return end
    model_data = {
      id            = model_id,
      name          = (name and name ~= "") and name or model_id,
      reasoning     = reason_str:lower() == "s" or reason_str:lower() == "y",
      input         = {"text"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = tonumber(ctx_str) or 200000,
      maxTokens     = tonumber(max_str) or 4096,
    }
  end

  local model_id = model_data.id
  local ok, err = models_mod.add_model(provider_id, model_data)
  if not ok then
    io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
    return
  end
  local full_ref = provider_id .. "/" .. model_id
  io.write(c.green .. "  ✅ Modelo adicionado: " .. full_ref .. c.reset .. "\n")
  -- ── Validação pós-adição (igual à validação de provedores) ────────────
  local resolved = models_mod.resolve(full_ref)
  if resolved then
    io.write(c.gray .. "  Testando conexão com " .. full_ref .. "...\n" .. c.reset)
    local ok_t, msg_t = validate.test_connection(resolved)
    if ok_t then
      io.write(c.green .. "  ✓ Modelo validado com sucesso.\n" .. c.reset)
    else
      io.write(c.red .. "  ✗ Falha na validação: " .. tostring(msg_t) .. "\n" .. c.reset)
      io.write("\n")
      io.write("  " .. c.white .. "1." .. c.reset .. " Manter mesmo assim\n")
      io.write("  " .. c.white .. "2." .. c.reset .. " Remover modelo\n\n")
      local opt = ui.prompt_read("Escolha")
      if opt == "2" then
        models_mod.remove_model(provider_id, model_id)
        io.write(c.gray .. "  Modelo removido.\n" .. c.reset)
      end
    end
  end
  ui.pause()
end
M.add = add
return M
