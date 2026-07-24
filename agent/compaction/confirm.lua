-- confirm.lua — REQ-8: turno 1 (summary_merge.lua) gera SÓ o resumo,
-- sem marcador nenhum. Turno 2, aqui, é SEPARADO e faz uma coisa só:
-- sinalizar que acabou, sem julgar qualidade (isso seria redundante com
-- o turno 1). Se o turno 2 não confirmar, refaz o turno 1. Espelha o
-- Memory Flush: gerar e confirmar são chamadas diferentes.
local M = {}

local MAX_TENTATIVAS_PADRAO <const> = 2

-- Rede de segurança: turno 1 não é mais instruído a incluir [COMP_DONE],
-- mas se algum modelo soltar isso por hábito, ainda limpa.
local function extrai_resumo(texto)
  local marker_idx = texto:find("%[COMP_DONE%]")
  if marker_idx then
    return texto:sub(1, marker_idx - 1):match("^%s*(.-)%s*$") or ""
  end
  return texto:match("^%s*(.-)%s*$") or ""
end

-- Turno 2: só sinaliza conclusão, não avalia o conteúdo do resumo.
local function confirmar(pensar_stream, comp_active, cfg, resumo)
  local confirm_ctx = {
    cfg = cfg, active = comp_active, tokens = 0, no_tools = true,
    msgs = {
      { role = "system", content = "Você é o sinalizador de conclusão do TermAI. Um resumo "
        .. "técnico acabou de ser gerado por outro processo. Sua única tarefa é confirmar que "
        .. "a compactação terminou, respondendo ESTRITAMENTE com a palavra [COMP_DONE], em "
        .. "maiúsculo, e mais nada. Não use ferramentas, não escreva mais nada além disso." },
      { role = "user", content = "[RESUMO GERADO]\n\n" .. resumo .. "\n\nConfirme." },
      { role = "assistant", content = "Confirmando..." },
    }
  }
  local resposta, is_overflow = pensar_stream(confirm_ctx, nil, nil)
  if is_overflow or not resposta then return false end
  return resposta:match("%[COMP_DONE%]") ~= nil
end

-- build_comp_ctx() devolve uma comp_ctx NOVA a cada chamada. Retorna
-- (resumo, confirmado) — confirmado=false com resumo não-nil é fallback
-- (melhor tentativa, nenhuma confirmada). (nil, false) só se nem uma
-- geração válida saiu do turno 1.
function M.gerar_e_confirmar(pensar_stream, build_comp_ctx, comp_active, cfg, max_tentativas)
  max_tentativas = max_tentativas or MAX_TENTATIVAS_PADRAO
  local melhor_resumo = nil
  for _ = 1, max_tentativas do
    local comp_ctx = build_comp_ctx()
    comp_ctx.no_tools = true
    local summary, is_overflow = pensar_stream(comp_ctx, nil, nil)
    if not (is_overflow or not summary or summary == "" or summary:match("^%[ERRO")) then
      local candidato = extrai_resumo(summary)
      if candidato ~= "" then
        melhor_resumo = candidato
        if confirmar(pensar_stream, comp_active, cfg, candidato) then
          return candidato, true
        end
      end
    end
  end
  return melhor_resumo, false
end

return M
