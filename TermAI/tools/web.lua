-- tools/web.lua — Ferramenta "pesquisar_web".
-- v2: schema JSON para native tool calling + arg backward compat.
-- v3: Despacha dinamicamente para o Provedor de Busca (Search Provider) ativo.
-- v4: Suporta fallback dinâmico em cadeia (Chain-of-Responsibility) ordenável pelo usuário.
local M = {}

function M.register(tools)
  tools.register("pesquisar_web",
    "Pesquisa na web por informações atualizadas. "
    .. "O comportamento depende do Provedor de Busca e do Fallback ativos no config.json.",
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
          -- Se a busca foi bem-sucedida (não retorna erro nem indicativos de CAPTCHA/Bloqueio)
          if not res:match("^❌") and not res:match("🔍 Nenhum resultado") then
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
        query = {type = "string", description = "Termo de busca na web"}
      },
      required = {"query"}
    }
  )
end

return M
