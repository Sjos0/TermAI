-- memoryflush/formatter.lua — Compactação e estado final voltados para exibição.
local M = {}
local state_mod   = require("memoryflush.state")
local checker_mod = require("memoryflush.checker")

function M.compactar_msgs(msgs)
  if #msgs <= 4 then return msgs end
  local nova   = {msgs[1]}
  local inicio = math.max(2, math.floor(#msgs / 2))
  if inicio <= #msgs and msgs[inicio].role == "assistant" then inicio = inicio + 1 end
  for i = inicio, #msgs do nova[#nova + 1] = msgs[i] end
  return nova
end

function M.estado(tokens, config)
  local state_file = state_mod.get_state_file()
  local agent_id   = state_mod.get_agent_id()
  local limite     = (config.limites and config.limites.flush_tokens) or 40000
  local ultimo     = state_mod.get_ultimo(tokens)
  local proximo    = checker_mod.proximo_flush(tokens, config)
  return {
    agent_id   = agent_id,
    state_file = state_file,
    ultimo     = ultimo,
    proximo    = proximo,
    faltam     = math.max(0, proximo - tokens),
    limite     = limite,
    enabled    = config.limites and config.limites.flush_enabled ~= false,
  }
end

return M
