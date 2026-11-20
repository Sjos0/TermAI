local M = {}

local function transparency_enabled(ctx)
  local req = ctx.cfg and ctx.cfg.agents and ctx.cfg.agents.defaults
    and ctx.cfg.agents.defaults.request or {}
  return req.fallback_transparency ~= false
end

function M.redact_secret(utils, value, secret)
  if utils.redact_secret then return utils.redact_secret(value, secret) end
  return tostring(value or "")
end

function M.handle_sync_result(fb, ctx, role, result, rcfg, reasoning, tool_calls)
  if type(result) == "string" and result:match("^%[ERRO_OVERFLOW%]") then
    return result, true, false, reasoning
  end
  if type(result) == "string" and result:match("^%[ERRO DE COMUNICACAO%]") then
    local fallback, err = fb.tentar_fallbacks(ctx, role, result, rcfg)
    if fallback then return table.unpack(fallback, 1, fallback.n) end
    return fb.falha_final(ctx, rcfg, err or result)
  end
  return result, false, true, reasoning, tool_calls
end

function M.record(models_mod, active, success)
  if not active or not active.provider or not active.api_key_count
     or active.api_key_count < 1 then return end
  models_mod.record_api_key(active.provider, active.api_key_index, success)
end

function M.endpoint_label(active, utils)
  local endpoint = active and active.endpoint or ""
  local label = utils.redact_endpoint and utils.redact_endpoint(endpoint) or tostring(endpoint)
  if active and (active.api_key_count or 0) > 1 then
    label = label .. " [chave " .. tostring(active.api_key_index)
      .. "/" .. tostring(active.api_key_count) .. "]"
  end
  return label
end

function M.rotate(models_mod, ctx)
  local active = ctx.active
  local key, index, total = models_mod.rotate_api_key(
    active.provider, active.api_key_index)
  if not key then return false end
  local resolved = models_mod.resolve(active.ref)
  if not resolved then return false end
  ctx.active = resolved
  if transparency_enabled(ctx) then
    io.write("\n\27[38;5;220m[chave] " .. tostring(active.provider)
      .. ": chave " .. tostring(active.api_key_index) .. " falhou; usando chave "
      .. tostring(index) .. "/" .. tostring(total) .. ".\27[0m\n")
    io.flush()
  end
  return true
end

return M
