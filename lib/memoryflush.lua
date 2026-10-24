-- memoryflush.lua — Fachada do sistema de Memory Flush do TermAI.
-- v3: Refatorado para o padrão Facade + Domain.
local mf = {}

local state_mod     = require("memoryflush.state")
local checker_mod   = require("memoryflush.checker")
local prompt_mod    = require("memoryflush.prompt")
local formatter_mod = require("memoryflush.formatter")

-- ── Estado e Checkpoints ───────────────────────────────────────────────────
function mf.init(agent_base, agent_id)
  state_mod.init(agent_base, agent_id)
end

function mf.get_state_file() return state_mod.get_state_file() end
function mf.get_agent_id()   return state_mod.get_agent_id()   end

function mf.marcar_flush(tokens)
  state_mod.marcar_flush(tokens)
end

-- ── Limiares Lógicos ───────────────────────────────────────────────────────
function mf.deve_flush(tokens, config)
  return checker_mod.deve_flush(tokens, config)
end

function mf.deve_compactar(tokens, config)
  return checker_mod.deve_compactar(tokens, config)
end

function mf.proximo_flush(tokens, config)
  return checker_mod.proximo_flush(tokens, config)
end

-- ── Prompts e Formatação ───────────────────────────────────────────────────
function mf.get_flush_prompt(config)
  return prompt_mod.get_flush_prompt(config)
end

function mf.compactar_msgs(msgs)
  return formatter_mod.compactar_msgs(msgs)
end

function mf.estado(tokens, config)
  return formatter_mod.estado(tokens, config)
end

return mf
