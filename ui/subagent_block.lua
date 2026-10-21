-- ui/subagent_block.lua — Bloco ao vivo dos subagentes, logo acima do prompt. Reescreve só quando muda.
local core      = require("ui.core")
local registry  = require("tools.subagents.registry")
local events    = require("tools.subagents.events")
local json      = require("json")
local c         = core.c

local M = {}

local MAX_ROWS = 5
local drawn = 0          -- linhas do bloco atualmente na tela
local last_text = nil    -- conteúdo da última escrita (evita redesenho à toa)

-- Texto curto (em caracteres UTF-8, não bytes) para não quebrar a linha.
local function trim(s, n)
  if utf8.len(s) == nil or utf8.len(s) <= n then return s end
  return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…"
end

-- Última ferramenta usada pelo subagente, lida do log de eventos.
local function last_tool(run_id)
  local lines = events.tail(run_id, 30)
  for i = #lines, 1, -1 do
    local ok, ev = pcall(json.decode, lines[i])
    if ok and type(ev) == "table" and ev.kind == "tool" and ev.text then return ev.text end
  end
  return nil
end

-- Linhas do bloco para o agente pai. Vazio quando não há subagente ativo.
function M.render(agent_id)
  local parent = agent_id or "main"
  local active, running, queued = {}, 0, 0
  for _, r in ipairs(registry.list()) do
    if (r.status == "running" or r.status == "queued") and (r.parent_agent or "main") == parent then
      active[#active + 1] = r
      if r.status == "running" then running = running + 1 else queued = queued + 1 end
    end
  end
  if #active == 0 then return {} end

  local rows = { c.yellow .. "⬤" .. c.reset .. c.bold .. " Subagentes" .. c.reset
    .. c.gray .. string.format(" · %d ativo(s) · %d na fila", running, queued) .. c.reset }
  for i, r in ipairs(active) do
    if i > MAX_ROWS then
      rows[#rows + 1] = c.gray .. string.format("  … +%d", #active - MAX_ROWS) .. c.reset
      break
    end
    local dot = r.status == "running" and c.yellow or c.gray
    local what = r.status == "queued" and "aguardando na fila" or (last_tool(r.runId) or "iniciando…")
    rows[#rows + 1] = string.format("  %s⬤%s %s · %s · %s", dot, c.reset,
      r.runId, tostring(r.agentId), trim(what, 48))
  end
  return rows
end

-- Desenha (ou redesenha no lugar) o bloco. prompt_visible: o cursor está na linha do prompt,
-- então o bloco é reescrito acima dela e o prompt é reimpresso.
function M.refresh(rows, prompt_visible, prompt_text)
  local text = table.concat(rows, "\n")
  if text == last_text then return false end
  last_text = text
  if drawn > 0 then io.write(string.format("\27[%dA\r\27[J", drawn)) end
  for _, row in ipairs(rows) do io.write(row, "\27[K\n") end
  drawn = #rows
  if prompt_visible and prompt_text then io.write(prompt_text) end
  io.flush()
  return true
end

-- Chamado quando o prompt termina: o bloco fica no histórico e o próximo começa do zero.
function M.finish()
  drawn, last_text = 0, nil
end

-- Linhas desenhadas agora (para testes).
function M.drawn_lines() return drawn end

return M
