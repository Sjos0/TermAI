-- Uma tentativa de stream: payload tmp, curl/buffer, consumo SSE e pós-processo.
local M = {}

function M.write_payload(tmp_path, pl)
  local tmp = io.open(tmp_path, "w")
  if not tmp then return false end
  tmp:write(pl)
  tmp:close()
  return true
end

function M.build_cmd(rcfg, ctx, utils, auth, tmp_path)
  if rcfg.request_mode == "buffer" then
    local wt = (rcfg.wait_timeout > 0) and rcfg.wait_timeout or 25
    return string.format(
      'sh %s/tools/timeout_wrapper.sh %d %d "%s" "%s" "%s" %s',
      utils.BASE, rcfg.timeout, wt, ctx.active.endpoint,
      ctx.active.auth_style or "", ctx.active.api_key or "", tmp_path)
  end
  return string.format(
    'curl -s -N --max-time %d --speed-time %d --speed-limit 1 -X POST "%s"%s'
    .. ' -H "Content-Type: application/json" -d @%s 2>/dev/null',
    rcfg.timeout, rcfg.idle_timeout, ctx.active.endpoint, auth, tmp_path)
end

function M.consume(h, ctx, deps)
  local json, ui, thinking_parser, tokens_mod, tool_parser =
    deps.json, deps.ui, deps.thinking_parser, deps.tokens_mod, deps.tool_parser
  local body, got_data, done_received, error_reason = "", false, false, nil
  local tc_acc, stream_fresh = {}, false
  local ok_stream, stream_err = pcall(function()
    for line in h:lines() do
      body = body .. line .. "\n"
      if line:match("^data: ") then
        local data = line:sub(7)
        if data == "[DONE]" then
          got_data, done_received = true, true
          return
        end
        local ok, chunk = pcall(json.decode, data)
        if ok and chunk then
          if chunk.error then
            error_reason = chunk.error.message or "API error"
            return
          end
          if not got_data then ui.stream_confirm() end
          got_data = true
          local tok_ok, fresh = tokens_mod.process_tokens(ctx, chunk)
          if tok_ok then stream_fresh = fresh end
          local choice = chunk.choices and chunk.choices[1]
          local delta = choice and choice.delta
          if delta then
            local r = delta.reasoning or delta.reasoning_content
            if r and r ~= "" then ui.stream_reasoning(r) end
            if delta.content and delta.content ~= "" then
              thinking_parser.feed(
                delta.content, ui.stream_reasoning, ui.stream_token)
            end
            if delta.tool_calls then
              for _, tcd in ipairs(delta.tool_calls) do
                tool_parser.feed(tc_acc, tcd)
              end
            end
          end
        end
      end
    end
  end)
  if not ok_stream and not error_reason then
    error_reason = "erro interno no streaming: " .. tostring(stream_err)
  end
  return {
    body = body,
    got_data = got_data,
    done_received = done_received,
    error_reason = error_reason,
    tc_acc = tc_acc,
    stream_fresh = stream_fresh,
  }
end

function M.pack_success(ctx, deps, result, close_ok)
  local ui, thinking_parser, tool_parser, utils =
    deps.ui, deps.thinking_parser, deps.tool_parser, deps.utils
  thinking_parser.flush(ui.stream_reasoning, ui.stream_token)
  local full, reasoning = ui.stream_end()
  for i, tc in ipairs(result.tc_acc) do
    if not tc.id or tc.id == "" then
      tc.id = "tc_" .. i .. "_" .. os.time()
    end
  end
  local tc_valid = tool_parser.filter(result.tc_acc)
  local tool_calls = tool_parser.parse(tc_valid)
  return full, reasoning, tc_valid, tool_calls,
    result.done_received or close_ok == true, result.stream_fresh
end

function M.handle_failure(ctx, deps, key_rotation, attempt, rcfg, body, error_reason)
  local ui, utils, error_log = deps.ui, deps.utils, deps.error_log
  ui.stream_end()
  if not error_reason then
    error_reason = error_log.extract_from_body(body:gsub("%s+$", ""))
  end
  local last_error = key_rotation.redact_secret(
    utils, error_reason or "Sem resposta do servidor", ctx.active.api_key)
  local retryable, http_status = true, nil
  if error_log.should_retry then
    retryable, http_status = error_log.should_retry(last_error, body)
  end
  if http_status then
    last_error = last_error .. " (HTTP " .. tostring(http_status) .. ")"
  end
  local endpoint_label = key_rotation.endpoint_label(ctx.active, utils)
  error_log.record(attempt, rcfg.max_retries, endpoint_label, last_error,
    key_rotation.redact_secret(utils, body, ctx.active and ctx.active.api_key))
  return last_error, retryable
end

function M.wait_retry(ctx, ui, utils, attempt, rcfg, last_error)
  local wait = utils.wait_time(attempt, rcfg)
  ui.kill_spinner()
  ui.show_retry(attempt, rcfg.max_retries, last_error, wait)
  require("tools.subagents.events").retry(
    ctx, attempt, rcfg.max_retries, last_error, wait)
  os.execute(string.format("sleep %d", wait))
  ui.restart_spinner()
end

return M
