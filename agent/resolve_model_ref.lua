-- agent/resolve_model_ref.lua — Resolução em camadas do ref de modelo (Issue #373).
-- Pura: recebe cfg + opts e devolve ref, source e lista de fallbacks a usar.
-- Não chama models.resolve (fica no caller) para facilitar testes unitários.
local M = {}

local function nonempty(s)
  return type(s) == "string" and s:match("%S") ~= nil
end

-- Normaliza borda: "" / só espaços → nil.
function M.normalize_model(ref)
  if type(ref) ~= "string" then return nil end
  if ref:match("^%s*$") then return nil end
  return ref
end

-- sources: tabela opcional com candidatas já resolvidas pelo caller (para testes).
-- Se resolve_fn for fornecido, tenta cada candidato até um resolver.
-- Retorno: ref, source ("spawn"|"agent_list"|"subagents_default"|"global"), fallbacks
function M.resolve(opts, cfg, resolve_fn)
  opts = opts or {}
  cfg = cfg or {}
  local defaults = (cfg.agents and cfg.agents.defaults) or {}
  local global_model = defaults.model or {}
  local sub_block = defaults.subagents or {}
  local sub_model = sub_block.model or {}

  local candidates = {}

  if opts.is_subagent then
    local spawn_ref = M.normalize_model(opts.model)
    if spawn_ref then
      candidates[#candidates + 1] = { ref = spawn_ref, source = "spawn" }
    end

    -- Prioridade 2: agents.list[agentId].model.primary (ativa dead config).
    local agent_id = opts.agent_id
    if type(agent_id) == "string" and agent_id ~= "" then
      local list = (cfg.agents and cfg.agents.list) or {}
      for _, entry in ipairs(list) do
        if entry.id == agent_id then
          local ap = entry.model and entry.model.primary
          if nonempty(ap) then
            candidates[#candidates + 1] = { ref = ap, source = "agent_list" }
          end
          break
        end
      end
    end

    if nonempty(sub_model.primary) then
      candidates[#candidates + 1] = { ref = sub_model.primary, source = "subagents_default" }
    end

    if nonempty(global_model.primary) then
      candidates[#candidates + 1] = { ref = global_model.primary, source = "global" }
    end
  else
    local explicit = M.normalize_model(opts.model)
    if explicit then
      candidates[#candidates + 1] = { ref = explicit, source = "spawn" }
    end
    if nonempty(global_model.primary) then
      candidates[#candidates + 1] = { ref = global_model.primary, source = "global" }
    end
  end

  local chosen_ref, chosen_source
  for _, c in ipairs(candidates) do
    if resolve_fn then
      local ok = resolve_fn(c.ref)
      if ok then
        chosen_ref, chosen_source = c.ref, c.source
        break
      end
    else
      chosen_ref, chosen_source = c.ref, c.source
      break
    end
  end

  -- Fallbacks: subagente usa lista própria se não-vazia; senão herda global.
  local fallbacks
  if opts.is_subagent then
    local sub_fb = sub_model.fallbacks
    if type(sub_fb) == "table" and #sub_fb > 0 then
      fallbacks = sub_fb
    else
      fallbacks = global_model.fallbacks or {}
    end
  else
    fallbacks = global_model.fallbacks or {}
  end

  return chosen_ref, chosen_source, fallbacks
end

return M
