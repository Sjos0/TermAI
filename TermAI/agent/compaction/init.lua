-- compaction/init.lua — Fachada da compactação com LLM (State Reset).
-- v7: detecta corte no meio de um turno gigante e gera 2 resumos
-- separados + merge (REQ-2 → splitturn.lua). Mantém tudo do v6: teto de
-- tokens = max_tokens do modelo (REQ-6), geração+confirmação em turnos
-- separados sem ferramentas (REQ-8 → confirm.lua), corte por tokens
-- (REQ-1 → cutpoint.lua), merge com resumo anterior + foco customizável
-- (REQ-3/11 → summary_merge.lua), file tracking cumulativo (REQ-5 →
-- filetracking.lua), poda mecânica sem LLM (REQ-10 → poda.lua) e guarda
-- anti-thrashing (REQ-9). Streaming ao vivo mantido.
local api            = require("agent.api")
local session        = require("session")
local mf             = require("memoryflush")
local cutpoint       = require("agent.compaction.cutpoint")
local poda           = require("agent.compaction.poda")
local serialize      = require("agent.compaction.serialize")
local summary_merge  = require("agent.compaction.summary_merge")
local filetracking   = require("agent.compaction.filetracking")
local confirm        = require("agent.compaction.confirm")
local splitturn      = require("agent.compaction.splitturn")
local M = {}

local MAX_TENTATIVAS_SEM_PROGRESSO <const> = 2
local CUSTOM_INSTRUCTIONS_MAX_CHARS <const> = 500

function M.get_mf_config(ctx)
  local c = ctx.compaction or {}
  return {
    max_contexto = ctx.active.context_window,
    limites = {
      flush_tokens    = c.flush_tokens    or 40000,
      compactacao_pct = c.compactacao_pct or 0.9,
      reserve_tokens  = c.reserve_tokens  or 16384,
      flush_prompt    = c.flush_prompt    or "",
      flush_enabled   = c.flush_enabled,
    }
  }
end

local function sanitize_roles(msgs)
  local clean = {}
  for _, m in ipairs(msgs) do
    if #clean == 0 then
      clean[#clean + 1] = { role = m.role, content = m.content, tool_calls = m.tool_calls, tool_call_id = m.tool_call_id, reasoning = m.reasoning, pasted_texts = m.pasted_texts }
    else
      local last = clean[#clean]
      if last.role == m.role and not last.tool_calls and not m.tool_calls then
        last.content = last.content .. "\n\n" .. (m.content or "")
      else
        clean[#clean + 1] = { role = m.role, content = m.content, tool_calls = m.tool_calls, tool_call_id = m.tool_call_id, reasoning = m.reasoning, pasted_texts = m.pasted_texts }
      end
    end
  end
  return clean
end

function M.poda_mecanica(ctx)
  local c = ctx.compaction or {}
  local ok = poda.poda_mecanica(
    ctx.msgs,
    c.keep_recent_tokens or 20000,
    c.poda_max_chars or 500,
    api.estimate_tokens
  )
  if ok then
    ctx.tokens = api.estimate_tokens(ctx.msgs)
  end
  return ok
end

function M.do_compaction(ctx, custom_instructions)
  local tokens_before = ctx.tokens
  local c = ctx.compaction or {}

  if custom_instructions and #custom_instructions > CUSTOM_INSTRUCTIONS_MAX_CHARS then
    custom_instructions = custom_instructions:sub(1, CUSTOM_INSTRUCTIONS_MAX_CHARS)
  end

  local safe_start, safe_end = cutpoint.find_compaction_bounds(ctx.msgs, {
    anchor_keep        = c.anchor_keep or 5,
    anchor_token_cap   = c.anchor_token_cap or 8000,
    keep_recent_tokens = c.keep_recent_tokens or 20000,
  }, api.estimate_tokens)
  if not safe_start then return false, safe_end end

  local discarded = {}
  for i = safe_start + 1, safe_end - 1 do
    if ctx.msgs[i] then discarded[#discarded + 1] = ctx.msgs[i] end
  end
  if #discarded == 0 then return false, "short_history" end

  local prev_summary, prev_details = summary_merge.get_previous(session)

  local compaction_active = ctx.active
  if c.compaction_model then
    compaction_active = {}
    for k, v in pairs(ctx.active) do compaction_active[k] = v end
    compaction_active.model_id = c.compaction_model
  end
  -- REQ-6: teto do resumo = max_tokens do modelo configurado.
  if c.compaction_max_tokens then
    compaction_active.max_tokens = c.compaction_max_tokens
  end

  local function build_summary_prompt(serialized)
    return summary_merge.build_prompt(serialized, prev_summary, custom_instructions)
  end

  -- REQ-2: se safe_end cai no meio de um turno (não é um "user" limpo),
  -- separa em história completa + início do turno cortado, e gera os
  -- dois resumos separadamente.
  local turn_start = splitturn.find_turn_start(ctx.msgs, safe_end, safe_start)
  local processed_summary, confirmado

  if turn_start < safe_end then
    local history_msgs, prefix_msgs = {}, {}
    for i = safe_start + 1, turn_start - 1 do history_msgs[#history_msgs + 1] = ctx.msgs[i] end
    for i = turn_start, safe_end - 1 do prefix_msgs[#prefix_msgs + 1] = ctx.msgs[i] end
    processed_summary, confirmado = splitturn.gerar_resumo_dividido(
      history_msgs, prefix_msgs, build_summary_prompt,
      { pensar_stream = api.pensar_stream, serialize = serialize, confirm = confirm,
        comp_active = compaction_active, cfg = ctx.cfg, max_tentativas = c.confirm_max_tentativas })
  else
    local serialized_history = serialize.serialize_messages(discarded)
    local function build_comp_ctx()
      local system_prompt, user_content = build_summary_prompt(serialized_history)
      return {
        cfg = ctx.cfg, active = compaction_active, tokens = 0, no_tools = true,
        msgs = {
          { role = "system", content = system_prompt },
          { role = "user",   content = user_content },
          { role = "assistant", content = "Histórico recebido. Iniciando compactação..." }
        }
      }
    end
    processed_summary, confirmado = confirm.gerar_e_confirmar(
      api.pensar_stream, build_comp_ctx, compaction_active, ctx.cfg, c.confirm_max_tentativas)
  end

  if not processed_summary then
    io.write("\n\27[38;5;203m❌ Falha na compactação: nenhuma tentativa de resumo foi gerada.\27[0m\n\n")
    io.flush()
    return false, "api_error"
  end
  if not confirmado then
    io.write("\n\27[38;5;220m⚠️  Resumo não confirmado no turno de verificação — usando a melhor versão gerada.\27[0m\n\n")
    io.flush()
  end

  local attention_xml, details = filetracking.accumulate(prev_details, ctx.session_files)

  local new_msgs = {}
  for i = 1, safe_start do new_msgs[#new_msgs + 1] = ctx.msgs[i] end
  new_msgs[#new_msgs + 1] = {
    role    = "user",
    content = "[ESTADO DO SISTEMA CONDENSADO]\n\n" .. processed_summary .. attention_xml
  }
  for i = safe_end, #ctx.msgs do new_msgs[#new_msgs + 1] = ctx.msgs[i] end

  local persisted_source = {}
  for i = 1, safe_start do persisted_source[#persisted_source + 1] = ctx.msgs[i] end
  for i = safe_end, #ctx.msgs do persisted_source[#persisted_source + 1] = ctx.msgs[i] end

  ctx.msgs = sanitize_roles(new_msgs)
  ctx.tokens = api.estimate_tokens(ctx.msgs)

  local persisted_msgs = sanitize_roles(persisted_source)
  session.save_compaction(processed_summary, tokens_before, persisted_msgs, details)
  session.save_session_tokens(ctx.tokens, true)
  mf.marcar_flush(ctx.tokens)

  local misc = require("ui.misc")
  local end_time = os.date("%H:%M")
  misc.footer(ctx.tokens, ctx.active.context_window, 0, end_time)

  return true, processed_summary
end

function M.do_compaction_guarded(ctx, custom_instructions)
  ctx._compactacoes_sem_progresso = ctx._compactacoes_sem_progresso or 0
  if ctx._compactacoes_sem_progresso >= MAX_TENTATIVAS_SEM_PROGRESSO then
    return false, "thrashing"
  end

  local mf_cfg = M.get_mf_config(ctx)

  if M.poda_mecanica(ctx) and not mf.deve_compactar(ctx.tokens, mf_cfg) then
    ctx._compactacoes_sem_progresso = 0
    return true, "poda_mecanica"
  end

  local sucesso, resultado = M.do_compaction(ctx, custom_instructions)

  if sucesso and not mf.deve_compactar(ctx.tokens, mf_cfg) then
    ctx._compactacoes_sem_progresso = 0
    return sucesso, resultado
  end

  ctx._compactacoes_sem_progresso = ctx._compactacoes_sem_progresso + 1
  return sucesso, resultado
end

return M
