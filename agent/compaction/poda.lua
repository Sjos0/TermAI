-- poda.lua — Poda mecânica de tool results antigos (REQ-10). Sem chamada
-- de LLM: tenta liberar espaço truncando resultados de ferramenta grandes
-- que já saíram da janela "recente" protegida, antes de escalar pro
-- pipeline caro de compactação via LLM. Se resolver sozinha, economiza
-- uma chamada inteira de modelo premium.
local M = {}

-- estimate_fn: mesma injeção de dependência do cutpoint.lua (evita
-- acoplar este módulo a agent.api).
-- Retorna true se algo foi podado (ctx.tokens deve ser recalculado pelo
-- chamador depois), false se não havia nada a podar.
function M.poda_mecanica(msgs, keep_recent_tokens, max_chars, estimate_fn)
  local total = #msgs
  if total == 0 then return false end
  max_chars = max_chars or 500

  -- Optimization (Bolt): Reusable scratch table to avoid GC thrashing/table allocations in the high-frequency loop
  local scratch = {}

  -- Mesma lógica de "janela recente" do REQ-1: tudo daqui pra trás fica
  -- intocado; só o que já ficou "velho" é candidato à poda.
  local acc = 0
  local recent_from = 1
  for i = total, 1, -1 do
    scratch[1] = msgs[i]
    acc = acc + estimate_fn(scratch)
    if acc >= keep_recent_tokens then
      recent_from = i
      break
    end
  end
  scratch[1] = nil

  local podou = false
  for i = 1, recent_from - 1 do
    local m = msgs[i]
    if m and m.role == "tool" and m.content and #m.content > max_chars then
      local tamanho_original = #m.content
      m.content = m.content:sub(1, max_chars)
        .. string.format("\n\n[... %d caracteres podados (resultado antigo de ferramenta)]",
                          tamanho_original - max_chars)
      podou = true
    end
  end

  return podou
end

return M
