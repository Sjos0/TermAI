-- commands/config/menus/web_tools/submenus.lua — submenus de provedor, ordem de fallback e chaves do web_tools.
return function(N)
  local ui, config_mod, c, SEP, cls = N.ui, N.config_mod, N.c, N.SEP, N.cls
  local M = {}

  function M.escolher_provedor(ctx)
    cls()
    io.write("\n"..c.bold..c.cyan.."  Configurações › Escolha do Provedor"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write("  "..c.white.."1."..c.reset.."  Google Search Grounding  "..c.dim.."(Requer API Key)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  DuckDuckGo Search        "..c.dim.."(Gratuito, sem chave)"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  Tavily Search            "..c.dim.."(Requer API Key)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
    local choice = ui.prompt_read("Escolha")
    if choice == "1" then
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.provider = "google_grounding"
      config_mod.set("web_tools.provider", "google_grounding")
      io.write(c.green.."\n  ✅ Provedor definido: Google Grounding\n"..c.reset)
    elseif choice == "2" then
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.provider = "duckduckgo_search"
      config_mod.set("web_tools.provider", "duckduckgo_search")
      io.write(c.green.."\n  ✅ Provedor definido: DuckDuckGo Search (Gratuito)\n"..c.reset)
    elseif choice == "3" then
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.provider = "tavily_search"
      config_mod.set("web_tools.provider", "tavily_search")
      io.write(c.green.."\n  ✅ Provedor definido: Tavily Search\n"..c.reset)
    end
    ui.pause()
  end

  function M.escolher_ordem(ctx)
    cls()
    io.write("\n"..c.bold..c.cyan.."  Configurações › Ordem de Fallback"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write("  "..c.white.."1."..c.reset.."  DDG → Tavily → Google  "..c.dim.."(Recomendado - Máxima economia)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  Tavily → Google → DDG  "..c.dim.."(Foco em relevância de IA)"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  Google → Tavily → DDG  "..c.dim.."(Estabilidade máxima)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
    local choice = ui.prompt_read("Escolha")
    if choice == "1" then
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.fallback_chain = {"duckduckgo_search", "tavily_search", "google_grounding"}
      config_mod.set("web_tools.fallback_chain", {"duckduckgo_search", "tavily_search", "google_grounding"})
      io.write(c.green.."\n  ✅ Ordem definida: DDG → Tavily → Google\n"..c.reset)
    elseif choice == "2" then
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.fallback_chain = {"tavily_search", "google_grounding", "duckduckgo_search"}
      config_mod.set("web_tools.fallback_chain", {"tavily_search", "google_grounding", "duckduckgo_search"})
      io.write(c.green.."\n  ✅ Ordem definida: Tavily → Google → DDG\n"..c.reset)
    elseif choice == "3" then
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.fallback_chain = {"google_grounding", "tavily_search", "duckduckgo_search"}
      config_mod.set("web_tools.fallback_chain", {"google_grounding", "tavily_search", "duckduckgo_search"})
      io.write(c.green.."\n  ✅ Ordem definida: Google → Tavily → DDG\n"..c.reset)
    end
    ui.pause()
  end

  function M.configurar_chaves(ctx)
    cls()
    io.write("\n"..c.bold..c.cyan.."  Configurações › Configurar Chaves"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write("  "..c.white.."1."..c.reset.."  Google Grounding Key  "..c.dim.."(AI Studio)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  Tavily API Key        "..c.dim.."(tavily.com)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
    local choice = ui.prompt_read("Escolha")
    if choice == "1" then
      local s = ui.prompt_read("Chave Google (AI Studio)")
      if s and s ~= "" then
        ctx.cfg.web_tools = ctx.cfg.web_tools or {}
        ctx.cfg.web_tools.google_grounding_key = s
        config_mod.set("web_tools.google_grounding_key", s)
        io.write(c.green.."\n  ✅ Chave Google atualizada.\n"..c.reset)
      end
    elseif choice == "2" then
      local s = ui.prompt_read("Chave Tavily (tavily.com)")
      if s and s ~= "" then
        ctx.cfg.web_tools = ctx.cfg.web_tools or {}
        ctx.cfg.web_tools.tavily_key = s
        config_mod.set("web_tools.tavily_key", s)
        io.write(c.green.."\n  ✅ Chave Tavily atualizada.\n"..c.reset)
      end
    end
    ui.pause()
  end

  return M
end
