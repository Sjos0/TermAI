package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/resolve_model_ref_spec.lua — Matriz de resolução de modelo para subagentes (#373).

local R = require("agent.resolve_model_ref")
local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local function always_ok(ref) return true end
local function only(allowed)
  local set = {}
  for _, r in ipairs(allowed) do set[r] = true end
  return function(ref) return set[ref] == true end
end

local cfg = {
  agents = {
    defaults = {
      model = { primary = "global/strong", fallbacks = { "global/fb1" } },
      subagents = {
        model = { primary = "sub/fast", fallbacks = { "sub/fb1" } },
      },
    },
    list = {
      { id = "main", model = { primary = "" } },
      { id = "researcher", model = { primary = "agent/specialist" } },
    },
  },
}

-- 1) spawn override vence tudo
do
  local ref, src, fb = R.resolve(
    { is_subagent = true, model = "spawn/override", agent_id = "researcher" }, cfg, always_ok)
  check(ref == "spawn/override" and src == "spawn", "spawn override tem prioridade")
  check(fb[1] == "sub/fb1", "fallbacks próprios do subagente")
end

-- 2) agent list quando sem spawn e kind==agente
do
  local ref, src = R.resolve(
    { is_subagent = true, model = nil, agent_id = "researcher", kind = "agente" }, cfg, always_ok)
  check(ref == "agent/specialist" and src == "agent_list", "agents.list[].model.primary ativo (kind=agente)")
end

-- 2b) clone NÃO usa list[].model.primary do pai
do
  local ref, src = R.resolve(
    { is_subagent = true, model = nil, agent_id = "researcher", kind = "clone" }, cfg, always_ok)
  check(ref == "sub/fast" and src == "subagents_default", "clone ignora list primary do pai")
end

-- 3) subagents default quando list sem primary
do
  local ref, src = R.resolve(
    { is_subagent = true, model = nil, agent_id = "main" }, cfg, always_ok)
  check(ref == "sub/fast" and src == "subagents_default", "subagents.model.primary")
end

-- 4) global quando sem bloco subagents.model.primary
do
  local cfg2 = {
    agents = {
      defaults = {
        model = { primary = "global/strong", fallbacks = { "global/fb1" } },
        subagents = { model = { primary = "", fallbacks = {} } },
      },
      list = { { id = "main", model = { primary = "" } } },
    },
  }
  local ref, src, fb = R.resolve({ is_subagent = true, agent_id = "main" }, cfg2, always_ok)
  check(ref == "global/strong" and src == "global", "herda primary global")
  check(fb[1] == "global/fb1", "fallbacks herdam global quando lista sub vazia")
end

-- 5) string vazia no spawn não vence
do
  local ref, src = R.resolve(
    { is_subagent = true, model = "", agent_id = "main" }, cfg, always_ok)
  check(ref == "sub/fast" and src == "subagents_default", "\"\" normalizado → cai no default sub")
  check(R.normalize_model("") == nil, "normalize_model(\"\") == nil")
  check(R.normalize_model("   ") == nil, "normalize_model espaços == nil")
end

-- 6) candidato inválido pula para o próximo
do
  local ref, src = R.resolve(
    { is_subagent = true, model = "spawn/bad", agent_id = "researcher", kind = "agente" },
    cfg, only({ "agent/specialist", "sub/fast", "global/strong" }))
  check(ref == "agent/specialist" and src == "agent_list", "skip inválido do spawn")
end

-- 7) não-subagente: só explicit + global
do
  local ref, src = R.resolve({ model = nil }, cfg, always_ok)
  check(ref == "global/strong" and src == "global", "chat usa primary global")
end

-- 8) compat: sem bloco subagents
do
  local cfg3 = {
    agents = {
      defaults = { model = { primary = "global/strong", fallbacks = {} } },
      list = {},
    },
  }
  local ref, src = R.resolve({ is_subagent = true }, cfg3, always_ok)
  check(ref == "global/strong" and src == "global", "config legada sem subagents.model")
end

if failures > 0 then
  print(failures .. " falha(s)")
  os.exit(1)
end
print("todos os testes passaram")
