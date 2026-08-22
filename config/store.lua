local json = require("json")
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.PATH = HOME .. "/.TermAI/config.json"
M._data = nil

-- Config padrão de instalação nova: sem provider/modelo ainda —
-- isso é resolvido depois via "TermAI models add-provider".
local function defaults()
  return {
    meta = { version = "0.1.0", lastTouchedAt = os.date("!%Y-%m-%dT%H:%M:%S.000Z") },
    agents = {
      defaults = {
        model = { primary = "", fallbacks = {} },
        thinking = true,
        thinkingEffort = "high",
        temperature = 0.7,
        maxIter = 20,
        compaction = {
          flush_tokens = 40000,
          compactacao_pct = 0.9,
          flush_prompt = "",
          keep_recent_tokens = 20000,
          anchor_keep = 5,
          anchor_token_cap = 8000,
          summary_max_tokens_ratio = 0.8,
        },
      },
      list = {
        { id = "main", agentDir = "agents/main/agent", workspace = "workspace", model = { primary = "" } },
      },
    },
  }
end

local function ensure_dir()
  local dir = M.PATH:match("^(.*)/[^/]+$")
  if dir then os.execute("mkdir -p '" .. dir .. "'") end
end

function M.load()
  local f = io.open(M.PATH, "r")
  if not f then
    -- Primeira execução: cria config.json com defaults em vez de travar o boot.
    M._data = defaults()
    M.save()
    return M._data
  end
  local content = f:read("*a")
  f:close()

  local ok, data = pcall(json.decode, content)
  if not ok then
    print("[ERRO] config.json inválido!")
    os.exit(1)
  end

  local needs_save = false
  if data.modelo then
    local migrate = require("config.migrate")
    data = migrate.run(data)
    needs_save = true
  end

  M._data = data
  if needs_save then M.save() end
  return M._data
end

function M.save()
  if not M._data then return false end
  M._data.meta = M._data.meta or {}
  M._data.meta.lastTouchedAt = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
  ensure_dir()
  local f = io.open(M.PATH, "w")
  if not f then return false end
  f:write(json.encode(M._data))
  f:close()
  return true
end

function M.data()
  if not M._data then M.load() end
  return M._data
end

return M
