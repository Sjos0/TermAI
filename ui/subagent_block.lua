-- ui/subagent_block.lua — Subagentes na TUI aparecem como uma tool: uma linha amarela ao iniciar
-- e uma linha verde (ou vermelha) ao terminar. Só ACRESCENTA linhas: nunca sobe o cursor nem
-- redesenha. No Termux a largura quebra linhas, então o antigo ESC[nA apagava o lugar errado
-- e deixava resíduos empilhados. Não mostra as tools internas do filho.
local core     = require("ui.core")
local registry = require("tools.subagents.registry")
local redact   = require("tools.subagents.redact")
local c        = core.c

local M = {}

local started, ended = {}, {}   -- runId -> true, já anunciados nesta sessão
local baselined = false
local DONE = { completed = true, failed = true, timeout = true, killed = true }

-- Texto curto em caracteres UTF-8 (não bytes), para não quebrar a linha.
local function trim(s, n)
  if utf8.len(s) == nil or utf8.len(s) <= n then return s end
  return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…"
end

-- Primeira chamada: runs que já existiam antes da TUI abrir não são anunciados de novo.
local function baseline(runs)
  for _, r in ipairs(runs) do
    started[r.runId] = true
    if DONE[r.status] then ended[r.runId] = true end
  end
  baselined = true
end

local function end_line(r)
  local id = r.runId
  if r.status == "completed" then
    return c.green .. "✓" .. c.reset .. " Subagente " .. id .. c.gray
      .. " · concluído · resultado já está no contexto do pai" .. c.reset
  end
  local why = r.status
  if r.status == "failed" then why = trim(redact.clean(r.error or "falhou"), 70) end
  return c.red .. "✗" .. c.reset .. " Subagente " .. id .. c.gray .. " · " .. why .. c.reset
end

-- Linhas novas para o agente pai. Cada evento sai uma única vez.
function M.pending_lines(agent_id)
  local parent = agent_id or "main"
  local mine = {}
  for _, r in ipairs(registry.list()) do
    if (r.parent_agent or "main") == parent then mine[#mine + 1] = r end
  end
  if not baselined then baseline(mine); return {} end

  local out = {}
  for _, r in ipairs(mine) do
    if not started[r.runId] and (r.status == "running" or r.status == "queued") then
      started[r.runId] = true
      out[#out + 1] = c.yellow .. "⬤" .. c.reset .. " Subagente " .. r.runId .. c.gray
        .. " · " .. trim(redact.clean(r.task or ""), 60) .. c.reset
    end
    if DONE[r.status] and not ended[r.runId] then
      started[r.runId], ended[r.runId] = true, true
      out[#out + 1] = end_line(r)
    end
  end
  return out
end

-- Escreve as linhas pendentes acima do prompt. Não escreve enquanto o usuário digita
-- (buffer_empty falso): as linhas ficam pendentes e saem quando o campo estiver vazio.
function M.flush(agent_id, buffer_empty, prompt_text)
  if buffer_empty == false then return false end
  local lines = M.pending_lines(agent_id)
  if #lines == 0 then return false end
  io.write("\r\27[K")
  for _, l in ipairs(lines) do io.write(l, "\27[K\n") end
  if prompt_text then io.write(prompt_text) end
  io.flush()
  return true
end

return M
