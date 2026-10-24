-- tools/subagents/inbox.lua — Mensagens do pai para um filho em execução (send / steer).
-- O pai grava uma linha em inbox.jsonl; o filho lê só o que é novo, no ponto seguro dele.
-- Nada entra no meio de uma chamada de modelo: a entrega é sempre entre turnos.
local registry = require("tools.subagents.registry")
local json     = require("json")
local M = {}

local read_upto = {}   -- runId -> quantas linhas deste processo já leu

local function path(run_id) return registry.dir(run_id) .. "/inbox.jsonl" end

-- Grava uma mensagem. kind: "message" (mensagem comum) ou "redirect" (redirecionamento).
function M.post(run_id, kind, text)
  local f = io.open(path(run_id), "a")
  if not f then return false end
  f:write(json.encode({ t = os.time(), kind = kind, text = tostring(text or "") }), "\n")
  f:close()
  return true
end

-- Mensagens novas desde a última leitura deste processo, em ordem.
function M.read_new(run_id)
  local f = io.open(path(run_id), "r")
  if not f then return {} end
  local out, n = {}, 0
  for line in f:lines() do
    n = n + 1
    if n > (read_upto[run_id] or 0) then
      local ok, msg = pcall(json.decode, line)
      if ok and type(msg) == "table" then out[#out + 1] = msg end
    end
  end
  f:close()
  read_upto[run_id] = n
  return out
end

-- Entrega no contexto do filho: vira mensagem do usuário, com a origem clara.
function M.deliver(ctx)
  if not (ctx and ctx.is_subagent and ctx.run_id) then return 0 end
  local n = 0
  for _, m in ipairs(M.read_new(ctx.run_id)) do
    local label = (m.kind == "redirect") and "[redirecionamento do orquestrador]" or "[mensagem do orquestrador]"
    ctx.msgs[#ctx.msgs + 1] = { role = "user", content = label .. " " .. tostring(m.text) }
    n = n + 1
  end
  return n
end

function M.reset_offsets() read_upto = {} end

return M
