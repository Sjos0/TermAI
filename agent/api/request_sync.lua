-- Request síncrono: mantém a mesma política de retry e Micro Fallback do streaming.
local json        = require("json")
local utils       = require("agent.api.utils")
local payload_mod = require("agent.api.payload")
local error_log   = require("agent.api.request_stream.error_log")
local key_rotation = require("agent.api.request_stream.streamer.key_rotation")
local M = {}

local function response_error(rep, decode_error)
  if type(rep) == "table" and rep.error then
    local err = rep.error
    if type(err) == "table" then return err.message or err.code or "Erro do provedor" end
    return tostring(err)
  end
  return decode_error or "Resposta síncrona sem choices"
end

function M.pensar_sync(ctx, txt, role)
  local rcfg = utils.get_req_cfg(ctx)
  local pl = payload_mod.build_payload(ctx, txt, role, false)
  if not pl then
    if txt ~= nil then table.remove(ctx.msgs) end
    return "[ERRO_OVERFLOW] Prompt excede a janela de contexto (local)", "", nil
  end

  local models_mod = require("models")
  local key_rounds = math.max(1, tonumber(ctx.active.api_key_count) or 0)
  local last_error
  for key_round = 1, key_rounds do
    for attempt = 1, rcfg.max_retries do
      local auth = utils.build_auth(ctx.active)
      local tmp_path = utils.make_tmp_path()
      local tmp = io.open(tmp_path, "w"); tmp:write(pl); tmp:close()
      local cmd = string.format(
        'curl -s --max-time %d --speed-time %d --speed-limit 1 -X POST "%s"%s'
        .. ' -H "Content-Type: application/json" -d @%s 2>/dev/null',
        rcfg.timeout, rcfg.idle_timeout, ctx.active.endpoint, auth, tmp_path)
      local h = io.popen(cmd)
      local body = h and h:read("*a") or ""
      if h then h:close() end
      os.remove(tmp_path)

      local ok, rep = pcall(json.decode, body)
      if ok and rep and rep.choices and rep.choices[1] then
        key_rotation.record(models_mod, ctx.active, true)
        if rep.usage then ctx.usage_acc = require("agent.api.usage").add(ctx.usage_acc, rep.usage) end
        local sync_fresh = false
        if rep.usage and rep.usage.total_tokens then
          local new_tok, prev_tok = rep.usage.total_tokens, ctx.tokens or 0
          if prev_tok == 0 or new_tok >= prev_tok * 0.5 then
            ctx.tokens, sync_fresh = new_tok, true
          else
            io.write(string.format(
              "\27[38;5;240m[token-debug] Queda suspeita (sync): provider=%d prev=%d est=%d — mantendo anterior\27[0m\n",
              new_tok, prev_tok, utils.estimate_tokens(ctx.msgs)))
          end
        end
        utils.ensure_tokens(ctx)
        ctx.tokens_fresh = sync_fresh
        local msg = rep.choices[1].message or {}
        local content = utils.strip_thinking_tags(msg.content or "")
        local tool_calls
        if msg.tool_calls and #msg.tool_calls > 0 then
          tool_calls = {}
          for _, tc in ipairs(msg.tool_calls) do
            local fn = tc["function"] or {}
            local ok_j, args = pcall(json.decode,
              (fn.arguments and fn.arguments ~= "") and fn.arguments or "{}")
            tool_calls[#tool_calls + 1] = {
              id = tc.id or "", name = fn.name or "",
              args = (ok_j and type(args) == "table") and args or {},
            }
          end
        end
        local asst = { role = "assistant", content = content }
        if msg.tool_calls then asst.tool_calls = msg.tool_calls end
        table.insert(ctx.msgs, asst)
        return content, "", tool_calls
      end

      local decode_error = not ok and tostring(rep) or nil
      last_error = utils.redact_secret(response_error(rep, decode_error), ctx.active.api_key)
      local retryable, http_status = true, nil
      if error_log.should_retry then
        retryable, http_status = error_log.should_retry(last_error, body)
      end
      if http_status then last_error = last_error .. " (HTTP " .. tostring(http_status) .. ")" end
      error_log.record(attempt, rcfg.max_retries,
        key_rotation.endpoint_label(ctx.active, utils), last_error,
        utils.redact_secret(body, ctx.active.api_key))
      if not retryable then break end
      if attempt < rcfg.max_retries then
        os.execute(string.format("sleep %d", utils.wait_time(attempt, rcfg)))
      end
    end
    key_rotation.record(models_mod, ctx.active, false)
    if key_round < key_rounds and not key_rotation.rotate(models_mod, ctx) then break end
  end
  return "[ERRO DE COMUNICACAO] " .. tostring(last_error or "Sem resposta do servidor"), "", nil
end

return M
