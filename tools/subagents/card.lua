-- tools/subagents/card.lua — Cartão de detalhes de um subagente (subagents_info), no formato do OpenClaw:
-- status, tempos, runtime, notas e resultado truncado e redigido. Função pura: recebe os dados prontos.
local redact = require("tools.subagents.redact")
local M = {}

M.PREVIEW_CHARS = 400
M.TASK_CHARS    = 200
M.ERROR_CHARS   = 200

-- Corta em caracteres UTF-8 (não bytes). Devolve o texto e se cortou.
local function cut(s, max_chars)
  if utf8.len(s) == nil or utf8.len(s) <= max_chars then return s, false end
  return s:sub(1, utf8.offset(s, max_chars + 1) - 1), true
end
M.cut = cut

local function clock(t)
  if not t then return "—" end
  return os.date("%H:%M:%S", t)
end

local function duration(rec)
  if not rec.started_at then return "—" end
  return tostring((rec.finished_at or os.time()) - rec.started_at) .. "s"
end

-- Nomes de status no estilo do OpenClaw (timed out, em vez de timeout).
local STATUS = {
  completed = "completed", failed = "failed", timeout = "timed out", killed = "killed",
  running = "running", queued = "queued",
}

-- rec: registro do run. extra: tools (n), elapsed (s), last_event (texto), result (texto), events_path.
function M.build(rec, extra)
  extra = extra or {}
  local lines = {}
  local function add(label, value)
    lines[#lines + 1] = string.format("%-10s %s", label .. ":", value)
  end

  lines[#lines + 1] = "Subagente " .. tostring(rec.runId)
  add("Status", STATUS[rec.status] or tostring(rec.status or "unknown"))
  add("Agente", string.format("%s (pai: %s)", tostring(rec.agentId or "main"), tostring(rec.parent_agent or "main")))
  add("Tarefa", (cut(redact.clean(tostring(rec.task or "")), M.TASK_CHARS)))
  add("Tempo", string.format("criado %s · iniciado %s · terminado %s · duração %s",
    clock(rec.created_at), clock(rec.started_at), clock(rec.finished_at), duration(rec)))
  add("Runtime", string.format("tools=%d · prazo=%ss", extra.tools or 0, tostring(rec.timeout_seconds or "padrão")))
  add("Entregue", rec.announce_consumed and "sim" or "não")
  add("Limpeza", tostring(rec.cleanup or "retain"))

  if rec.error then
    local msg = cut(redact.clean(tostring(rec.error)), M.ERROR_CHARS)
    add("Erro", string.format("%s — %s", tostring(rec.error_class or "provider"), msg))
  end
  if rec.partial then
    add("Notes", "resultado parcial salvo antes do fim do run")
  end
  if rec.status == "running" or rec.status == "queued" then
    add("Progresso", string.format("decorrido %ss · tools=%d · último: %s",
      tostring(extra.elapsed or 0), extra.tools or 0, redact.clean(extra.last_event or "—")))
  end
  if extra.result and extra.result ~= "" then
    local shown, was_cut = cut(redact.clean(extra.result), M.PREVIEW_CHARS)
    local flag = was_cut and string.format(" [truncado: %d bytes no total]", #extra.result) or ""
    add("Resultado", shown .. flag)
  end
  if extra.events_path then
    add("Arquivos", "eventos: " .. extra.events_path)
  end
  if rec.usage then
    local u = rec.usage
    add("Tokens", string.format("entrada %d · saída %d · total %d (%d chamadas, somado por chamada)",
      u.prompt or 0, u.completion or 0, u.total or 0, u.calls or 0))
  else
    add("Tokens", "não registrados (sem uso reportado pelo provedor neste run)")
  end
  return table.concat(lines, "\n")
end

-- Cartão para um run que não existe no registro (retenção ou id errado).
function M.unknown(run_id)
  return table.concat({
    "Subagente " .. tostring(run_id),
    "Status:   unknown",
    "Notes:    run não encontrado no registro (removido pela retenção ou id errado).",
  }, "\n")
end

return M
