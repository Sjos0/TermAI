-- providers/google_grounding.lua — Google Search Grounding via Interactions API
-- MIGRADO em 2026-07-27: Google descontinuou generateContent para grounding.
-- Endpoint: POST /v1beta/interactions
-- Formato: { model, input, tools: [{type:"google_search"}] }
-- Resposta: { steps: [{type:"thought"}, {type:"google_search_call"}, {type:"google_search_result"}, {type:"model_output"}] }
--
-- Fallback chain: gemini-2.5-flash → gemini-2.5-flash-lite → gemini-2.5-flash-lite-preview-09-2025

local json = require("json")
local security = require("agent.security")
local M = {}
M.id = "google_grounding"
M.name = "Google Search Grounding (Gemini)"

-- Modelo primário + fallbacks (todos suportam grounding no free tier)
local MODELS = {
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash-lite-preview-09-2025",
}

local INTERACTIONS_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"

local function get_config()
  local config_mod = require("config")
  local cfg = config_mod.load()
  return (cfg.web_tools or {})
end

local function parse_retry(msg)
  local s = msg:match("retry in (%d+%.?%d*)s")
  return s and (" Tente em " .. s .. "s.") or ""
end

local function classify_error(data)
  local err = data.error
  if not err then return "❌ Erro desconhecido do Google." end

  local code  = err.code or 0
  local msg   = err.message or "Erro desconhecido"
  local lower = msg:lower()

  -- 429 / too_many_requests = cota esgotada
  if code == 429 or lower:match("too_many_requests") then
    local retry = parse_retry(msg)
    if lower:match("quota") or lower:match("resource_exhausted") then
      return "❌ Cota de Search Grounding esgotada." .. retry .. "\n"
          .. "  Limite free tier: 500 req/dia por modelo. Detalhe: " .. msg
    end
    return "❌ Rate limit atingido." .. retry .. "\n"
        .. "  Detalhe: " .. msg
  end

  -- 403 = chave inválida ou leaked
  if code == 403 then
    if lower:match("leaked") then
      return "❌ Chave de API comprometida (reported as leaked).\n"
          .. "  Gere uma nova chave em https://aistudio.google.com/apikey\n"
          .. "  e atualize em Config › Web Tools."
    end
    return "❌ Chave de API inválida ou sem permissão para Grounding.\n"
        .. "  Verifique em Config › Web Tools. Detalhe: " .. msg
  end

  -- 400 = payload inválido
  if code == 400 then
    return "❌ Requisição inválida. Verifique a configuração do provider.\n"
        .. "  Detalhe: " .. msg
  end

  return "❌ Erro Google [" .. tostring(code) .. "]: " .. msg
end

--- Extrair texto e fontes de uma resposta Interactions API
-- @param data table Resposta decodificada do JSON
-- @return string, table Texto da resposta e lista de fontes {url, title}
local function extract_response(data)
  local response_text = ""
  local sources = {}
  local queries = {}

  -- Buscar em output_text primeiro (fallback API clássica)
  if data.output_text and data.output_text ~= "" then
    response_text = data.output_text
  end

  -- Buscar em steps (formato Interactions API)
  if data.steps then
    for _, step in ipairs(data.steps) do
      -- thought: raciocínio do modelo (ignorar)
      -- google_search_call: queries executadas
      if step.type == "google_search_call" and step.arguments then
        if step.arguments.queries then
          for _, q in ipairs(step.arguments.queries) do
            queries[#queries + 1] = q
          end
        end
      end

      -- model_output: texto final com annotations
      if step.type == "model_output" and step.content then
        for _, block in ipairs(step.content) do
          -- Texto da resposta
          if block.type == "text" and block.text then
            response_text = response_text .. block.text
          end

          -- Annotations (citações inline)
          if block.annotations then
            for _, ann in ipairs(block.annotations) do
              if ann.type == "url_citation" and ann.url then
                sources[#sources + 1] = {
                  url = ann.url,
                  title = ann.title or ann.url,
                  start = ann.start_index,
                  ["end"] = ann.end_index,
                }
              end
            end
          end
        end
      end
    end
  end

  -- Fallback: grounding_metadata (formato antigo generateContent)
  if #sources == 0 then
    local meta = data.grounding_metadata
    if meta and meta.grounding_chunks then
      for _, chunk in ipairs(meta.grounding_chunks) do
        if chunk.web and chunk.web.uri then
          sources[#sources + 1] = { url = chunk.web.uri, title = chunk.web.title or chunk.web.uri }
        end
      end
    end
    -- camelCase fallback
    if #sources == 0 and meta and meta.groundingChunks then
      for _, chunk in ipairs(meta.groundingChunks) do
        if chunk.web and chunk.web.uri then
          sources[#sources + 1] = { url = chunk.web.uri, title = chunk.web.title or chunk.web.uri }
        end
      end
    end
  end

  return response_text, sources, queries
end

--- Fazer chamada à API com um modelo específico
-- @param model string Nome do modelo
-- @param api_key string Chave de API
-- @param query string Pergunta do usuário
-- @return string, table, table, string Resposta, fontes, queries, raw response
local function call_api(model, api_key, query)
  local pl = json.encode({
    model = model,
    input = query,
    tools = {{ type = "google_search" }}
  })

  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  local tmp_path = TMPDIR .. "/gg_search.json"
  local tmp = io.open(tmp_path, "w")
  if not tmp then return nil, nil, nil, "" end
  tmp:write(pl); tmp:close()

  local cmd = string.format(
    'curl -s --max-time 30 --speed-time 15 --speed-limit 1 -X POST "%s"'
    .. ' -H "Content-Type: application/json"'
    .. ' -H "x-goog-api-key: %s"'
    .. ' -d @%s 2>/dev/null',
    INTERACTIONS_URL, api_key, tmp_path
  )

  local h   = io.popen(cmd)
  local raw = h and h:read("*a") or ""
  if h then h:close() end
  os.remove(tmp_path)

  return raw
end

function M.search(query)
  local web = get_config()

  if not web.enabled then
    return "❌ Web Tools desativadas. Ative em Config › Web Tools."
  end

  local api_key = web.google_grounding_key
  if not api_key or api_key == "" then
    return "❌ Chave de Grounding não configurada. Vá em Config › Web Tools."
  end

  local safe, char = security.is_safe(api_key)
  if not safe then
    return "❌ Erro de segurança: chave de API contém caractere inválido '" .. char .. "'"
  end

  -- Fallback chain: tentar cada modelo até um funcionar
  local last_error = ""
  for _, model in ipairs(MODELS) do
    local raw = call_api(model, api_key, query)

    if raw == "" then
      last_error = "❌ Sem resposta do Google. Verifique sua conexão."
    else
      local ok, data = pcall(json.decode, raw)
      if not ok then
        last_error = "❌ Resposta inválida do Google."
      elseif data.error then
        last_error = classify_error(data)
        -- Se erro de cota (429), tentar próximo modelo
        local code = data.error.code or 0
        local lower = (data.error.message or ""):lower()
        if code == 429 or lower:match("too_many_requests") then
          goto continue
        end
        -- Se erro de chave (403) ou payload (400), não adianta trocar modelo
        break
      else
        -- Sucesso!
        local response_text, sources, queries = extract_response(data)

        if response_text == "" then
          last_error = "🔍 Nenhum resultado para: " .. query
          break  -- output vazio, sem mais o que tentar
        else
          local out = { "🔍 **Resultado:** \"" .. query .. "\"\n" }

          -- Adicionar queries executadas (se houver)
          if #queries > 0 then
            out[#out + 1] = "🔎 *Queries:* " .. table.concat(queries, ", ") .. "\n"
          end

          out[#out + 1] = response_text

          -- Adicionar fontes
          if #sources > 0 then
            out[#out + 1] = "\n📎 **Fontes:**"
            local seen = {}
            local idx = 0
            for _, src in ipairs(sources) do
              if not seen[src.url] then
                idx = idx + 1
                seen[src.url] = true
                out[#out + 1] = idx .. ". " .. src.title .. " — " .. src.url
              end
            end
          end

          return table.concat(out, "\n")
        end
      end
    end

    ::continue::
  end

  return last_error
end

return M
