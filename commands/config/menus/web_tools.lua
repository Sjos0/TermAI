-- commands/config/menus/web_tools.lua
-- Menu de Web Tools na TUI: escolher provedor principal, chaves e cadeia de fallback.
local ui         = require("commands.models.ui")
local config_mod = require("config")
local c = ui.c
local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)
local M = {}

local function cls() io.write("\27[2J\27[H"); io.flush() end

local function row(label, value, color)
  color = color or c.white
  io.write(string.format("  %s%-22s%s %s%s%s\n",
    c.gray, label, c.reset, color, tostring(value), c.reset))
end

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
    elseif ch == "3" then
      local new = not fallback_enabled
      ctx.cfg.web_tools = ctx.cfg.web_tools or {}
      ctx.cfg.web_tools.fallback_enabled = new
      config_mod.set("web_tools.fallback_enabled", new)
      io.write((new and c.green or c.red).."\n  ✅ Fallback: "..(new and "Ativado" or "Desativado").."\n"..c.reset)
      ui.pause()
    elseif ch == "4" and fallback_enabled then
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
    elseif ch == "5" then
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
  end
end

return M
