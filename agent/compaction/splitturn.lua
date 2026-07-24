-- splitturn.lua — REQ-2: detecta corte no meio de um turno (ex: uma
-- sequência de tool_calls tão grande que sozinha já passa da janela
-- recente) e gera DOIS resumos — histórico completo + início do turno
-- cortado — depois junta os dois. Sem isso, um turno gigante cortado no
-- meio perderia o que aconteceu no começo dele.
local M = {}

-- Acha o índice do "user" que inicia o turno onde safe_end cai. Se
-- safe_end já É um "user" (turno limpo), retorna o próprio safe_end —
-- ou seja, sem split. floor_idx (a âncora) nunca é ultrapassado.
function M.find_turn_start(msgs, safe_end, floor_idx)
  local i = safe_end
  while i > floor_idx do
    if msgs[i].role == "user" then return i end
    i = i - 1
  end
  return floor_idx
end

local function build_prefix_prompt(serialized_prefix)
  local system_prompt = "Você é o CompactAgent do TermAI. Vai receber o INÍCIO de uma tarefa "
    .. "que foi interrompida no meio pra liberar espaço de contexto — o restante dela ainda "
    .. "está ativo na conversa, você não viu. Resuma em poucas linhas o que essa tarefa estava "
    .. "tentando fazer e o que já foi feito até aqui. Não invente o que vem depois. Responda "
    .. "APENAS com o resumo, sem marcação especial no final."
  local user_content = "[INÍCIO DE TURNO INTERROMPIDO]\n\n" .. serialized_prefix
  return system_prompt, user_content
end

local function gerar(pensar_stream, confirm, comp_active, cfg, max_tentativas, system_prompt, user_content, seed)
  local function build()
    return {
      cfg = cfg, active = comp_active, tokens = 0, no_tools = true,
      msgs = {
        { role = "system", content = system_prompt },
        { role = "user", content = user_content },
        { role = "assistant", content = seed },
      }
    }
  end
  return confirm.gerar_e_confirmar(pensar_stream, build, comp_active, cfg, max_tentativas)
end

-- history_msgs: mensagens completas ANTES do turno cortado (pode vir
-- vazio). prefix_msgs: início do turno cortado (nunca vazio quando esta
-- função é chamada). build_history_prompt(serialized) -> (system, user) —
-- mesma função do caminho sem split (já traz merge REQ-3 e foco REQ-11).
-- deps = { pensar_stream, serialize, confirm, comp_active, cfg, max_tentativas }
function M.gerar_resumo_dividido(history_msgs, prefix_msgs, build_history_prompt, deps)
  local history_summary, history_ok = nil, true
  if #history_msgs > 0 then
    local serialized = deps.serialize.serialize_messages(history_msgs)
    local sp, uc = build_history_prompt(serialized)
    history_summary, history_ok = gerar(deps.pensar_stream, deps.confirm, deps.comp_active,
      deps.cfg, deps.max_tentativas, sp, uc, "Histórico recebido. Iniciando compactação...")
  end

  local prefix_serialized = deps.serialize.serialize_messages(prefix_msgs)
  local psp, puc = build_prefix_prompt(prefix_serialized)
  local prefix_summary, prefix_ok = gerar(deps.pensar_stream, deps.confirm, deps.comp_active,
    deps.cfg, deps.max_tentativas, psp, puc, "Recebido. Resumindo o turno em andamento...")

  if not history_summary and not prefix_summary then
    return nil, false
  end

  local partes = {}
  if history_summary then partes[#partes + 1] = history_summary end
  if prefix_summary then
    partes[#partes + 1] = "---\n\n**Contexto do turno em andamento (dividido):**\n\n" .. prefix_summary
  end
  return table.concat(partes, "\n\n"), (history_ok and prefix_ok)
end

return M
