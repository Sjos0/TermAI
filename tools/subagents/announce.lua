-- tools/subagents/announce.lua — Entrega ao pai o resultado de cada run terminado (uma vez).
-- Cabeçalho com duração, número de tools e classe do erro; corpo com teto de 8 KB (issue #96).
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local log       = require("diag.log")
local M = {}

local MAX_BODY = 8192

-- Corta em fronteira de caractere UTF-8, para não partir um acento no meio.
local function cut_utf8(s, max)
  if #s <= max then return s end
  local k = max
  while k > 0 and (s:byte(k + 1) or 0) & 0xC0 == 0x80 do k = k - 1 end
  return s:sub(1, k)
end

local function count_tools(run_id)
  local f = io.open(registry.dir(run_id) .. "/events.jsonl", "r")
  if not f then return 0 end
  local n = 0
  for line in f:lines() do
    if line:find('"kind"%s*:%s*"tool"') then n = n + 1 end
  end
  f:close()
  return n
end

local function duration(rec)
  if not rec.started_at or not rec.finished_at then return "?" end
  return tostring(rec.finished_at - rec.started_at) .. "s"
end

local function body(rec)
  local text
  if rec.status == "completed" then
    text = registry.read_result(rec.runId) or ""
  else
    text = "erro: " .. tostring(rec.error or rec.status)
    local partial = rec.partial and registry.read_result(rec.runId) or ""
    if partial ~= "" then text = text .. "\n[resultado parcial, incompleto]\n" .. partial end
    text = text .. "\nO trabalho do subagente NÃO foi concluído. Decida: tentar de novo (no máximo uma vez), assumir a tarefa você mesmo ou avisar o usuário."
  end
  if #text > MAX_BODY then
    text = cut_utf8(text, MAX_BODY) .. string.format(
      "\n[… anúncio cortado em %d bytes; resultado completo em %s/result.txt]",
      MAX_BODY, registry.dir(rec.runId))
  end
  return text
end

local function header(rec)
  local cls = rec.error_class and (" classe=" .. rec.error_class) or ""
  return string.format("[subagente %s status=%s agente=%s duracao=%s tools=%d%s]",
    rec.runId, rec.status, tostring(rec.agentId), duration(rec), count_tools(rec.runId), cls)
end

-- Injeta no contexto do pai as respostas finais. A TUI mostra a linha verde ou vermelha.
function M.inject(ctx)
  if not ctx or not ctx.msgs then return 0 end
  local n = 0
  for _, rec in ipairs(registry.list()) do
    if scheduler.is_terminal(rec) and not rec.announce_consumed and rec.parent_agent == ctx.agent_id then
      ctx.msgs[#ctx.msgs + 1] = {
        role = "system",
        content = header(rec) .. "\n" .. body(rec),
      }
      io.write(require("ui.subagent_block").end_line(rec), "\n")
      rec.announce_consumed, rec.announce_pending = true, false
      rec.announced_at = os.time()
      log.info("announce_delivered", { run_id = rec.runId, status = rec.status,
        result_chars = #body(rec) })
      registry.save(rec)
      n = n + 1
    end
  end
  io.flush()
  return n
end

return M
