-- agent/flush.lua — Executa o Memory Flush em contexto ISOLADO.
-- Flush Protocol Monitor (FPM) — supervisor de estado do protocolo de Memory Flush.
-- ARQUITETURA: Recebe apenas as mensagens NOVAS desde o último flush,
-- não toda a conversa. Isso reduz alucinações e melhora a precisão do resumo.
-- O agente de flush NÃO TEM ACESSO ao histórico completo da sessão principal.

local api         = require("agent.api")
local tool_runner = require("agent.loop.tool_runner")
local tools       = require("tools")

local M = {}

-- Formata as mensagens novas como um bloco de texto legível.
-- Remove o XML de tools para evitar o "Mimicry Bug" (onde o modelo tenta imitar o histórico).
local function format_context(msgs)
  if #msgs == 0 then
    return "[Nenhuma mensagem nova desde o último Flush]"
  end
  local parts = {}
  for _, m in ipairs(msgs) do
    if m.role == "user" or m.role == "assistant" then
      local role    = m.role == "user" and "USUÁRIO" or "AGENTE"
      local content = m.content or ""

      -- Removemos completamente as tool calls e resultados.
      -- Deixar "marcas falsas" confunde o modelo durante a extração de memória.
      content = content:gsub("<tool>.-</tool>", "")
      content = content:gsub("<tool_result[^>]*>.-</tool_result>", "")

      -- Trunca mensagens gigantescas para o flush context não explodir em tokens
      if #content > 1500 then
        content = content:sub(1, 1500) .. "\n… [truncado]"
      end
      if content:match("^%s*$") then goto continue end
      parts[#parts + 1] = "[" .. role .. "]\n" .. content
      ::continue::
    end
  end
  return #parts > 0
    and table.concat(parts, "\n\n" .. string.rep("─", 30) .. "\n\n")
    or  "[Contexto sem mensagens relevantes]"
end

-- Executa o flush em contexto isolado (Sandbox).
-- ctx: contexto principal (para active/cfg — não é modificado!)
-- new_msgs: apenas as mensagens recentes
function M.run(ctx, new_msgs, flush_prompt)
  local context_text = format_context(new_msgs)

  -- System prompt mínimo: apenas tools + regra de confidencialidade
  -- Sem SOUL.md, IDENTITY.md etc. — o MemoryFlush não tem personalidade, é um operário.
  local system = table.concat({
    "Você é o MemoryFlush, um processo interno do TermAI.",
    "Sua única função é arquivar memórias. Siga o protocolo rigorosamente.",
  }, "\n")

  -- Criação da Sandbox (Contexto isolado)
  local flush_ctx = {
    cfg      = ctx.cfg,
    active   = ctx.active,
    tokens   = 0,
    MAX_ITER = 10,  -- limite para o flush completar todos os passos sem loop infinito
    msgs     = {
      { role = "system",    content = system },
      { role = "user",      content = "[CONTEXTO DO CICLO ATUAL]\n\n" .. context_text },
      { role = "assistant", content = "Contexto recebido. Iniciando protocolo de flush." },
    },
    flush_state = {
      exec = false,
      read = false,
      edit = false,
      done = false,
    },
  }

  function flush_ctx.flush_state.reset()
    flush_ctx.flush_state.exec = false
    flush_ctx.flush_state.read = false
    flush_ctx.flush_state.edit = false
    flush_ctx.flush_state.done = false
  end

  -- Detecta gates do protocolo baseado em tool_calls e resposta
  -- FPM: GateDetector — inspeciona tool_calls reais e atualiza flush_state
  local function detect_gates(tool_calls, resp, flush_state, tool_results)
    tool_results = tool_results or {}
    if tool_calls and #tool_calls > 0 then
      for i, tc in ipairs(tool_calls) do
        local func = tc["function"] or tc
        local name = func.name or tc.name
        local args = func.arguments or tc.arguments or ""
        local args_str = type(args) == "string" and args or (type(args) == "table" and (args.file or args.path or "") or "")

        if not flush_state.exec then
          if name == "exec" and (args_str:match("date") or args_str:match("%%Y") or args_str:match("%%A")) then
            flush_state.exec = true
          end
        end

        if not flush_state.read then
          if name == "Read" and (args_str:match("memory/") or args_str:match("%.md")) then
            flush_state.read = true
          end
        end

        if not flush_state.edit then
          if (name == "Edit" or name == "Write") and (args_str:match("memory/") or args_str:match("%.md")) then
            local result = tool_results[i]
            if result == nil or result == true or (type(result) == "string" and result:match("Sucesso")) then
              flush_state.edit = true
            end
          end
        end
      end
    end
    if not flush_state.done and resp and resp:match("%[FLUSH_DONE%]") then
      flush_state.done = true
    end
  end

  -- Gera o XML <FLUSH_STATUS> com checkmarks
  -- FPM: ChecklistRenderer — mostra o progresso do protocolo
  local function render_checklist(fs)
    local x = "[x]"
    local o = "[ ]"
    return string.format("<FLUSH_STATUS>\\n  %s exec  %s read  %s edit  %s done\\n</FLUSH_STATUS>",
      fs.exec and x or o, fs.read and x or o, fs.edit and x or o, fs.done and x or o)
  end

  -- FlushLoop próprio (FPM) — loop ReAct headless com monitoramento de estado.
  -- NÃO chama ag_loop.rodar: evitamos ui.*, _mem.search, boot injection.
  local iter = 0
  local cur_text = flush_prompt
  local cur_role = "user"
  local limit = flush_ctx.MAX_ITER or 10

  while iter < limit do
    iter = iter + 1

    -- Injeta o checklist no prompt (FPM: ChecklistRenderer)
    local checklist = render_checklist(flush_ctx.flush_state)
    local prompt_com_checklist = nil

    if cur_text then
      prompt_com_checklist = cur_text .. "\n\n" .. checklist
    else
      -- Se cur_text é nil (iterações subsequentes), injeta ou substitui o checklist na última
      -- mensagem de histórico, independente de role (Mitiga Problemas 1 e 2 do Ameno)
      local last_msg = flush_ctx.msgs[#flush_ctx.msgs]
      if last_msg then
        if last_msg.content:match('<FLUSH_STATUS>') then
          last_msg.content = last_msg.content:gsub('<FLUSH_STATUS>.-</FLUSH_STATUS>', checklist)
        else
          last_msg.content = last_msg.content .. '\n\n' .. checklist
        end
      end
    end


    -- Chama a API sem UI (headless)
    local resp, is_overflow, _, _, tool_calls =
      api.pensar_stream(flush_ctx, prompt_com_checklist, cur_role)

    if is_overflow then
      return false  -- overflow do provedor = desiste graciosamente
    end

    -- Processa tool_calls (caminho nativo JSON)
    if tool_calls and #tool_calls > 0 then
      tool_runner.run_batch(flush_ctx, tool_calls)

      -- Detecta gates baseado nas tool_calls executadas
      -- tool_results não estão disponíveis diretamente; detect_gates
      -- usa o resp para FLUSH_DONE e as tool_calls originais
      detect_gates(tool_calls, resp or "", flush_ctx.flush_state)

      cur_text = nil
      cur_role = nil

      if flush_ctx.flush_state.done then
        return true
      end
    else
      -- Resposta sem tool_calls: verifica FLUSH_DONE no texto
      detect_gates({}, resp or "", flush_ctx.flush_state)

      if flush_ctx.flush_state.done then
        return true
      end
    end
  end

  -- MAX_ITER estourado sem completar = desiste graciosamente
  return false
end

return M
