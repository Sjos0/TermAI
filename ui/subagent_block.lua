-- ui/subagent_block.lua — Subagente lançado aparece na TUI como uma linha amarela.
-- O término NÃO é impresso aqui: a linha verde (ou vermelha) sai junto com o aviso ao pai
-- (tools/subagents/announce.lua), no ponto em que o pai é acordado. Assim a bolinha verde
-- significa "terminou e o orquestrador foi avisado", não "o lançamento foi confirmado".
-- Só ACRESCENTA linhas: nunca sobe o cursor (no Termux a largura quebra linhas e o ESC[nA
-- deixava resíduos). Não mostra as tools internas do filho.
local core     = require("ui.core")
local registry = require("tools.subagents.registry")
local redact   = require("tools.subagents.redact")
local c        = core.c

local M = {}

local seen = {}                 -- runId -> true, já anunciado (amarela) nesta sessão
local baselined = false
local DONE = { completed = true, failed = true, timeout = true, killed = true }

-- Texto curto em caracteres UTF-8 (não bytes), para não quebrar a linha.
local function trim(s, n)
  if utf8.len(s) == nil or utf8.len(s) <= n then return s end
  return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…"
end

-- Primeira chamada: runs que já existiam antes da TUI abrir não são anunciados de novo.
local function baseline(runs)
  for _, r in ipairs(runs) do seen[r.runId] = true end
  baselined = true
end

-- Linha de término: verde ao concluir, vermelha com o motivo. Usada no aviso ao pai.
function M.end_line(r)
  if r.status == "completed" then
    return c.green .. "⬤" .. c.reset .. " Subagente " .. r.runId .. c.gray
      .. " · concluído · resultado entregue ao orquestrador" .. c.reset
  end
  local why = r.status
  if r.status == "failed" then why = trim(redact.clean(r.error or "falhou"), 70) end
  return c.red .. "⬤" .. c.reset .. " Subagente " .. r.runId .. c.gray .. " · " .. why .. c.reset
end

-- Linhas amarelas de lançamento para o agente pai. Cada lançamento sai uma única vez.
function M.pending_lines(agent_id)
  local parent = agent_id or "main"
  local mine = {}
  for _, r in ipairs(registry.list()) do
    if (r.parent_agent or "main") == parent then mine[#mine + 1] = r end
  end
  if not baselined then baseline(mine); return {} end

  local out = {}
  for _, r in ipairs(mine) do
    if not seen[r.runId] then
      seen[r.runId] = true
      -- Só o lançamento é mostrado aqui; um run que já terminou antes de ser visto não é anunciado por aqui.
      if r.status == "running" or r.status == "queued" then
        out[#out + 1] = c.yellow .. "⬤" .. c.reset .. " Subagente " .. r.runId .. c.gray
          .. (r.origin == "user" and " · lançado pelo usuário · " or " · lançado pelo orquestrador · ") .. trim(redact.clean(r.task or ""), 50) .. c.reset
      end
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
