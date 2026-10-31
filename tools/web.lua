-- tools/web.lua — Ferramenta "web_search".
-- v2: schema JSON para native tool calling + arg backward compat.
-- v3: Despacha dinamicamente para o Provedor de Busca (Search Provider) ativo.
-- v4: Suporta fallback dinâmico em cadeia (Chain-of-Responsibility) ordenável pelo usuário.
local M = {}

function M.register(tools)
  tools.register("web_search",
    [==[Search the web for current information and return ranked results. Use it when the answer depends on facts that may have changed, or when you do not know the source. Do not use it when you already have the exact URL; use web_fetch for that. The search provider and the fallback order come from the web_tools section of config.json. Pass short, specific search terms as query. Example: query 'Lua 5.4 release date'.]==],
    function(arg)
      local q = type(arg) == "table" and (arg.query or arg.arg or "") or arg
      if not q or q:match("^%s*$") then
        return "❌ Forneça um termo de busca."
      end

      local config_mod = require("config")
      local cfg = config_mod.load()
      local web_cfg = cfg.web_tools or {}
      local fallback_enabled = web_cfg.fallback_enabled == true
      local chain = web_cfg.fallback_chain or { "google_grounding", "duckduckgo_search" }
      local active_provider = web_cfg.provider or "google_grounding"

      -- Resolve a lista de provedores que tentaremos em ordem
      local providers_to_try = {}
      if not fallback_enabled then
        providers_to_try[1] = active_provider
      else
        providers_to_try[1] = active_provider
        for _, p in ipairs(chain) do
          if p ~= active_provider then
            providers_to_try[#providers_to_try + 1] = p
          end
        end
      end

      local last_err = "❌ Nenhum provedor de busca disponível."
      for _, p in ipairs(providers_to_try) do
        local ok, search_mod = pcall(require, "providers." .. p)
        if ok and search_mod and search_mod.search then
          local res = search_mod.search(q)
          -- #338: os provedores emitem a falha em dois formatos — o antigo (^❌,
          -- "🔍 Nenhum resultado") e o novo do lote 1 do #325 (^[FAIL],
          -- "[SEARCH] Nenhum resultado"). Aceitar os dois para o fallback voltar a ocorrer.
          local falhou = res:match("^❌") or res:match("^%[FAIL%]")
          local vazio = res:match("🔍 Nenhum resultado") or res:match("%[SEARCH%] Nenhum resultado")
          if not falhou and not vazio then
            return res
          else
            last_err = res
          end
        else
          last_err = "❌ Erro ao carregar provedor de busca: " .. tostring(p)
        end
      end

      return last_err
    end,
    {
      type = "object",
      properties = {
        query = {type = "string", description = "Search terms, short and specific."}
      },
      required = {"query"}
    }
  )
end

return M
