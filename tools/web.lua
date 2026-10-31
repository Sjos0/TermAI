-- tools/web.lua — Ferramenta "web_search".
-- v2: schema JSON para native tool calling + arg backward compat.
-- v3: Despacha dinamicamente para o Provedor de Busca (Search Provider) ativo.
-- v4: Suporta fallback dinâmico em cadeia (Chain-of-Responsibility) ordenável pelo usuário.
local M = {}
local resultado = require("lib.result")

function M.register(tools)
  tools.register("web_search",
    [==[Search the web for current information and return ranked results. Use it when the answer depends on facts that may have changed, or when you do not know the source. Do not use it when you already have the exact URL; use web_fetch for that. The search provider and the fallback order come from the web_tools section of config.json. Pass short, specific search terms as query. Example: query 'Lua 5.4 release date'.]==],
    function(arg)
      local q = type(arg) == "table" and (arg.query or arg.arg or "") or arg
      if not q or q:match("^%s*$") then
        return "[FAIL] Forneça um termo de busca."
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

      local last_err = "[FAIL] Nenhum provedor de busca disponível."
      for _, p in ipairs(providers_to_try) do
        local ok, search_mod = pcall(require, "providers." .. p)
        if ok and search_mod and search_mod.search then
          local res = search_mod.search(q)
          -- #338/#343/#352: a falha e o "sem resultado" dos provedores são lidos pelo
          -- prefixo de resultado, e essa detecção vive num lugar só: lib/result.lua —
          -- que reconhece apenas o formato novo (o símbolo antigo saiu no D6 do #325).
          -- O detalhe "resultado" segue exigido, como antes: só busca sem resultado
          -- aciona o fallback, e não qualquer mensagem de "Nenhum".
          local falhou = resultado.e_falha(res)
          local vazio  = resultado.e_busca_vazia(res, "resultado")
          if not falhou and not vazio then
            return res
          else
            last_err = res
          end
        else
          last_err = "[FAIL] Erro ao carregar provedor de busca: " .. tostring(p)
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
