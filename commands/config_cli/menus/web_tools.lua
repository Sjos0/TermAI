-- commands/config_cli/menus/web_tools.lua
-- Menu de Web Tools: configurar Provedor ativo (Google/DDG/Tavily) e cadeia de Fallback.
local M = {}

function M.run(config_mod, ui)
  while true do
    local cfg      = config_mod.load()
    local web      = cfg.web_tools or {}
    local enabled  = web.enabled == true
    local api_key  = web.google_grounding_key or ""
    local tav_key  = web.tavily_key or ""
    local provider = web.provider or "google_grounding"
    local fallback_enabled = web.fallback_enabled == true
    local chain = web.fallback_chain or { "duckduckgo_search", "tavily_search", "google_grounding" }

    local key_display = api_key
    if #key_display > 12 then
      key_display = key_display:sub(1, 8) .. "..." .. key_display:sub(-4)
    end

    local tav_display = tav_key
    if #tav_display > 12 then
      tav_display = tav_display:sub(1, 8) .. "..." .. tav_display:sub(-4)
    end

    -- Formata a exibição da cadeia de fallback para o usuário
    local chain_names = {}
    for _, p in ipairs(chain) do
      if p == "google_grounding" then table.insert(chain_names, "Google")
      elseif p == "duckduckgo_search" then table.insert(chain_names, "DDG")
      elseif p == "tavily_search" then table.insert(chain_names, "Tavily") end
    end

    ui.hdr("TermAI Config › Pesquisa Web")
    io.write(ui.DM..[[  Escolha seu Provedor principal e ative o Fallback em Cadeia.
  Suporta Google Grounding, DuckDuckGo (Gratuito) e Tavily Search.
]]..ui.R.."\n")
    io.write(ui.GR.."  ── Status "..ui.SEP2..ui.R.."\n")
    ui.row("Pesquisa Web:", enabled and (ui.G.."✅ Ativa"..ui.R) or (ui.RE.." ❌ Desativada"..ui.R))
    ui.row("Provedor Ativo:", provider == "google_grounding" and "Google Grounding (API)"
                         or (provider == "tavily_search" and "Tavily Search (API)" or "DuckDuckGo (Gratuito)"), ui.G)
    ui.row("Fallback Ativo:", fallback_enabled and (ui.G.."✅ Ativado"..ui.R) or (ui.RE.." ❌ Desativado"..ui.R))
    if fallback_enabled then
      ui.row("Cadeia de Fallback:", table.concat(chain_names, " → "), ui.G)
    end
    if provider == "google_grounding" or (fallback_enabled and (chain[1] == "google_grounding" or chain[2] == "google_grounding" or chain[3] == "google_grounding")) then
      ui.row("Chave Google:", api_key ~= "" and key_display or ui.RE.."(não configurada)"..ui.R)
    end
    if provider == "tavily_search" or (fallback_enabled and (chain[1] == "tavily_search" or chain[2] == "tavily_search" or chain[3] == "tavily_search")) then
      ui.row("Chave Tavily:", tav_display ~= "" and tav_display or ui.RE.."(não configurada)"..ui.R)
    end

    io.write("\n"..ui.GR.."  ── Opções "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."1."..ui.R.."  "..(enabled and (ui.RE.."Desativar"..ui.R) or (ui.G.."Ativar"..ui.R)).." Pesquisa Web\n")
    io.write("  "..ui.B.."2."..ui.R.."  Alterar Provedor de Busca Principal  "..ui.DM.."(Google / DDG / Tavily)"..ui.R.."\n")
    io.write("  "..ui.B.."3."..ui.R.."  "..(fallback_enabled and (ui.RE.."Desativar"..ui.R) or (ui.G.."Ativar"..ui.R)).." Fallback de Provedores\n")
    if fallback_enabled then
      io.write("  "..ui.B.."4."..ui.R.."  Alterar Ordem da Cadeia de Fallback\n")
    end
    io.write("  "..ui.B.."5."..ui.R.."  Configurar Chaves de API (Google / Tavily)\n")
    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch == "1" then
      local new = not enabled
      config_mod.set("web_tools.enabled", new)
      io.write(new and (ui.G.."\n  ✅ Pesquisa Web ativada.\n"..ui.R)
                    or (ui.RE.."\n  ❌ Pesquisa Web desativada.\n"..ui.R))
      ui.pause()

    elseif ch == "2" then
      cls = function() io.write("\27[2J\27[H"); io.flush() end
      cls()
      ui.hdr("TermAI Config › Provedor Principal")
      io.write("  "..ui.B.."1."..ui.R.."  Google Search Grounding (API Key)\n")
      io.write("  "..ui.B.."2."..ui.R.."  DuckDuckGo Search (Gratuito, sem chave)\n")
      io.write("  "..ui.B.."3."..ui.R.."  Tavily Search (API Key)\n")
      io.write("  "..ui.B.."0."..ui.R.."  Cancelar\n\n")
      local choice = ui.rdl("Escolha")
      if choice == "1" then
        config_mod.set("web_tools.provider", "google_grounding")
        io.write(ui.G.."\n  ✅ Provedor definido: Google Grounding\n"..ui.R)
      elseif choice == "2" then
        config_mod.set("web_tools.provider", "duckduckgo_search")
        io.write(ui.G.."\n  ✅ Provedor definido: DuckDuckGo Search\n"..ui.R)
      elseif choice == "3" then
        config_mod.set("web_tools.provider", "tavily_search")
        io.write(ui.G.."\n  ✅ Provedor definido: Tavily Search\n"..ui.R)
      end
      ui.pause()

    elseif ch == "3" then
      local new = not fallback_enabled
      config_mod.set("web_tools.fallback_enabled", new)
      io.write(new and (ui.G.."\n  ✅ Fallback de provedores ativado.\n"..ui.R)
                    or (ui.RE.."\n  ❌ Fallback de provedores desativado.\n"..ui.R))
      ui.pause()

    elseif ch == "4" and fallback_enabled then
      cls = function() io.write("\27[2J\27[H"); io.flush() end
      cls()
      ui.hdr("TermAI Config › Ordem de Fallback")
      io.write("  "..ui.B.."1."..ui.R.."  DDG → Tavily → Google  "..ui.DM.."(Recomendado - Máxima economia)"..ui.R.."\n")
      io.write("  "..ui.B.."2."..ui.R.."  Tavily → Google → DDG  "..ui.DM.."(Foco em relevância de IA)"..ui.R.."\n")
      io.write("  "..ui.B.."3."..ui.R.."  Google → Tavily → DDG  "..ui.DM.."(Estabilidade máxima)"..ui.R.."\n")
      io.write("  "..ui.B.."0."..ui.R.."  Cancelar\n\n")
      local choice = ui.rdl("Escolha")
      if choice == "1" then
        config_mod.set("web_tools.fallback_chain", {"duckduckgo_search", "tavily_search", "google_grounding"})
        io.write(ui.G.."\n  ✅ Ordem definida: DDG → Tavily → Google\n"..ui.R)
      elseif choice == "2" then
        config_mod.set("web_tools.fallback_chain", {"tavily_search", "google_grounding", "duckduckgo_search"})
        io.write(ui.G.."\n  ✅ Ordem definida: Tavily → Google → DDG\n"..ui.R)
      elseif choice == "3" then
        config_mod.set("web_tools.fallback_chain", {"google_grounding", "tavily_search", "duckduckgo_search"})
        io.write(ui.G.."\n  ✅ Ordem definida: Google → Tavily → DDG\n"..ui.R)
      end
      ui.pause()

    elseif ch == "5" then
      cls = function() io.write("\27[2J\27[H"); io.flush() end
      cls()
      ui.hdr("TermAI Config › Configurar Chaves")
      io.write("  "..ui.B.."1."..ui.R.."  Google Grounding Key (AI Studio)\n")
      io.write("  "..ui.B.."2."..ui.R.."  Tavily API Key (tavily.com)\n")
      io.write("  "..ui.B.."0."..ui.R.."  Cancelar\n\n")
      local choice = ui.rdl("Escolha")
      if choice == "1" then
        local s = ui.rdl("Chave Google (AI Studio)")
        if s and s ~= "" then
          config_mod.set("web_tools.google_grounding_key", s)
          io.write(ui.G.."\n  ✅ Chave Google atualizada.\n"..ui.R)
        end
      elseif choice == "2" then
        local s = ui.rdl("Chave Tavily (tavily.com)")
        if s and s ~= "" then
          config_mod.set("web_tools.tavily_key", s)
          io.write(ui.G.."\n  ✅ Chave Tavily atualizada.\n"..ui.R)
        end
      end
      ui.pause()
    end
  end
end

return M
