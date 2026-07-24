-- test_connection.lua — Testa conexão com um provedor e oferece retry interativo.
-- Usado após adicionar um provedor (add.lua) ou trocar sua API key (update_key.lua).
local ui       = require("commands.models.ui")
local validate = require("models.validate")
local c        = ui.c
local M = {}

local function test_and_confirm(models_mod, provider_id)
  local builtin_model
  local ok_prov, pmod = pcall(require, "providers")
  if ok_prov then
    local prov = pmod.get(provider_id)
    if prov and prov.models and prov.models[1] then
      builtin_model = prov.models[1].id
    end
  end

  local resolved = models_mod.resolve(provider_id .. "/" .. (builtin_model or ""))
  if not resolved then
    io.write(c.yellow .. "\n  ⚠️  Não foi possível testar (nenhum modelo encontrado).\n" .. c.reset)
    return true
  end
  io.write(c.gray .. "  Testando conexão com "
    .. provider_id .. "/" .. (builtin_model or "") .. "...\n" .. c.reset)
  local ok, msg = validate.test_connection(resolved)
  if ok then
    io.write(c.green .. "  ✓ Conexão OK\n" .. c.reset)
    return true
  end

  io.write(c.red .. "  ✗ Falha na conexão: " .. tostring(msg) .. "\n\n" .. c.reset)

  while true do
    io.write("  " .. c.white .. "1." .. c.reset .. " Corrigir API Key e testar novamente\n")
    io.write("  " .. c.white .. "2." .. c.reset .. " Manter mesmo assim\n")
    io.write("  " .. c.white .. "3." .. c.reset .. " Remover provedor\n\n")
    local ch = ui.prompt_read("Escolha")

    if ch == "1" then
      io.write(c.gray .. "  Formato: " .. c.reset)
      local prov_data = models_mod.list_providers()
      for _, p in ipairs(prov_data) do
        if p.id == provider_id then
          local ok_b, cat = pcall(require, "providers")
          if ok_b then
            local bp = cat.get(provider_id)
            if bp then io.write(bp.key_hint or "") end
          end
          break
        end
      end
      io.write("\n")
      local new_key = ui.prompt_read("Nova API Key (0 para cancelar)")
      if ui.is_cancel(new_key) then return false end
      models_mod.update_api_key(provider_id, new_key)
      local resolved2 = models_mod.resolve(provider_id .. "/" .. (builtin_model or ""))
      if resolved2 then
        local ok2, msg2 = validate.test_connection(resolved2)
        if ok2 then
          io.write(c.green .. "  ✓ Conexão OK\n" .. c.reset)
          return true
        end
        io.write(c.red .. "  ✗ Falha: " .. tostring(msg2) .. "\n" .. c.reset)
      end

    elseif ch == "2" then
      io.write(c.yellow .. "  Provedor mantido sem validação.\n" .. c.reset)
      return true

    elseif ch == "3" then
      models_mod.remove_provider(provider_id)
      io.write(c.gray .. "  Provedor removido.\n" .. c.reset)
      return false
    end
  end
end

M.test_and_confirm = test_and_confirm
return M
