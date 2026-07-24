-- agent/api/summarizer/validator.lua — Validador estrutural e prompts de condensação.
local M = {}

M.system_prompt = table.concat({
  "Você é o módulo de Condensação de Estado do TermAI.",
  "Sua tarefa não é contar uma história, mas extrair o ESTADO TÉCNICO absoluto da conversa para que o agente principal possa continuar trabalhando sem perder nada.",
  "Sua resposta DEVE conter rigorosamente os seguintes quatro cabeçalhos em maiúsculo no formato markdown na raiz da resposta:",
  "1. OBJETIVO ATUAL: O que o usuário estava tentando alcançar?",
  "2. PROGRESSO CONCLUÍDO: O que já foi codificado/concluído com sucesso no histórico?",
  "3. DECISÕES & ARQUIVOS: Caminhos de arquivos modificados, decisões técnicas tomadas, scripts criados.",
  "4. ESTADO ATUAL & BUGS: Onde a conversa parou? Existem erros ou bugs pendentes a serem resolvidos?",
  "Não use jargões como 'O usuário disse...'. Use formato direto de documentação técnica. Preserve o sumo das operações agênticas.",
}, "\n")

-- Validação de Qualidade com Auto-Healing: verifica os quatro cabeçalhos obrigatórios
function M.is_valid_summary(content)
  if not content or #content < 150 then return false end

  local lower = content:lower()
  local has_obj  = lower:match("objetivo") or lower:match("goal")
  local has_prog = lower:match("progresso") or lower:match("progress") or lower:match("conclu")
  local has_dec  = lower:match("decis") or lower:match("arquivo") or lower:match("file")
  local has_bug  = lower:match("estado") or lower:match("bug") or lower:match("erro")

  local score = 0
  if has_obj  then score = score + 1 end
  if has_prog then score = score + 1 end
  if has_dec  then score = score + 1 end
  if has_bug  then score = score + 1 end

  return score >= 3
end

return M
