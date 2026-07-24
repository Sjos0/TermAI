-- summary_merge.lua — REQ-3 (merge iterativo com resumo anterior) e
-- REQ-11 (foco customizável): busca o resumo da última compactação
-- persistida e monta os prompts system/user da chamada de resumo.
-- Turno 1 (aqui) só gera o resumo puro — o sinal de conclusão é
-- responsabilidade exclusiva do turno 2, em confirm.lua.
local M = {}

local BASE_SYSTEM_PROMPT = "Você é o CompactAgent, um processo interno especializado do TermAI. "
  .. "Sua única tarefa é ler o histórico de operações agênticas fornecido e gerar um resumo "
  .. "técnico altamente condensado, objetivo e coerente do progresso, decisões técnicas, "
  .. "caminhos de arquivos e estado de bugs da conversa. Não use falas de chat, comentários "
  .. "pessoais ou introduções (como 'Aqui está o resumo...'). Responda APENAS com o resumo "
  .. "técnico de forma objetiva, sem nenhuma marcação ou tag especial no final."

local UPDATE_SUFFIX = " Você recebeu também o RESUMO ANTERIOR de uma compactação prévia desta "
  .. "mesma sessão. Sua tarefa agora é FUNDIR (merge) o resumo anterior com o histórico novo "
  .. "abaixo em UM ÚNICO resumo atualizado — preserve as decisões, arquivos e estado de bugs "
  .. "do resumo anterior que ainda sejam relevantes, e incorpore o progresso novo. Não "
  .. "descarte informação do resumo anterior sem necessidade."

function M.get_previous(session_mod)
  local ok, r1, r2 = pcall(function() return session_mod.get_last_compaction() end)
  if ok then return r1, r2 end
  return nil, nil
end

function M.build_prompt(serialized_history, prev_summary, custom_instructions)
  local system_prompt = BASE_SYSTEM_PROMPT
  if prev_summary then
    system_prompt = system_prompt .. UPDATE_SUFFIX
  end
  if custom_instructions and custom_instructions ~= "" then
    system_prompt = system_prompt
      .. " O usuário pediu foco específico neste resumo: \"" .. custom_instructions
      .. "\" — priorize isso, mas sem inventar informação que não está no histórico."
  end

  local user_content = "[HISTÓRICO DA SESSÃO A SER COMPACTADO]\n\n" .. serialized_history
  if prev_summary then
    user_content = "[RESUMO ANTERIOR]\n\n" .. prev_summary
      .. "\n\n[HISTÓRICO NOVO A INCORPORAR]\n\n" .. serialized_history
  end

  return system_prompt, user_content
end

return M
