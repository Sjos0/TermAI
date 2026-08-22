-- agent/api/request_stream/streamer.lua — Core loop do HTTP streaming com suporte a SSE.
local json            = require("json")
local ui              = require("ui")
local thinking_parser = require("ui.thinking_parser")
local utils           = require("agent.api.utils")
local payload_mod     = require("agent.api.payload")
local sync_mod        = require("agent.api.request_sync")
local tool_parser     = require("agent.api.request_stream.tool_parser")
local recovery        = require("agent.api.request_stream.recovery")
local tokens_mod      = require("agent.api.request_stream.tokens")
local error_log       = require("agent.api.request_stream.error_log")

local M = {}

function M.pensar_stream(ctx, txt, role)
  local rcfg = utils.get_req_cfg(ctx)
  local pl   = payload_mod.build_payload(ctx, txt, role, true)
  local auth = utils.build_auth(ctx.active)

  if not pl then
    if txt ~= nil then table.remove(ctx.msgs) end
    return "[ERRO_OVERFLOW] Prompt excede a janela de contexto (local)", true, false, ""
  end

  local flag_path = (os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp") .. "/termai_stream.flag"
  os.remove(flag_path)

  local last_error
  for attempt = 1, rcfg.max_retries do
    local tmp_path = utils.make_tmp_path()
    local tmp = io.open(tmp_path, "w"); tmp:write(pl); tmp:close()

    local cmd
    if rcfg.request_mode == "buffer" then
      local wt = (rcfg.wait_timeout > 0) and rcfg.wait_timeout or 25
      cmd = string.format('sh %s/tools/timeout_wrapper.sh %d %d "%s" "%s" "%s" %s',
        utils.BASE, rcfg.timeout, wt, ctx.active.endpoint,
        ctx.active.auth_style or "", ctx.active.api_key or "", tmp_path)
    else
      cmd = string.format(
        'curl -s -N --max-time %d --speed-time %d --speed-limit 1 -X POST "%s"%s'
        .. ' -H "Content-Type: application/json" -d @%s 2>/dev/null',
        rcfg.timeout, rcfg.idle_timeout, ctx.active.endpoint, auth, tmp_path)
    end

    ui.stream_start()
    thinking_parser.reset()

    local h     = io.popen(cmd)
    local body  = ""
    local got_data, done_received, error_reason = false, false, nil
    local tc_acc = {}
    local stream_fresh = false

    for line in h:lines() do
      body = body .. line .. "\n"
      if line:match("^data: ") then
        local data = line:sub(7)
        if data == "[DONE]" then got_data = true; done_received = true; break end
        local ok, chunk = pcall(json.decode, data)
        if ok and chunk then
          if chunk.error then error_reason = chunk.error.message or "API error"; break end
          if not got_data then ui.stream_confirm() end
          got_data = true

          local tok_ok, fresh = tokens_mod.process_tokens(ctx, chunk)
          if tok_ok then stream_fresh = fresh end

          local choice = chunk.choices and chunk.choices[1]
          local delta  = choice and choice.delta
          if delta then
            local r = delta.reasoning or delta.reasoning_content
            if r and r ~= "" then ui.stream_reasoning(r) end
            if delta.content and delta.content ~= "" then
              thinking_parser.feed(delta.content, ui.stream_reasoning, ui.stream_token)
            end
            if delta.tool_calls then
              for _, tcd in ipairs(delta.tool_calls) do tool_parser.feed(tc_acc, tcd) end
            end
          end
        end
      end
    end
    -- Curl que sai com código 0 fechou a conexão de forma limpa — mesmo sem
    -- o sentinela "[DONE]" explícito, a resposta está completa. Só um exit
    -- não-zero (ex: 28 = timeout do --max-time) indica corte de verdade.
    local close_ok = h:close()
    os.remove(tmp_path)

    if got_data then
      thinking_parser.flush(ui.stream_reasoning, ui.stream_token)
      local full, reasoning = ui.stream_end()

      for i, tc in ipairs(tc_acc) do
        if not tc.id or tc.id == "" then tc.id = "tc_" .. i .. "_" .. os.time() end
      end

      local tc_valid   = tool_parser.filter(tc_acc)
      local tool_calls = tool_parser.parse(tc_valid)

      if full == "" and not tool_calls then
        local stream_reasoning = reasoning
        if txt ~= nil then table.remove(ctx.msgs) end
        local sync_r, _, sync_tc = sync_mod.pensar_sync(ctx, txt, role)
        utils.ensure_tokens(ctx)
        if ctx.tokens_fresh == nil then ctx.tokens_fresh = stream_fresh end
        return sync_r, false, true, stream_reasoning, sync_tc
      end

      local asst = {role = "assistant", content = full ~= "" and full or ""}
      if reasoning and reasoning ~= "" then asst.reasoning = reasoning end
      if #tc_valid > 0 then asst.tool_calls = tool_parser.raw(tc_valid) end
      table.insert(ctx.msgs, asst)
      utils.ensure_tokens(ctx)
      ctx.tokens_fresh = stream_fresh
      local stream_finished = done_received or close_ok == true
      return full, false, stream_finished, reasoning, tool_calls
    end

    ui.stream_end()
    if not error_reason then
      error_reason = error_log.extract_from_body(body:gsub("%s+$", ""))
    end

    last_error = error_reason or "Sem resposta do servidor"
    -- Persiste o corpo bruto em disco: o terminal rola e perde o erro, e a
    -- mensagem exibida na TUI (last_error) é só um resumo de uma linha.
    error_log.record(attempt, rcfg.max_retries, ctx.active and ctx.active.endpoint, last_error, body)
    if utils.is_overflow_error(last_error) then
      if txt ~= nil then table.remove(ctx.msgs) end
      return "[ERRO_OVERFLOW] " .. last_error, true, false, ""
    end

    if attempt < rcfg.max_retries then
      local wait = utils.wait_time(attempt, rcfg)
      ui.kill_spinner()
      ui.show_retry(attempt, rcfg.max_retries, last_error, wait)
      os.execute(string.format("sleep %d", wait))
      ui.restart_spinner()
    else
      ui.kill_spinner()
      ui.show_retry(attempt, rcfg.max_retries, last_error, 0)
    end
  end

  -- Não removemos a mensagem do usuário aqui: falha de rede não pode apagar
  -- o que ela digitou. Fica em ctx.msgs e é salva normalmente pelo
  -- persistence.save_exchange no final do turno em main_loop.lua.
  recovery.recover_tool_seq(ctx.msgs)
  -- done_flag = nil (não false): não houve stream nenhum pra ficar
  -- incompleto — a requisição inteira falhou. Retornar false aqui fazia
  -- main_loop.lua mostrar "Resposta incompleta — stream cortado", que é
  -- enganoso quando não existe resposta nenhuma pra truncar.
  return "[ERRO] Falha apos " .. rcfg.max_retries .. " tentativas - " .. last_error, false, nil, ""
end

return M
