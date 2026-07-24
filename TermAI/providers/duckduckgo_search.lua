-- providers/duckduckgo_search.lua — Provedor de busca DuckDuckGo sem API Key (Scraper leve).
-- Baseado no algoritmo de parsing e decodificação do OpenClaw.
local M = {}
M.id = "duckduckgo_search"
M.name = "DuckDuckGo Search (Gratuito)"
M.requires_key = false

local function url_encode(str)
  if not str then return "" end
  str = str:gsub("\n", "\r\n")
  str = str:gsub("([^%w%.%_ %-])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  str = str:gsub(" ", "+")
  return str
end

local function url_decode(str)
  str = str:gsub("+", " ")
  str = str:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  return str
end

local function decode_ddg_url(raw_url)
  local uddg = raw_url:match("[?&]uddg=([^&]+)")
  if uddg then
    return url_decode(uddg)
  end
  return url_decode(raw_url)
end

local function strip_html(s)
  if not s then return "" end
  s = s:gsub("<[^>]+>", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("&amp;", "&")
  s = s:gsub("&lt;", "<")
  s = s:gsub("&gt;", ">")
  s = s:gsub("&quot;", '"')
  s = s:gsub("&#39;", "'")
  s = s:gsub("&nbsp;", " ")
  s = s:match("^%s*(.-)%s*$")
  return s
end

function M.search(query)
  local config_mod = require("config")
  local cfg = config_mod.load()
  local web_cfg = cfg.web_tools or {}

  if not web_cfg.enabled then
    return "❌ Web Tools desativadas. Ative em Config › Pesquisa Web."
  end

  local esc_query = url_encode(query)
  local url = "https://html.duckduckgo.com/html?q=" .. esc_query

  local user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  local cmd = string.format('curl -s -L --max-time 15 -A "%s" "%s" 2>/dev/null', user_agent, url)

  local h = io.popen(cmd)
  local html = h and h:read("*a") or ""
  if h then h:close() end

  if html == "" then
    return "❌ Falha na conexão com o DuckDuckGo. Verifique sua rede."
  end

  if html:match("g-recaptcha") or html:match("challenge-form") then
    return "❌ Busca bloqueada temporariamente pelo DuckDuckGo (Bot Challenge)."
  end

  local results = {}
  -- Mapeamento cirúrgico de blocos de links Deep do DDG
  for block in (html .. "<div class=\"result"):gmatch("(.-)<div class=\"result") do
    local href, title = block:match('class="result__a"%s+href="([^"]+)"[^>]*>(.-)</a>')
    local snippet     = block:match('class="result__snippet"[^>]*>(.-)</a>')

    if href and title then
      results[#results + 1] = {
        title   = strip_html(title),
        url     = decode_ddg_url(href),
        snippet = snippet and strip_html(snippet) or ""
      }
    end
  end

  if #results == 0 then
    return "🔍 Nenhum resultado para: " .. query
  end

  -- Formata a saída no mesmo layout que o Google Grounding espera
  local out = { "🔍 **Resultado (DuckDuckGo):** \"" .. query .. "\"\n" }
  for i = 1, math.min(#results, 5) do
    local r = results[i]
    out[#out + 1] = string.format("%d. **%s**", i, r.title)
    out[#out + 1] = "   " .. r.snippet
    out[#out + 1] = "   Font: " .. r.url .. "\n"
  end

  return table.concat(out, "\n")
end

return M
