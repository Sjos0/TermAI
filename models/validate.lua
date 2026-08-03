local json = require("json")
local security = require("agent.security")
local error_log = require("agent.api.request_stream.error_log")
local M = {}

function M.test_connection(active)
  -- Validação de segurança prévia para mitigar injeção de comandos
  if active.endpoint then
    local safe, char = security.is_safe(active.endpoint)
    if not safe then
      return false, "Erro de segurança: endpoint contém caractere inválido '" .. char .. "'"
    end
  end
  if active.api_key and active.api_key ~= "" then
    local safe, char = security.is_safe(active.api_key)
    if not safe then
      return false, "Erro de segurança: API key contém caractere inválido '" .. char .. "'"
    end
  end

  local payload = {
    model    = active.model_id,
    messages = {{role = "user", content = "hi"}},
    max_tokens = 5,
  }

  -- Se o modelo tem reasoning, testa com o payload de reasoning de verdade
  -- (mesmo formato de agent/api/payload.lua) — senão a validação passa,
  -- mas o reasoning_style errado só quebra depois, no meio de uma conversa.
  if active.reasoning then
    local style = active.reasoning_style or "openrouter"
    if style == "openrouter" then
      payload.include_reasoning = true
      payload.reasoning = { effort = "medium" }
    elseif style == "chat_template_kwargs" then
      payload.chat_template_kwargs = { thinking = true }
    elseif style == "reasoning_effort" then
      payload.reasoning_effort = "high"
    end
  end

  local auth = ""
  local style = active.auth_style or ""
  if style == "bearer" then
    if active.api_key and active.api_key ~= "" then
      auth = ' -H "Authorization: Bearer ' .. active.api_key .. '"'
    end
  elseif style == "x-goog-api-key" then
    if active.api_key and active.api_key ~= "" then
      auth = ' -H "x-goog-api-key: ' .. active.api_key .. '"'
    end
  end

  local tmp_path = os.tmpname()
  local tmp = io.open(tmp_path, "w")
  tmp:write(json.encode(payload))
  tmp:close()

  local cmd = string.format(
    'curl -s -w "\\n%%{http_code}" -X POST "%s"%s -H "Content-Type: application/json" -d @%s 2>/dev/null',
    active.endpoint, auth, tmp_path)
  local h = io.popen(cmd)
  local r = h:read("*a")
  h:close()
  os.remove(tmp_path)

  local body, http_code = r:match("^(.-)\n(%d+)$")
  if not body then
    return false, "Sem resposta do servidor"
  end

  http_code = tonumber(http_code)
  if http_code ~= 200 then
    local err_msg = "HTTP " .. tostring(http_code)
    local detail = error_log.extract_from_body(body)
    if detail then
      err_msg = err_msg .. ": " .. detail
    else
      -- Corpo não bateu com nenhum formato conhecido: mostra os primeiros
      -- 100 caracteres crus em vez de esconder a informação.
      local snippet = body:sub(1, 100)
      if snippet ~= "" then err_msg = err_msg .. " - " .. snippet end
    end
    return false, err_msg
  end

  local ok, data = pcall(json.decode, body)
  if not ok then
    return false, "Resposta inválida do servidor"
  end

  if data.choices and data.choices[1] then
    return true, "Conexão OK"
  end

  return false, "Resposta sem dados válidos"
end

return M
