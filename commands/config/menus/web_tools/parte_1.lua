-- commands/config/menus/web_tools/parte_1.lua — exporta: run.
return function(M, N)
  local ui, config_mod, c, SEP, SEP2, cls, row = N.ui, N.config_mod, N.c, N.SEP, N.SEP2, N.cls, N.row
  local sub = require("commands.config.menus.web_tools.submenus")(N)


  function M.run(ctx)
    while true do
      cls()
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

      local chain_names = {}
      for _, p in ipairs(chain) do
        if p == "google_grounding" then table.insert(chain_names, "Google")
        elseif p == "duckduckgo_search" then table.insert(chain_names, "DDG")
        elseif p == "tavily_search" then table.insert(chain_names, "Tavily") end
      end

      io.write("\n"..c.bold..c.cyan.."  Configurações › Pesquisa Web"..c.reset.."\n")
      io.write(c.gray.."  "..SEP..c.reset.."\n\n")

      io.write(c.gray.."  ── Status "..SEP2..c.reset.."\n")
      row("Pesquisa Web:", enabled and (c.green.."✅ Ativa"..c.reset) or (c.red.."❌ Desativada"..c.reset))
      row("Provedor Ativo:", provider == "google_grounding" and "Google Grounding"
                           or (provider == "tavily_search" and "Tavily Search" or "DuckDuckGo (Gratuito)"), c.cyan)
      row("Fallback Ativo:", fallback_enabled and (c.green.."✅ Ativado"..c.reset) or (c.red.."❌ Desativado"..c.reset))
      if fallback_enabled then
        row("Cadeia de Fallback:", table.concat(chain_names, " → "), c.cyan)
      end
      if provider == "google_grounding" or (fallback_enabled and (chain[1] == "google_grounding" or chain[2] == "google_grounding" or chain[3] == "google_grounding")) then
        row("Chave Google:", key_display ~= "" and key_display or c.red.."(não configurada)"..c.reset)
      end
      if provider == "tavily_search" or (fallback_enabled and (chain[1] == "tavily_search" or chain[2] == "tavily_search" or chain[3] == "tavily_search")) then
        row("Chave Tavily:", tav_display ~= "" and tav_display or c.red.."(não configurada)"..c.reset)
      end

      io.write("\n"..c.gray.."  ── Opções "..SEP2..c.reset.."\n")
      io.write("  "..c.white.."1."..c.reset.."  "..(enabled and "Desativar" or "Ativar").." Pesquisa Web\n")
      io.write("  "..c.white.."2."..c.reset.."  Alterar Provedor de Busca Principal  "..c.dim.."(Google / DDG / Tavily)"..c.reset.."\n")
      io.write("  "..c.white.."3."..c.reset.."  "..(fallback_enabled and "Desativar" or "Ativar").." Fallback de Provedores\n")
      if fallback_enabled then
        io.write("  "..c.white.."4."..c.reset.."  Alterar Ordem do Fallback\n")
      end
      io.write("  "..c.white.."5."..c.reset.."  Configurar Chaves de API  "..c.dim.."(Google / Tavily)"..c.reset.."\n")
      io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")

      local ch = ui.prompt_read("Escolha")
      if ui.is_cancel(ch) then break end

      if ch == "1" then
        local new = not enabled
        ctx.cfg.web_tools = ctx.cfg.web_tools or {}
        ctx.cfg.web_tools.enabled = new
        config_mod.set("web_tools.enabled", new)
        io.write((new and c.green or c.red).."\n  ✅ Pesquisa Web: "..(new and "Ativada" or "Desativada").."\n"..c.reset)
        ui.pause()
      elseif ch == "2" then
        sub.escolher_provedor(ctx)
      elseif ch == "3" then
        local new = not fallback_enabled
        ctx.cfg.web_tools = ctx.cfg.web_tools or {}
        ctx.cfg.web_tools.fallback_enabled = new
        config_mod.set("web_tools.fallback_enabled", new)
        io.write((new and c.green or c.red).."\n  ✅ Fallback: "..(new and "Ativado" or "Desativado").."\n"..c.reset)
        ui.pause()
      elseif ch == "4" and fallback_enabled then
        sub.escolher_ordem(ctx)
      elseif ch == "5" then
        sub.configurar_chaves(ctx)
      end
    end
  end
end
