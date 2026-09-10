-- agent/loop/xml_path.lua — Caminho legado XML do loop ReAct + retries vazio/unfulfilled.
local ui = require("ui")
local th = require("agent.tools_handler")
local response_utils = require("agent.loop.response_utils")

local M = {}

--- Processa um turno sem tool_calls nativos (parse XML legado).
-- @param ctx table
-- @param resp string Resposta bruta da API
-- @param reasoning string|nil
-- @param stream_complete boolean
-- @param elapsed number
-- @param vazio_count number Contador atual de retries
-- @param max_vazio_retries number Limite de retries
-- @return table Resultado estruturado com action "return" | "continue" | "retry"
function M.handle(ctx, resp, reasoning, stream_complete, elapsed, vazio_count, max_vazio_retries)
  local texto, ferramentas, pre_feedback = th.parsear(resp)
  local display_text     = response_utils.strip_flush_tag(texto)
  local has_pre_feedback = pre_feedback and pre_feedback ~= ""

  if #ferramentas > 0 or has_pre_feedback then
    if display_text ~= "" then ui.ai_msg_stream(display_text) end
    local exec_result = ""
    local iter_delta = 0
    if #ferramentas > 0 then
      exec_result = th.executar(ferramentas)
      iter_delta = 1
    end
    local cur_text = has_pre_feedback
      and (exec_result .. (exec_result ~= "" and "\n\n" or "") .. pre_feedback)
      or exec_result

    if resp:match("%[FLUSH_DONE%]") then
      return {
        action = "return",
        resp = resp,
        elapsed = elapsed,
        flush_done = true,
        is_overflow = false,
        stream_complete = stream_complete,
        last_reasoning = "",
      }
    end

    return {
      action = "continue",
      iter_delta = iter_delta,
      cur_text = cur_text,
      cur_role = "user",
      last_reasoning = "",
    }
  end

  -- Sem ferramentas: resposta final, vazia ou unfulfilled
  local is_vazio = (display_text == "" or display_text == "[vazio]")
                   and not resp:match("^%[ERRO")
                   and not resp:match("%[FLUSH_DONE%]")
  local is_unfulfilled = not is_vazio
                      and response_utils.is_unfulfilled_intent(display_text)
                      and not resp:match("^%[ERRO")
                      and not resp:match("%[FLUSH_DONE%]")

  if (is_vazio or is_unfulfilled) and vazio_count < max_vazio_retries then
    local new_count = vazio_count + 1
    local cur_text
    if is_unfulfilled then
      ui.ai_msg_stream(display_text)
      cur_text = "[SISTEMA] Você anunciou uma ação mas não chamou "
               .. "nenhuma ferramenta. Prossiga executando agora o "
               .. "que foi anunciado."
    else
      cur_text = (reasoning and reasoning ~= "")
        and "[SISTEMA] Você estava processando mas não emitiu resposta. "
         .. "Revise o raciocínio anterior e entregue a resposta completa."
        or  "[SISTEMA] Continue de onde parou e revise o que estava fazendo."
    end
    local tag = is_unfulfilled and "anúncio sem execução" or "resposta vazia"
    io.write("\27[38;5;245m[auto-retry " .. new_count
      .. "/" .. max_vazio_retries .. " " .. tag .. "]\27[0m\n")
    io.flush()
    return {
      action = "retry",
      vazio_count = new_count,
      cur_text = cur_text,
      cur_role = "user",
    }
  end

  -- Resposta final (ou esgotou retries)
  if is_vazio then
    io.write("\27[38;5;203m⚠️  Agente sem resposta após "
      .. max_vazio_retries .. " tentativas automáticas.\27[0m\n\n")
    io.flush()
  elseif display_text ~= "" then
    ui.ai_msg_stream(display_text)
  end

  local flush_done = resp:match("%[FLUSH_DONE%]") ~= nil
  return {
    action = "return",
    resp = resp,
    elapsed = elapsed,
    flush_done = flush_done,
    is_overflow = false,
    stream_complete = stream_complete,
    last_reasoning = reasoning or "",
  }
end

return M
