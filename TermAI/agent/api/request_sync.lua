-- request_sync.lua — Request síncrono à API com retry e backoff.
-- v2: detecta tool_calls na resposta (3º valor); suporte a txt=nil.
-- v4: propaga tokens_fresh via ctx.tokens_fresh (T5: TFA-001-R3).
local json        = require("json")
local utils       = require("agent.api.utils")
local payload_mod = require("agent.api.payload")
local M = {}

function M.pensar_sync(ctx, txt, role)
  local rcfg = utils.get_req_cfg(ctx)
  local pl   = payload_mod.build_payload(ctx, txt, role, false)
  local auth = utils.build_auth(ctx.active)

  if not pl then
    if txt ~= nil then table.remove(ctx.msgs) end  -- v2: só remove se inseriu
    return "[ERRO_OVERFLOW] Prompt excede a janela de contexto (local)", "", nil
  end

  for i = 1, rcfg.max_retries do
    local tmp_path = utils.make_tmp_path()
    local tmp = io.open(tmp_path, "w"); tmp:write(pl); tmp:close()

    local cmd = string.format(
      'curl -s --max-time %d --speed-time %d --speed-limit 1 -X POST "%s"%s'
      .. ' -H "Content-Type: application/json" -d @%s 2>/dev/null',
      rcfg.timeout, rcfg.idle_timeout, ctx.active.endpoint, auth, tmp_path)

    local h = io.popen(cmd)
    local r = h:read("*a"); h:close()
    os.remove(tmp_path)

    local ok, rep = pcall(json.decode, r)
    if ok and rep and rep.choices and rep.choices[1] then
      local sync_fresh = false  -- T5: assume não confiável até provider confirmar

      if rep.usage and rep.usage.total_tokens then
        local new_tok = rep.usage.total_tokens
        local prev_tok = ctx.tokens or 0
        if prev_tok > 0 and new_tok < prev_tok * 0.5 then
          sync_fresh = false  -- T5: sanity check bloqueou
          io.write(string.format(
            "\27[38;5;240m[token-debug] Queda suspeita (sync): provider=%d prev=%d est=%d — mantendo anterior\27[0m\n",
            new_tok, prev_tok, utils.estimate_tokens(ctx.msgs)))
        else
          ctx.tokens = new_tok
          sync_fresh = true   -- T5: sanity check passou
        end
      end
      utils.ensure_tokens(ctx)
      ctx.tokens_fresh = sync_fresh  -- T5: propaga freshness pro contexto

      local msg     = rep.choices[1].message
      local content = utils.strip_thinking_tags(msg.content or "")

      -- v2: parseia tool_calls da resposta síncrona
      local tool_calls = nil
      if msg.tool_calls and #msg.tool_calls > 0 then
        tool_calls = {}
        for _, tc in ipairs(msg.tool_calls) do
          local fn      = tc["function"] or {}
          local ok_j, a = pcall(json.decode,
            (fn.arguments and fn.arguments ~= "") and fn.arguments or "{}")
          tool_calls[#tool_calls + 1] = {
            id   = tc.id or "",
            name = fn.name or "",
            args = (ok_j and type(a) == "table") and a or {},
          }
        end
      end

      local asst = {role = "assistant", content = content}
      if msg.tool_calls then asst.tool_calls = msg.tool_calls end
      table.insert(ctx.msgs, asst)
      return content, "", tool_calls
    end
    if i < rcfg.max_retries then
      os.execute(string.format("sleep %d", utils.wait_time(i, rcfg)))
    end
  end
  return "[ERRO DE COMUNICACAO]", "", nil
end

return M
