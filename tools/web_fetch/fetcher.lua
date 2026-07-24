-- tools/web_fetch/fetcher.lua — Implementação física da extração de páginas web.
-- Se 'lynx' estiver disponível no Termux, usa 'lynx -dump' para extração HTML -> Texto limpa.
-- Caso contrário, cai para curl + regex-stripper leve de HTML.
local M = {}

local function strip_html(html)
  if not html then return "" end
  html = html:gsub("<script[^>]*>.-</script>", " ")
  html = html:gsub("<style[^>]*>.-</style>", " ")
  html = html:gsub("<[^>]+>", " ")
  html = html:gsub("%s+", " ")
  -- Decodificação de entidades básicas
  html = html:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
  html = html:gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&nbsp;", " ")
  return html:match("^%s*(.-)%s*$")
end

local function check_lynx()
  local h = io.popen("which lynx 2>/dev/null")
  local res = h and h:read("*a") or ""
  if h then h:close() end
  return res:match("%S") ~= nil
end

function M.run(arg)
  local url, extract_mode, max_chars
  if type(arg) == "table" then
    url          = arg.url or arg.arg or ""
    extract_mode = arg.extractMode or "markdown"
    max_chars    = tonumber(arg.maxChars) or 8000 -- default limite de segurança: 8k chars
  else
    url          = arg
    extract_mode = "markdown"
    max_chars    = 8000
  end

  if not url or url == "" then
    return "❌ URL inválida ou não informada."
  end

  if not url:match("^https?://") then
    return "❌ Protocolo inválido. A URL deve começar com http:// ou https://."
  end

  -- Proteção ativa de rede (SSRF Shield): impede requisições para localhost ou rede local
  if url:match("localhost") or url:match("127%.0%.0") or url:match("192%.168%.") or url:match("10%.%d+%.") then
    return "❌ [SEGURANÇA] Bloqueio SSRF: requisições para a rede local privada são proibidas."
  end

  local has_lynx = check_lynx()
  local output = ""

  if has_lynx then
    -- lynx -dump fornece a melhor extração de texto estruturado sem anúncios do console
    local cmd = string.format('lynx -dump -nolist -width=80 "%s" 2>/dev/null', url)
    local h = io.popen(cmd)
    output = h and h:read("*a") or ""
    if h then h:close() end
  else
    -- Fallback leve via curl + regex HTML stripper
    local cmd = string.format('curl -s -L --max-time 15 -A "Mozilla/5.0" "%s" 2>/dev/null', url)
    local h = io.popen(cmd)
    local raw_html = h and h:read("*a") or ""
    if h then h:close() end

    output = strip_html(raw_html)
    if output ~= "" then
      output = output .. "\n\n💡 [Dica: Execute 'pkg install lynx' no Termux para uma formatação de página infinitamente melhor!]"
    end
  end

  if output == "" then
    return "❌ Falha ao baixar o conteúdo da URL. Verifique se o link está acessível."
  end

  -- Truncamento seguro de caracteres para proteger a cota de tokens (Estilo OpenClaw)
  local truncated = false
  if #output > max_chars then
    output = output:sub(1, max_chars)
    truncated = true
  end

  -- Envelopamento com aviso de segurança (External Untrusted Content warning)
  local out = {
    "⚠️ [CONTEÚDO DA WEB EXTERNO E NÃO CONFIÁVEL - FONTE: " .. url .. "]",
    "---",
    output,
    "---"
  }
  if truncated then
    out[#out + 1] = "⚠️ [Nota: O conteúdo foi truncado em " .. max_chars .. " caracteres para economizar tokens.]"
  end

  return table.concat(out, "\n")
end

return M
