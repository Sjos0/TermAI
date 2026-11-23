return function(M, N)
  local fb = require("agent.api.request_stream.streamer.fallback")(M)
  local key_rotation = require("agent.api.request_stream.streamer.key_rotation")
  local key_attempts = require("agent.api.request_stream.streamer.key_attempts")
  local stream_attempt = require("agent.api.request_stream.streamer.stream_attempt")
  local json, ui, thinking_parser, utils, payload_mod, sync_mod, tool_parser, recovery, tokens_mod, error_log =
    N.json, N.ui, N.thinking_parser, N.utils, N.payload_mod, N.sync_mod,
    N.tool_parser, N.recovery, N.tokens_mod, N.error_log
  local deps = {
    json = json, ui = ui, thinking_parser = thinking_parser, utils = utils,
    tool_parser = tool_parser, tokens_mod = tokens_mod, error_log = error_log,
  }

  function M.pensar_stream(ctx, txt, role)
    local rcfg = utils.get_req_cfg(ctx)
    key_attempts.begin(ctx)
    local pl = payload_mod.build_payload(ctx, txt, role, true)
    if not pl then
      if txt ~= nil then table.remove(ctx.msgs) end
      return "[ERRO_OVERFLOW] Prompt excede a janela de contexto (local)", true, false, ""
    end
    local flag_path = (os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp")
      .. "/termai_stream.flag"
    os.remove(flag_path)
    local last_error
    local models_mod = require("models")
    local key_rounds = math.max(1, tonumber(ctx.active.api_key_count) or 0)
    rcfg.keys_total = key_rounds

    for key_round = 1, key_rounds do
      key_attempts.start_key(ctx, key_round)
      for attempt = 1, rcfg.max_retries do
        key_attempts.start_attempt(ctx, attempt)
        local auth = utils.build_auth(ctx.active)
        local tmp_path = utils.make_tmp_path()
        if not stream_attempt.write_payload(tmp_path, pl) then
          last_error = "não foi possível gravar payload temporário"
          break
        end
        local cmd = stream_attempt.build_cmd(rcfg, ctx, utils, auth, tmp_path)
        ui.stream_start()
        thinking_parser.reset()
        local h = io.popen(cmd)
        local result = stream_attempt.consume(h, ctx, deps)
        local close_ok = h:close()
        os.remove(tmp_path)

        if result.got_data then
          local full, reasoning, tc_valid, tool_calls, finished, stream_fresh =
            stream_attempt.pack_success(ctx, deps, result, close_ok)
          if full == "" and not tool_calls then
            if txt ~= nil then table.remove(ctx.msgs) end
            local sync_r, _, sync_tc = sync_mod.pensar_sync(ctx, txt, role)
            utils.ensure_tokens(ctx)
            key_attempts.end_key(ctx)
            key_attempts.finish(ctx, key_rounds)
            if ctx.tokens_fresh == nil then ctx.tokens_fresh = stream_fresh end
            return key_rotation.handle_sync_result(
              fb, ctx, role, sync_r, rcfg, reasoning, sync_tc)
          end
          key_attempts.end_key(ctx)
          key_attempts.finish(ctx, key_rounds)
          key_rotation.record(models_mod, ctx.active, true)
          local asst = { role = "assistant", content = full ~= "" and full or "" }
          if reasoning and reasoning ~= "" then asst.reasoning = reasoning end
          if #tc_valid > 0 then asst.tool_calls = tool_parser.raw(tc_valid) end
          table.insert(ctx.msgs, asst)
          utils.ensure_tokens(ctx)
          ctx.tokens_fresh = stream_fresh
          return full, false, finished, reasoning, tool_calls
        end

        local retryable
        last_error, retryable = stream_attempt.handle_failure(
          ctx, deps, key_rotation, attempt, rcfg, result.body, result.error_reason)
        if utils.is_overflow_error(last_error) then
          if txt ~= nil then table.remove(ctx.msgs) end
          return "[ERRO_OVERFLOW] " .. last_error, true, false, ""
        end
        if not retryable then
          ui.kill_spinner()
          if ui.clear_retry_lines then ui.clear_retry_lines() end
          break
        end
        if attempt < rcfg.max_retries then
          stream_attempt.wait_retry(ctx, ui, utils, attempt, rcfg, last_error)
        else
          ui.kill_spinner()
          if ui.clear_retry_lines then ui.clear_retry_lines() end
        end
      end

      key_attempts.end_key(ctx)
      key_rotation.record(models_mod, ctx.active, false)
      if key_round < key_rounds then
        if not key_rotation.rotate(models_mod, ctx) then break end
      end
    end

    key_attempts.finish(ctx, key_rounds)
    local fb_res, fb_err = fb.tentar_fallbacks(ctx, role, last_error, rcfg)
    if fb_res then return table.unpack(fb_res, 1, fb_res.n) end
    last_error = fb_err
    return fb.falha_final(ctx, rcfg, last_error)
  end
end
