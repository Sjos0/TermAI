-- cutpoint.lua — Encontra um ponto de corte seguro para o State Reset e
-- calcula os limites de âncora/foco por orçamento de tokens (REQ-1).
-- Nunca separa um tool_call (assistant com .tool_calls) dos seus role="tool"
-- correspondentes — quebrar esse par 1:1 faz o provider rejeitar o
-- histórico inteiro (mesmo risco documentado em tool_runner.lua).
local M = {}

local function is_safe_cut(msgs, idx)
  local atual = msgs[idx]
  if not atual then return true end
  if atual.role == "tool" then return false end
  -- Se o ATUAL é assistant com tool_calls, cortar aqui descarta os
  -- tool results que vêm logo depois — par quebrado.
  if atual.role == "assistant" and atual.tool_calls and #atual.tool_calls > 0 then
    return false
  end
  -- Se o ANTERIOR é assistant com tool_calls, este idx é um tool
  -- result que precisa ficar junto com o par.
  local anterior = msgs[idx - 1]
  if anterior and anterior.role == "assistant"
     and anterior.tool_calls and #anterior.tool_calls > 0 then
    return false
  end
  return true
end

-- Caminha SÓ pra frente a partir do corte desejado até achar um índice
-- seguro. Pode preservar mensagens extras, nunca menos — nunca corrompe.
function M.find_safe_keep_from(msgs, desired)
  local idx = math.max(desired, 1)
  while idx <= #msgs and not is_safe_cut(msgs, idx) do
    idx = idx + 1
  end
  if idx > #msgs then return #msgs end
  return idx
end

-- REQ-1: acha o fim da âncora (preâmbulo, com teto de tokens) e o início
-- do foco (janela recente, por orçamento de tokens), sempre respeitando
-- os cortes seguros acima. Substitui a antiga janela fixa 5/5.
--
-- estimate_fn(msgs_subset) -> number : injeção de dependência — cutpoint.lua
-- não conhece agent.api, evita acoplamento/import circular.
--
-- Retorna (safe_start, safe_end) em caso de sucesso — âncora é msgs[1..safe_start],
-- foco é msgs[safe_end..#msgs], miolo descartável é msgs[safe_start+1..safe_end-1].
-- Retorna (nil, motivo) se não houver histórico suficiente pra compactar
-- com segurança ("short_history").
function M.find_compaction_bounds(msgs, opts, estimate_fn)
  opts = opts or {}
  local total = #msgs
  local anchor_keep      = opts.anchor_keep or 5
  local anchor_token_cap = opts.anchor_token_cap or 8000
  local keep_recent      = opts.keep_recent_tokens or 20000

  if total < (anchor_keep + 3) then
    return nil, "short_history"
  end

  -- Âncora: encolhe a partir de anchor_keep enquanto exceder o teto de tokens
  local anchor_end = math.min(anchor_keep, total)
  while anchor_end > 1 do
    local slice = {}
    for i = 1, anchor_end do slice[#slice + 1] = msgs[i] end
    if estimate_fn(slice) <= anchor_token_cap then break end
    anchor_end = anchor_end - 1
  end
  local safe_start = M.find_safe_keep_from(msgs, anchor_end + 1) - 1

  -- Optimization (Bolt): Reusable scratch table to avoid GC thrashing/table allocations in the high-frequency loop
  local scratch = {}

  -- Foco: anda de trás pra frente acumulando tokens até keep_recent
  local acc = 0
  local cut_candidate = nil
  for i = total, safe_start + 1, -1 do
    scratch[1] = msgs[i]
    acc = acc + estimate_fn(scratch)
    if acc >= keep_recent then
      cut_candidate = i
      break
    end
  end
  scratch[1] = nil

  if not cut_candidate then
    -- Tudo depois da âncora cabe na janela recente — nada de relevante a
    -- descartar. Evita compactação inútil (miolo vazio ou quase vazio).
    return nil, "short_history"
  end
  local safe_end = M.find_safe_keep_from(msgs, cut_candidate)

  if safe_start + 1 >= safe_end then
    return nil, "short_history"
  end

  return safe_start, safe_end
end

M.is_safe_cut = is_safe_cut
return M
