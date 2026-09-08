-- providers/google_grounding/api_client.lua — Cliente HTTP (curl) para Interactions API.
local json = require("json")
local constants = require("providers.google_grounding.constants")

local M = {}

--- Fazer chamada à API com um modelo específico
-- @param model string Nome do modelo
-- @param api_key string Chave de API
-- @param query string Pergunta do usuário
-- @return string Raw response body (ou "" em falha de I/O)
function M.call_api(model, api_key, query)
  local pl = json.encode({
    model = model,
    input = query,
    tools = {{ type = "google_search" }}
  })

  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  local tmp_path = TMPDIR .. "/gg_search.json"
  local tmp = io.open(tmp_path, "w")
  if not tmp then return "" end
  tmp:write(pl); tmp:close()

  local cmd = string.format(
    'curl -s --max-time 30 --speed-time 15 --speed-limit 1 -X POST "%s"'
    .. ' -H "Content-Type: application/json"'
    .. ' -H "x-goog-api-key: %s"'
    .. ' -d @%s 2>/dev/null',
    constants.INTERACTIONS_URL, api_key, tmp_path
  )

  local h   = io.popen(cmd)
  local raw = h and h:read("*a") or ""
  if h then h:close() end
  os.remove(tmp_path)

  return raw
end

return M
