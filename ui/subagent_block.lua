-- ui/subagent_block.lua — Avisos de subagentes na TUI, no estilo do OpenClaw.
-- Sem rótulo de origem e sem linha de lançamento: o lançamento já aparece no card da tool
-- (sessions_spawn). Aqui sai só o aviso de término, uma linha de sistema, cortada na largura da tela.
local core     = require("ui.core")
local header   = require("ui.tools_init.header")
local redact   = require("tools.subagents.redact")
local registry = require("tools.subagents.registry")
local c        = core.c

local M = {}

-- O lançamento não gera linha própria: o card da tool já mostra.
function M.pending_lines(_) return {} end

-- Mantido para compatibilidade com o main_loop: nada a desenhar fora do aviso de término.
function M.flush(_, _, _) return false end

local function one_line(text)
  local s = (text or ""):gsub("%s+", " ")
  return redact.clean(s)
end

-- Linha de sistema do término. Concluído: prévia do resultado. Falha ou prazo: motivo curto.
function M.end_line(r)
  local tw = core.tw()
  local plain, color
  if r.status == "completed" then
    local p = header.cut_cols(one_line(registry.read_result(r.runId) or ""), 60)
    plain = "── " .. r.runId .. " concluído" .. (p ~= "" and (" · " .. p) or "") .. " ──"
    color = c.gray
  else
    local why = header.cut_cols(one_line(r.error or r.status), 60)
    local verb = (r.status == "timeout") and "estourou o prazo" or "falhou"
    plain = "── " .. r.runId .. " " .. verb .. " · " .. why .. " ──"
    color = c.red
  end
  return color .. header.cut_cols(plain, tw - 1) .. c.reset
end

return M
