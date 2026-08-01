-- add.lua — Adiciona um provedor: via catálogo built-in ou manualmente (customizado).
local ui = require("commands.models.ui")
local test_connection = require("commands.models.providers.test_connection")
local c  = ui.c
local M = {}

local function add(models_mod)
  io.write("\n" .. c.bold .. c.cyan .. "  Adicionar Provedor" .. c.reset .. "\n")
  io.write(c.gray .. "  " .. string.rep("─", 45) .. c.reset .. "\n\n")
  io.write("  " .. c.white .. "1." .. c.reset .. " Provedor built-in (pré-configurado)\n")
  io.write("  " .. c.white .. "2." .. c.reset .. " Provedor customizado (manual)\n\n")
  local ch = ui.prompt_read("Escolha (0 para voltar)")
  if ui.is_cancel(ch) then return end

  if ch == "1" then
    local ok_mod, pmod = pcall(require, "providers")
    if not ok_mod then
      io.write(c.red .. "  Erro ao carregar catálogo de provedores.\n" .. c.reset)
      return
    end
    local catalog = pmod.list()
    if #catalog == 0 then
      io.write(c.gray .. "  Nenhum provedor built-in disponível.\n" .. c.reset)
      return
    end

    ui.header("Provedores Disponíveis")
    for i, prov in ipairs(catalog) do
      local n_models = prov.models and #prov.models or 0
      local key_note = prov.needs_key and " [precisa de API Key/Token]" or ""
      io.write("  " .. c.white .. i .. ". " .. c.reset
        .. prov.name .. c.gray
        .. " (" .. n_models .. " modelo(s))" .. key_note .. c.reset .. "\n")
    end
    io.write("\n")
    local pch = ui.prompt_read("Número do provedor (0 para voltar)")
    if ui.is_cancel(pch) then return end
    local pidx = tonumber(pch)
    if not pidx or pidx < 1 or pidx > #catalog then
      io.write(c.red .. "  Opção inválida.\n" .. c.reset); return
    end
    local prov = catalog[pidx]

    local base_url = prov.baseUrl
    if prov.requires_account_id then
      io.write(c.gray .. "\n  " .. (prov.account_id_hint or "Account ID necessário") .. "\n" .. c.reset)
      local account_id = ui.prompt_read("Account ID (0 para voltar)")
      if ui.is_cancel(account_id) or account_id == "" then return end
      base_url = base_url:format(account_id)
    end

    local api_key = ""
    if prov.needs_key then
      if prov.id == "mimo" then
        io.write("\n" .. c.bold .. c.yellow .. "  Como obter seu Token Xiaomi MiMo Gratuito:" .. c.reset .. "\n")
        io.write("  1. Acesse no navegador: " .. c.cyan .. "https://platform.xiaomimimo.com" .. c.reset .. "\n")
        io.write("  2. Faça login com sua conta (Google/GitHub/E-mail)\n")
        io.write("  3. Vá em 'Configurações de Desenvolvedor' ou 'API Keys'\n")
        io.write("  4. Copie seu Token de Acesso (Bearer Token)\n\n")
      else
        io.write(c.gray .. "  Obtenha sua key em: " .. c.reset .. (prov.docs or "") .. "\n")
        io.write(c.gray .. "  Formato: " .. c.reset .. (prov.key_hint or "") .. "\n\n")
      end

      local key = ui.prompt_read("API Key/Token (0 para voltar)")
      if ui.is_cancel(key) then return end
      api_key = key
    end

    local ok_add, err_add = models_mod.add_provider({
      id      = prov.id,
      baseUrl = base_url,
      apiKey  = api_key,
      api     = prov.api or "openai-completions",
      models  = prov.models or {},
    })
    if not ok_add then
      io.write(c.red .. "  Erro: " .. tostring(err_add) .. "\n" .. c.reset)
      return
    end
    local n = prov.models and #prov.models or 0
    io.write(c.green .. "  ✅ Provedor '" .. prov.name
      .. "' adicionado com " .. n .. " modelo(s).\n" .. c.reset)

    test_connection.test_and_confirm(models_mod, prov.id)

  elseif ch == "2" then
    local pid    = ui.prompt_read("ID único do provedor (0 para voltar)")
    if ui.is_cancel(pid) then return end
    local pname  = ui.prompt_read("Nome de exibição")
    local purl   = ui.prompt_read("Base URL (ex: https://api.example.com/v1)")
    if ui.is_cancel(purl) then return end
    local pkey   = ui.prompt_read("API Key (Enter para deixar vazio)")
    pkey = (pkey and pkey ~= "") and pkey or ""

    local ok_add, err_add = models_mod.add_provider({
      id      = pid,
      baseUrl = purl,
      apiKey  = pkey,
      api     = "openai-completions",
      models  = {},
    })
    if not ok_add then
      io.write(c.red .. "  Erro: " .. tostring(err_add) .. "\n" .. c.reset)
      return
    end
    io.write(c.green .. "  ✅ Provedor '" .. (pname or pid)
      .. "' adicionado. Use 'Adicionar modelo' para inserir modelos.\n" .. c.reset)
  end
end

M.add = add
return M
